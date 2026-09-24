"""Servidor que recebe comandos de gesto via WebSocket e controla o PC.

Executa em segundo plano no Windows, escutando em 0.0.0.0:8765. Cada mensagem
recebida é um JSON simples, por exemplo:
    {"type": "move", "dx": 10, "dy": -5}
    {"type": "click", "button": "left"}
    {"type": "media", "action": "play_pause"}
    {"type": "volume", "delta": 5}

Sem autenticação/criptografia: pensado para uso em rede local confiável.
"""

import asyncio
import json
import logging

import pyautogui
import websockets

HOST = "0.0.0.0"
PORT = 8765

pyautogui.FAILSAFE = False

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("gesture-server")

MEDIA_KEYS = {
    "play_pause": "playpause",
    "next": "nexttrack",
    "prev": "prevtrack",
}


def handle_move(command: dict) -> None:
    dx = int(command.get("dx", 0))
    dy = int(command.get("dy", 0))
    if dx or dy:
        pyautogui.moveRel(dx, dy, duration=0)


def handle_click(command: dict) -> None:
    button = command.get("button", "left")
    if button not in ("left", "right"):
        button = "left"
    pyautogui.click(button=button)


def handle_media(command: dict) -> None:
    action = command.get("action")
    key = MEDIA_KEYS.get(action)
    if key:
        pyautogui.press(key)
    else:
        log.warning("Ação de mídia desconhecida: %s", action)


def handle_volume(command: dict) -> None:
    delta = int(command.get("delta", 0))
    key = "volumeup" if delta > 0 else "volumedown"
    presses = max(1, abs(delta) // 2)
    for _ in range(presses):
        pyautogui.press(key)


HANDLERS = {
    "move": handle_move,
    "click": handle_click,
    "media": handle_media,
    "volume": handle_volume,
}


async def handle_connection(websocket):
    peer = websocket.remote_address
    log.info("Cliente conectado: %s", peer)
    try:
        async for raw_message in websocket:
            try:
                command = json.loads(raw_message)
            except json.JSONDecodeError:
                log.warning("Mensagem inválida (não é JSON): %r", raw_message)
                continue

            command_type = command.get("type")
            handler = HANDLERS.get(command_type)
            if handler is None:
                log.warning("Tipo de comando desconhecido: %s", command_type)
                continue

            log.info("Comando recebido: %s", command)
            try:
                handler(command)
            except Exception:
                log.exception("Erro ao executar comando: %s", command)
    finally:
        log.info("Cliente desconectado: %s", peer)


async def main():
    log.info("Servidor de controle por gestos escutando em %s:%d", HOST, PORT)
    async with websockets.serve(handle_connection, HOST, PORT):
        await asyncio.Future()  # roda para sempre


if __name__ == "__main__":
    asyncio.run(main())
