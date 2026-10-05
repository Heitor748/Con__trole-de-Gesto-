import {
  GestureRecognizer,
  FilesetResolver,
} from "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/vision_bundle.mjs";

const video = document.getElementById("video");
const overlay = document.getElementById("overlay");
const ctx = overlay.getContext("2d");
const statusEl = document.getElementById("status");
const gestureEl = document.getElementById("gesture");
const hostInput = document.getElementById("host");
const portInput = document.getElementById("port");

// Por padrão, conecta no mesmo servidor que serviu esta página.
hostInput.value = localStorage.getItem("gpc_host") || location.hostname;
portInput.value = localStorage.getItem("gpc_port") || location.port || "8765";

let ws = null;
let gestureRecognizer = null;

// ---- Estado do mapeador de gestos (equivalente ao GestureMapper.kt) ----
const state = {
  lastWristX: null,
  lastWristY: null,
  lastFiredGesture: null,
  openPalmStillSinceMs: null,
  lastOpenPalmWristX: null,
  lastOpenPalmWristY: null,
  wasPinching: false,
};

const PINCH_THRESHOLD = 0.05;
const STILL_THRESHOLD_PX = 12;
const PLAY_PAUSE_HOLD_MS = 1000;
const MOVE_SENSITIVITY = 3.0;

function resetState() {
  state.lastWristX = null;
  state.lastWristY = null;
  state.lastFiredGesture = null;
  state.openPalmStillSinceMs = null;
  state.wasPinching = false;
}

function distance(a, b) {
  return Math.hypot(a.x - b.x, a.y - b.y);
}

function fireOnce(gestureName, label, commands) {
  if (state.lastFiredGesture === gestureName) return null;
  state.lastFiredGesture = gestureName;
  return { label, commands };
}

/** Traduz o resultado do MediaPipe em comandos de alto nível para o PC. */
function mapGesture(result, frameWidth, frameHeight, nowMs) {
  const landmarksList = result.landmarks;
  if (!landmarksList || landmarksList.length === 0) {
    resetState();
    return null;
  }
  const landmarks = landmarksList[0];
  const gestureName = result.gestures?.[0]?.[0]?.categoryName;

  const wrist = landmarks[0];
  const wristPxX = wrist.x * frameWidth;
  const wristPxY = wrist.y * frameHeight;

  // 1) Pinch (polegar + indicador) => clique esquerdo
  const pinchDistance = distance(landmarks[4], landmarks[8]);
  const isPinching = pinchDistance < PINCH_THRESHOLD;
  if (isPinching && !state.wasPinching) {
    state.wasPinching = true;
    state.openPalmStillSinceMs = null;
    return { label: "Pinch (clique esquerdo)", commands: [{ type: "click", button: "left" }] };
  }
  if (!isPinching) state.wasPinching = false;

  // 2) Punho fechado => clique direito
  if (gestureName === "Closed_Fist") {
    state.openPalmStillSinceMs = null;
    return (
      fireOnce(gestureName, "Punho fechado (clique direito)", [{ type: "click", button: "right" }]) ||
      { label: "Punho fechado (clique direito)", commands: [] }
    );
  }

  // 3) Thumbs up / down => volume
  if (gestureName === "Thumb_Up") {
    state.openPalmStillSinceMs = null;
    return (
      fireOnce(gestureName, "Joia (volume +)", [{ type: "volume", delta: 5 }]) ||
      { label: "Joia (volume +)", commands: [] }
    );
  }
  if (gestureName === "Thumb_Down") {
    state.openPalmStillSinceMs = null;
    return (
      fireOnce(gestureName, "Joia invertida (volume -)", [{ type: "volume", delta: -5 }]) ||
      { label: "Joia invertida (volume -)", commands: [] }
    );
  }

  // 4) Sinal de V movendo horizontalmente => próximo/anterior
  if (gestureName === "Victory") {
    state.openPalmStillSinceMs = null;
    const prevX = state.lastWristX;
    state.lastWristX = wristPxX;
    state.lastWristY = wristPxY;
    if (prevX != null) {
      const deltaX = wristPxX - prevX;
      if (deltaX > STILL_THRESHOLD_PX * 2) {
        state.lastWristX = null;
        return { label: "V (próximo)", commands: [{ type: "media", action: "next" }] };
      } else if (deltaX < -STILL_THRESHOLD_PX * 2) {
        state.lastWristX = null;
        return { label: "V (anterior)", commands: [{ type: "media", action: "prev" }] };
      }
    }
    return { label: "V (aguardando movimento)", commands: [] };
  }

  // 5) Palma aberta parada por 1s => play/pause; senão, move o cursor
  if (gestureName === "Open_Palm") {
    const prevX = state.lastOpenPalmWristX;
    const prevY = state.lastOpenPalmWristY;
    state.lastOpenPalmWristX = wristPxX;
    state.lastOpenPalmWristY = wristPxY;

    const isStill =
      prevX != null && prevY != null && Math.hypot(wristPxX - prevX, wristPxY - prevY) < STILL_THRESHOLD_PX;

    if (isStill) {
      const stillSince = state.openPalmStillSinceMs ?? (state.openPalmStillSinceMs = nowMs);
      if (nowMs - stillSince >= PLAY_PAUSE_HOLD_MS) {
        state.openPalmStillSinceMs = nowMs + 10_000;
        return { label: "Palma parada (play/pause)", commands: [{ type: "media", action: "play_pause" }] };
      }
      state.lastWristX = wristPxX;
      state.lastWristY = wristPxY;
      return { label: "Modo mouse (parado)", commands: [] };
    }

    state.openPalmStillSinceMs = null;

    const prevMoveX = state.lastWristX;
    const prevMoveY = state.lastWristY;
    state.lastWristX = wristPxX;
    state.lastWristY = wristPxY;
    if (prevMoveX != null && prevMoveY != null) {
      const dx = Math.round((wristPxX - prevMoveX) * MOVE_SENSITIVITY);
      const dy = Math.round((wristPxY - prevMoveY) * MOVE_SENSITIVITY);
      if (dx !== 0 || dy !== 0) {
        return { label: "Modo mouse (movendo)", commands: [{ type: "move", dx, dy }] };
      }
    }
    return { label: "Modo mouse", commands: [] };
  }

  state.lastFiredGesture = null;
  return null;
}

