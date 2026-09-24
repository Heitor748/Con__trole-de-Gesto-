package com.gesturepc.control.gesture

import com.gesturepc.control.model.Command
import com.gesturepc.control.model.MediaAction
import com.gesturepc.control.model.MouseButton
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizerResult
import kotlin.math.hypot

/** Nomes de gesto retornados pelo modelo padrão do MediaPipe Gesture Recognizer. */
private object MpGesture {
    const val CLOSED_FIST = "Closed_Fist"
    const val OPEN_PALM = "Open_Palm"
    const val VICTORY = "Victory"
    const val THUMB_UP = "Thumb_Up"
    const val THUMB_DOWN = "Thumb_Down"
}

/** Landmarks da mão, na indexação padrão do MediaPipe Hand Landmarker. */
private object Landmark {
    const val WRIST = 0
    const val THUMB_TIP = 4
    const val INDEX_TIP = 8
}

/** Resultado do mapeamento: comandos a enviar e um rótulo legível para a UI. */
data class MappedGesture(
    val label: String,
    val commands: List<Command>
)

/**
 * Traduz o resultado bruto do MediaPipe (categoria de gesto + landmarks da mão)
 * em comandos de alto nível para o PC. Mantém um pequeno estado interno para:
 *  - calcular o movimento relativo do cursor (posição anterior do punho),
 *  - detectar "pinch" (polegar + indicador unidos) para clique esquerdo,
 *  - debouncar gestos que devem disparar uma única vez (fechar punho, joia, palma parada).
 */
class GestureMapper(
    private val frameWidth: Int = 640,
    private val frameHeight: Int = 480,
    private val moveSensitivity: Float = 3.0f
) {
    private var lastWristX: Float? = null
    private var lastWristY: Float? = null

    private var lastFiredGesture: String? = null
    private var openPalmStillSinceMs: Long? = null
    private var lastOpenPalmWristX: Float? = null
    private var lastOpenPalmWristY: Float? = null

    private val pinchThreshold = 0.05f // distância normalizada entre polegar e indicador
    private var wasPinching = false

    private val stillThresholdPx = 12f
    private val playPauseHoldMs = 1000L

    fun reset() {
        lastWristX = null
        lastWristY = null
        lastFiredGesture = null
        openPalmStillSinceMs = null
        wasPinching = false
    }

    fun map(result: GestureRecognizerResult, nowMs: Long): MappedGesture? {
        val landmarksList = result.landmarks()
        if (landmarksList.isEmpty()) {
            reset()
            return null
        }
        val landmarks = landmarksList[0]
        val gestureName = result.gestures().firstOrNull()?.firstOrNull()?.categoryName()

        val wrist = landmarks[Landmark.WRIST]
        val wristPxX = wrist.x() * frameWidth
        val wristPxY = wrist.y() * frameHeight

        // 1) Pinch (polegar + indicador) => clique esquerdo
        val pinchDistance = distance(landmarks[Landmark.THUMB_TIP], landmarks[Landmark.INDEX_TIP])
        val isPinching = pinchDistance < pinchThreshold
        if (isPinching && !wasPinching) {
            wasPinching = true
            openPalmStillSinceMs = null
            return MappedGesture("Pinch (clique esquerdo)", listOf(Command.Click(MouseButton.LEFT)))
        }
        if (!isPinching) {
            wasPinching = false
        }

        // 2) Punho fechado => clique direito (dispara uma vez por detecção do gesto)
        if (gestureName == MpGesture.CLOSED_FIST) {
            openPalmStillSinceMs = null
            return fireOnce(gestureName, "Punho fechado (clique direito)", listOf(Command.Click(MouseButton.RIGHT)))
                ?: MappedGesture("Punho fechado (clique direito)", emptyList())
        }

        // 3) Thumbs up / thumbs down => volume
        if (gestureName == MpGesture.THUMB_UP) {
            openPalmStillSinceMs = null
            return fireOnce(gestureName, "Joia (volume +)", listOf(Command.Volume(5)))
                ?: MappedGesture("Joia (volume +)", emptyList())
        }
        if (gestureName == MpGesture.THUMB_DOWN) {
            openPalmStillSinceMs = null
            return fireOnce(gestureName, "Joia invertida (volume -)", listOf(Command.Volume(-5)))
                ?: MappedGesture("Joia invertida (volume -)", emptyList())
        }

        // 4) Sinal de V (dois dedos) movendo horizontalmente => próximo/anterior
        if (gestureName == MpGesture.VICTORY) {
            openPalmStillSinceMs = null
            val prevX = lastWristX
            lastWristX = wristPxX
            lastWristY = wristPxY
            if (prevX != null) {
                val deltaX = wristPxX - prevX
                if (deltaX > stillThresholdPx * 2) {
                    lastWristX = null
                    return MappedGesture("V (próximo)", listOf(Command.Media(MediaAction.NEXT)))
                } else if (deltaX < -stillThresholdPx * 2) {
                    lastWristX = null
                    return MappedGesture("V (anterior)", listOf(Command.Media(MediaAction.PREV)))
                }
            }
            return MappedGesture("V (aguardando movimento)", emptyList())
        }

        // 5) Palma aberta parada por 1s => play/pause; caso contrário, move o cursor
        if (gestureName == MpGesture.OPEN_PALM) {
            val prevX = lastOpenPalmWristX
            val prevY = lastOpenPalmWristY
            lastOpenPalmWristX = wristPxX
            lastOpenPalmWristY = wristPxY

            val isStill = prevX != null && prevY != null &&
                hypot((wristPxX - prevX).toDouble(), (wristPxY - prevY).toDouble()) < stillThresholdPx

            if (isStill) {
                val stillSince = openPalmStillSinceMs ?: nowMs.also { openPalmStillSinceMs = it }
                if (nowMs - stillSince >= playPauseHoldMs) {
                    openPalmStillSinceMs = nowMs + 10_000L // evita disparar repetidamente
                    return MappedGesture("Palma parada (play/pause)", listOf(Command.Media(MediaAction.PLAY_PAUSE)))
                }
                lastWristX = wristPxX
                lastWristY = wristPxY
                return MappedGesture("Modo mouse (parado)", emptyList())
            }

            openPalmStillSinceMs = null

            // Modo mouse: move o cursor de acordo com o deslocamento do punho.
            val prevMoveX = lastWristX
            val prevMoveY = lastWristY
            lastWristX = wristPxX
            lastWristY = wristPxY
            if (prevMoveX != null && prevMoveY != null) {
                val dx = ((wristPxX - prevMoveX) * moveSensitivity).toInt()
                val dy = ((wristPxY - prevMoveY) * moveSensitivity).toInt()
                if (dx != 0 || dy != 0) {
                    return MappedGesture("Modo mouse (movendo)", listOf(Command.Move(dx, dy)))
                }
            }
            return MappedGesture("Modo mouse", emptyList())
        }

        // Nenhum gesto reconhecido relevante.
        lastFiredGesture = null
        return null
    }

    /** Garante que um gesto "de disparo único" só gere comando uma vez, até o gesto mudar. */
    private fun fireOnce(gestureName: String, label: String, commands: List<Command>): MappedGesture? {
        if (lastFiredGesture == gestureName) {
            return null
        }
        lastFiredGesture = gestureName
        return MappedGesture(label, commands)
    }

    private fun distance(a: NormalizedLandmark, b: NormalizedLandmark): Float =
        hypot((a.x() - b.x()).toDouble(), (a.y() - b.y()).toDouble()).toFloat()
}
