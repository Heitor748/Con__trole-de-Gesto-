package com.gesturepc.control.camera

import android.content.Context
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.common.util.concurrent.ListenableFuture
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Configura o CameraX (preview + análise de imagem) e entrega cada frame
 * capturado ao [onFrame] para ser processado pelo GestureRecognizerHelper.
 */
class CameraXManager(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner
) {
    private val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var cameraProviderFuture: ListenableFuture<ProcessCameraProvider>? = null

    fun start(previewView: PreviewView, onFrame: (androidx.camera.core.ImageProxy) -> Unit) {
        val providerFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture = providerFuture
        providerFuture.addListener({
            val cameraProvider = providerFuture.get()

            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(previewView.surfaceProvider)
            }

            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()
                .also { analysis ->
                    analysis.setAnalyzer(analysisExecutor) { imageProxy -> onFrame(imageProxy) }
                }

            val cameraSelector = CameraSelector.DEFAULT_FRONT_CAMERA

            cameraProvider.unbindAll()
            cameraProvider.bindToLifecycle(lifecycleOwner, cameraSelector, preview, imageAnalysis)
        }, ContextCompat.getMainExecutor(context))
    }

    fun stop() {
        cameraProviderFuture?.get()?.unbindAll()
        analysisExecutor.shutdown()
    }
}
