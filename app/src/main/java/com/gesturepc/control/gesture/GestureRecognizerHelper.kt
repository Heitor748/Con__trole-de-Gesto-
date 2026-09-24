package com.gesturepc.control.gesture

import android.content.Context
import android.util.Log
import androidx.camera.core.ImageProxy
import com.gesturepc.control.camera.ImageUtils
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizer
import com.google.mediapipe.tasks.vision.gesturerecognizer.GestureRecognizerResult

/**
 * Encapsula o MediaPipe Tasks "Gesture Recognizer" (baseado no Hand Landmarker),
 * rodando 100% on-device. Recebe frames da câmera (via CameraX) e devolve, de forma
 * assíncrona, os landmarks da mão e o gesto reconhecido pelo próprio MediaPipe
 * (ex: "Closed_Fist", "Open_Palm", "Thumb_Up", "Thumb_Down", "Victory", "Pointing_Up").
 *
 * O modelo (.task) precisa ser colocado em app/src/main/assets/gesture_recognizer.task
 * (não incluído neste repositório — baixe em
 * https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/latest/gesture_recognizer.task).
 */
class GestureRecognizerHelper(
    private val context: Context,
    private val listener: RecognitionListener
) {
    companion object {
        private const val TAG = "GestureRecognizerHelper"
        private const val MODEL_ASSET_PATH = "gesture_recognizer.task"
        private const val MIN_HAND_DETECTION_CONFIDENCE = 0.5f
        private const val MIN_HAND_PRESENCE_CONFIDENCE = 0.5f
        private const val MIN_TRACKING_CONFIDENCE = 0.5f
    }

    interface RecognitionListener {
        fun onResult(result: GestureRecognizerResult, inputWidth: Int, inputHeight: Int)
        fun onError(error: String)
    }

    private var gestureRecognizer: GestureRecognizer? = null

    fun setup() {
        try {
            val baseOptionsBuilder = BaseOptions.builder()
                .setModelAssetPath(MODEL_ASSET_PATH)
                .setDelegate(Delegate.CPU)

            val optionsBuilder = GestureRecognizer.GestureRecognizerOptions.builder()
                .setBaseOptions(baseOptionsBuilder.build())
                .setMinHandDetectionConfidence(MIN_HAND_DETECTION_CONFIDENCE)
                .setMinHandPresenceConfidence(MIN_HAND_PRESENCE_CONFIDENCE)
                .setMinTrackingConfidence(MIN_TRACKING_CONFIDENCE)
                .setRunningMode(RunningMode.LIVE_STREAM)
                .setNumHands(1)
                .setResultListener(::onResult)
                .setErrorListener { error -> listener.onError(error.message ?: "erro desconhecido") }

            gestureRecognizer = GestureRecognizer.createFromOptions(context, optionsBuilder.build())
        } catch (e: Exception) {
            Log.e(TAG, "Falha ao inicializar o GestureRecognizer", e)
            listener.onError("Falha ao inicializar o MediaPipe: ${e.message}")
        }
    }

    /** Processa um frame da câmera (modo LIVE_STREAM, assíncrono). */
    fun recognizeAsync(imageProxy: ImageProxy) {
        val recognizer = gestureRecognizer
        if (recognizer == null) {
            imageProxy.close()
            return
        }

        try {
            val bitmap = ImageUtils.imageProxyToBitmap(imageProxy)
            val mpImage = BitmapImageBuilder(bitmap).build()
            val frameTimeMs = SystemClockCompat.elapsedRealtime()
            recognizer.recognizeAsync(mpImage, frameTimeMs)
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao processar frame", e)
        } finally {
            imageProxy.close()
        }
    }

    private fun onResult(result: GestureRecognizerResult, input: com.google.mediapipe.framework.image.MPImage) {
        listener.onResult(result, input.width, input.height)
    }

    fun close() {
        gestureRecognizer?.close()
        gestureRecognizer = null
    }
}

/** Pequeno wrapper para não depender diretamente de android.os.SystemClock em testes. */
internal object SystemClockCompat {
    fun elapsedRealtime(): Long = android.os.SystemClock.uptimeMillis()
}
