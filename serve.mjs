// Simple HTTP server with COOP/COEP headers for SharedArrayBuffer (required by pthreads)
import http from 'http';
import fs from 'fs';
import path from 'path';

const PORT = 8090;
const DIR = path.dirname(new URL(import.meta.url).pathname);

const MIME = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.mjs': 'application/javascript',
  '.wasm': 'application/wasm',
  '.css': 'text/css',
  '.json': 'application/json',
};

http.createServer((req, res) => {
  const url = req.url === '/' ? '/test.html' : req.url;
  const filePath = path.join(DIR, url);
  const ext = path.extname(filePath);

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('Not found');
      return;
    }

    res.writeHead(200, {
      'Content-Type': MIME[ext] || 'application/octet-stream',
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    });
    res.end(data);
  });
}).listen(PORT, () => {
  console.log(`Serving at http://localhost:${PORT}`);
  console.log('(COOP/COEP headers enabled for SharedArrayBuffer)');
});
