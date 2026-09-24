package com.gesturepc.control.network

import com.gesturepc.control.model.Command
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.TimeUnit

enum class ConnectionState {
    DISCONNECTED,
    CONNECTING,
    CONNECTED
}

/**
 * Cliente WebSocket que mantém a conexão com o servidor Python rodando no PC
 * e envia os comandos gerados a partir dos gestos reconhecidos.
 */
class WebSocketClient(
    private val onStateChanged: (ConnectionState) -> Unit
) {
    private val json = Json { ignoreUnknownKeys = true }

    private val client = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .pingInterval(15, TimeUnit.SECONDS)
        .build()

    private var webSocket: WebSocket? = null

    @Volatile
    var state: ConnectionState = ConnectionState.DISCONNECTED
        private set(value) {
            field = value
            onStateChanged(value)
        }

    /** Conecta ao servidor em ws://[host]:[port]. */
    fun connect(host: String, port: Int) {
        disconnect()
        state = ConnectionState.CONNECTING

        val request = Request.Builder()
            .url("ws://$host:$port")
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                state = ConnectionState.CONNECTED
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
                state = ConnectionState.DISCONNECTED
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                state = ConnectionState.DISCONNECTED
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                state = ConnectionState.DISCONNECTED
            }
        })
    }

    fun disconnect() {
        webSocket?.close(1000, "bye")
        webSocket = null
        if (state != ConnectionState.DISCONNECTED) {
            state = ConnectionState.DISCONNECTED
        }
    }

    /** Envia um comando serializado como JSON. Retorna true se enfileirado com sucesso. */
    fun send(command: Command): Boolean {
        val socket = webSocket ?: return false
        val payload = json.encodeToString(command)
        return socket.send(payload)
    }

    fun shutdown() {
        disconnect()
        client.dispatcher.executorService.shutdown()
    }
}
