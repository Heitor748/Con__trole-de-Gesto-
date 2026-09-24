# Gesture PC Control

Controle o mouse, mídia e volume do seu PC usando gestos de mão capturados
pela câmera do celular — direto no navegador, sem instalar app (estilo
Stream Deck via web).

## Arquitetura

```
[Navegador do celular]                     [PC Windows]
  Página web (HTML/JS)                      server.py (aiohttp)
      |                                          ^
      v                                          |
  Câmera (getUserMedia)                           |  serve a própria página
      |                                          |  + recebe comandos
      v                                          |
  MediaPipe Gesture Recognizer (JS/WASM)          |
  (reconhecimento 100% no celular)                 |
      |                                          |
      v                                          |
  mapeamento gesto -> comando                    |
      |                                          |
      v                                          |
  WebSocket (wss://) -------- Wi-Fi (rede local) -+
  {"type": "move", "dx": 10, "dy": -5}
```

Todo o reconhecimento de gesto acontece no navegador do celular (on-device,
via MediaPipe Tasks Vision em WebAssembly). O celular só envia comandos já
traduzidos (mover cursor, clicar, mídia, volume) para o servidor Python no
PC, que serve a própria página e executa a ação de fato.

## Gestos suportados

| Gesto | Ação |
|---|---|
| Palma aberta se movendo | Move o cursor do mouse |
| Palma aberta parada por 1s | Play/pause |
| Polegar + indicador unidos (pinch) | Clique esquerdo |
| Punho fechado | Clique direito |
| Sinal de V movendo para a direita/esquerda | Próxima/anterior faixa |
| Joia (👍) | Volume + |
| Joia invertida (👎) | Volume - |

## Estrutura do repositório

- `server/` — servidor Python (aiohttp: HTTPS + WebSocket + pyautogui) que
  roda no Windows e também serve a página web
- `server/static/` — página web (`index.html` + `app.js`) aberta no
  navegador do celular

## Como usar

1. No PC (Windows), rode o servidor — veja [`server/README.md`](server/README.md).
2. No celular, abra `https://<IP-do-PC>:8765` no navegador (mesma rede Wi-Fi).
3. Aceite o aviso de certificado autoassinado e permita o acesso à câmera.
4. Toque em "Conectar" e faça os gestos na frente da câmera.

Não é necessário Android Studio, build de APK ou cabo USB — só um navegador.

## Status do projeto

**v1 — apenas Wi-Fi local (WebSocket sobre HTTPS).** Suporte a Bluetooth e
conexão via USB estão planejados como próximas etapas, para os casos em que
não há rede Wi-Fi disponível ou se deseja uma conexão mais estável/sem lag.

## Aviso de segurança

A comunicação entre navegador e servidor não tem autenticação nem
criptografia de aplicação nesta versão (o HTTPS existe só para liberar a
câmera) — pensado para uso doméstico em rede local confiável. Não exponha a
porta 8765 do servidor à internet.
