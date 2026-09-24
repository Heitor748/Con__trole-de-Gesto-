# Gesture PC Control

Controle o mouse, mídia e volume do seu PC usando gestos de mão capturados
pela câmera do celular.

## Arquitetura

```
[Celular Android]                          [PC Windows]
  Câmera (CameraX)                          server.py (WebSocket)
      |                                          ^
      v                                          |
  MediaPipe Gesture Recognizer                   |
  (reconhecimento 100% no celular)                |
      |                                          |
      v                                          |
  GestureMapper (gesto -> comando)                |
      |                                          |
      v                                          |
  WebSocketClient  -------- Wi-Fi (rede local) ---+
  {"type": "move", "dx": 10, "dy": -5}
```

Todo o reconhecimento de gesto acontece no celular (on-device, via MediaPipe
Tasks). O app só envia comandos já traduzidos (mover cursor, clicar, mídia,
volume) para o servidor Python no PC, que executa a ação de fato.

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

- `app/` — app Android (Kotlin + Jetpack Compose + CameraX + MediaPipe Tasks Vision)
- `server/` — servidor Python (WebSocket + pyautogui) que roda no Windows

## Como buildar o app Android

1. Abra a pasta raiz do repositório no Android Studio (ela já é o projeto Gradle).
2. Baixe o modelo `gesture_recognizer.task` do MediaPipe e coloque em
   `app/src/main/assets/gesture_recognizer.task`:
   https://storage.googleapis.com/mediapipe-models/gesture_recognizer/gesture_recognizer/float16/latest/gesture_recognizer.task
3. Rode o app em um celular físico (a câmera não funciona bem em emulador).

## Como rodar o servidor

Veja [`server/README.md`](server/README.md).

## Status do projeto

**v1 — apenas Wi-Fi local (WebSocket).** Suporte a Bluetooth e conexão via
USB estão planejados como próximas etapas, para os casos em que não há
rede Wi-Fi disponível ou se deseja uma conexão mais estável/sem lag.

## Aviso de segurança

A comunicação entre app e servidor não tem autenticação nem criptografia
nesta versão — pensado para uso doméstico em rede local confiável. Não
exponha a porta 8765 do servidor à internet.
