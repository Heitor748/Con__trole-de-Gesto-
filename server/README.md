# Servidor de controle por gestos (Windows)

Serve a página web de controle e recebe, via WebSocket, os comandos já
reconhecidos no celular (mover mouse, clicar, play/pause, próxima/anterior
faixa, volume).

## Como rodar

```
cd server
pip install -r requirements.txt
python server.py
```

Na primeira execução ele gera um certificado TLS autoassinado em
`server/certs/` (necessário para o navegador do celular liberar a câmera).

O servidor fica escutando em `https://0.0.0.0:8765`.

## Acessar do celular

1. Descubra o IP local do PC no Windows: abra o `cmd` e rode `ipconfig`,
   pegue o "Endereço IPv4" da rede Wi-Fi (ex: `192.168.0.10`).
2. No navegador do celular (Chrome recomendado), acesse:
   `https://192.168.0.10:8765`
3. O navegador vai avisar que o certificado não é confiável (é autoassinado,
   gerado localmente) — toque em "Avançado" → "Acessar mesmo assim". Isso só
   aparece na primeira vez.
4. Permita o acesso à câmera quando solicitado.
5. Confira se o campo de IP/porta na página já veio preenchido (o padrão é
   o mesmo endereço que você acessou) e toque em "Conectar".
6. Celular e PC precisam estar na mesma rede Wi-Fi.

## Firewall do Windows

Na primeira execução o Windows pode bloquear a porta. Libere o Python
(ou a porta 8765/TCP) no Firewall do Windows Defender quando solicitado,
ou manualmente em Painel de Controle → Firewall do Windows Defender →
Permitir um aplicativo pelo firewall.

## Aviso de segurança

Esta é a v1 do projeto: a comunicação **não tem autenticação nem
criptografia de aplicação** (o HTTPS aqui existe só para liberar a câmera no
navegador, com um certificado autoassinado). Qualquer dispositivo na mesma
rede local poderia, em teoria, enviar comandos para o servidor. Use apenas
em redes domésticas confiáveis.
