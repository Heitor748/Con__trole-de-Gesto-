package com.gesturepc.control.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Comandos enviados do app Android para o servidor Python no PC via WebSocket.
 * Cada comando é serializado como um objeto JSON simples com um campo "type"
 * que identifica a ação e campos extras específicos de cada tipo.
 */
@Serializable
sealed class Command {

    @Serializable
    @SerialName("move")
    data class Move(val dx: Int, val dy: Int) : Command()

    @Serializable
    @SerialName("click")
    data class Click(val button: String) : Command() // "left" ou "right"

    @Serializable
    @SerialName("media")
    data class Media(val action: String) : Command() // "play_pause", "next", "prev"

    @Serializable
    @SerialName("volume")
    data class Volume(val delta: Int) : Command() // positivo = subir, negativo = descer
}

/** Botões de clique suportados. */
object MouseButton {
    const val LEFT = "left"
    const val RIGHT = "right"
}

/** Ações de mídia suportadas. */
object MediaAction {
    const val PLAY_PAUSE = "play_pause"
    const val NEXT = "next"
    const val PREV = "prev"
}
