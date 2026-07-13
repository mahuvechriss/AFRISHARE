const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3000;
const UPLOAD_DIR = path.join(__dirname, 'uploads');
const MAX_FILE_SIZE = parseInt(process.env.MAX_FILE_SIZE) || 1073741824; // 1GB
const FILE_TTL_MS = parseInt(process.env.FILE_TTL) || 86400000; // 24 hours

// Ensure upload directory exists
if (!fs.existsSync(UPLOAD_DIR)) {
  fs.mkdirSync(UPLOAD_DIR, { recursive: true });
}

// In-memory store: shareCode -> { id, fileName, fileSize, senderName, filePath, createdAt, downloadCount }
const fileStore = new Map();

// Cleanup interval - remove expired files every hour
setInterval(() => {
  const now = Date.now();
  for (const [code, entry] of fileStore.entries()) {
    if (now - entry.createdAt > FILE_TTL_MS) {
      try { fs.unlinkSync(entry.filePath); } catch (_) {}
      fileStore.delete(code);
      console.log(`[Cleanup] Removed expired file: ${entry.fileName} (${code})`);
    }
  }
}, 3600000);

// Multer config
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const uniqueId = uuidv4();
    const ext = path.extname(file.originalname);
    cb(null, `${uniqueId}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: MAX_FILE_SIZE },
});

app.use(cors());
app.use(express.json());

// === API Routes ===

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

// Upload file - returns share code
app.post('/api/upload', upload.single('file'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file provided' });
    }

    const shareCode = uuidv4().substring(0, 8).toUpperCase();
    const senderName = req.body.senderName || 'Anonymous';

    const entry = {
      id: uuidv4(),
      fileName: req.file.originalname,
      fileSize: req.file.size,
      senderName,
      filePath: req.file.path,
      createdAt: Date.now(),
      downloadCount: 0,
    };

    fileStore.set(shareCode, entry);
    console.log(`[Upload] ${entry.fileName} (${(entry.fileSize / 1024 / 1024).toFixed(2)} MB) -> ${shareCode}`);

    res.json({
      status: 'ok',
      shareCode,
      fileName: entry.fileName,
      fileSize: entry.fileSize,
      expiresIn: FILE_TTL_MS,
    });
  } catch (err) {
    console.error('[Upload Error]', err);
    res.status(500).json({ error: 'Upload failed' });
  }
});

// Get file info by share code
app.get('/api/info/:code', (req, res) => {
  const code = req.params.code.toUpperCase();
  const entry = fileStore.get(code);

  if (!entry) {
    return res.status(404).json({ error: 'File not found or expired' });
  }

  res.json({
    status: 'ok',
    fileName: entry.fileName,
    fileSize: entry.fileSize,
    senderName: entry.senderName,
    createdAt: entry.createdAt,
    downloadCount: entry.downloadCount,
    expiresAt: entry.createdAt + FILE_TTL_MS,
  });
});

// Download file by share code
app.get('/api/download/:code', (req, res) => {
  const code = req.params.code.toUpperCase();
  const entry = fileStore.get(code);

  if (!entry) {
    return res.status(404).json({ error: 'File not found or expired' });
  }

  if (!fs.existsSync(entry.filePath)) {
    fileStore.delete(code);
    return res.status(404).json({ error: 'File no longer available' });
  }

  entry.downloadCount++;
  console.log(`[Download] ${entry.fileName} (${code}) - download #${entry.downloadCount}`);

  res.download(entry.filePath, entry.fileName, (err) => {
    if (err) {
      console.error('[Download Error]', err);
      // Don't delete on error to allow retry
    }
  });
});

// Delete a file by share code (one-time cleanup after download)
app.delete('/api/delete/:code', (req, res) => {
  const code = req.params.code.toUpperCase();
  const entry = fileStore.get(code);

  if (!entry) {
    return res.status(404).json({ error: 'File not found' });
  }

  try {
    if (fs.existsSync(entry.filePath)) {
      fs.unlinkSync(entry.filePath);
    }
  } catch (_) {}

  fileStore.delete(code);
  console.log(`[Delete] Removed ${entry.fileName} (${code})`);
  res.json({ status: 'ok' });
});

// Stats
app.get('/api/stats', (req, res) => {
  const activeFiles = fileStore.size;
  const totalSize = Array.from(fileStore.values()).reduce((sum, e) => sum + e.fileSize, 0);
  const totalDownloads = Array.from(fileStore.values()).reduce((sum, e) => sum + e.downloadCount, 0);

  // Count files in uploads directory
  let filesOnDisk = 0;
  try { filesOnDisk = fs.readdirSync(UPLOAD_DIR).length; } catch (_) {}

  res.json({
    activeFiles,
    filesOnDisk,
    totalSize,
    totalDownloads,
    uptime: process.uptime(),
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n  AfriShare Relay Server`);
  console.log(`  ─────────────────────`);
  console.log(`  Port:     ${PORT}`);
  console.log(`  Max file: ${(MAX_FILE_SIZE / 1024 / 1024).toFixed(0)} MB`);
  console.log(`  TTL:      ${FILE_TTL_MS / 3600000} hours`);
  console.log(`  Uploads:  ${UPLOAD_DIR}`);
  console.log(`  Server:   http://localhost:${PORT}\n`);
});
