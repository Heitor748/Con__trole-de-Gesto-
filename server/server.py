"""Servidor único (HTTPS) que serve a página web de controle por gestos
e recebe, via WebSocket, os comandos já reconhecidos no celular.

Acesse pelo navegador do celular em https://<IP-DO-PC>:8765
(aceite o aviso de certificado autoassinado na primeira vez).

Mensagens recebidas no WebSocket são um JSON simples, por exemplo:
    {"type": "move", "dx": 10, "dy": -5}
    {"type": "click", "button": "left"}
    {"type": "media", "action": "play_pause"}
    {"type": "volume", "delta": 5}

Sem autenticação/criptografia de aplicação: pensado para uso em rede
local confiável (o TLS aqui é só para liberar a câmera no navegador).
"""

import asyncio
import json
import logging
import ssl
from pathlib import Path

import pyautogui
from aiohttp import web, WSMsgType

from certs import ensure_certificate

HOST = "0.0.0.0"
PORT = 8765
STATIC_DIR = Path(__file__).parent / "static"

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


async def websocket_handler(request: web.Request) -> web.WebSocketResponse:
    ws = web.WebSocketResponse()
    await ws.prepare(request)

    peer = request.remote
    log.info("Cliente conectado: %s", peer)

    async for msg in ws:
        if msg.type != WSMsgType.TEXT:
            continue
        try:
            command = json.loads(msg.data)
        except json.JSONDecodeError:
            log.warning("Mensagem inválida (não é JSON): %r", msg.data)
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

    log.info("Cliente desconectado: %s", peer)
    return ws


def build_app() -> web.Application:
    app = web.Application()
    app.router.add_get("/ws", websocket_handler)
    app.router.add_static("/", STATIC_DIR, show_index=True)
    return app


def build_ssl_context() -> ssl.SSLContext:
    cert_file, key_file = ensure_certificate()
    ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ssl_context.load_cert_chain(certfile=str(cert_file), keyfile=str(key_file))
    return ssl_context


def main() -> None:
    app = build_app()
    ssl_context = build_ssl_context()
    log.info("Servidor de controle por gestos em https://%s:%d", HOST, PORT)
    web.run_app(app, host=HOST, port=PORT, ssl_context=ssl_context)


if __name__ == "__main__":
    main()
