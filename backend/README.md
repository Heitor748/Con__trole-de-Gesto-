# Drive upload proxy

Small Express server that uploads firewood-note photos to Google Drive on
behalf of the Flutter app. The Google service account credential lives only
here, on the server — never in the app bundle, which is what makes it safe
to run the app on the web (a Flutter web build's assets are publicly
downloadable, so shipping the credential there would leak it).

## Endpoints

- `GET /healthz` — liveness check.
- `POST /api/upload` — multipart form with a `file` field (the image) and an
  optional `fileName` field. Requires header `x-api-key: <API_KEY>`. Returns
  `{ "webViewLink": "..." }` on success.

## Local run

```bash
cp .env.example .env
# edit .env: set API_KEY, DRIVE_FOLDER_ID, and GOOGLE_SERVICE_ACCOUNT_JSON_BASE64
npm install
npm start
```

`GOOGLE_SERVICE_ACCOUNT_JSON_BASE64` is the full service account JSON key
file, base64-encoded onto a single line:

```bash
base64 -w0 service_account.json
```

The target Drive folder must be shared with the service account's email
(`client_email` in the JSON key) as Editor.

## Deploying to a VPS

1. Copy this `backend/` folder to the server (e.g. `/var/www/controle-lenha/backend`).
2. `npm install --omit=dev` on the server.
3. Create `.env` there from `.env.example` with real values.
4. Install the systemd unit: see `../deploy/controle-lenha-drive-proxy.service.example`.
5. Point nginx's `/api/` location at `http://127.0.0.1:8080` — see
   `../deploy/nginx.conf.example`, which also serves the Flutter web build.
6. In the Flutter app's `.env` (and the `DRIVE_PROXY_URL`/`DRIVE_PROXY_API_KEY`
   GitHub Actions secrets), set:
   - `DRIVE_PROXY_URL=https://your-domain.example.com`
   - `DRIVE_PROXY_API_KEY=` (same value as this server's `API_KEY`)