// ---- WebSocket ----
function setStatus(text, className) {
  statusEl.textContent = text;
  statusEl.className = className;
}

function connect() {
  const host = hostInput.value.trim();
  const port = portInput.value.trim();
  localStorage.setItem("gpc_host", host);
  localStorage.setItem("gpc_port", port);

  if (ws) {
    ws.close();
  }

  setStatus("Conectando...", "connecting");
  ws = new WebSocket(`wss://${host}:${port}/ws`);
  ws.onopen = () => setStatus("Conectado", "connected");
  ws.onclose = () => setStatus("Desconectado", "disconnected");
  ws.onerror = () => setStatus("Erro na conexão", "disconnected");
}

function disconnect() {
  ws?.close();
  ws = null;
  setStatus("Desconectado", "disconnected");
}

function sendCommand(command) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(command));
  }
}

document.getElementById("connectBtn").addEventListener("click", connect);
document.getElementById("disconnectBtn").addEventListener("click", disconnect);

// ---- Câmera + reconhecimento ----
async function setupCamera() {
  const stream = await navigator.mediaDevices.getUserMedia({
    video: { facingMode: "user", width: 640, height: 480 },
    audio: false,
  });
  video.srcObject = stream;
  await new Promise((resolve) => (video.onloadedmetadata = resolve));
  video.play();
  overlay.width = video.videoWidth;
  overlay.height = video.videoHeight;
}

async function setupGestureRecognizer() {
  const vision = await FilesetResolver.forVisionTasks(
    "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@0.10.14/wasm"
  );
  gestureRecognizer = await GestureRecognizer.createFromOptions(vision, {
    baseOptions: {
      modelAssetPath:
        "https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/latest/gesture_recognizer.task",
      delegate: "GPU",
    },
    runningMode: "VIDEO",
    numHands: 1,
  });
}

function drawLandmarks(landmarksList) {
  ctx.clearRect(0, 0, overlay.width, overlay.height);
  if (!landmarksList) return;
  ctx.fillStyle = "#3a7bd5";
  for (const landmarks of landmarksList) {
    for (const point of landmarks) {
      ctx.beginPath();
      ctx.arc(point.x * overlay.width, point.y * overlay.height, 4, 0, 2 * Math.PI);
      ctx.fill();
    }
  }
}

function processFrame() {
  if (gestureRecognizer && video.readyState >= 2) {
    const nowMs = performance.now();
    const result = gestureRecognizer.recognizeForVideo(video, nowMs);
    drawLandmarks(result.landmarks);

    const mapped = mapGesture(result, video.videoWidth, video.videoHeight, nowMs);
    if (mapped) {
      if (mapped.label) gestureEl.textContent = `Último gesto: ${mapped.label}`;
      mapped.commands.forEach(sendCommand);
    }
  }
  requestAnimationFrame(processFrame);
}

async function main() {
  try {
    await setupCamera();
    await setupGestureRecognizer();
    requestAnimationFrame(processFrame);
  } catch (err) {
    console.error(err);
    gestureEl.textContent = `Erro: ${err.message}`;
  }
}

main();
