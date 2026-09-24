package com.gesturepc.control.ui

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.gesturepc.control.camera.CameraXManager
import com.gesturepc.control.gesture.GestureMapper
import com.gesturepc.control.gesture.GestureRecognizerHelper
import com.gesturepc.control.network.ConnectionState
import com.gesturepc.control.network.WebSocketClient
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizerResult

private const val PREFS_NAME = "gesture_pc_control"
private const val KEY_HOST = "server_host"
private const val KEY_PORT = "server_port"
private const val DEFAULT_PORT = 8765

class MainActivity : ComponentActivity() {

    private lateinit var cameraManager: CameraXManager
    private lateinit var gestureHelper: GestureRecognizerHelper
    private lateinit var webSocketClient: WebSocketClient
    private val gestureMapper = GestureMapper()

    private var connectionState by mutableStateOf(ConnectionState.DISCONNECTED)
    private var lastGestureLabel by mutableStateOf("Nenhum gesto detectado")
    private var cameraPermissionGranted by mutableStateOf(false)

    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted -> cameraPermissionGranted = granted }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        webSocketClient = WebSocketClient { state -> connectionState = state }

        gestureHelper = GestureRecognizerHelper(this, object : GestureRecognizerHelper.RecognitionListener {
            override fun onResult(result: GestureRecognizerResult, inputWidth: Int, inputHeight: Int) {
                val mapped = gestureMapper.map(result, System.currentTimeMillis()) ?: return
                if (mapped.label.isNotBlank()) {
                    lastGestureLabel = mapped.label
                }
                mapped.commands.forEach { command -> webSocketClient.send(command) }
            }

            override fun onError(error: String) {
                lastGestureLabel = "Erro: $error"
            }
        })
        gestureHelper.setup()

        cameraPermissionGranted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
        if (!cameraPermissionGranted) {
            requestPermissionLauncher.launch(Manifest.permission.CAMERA)
        }

        cameraManager = CameraXManager(this, this)

        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    GesturePcControlScreen(
                        cameraPermissionGranted = cameraPermissionGranted,
                        connectionState = connectionState,
                        lastGestureLabel = lastGestureLabel,
                        onStartCamera = { previewView ->
                            cameraManager.start(previewView) { imageProxy ->
                                gestureHelper.recognizeAsync(imageProxy)
                            }
                        },
                        onConnect = { host, port -> webSocketClient.connect(host, port) },
                        onDisconnect = { webSocketClient.disconnect() }
                    )
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraManager.stop()
        gestureHelper.close()
        webSocketClient.shutdown()
    }
}

@Composable
private fun GesturePcControlScreen(
    cameraPermissionGranted: Boolean,
    connectionState: ConnectionState,
    lastGestureLabel: String,
    onStartCamera: (PreviewView) -> Unit,
    onConnect: (host: String, port: Int) -> Unit,
    onDisconnect: () -> Unit
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val prefs = remember { context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE) }

    var host by remember { mutableStateOf(prefs.getString(KEY_HOST, "") ?: "") }
    var portText by remember { mutableStateOf(prefs.getInt(KEY_PORT, DEFAULT_PORT).toString()) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(modifier = Modifier.fillMaxWidth()) {
            if (cameraPermissionGranted) {
                AndroidView(
                    modifier = Modifier.fillMaxWidth(),
                    factory = { ctx ->
                        PreviewView(ctx).also { previewView -> onStartCamera(previewView) }
                    }
                )
            } else {
                Text("Permissão de câmera necessária para reconhecer gestos.")
            }
        }

        Text("Status: ${connectionState.label()}")
        Text("Último gesto: $lastGestureLabel")

        OutlinedTextField(
            value = host,
            onValueChange = { host = it },
            label = { Text("IP do PC (ex: 192.168.0.10)") },
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = portText,
            onValueChange = { portText = it.filter { c -> c.isDigit() } },
            label = { Text("Porta") },
            modifier = Modifier.fillMaxWidth()
        )

        Row {
            Button(onClick = {
                val port = portText.toIntOrNull() ?: DEFAULT_PORT
                prefs.edit().putString(KEY_HOST, host).putInt(KEY_PORT, port).apply()
                onConnect(host, port)
            }) {
                Text("Conectar")
            }
            Button(onClick = { onDisconnect() }) {
                Text("Desconectar")
            }
        }
    }
}

private fun ConnectionState.label(): String = when (this) {
    ConnectionState.DISCONNECTED -> "Desconectado"
    ConnectionState.CONNECTING -> "Conectando..."
    ConnectionState.CONNECTED -> "Conectado"
}
