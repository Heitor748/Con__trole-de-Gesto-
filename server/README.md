# Servidor de controle por gestos (Windows)

Recebe comandos via WebSocket enviados pelo app Android e os executa no PC
(mover mouse, clicar, play/pause, próxima/anterior faixa, volume).

## Como rodar

```
cd server
pip install -r requirements.txt
python server.py
```

O servidor fica escutando em `0.0.0.0:8765`.

## Configurar o app

1. Descubra o IP local do PC no Windows: abra o `cmd` e rode `ipconfig`,
   pegue o "Endereço IPv4" da rede Wi-Fi (ex: `192.168.0.10`).
2. No app Android, digite esse IP e a porta `8765` na tela de configuração
   e toque em "Conectar".
3. Celular e PC precisam estar na mesma rede Wi-Fi.

## Firewall do Windows

Na primeira execução o Windows pode bloquear a porta. Libere o Python
(ou a porta 8765/TCP) no Firewall do Windows Defender quando solicitado,
ou manualmente em Painel de Controle → Firewall do Windows Defender →
Permitir um aplicativo pelo firewall.

## Aviso de segurança

Esta é a v1 do projeto: a comunicação **não tem autenticação nem
criptografia**. Qualquer dispositivo na mesma rede local poderia, em teoria,
enviar comandos para o servidor. Use apenas em redes domésticas confiáveis.
