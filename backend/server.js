require('dotenv').config();

const express = require('express');
const multer = require('multer');
const { google } = require('googleapis');
const { Readable } = require('stream');

const PORT = process.env.PORT || 8080;
const API_KEY = process.env.API_KEY;
const DRIVE_FOLDER_ID = process.env.DRIVE_FOLDER_ID || '';
const CREDENTIALS_BASE64 = process.env.GOOGLE_SERVICE_ACCOUNT_JSON_BASE64;

if (!API_KEY) {
  console.error('Missing API_KEY env var. Refusing to start.');
  process.exit(1);
}
if (!CREDENTIALS_BASE64) {
  console.error('Missing GOOGLE_SERVICE_ACCOUNT_JSON_BASE64 env var. Refusing to start.');
  process.exit(1);
}

const credentials = JSON.parse(
  Buffer.from(CREDENTIALS_BASE64, 'base64').toString('utf8'),
);

const auth = new google.auth.GoogleAuth({
  credentials,
  scopes: ['https://www.googleapis.com/auth/drive.file'],
});

const app = express();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
});

function requireApiKey(req, res, next) {
  if (req.header('x-api-key') !== API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

app.get('/healthz', (req, res) => res.json({ ok: true }));

app.post('/api/upload', requireApiKey, upload.single('file'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'Missing file field' });
  }

  try {
    const drive = google.drive({ version: 'v3', auth });

    const created = await drive.files.create({
      requestBody: {
        name: req.body.fileName || req.file.originalname || 'nota.jpg',
        parents: DRIVE_FOLDER_ID ? [DRIVE_FOLDER_ID] : undefined,
      },
      media: {
        mimeType: req.file.mimetype || 'application/octet-stream',
        body: Readable.from(req.file.buffer),
      },
      fields: 'id,webViewLink',
    });

    await drive.permissions.create({
      fileId: created.data.id,
      requestBody: { role: 'reader', type: 'anyone' },
    });

    res.json({ webViewLink: created.data.webViewLink });
  } catch (err) {
    console.error('Drive upload failed:', err);
    res.status(502).json({ error: 'Drive upload failed' });
  }
});

app.listen(PORT, () => {
  console.log(`Drive proxy listening on :${PORT}`);
});
