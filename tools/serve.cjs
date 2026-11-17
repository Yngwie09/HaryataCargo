'use strict';
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../build/web');
const port = Number(process.argv[2] || 8085);
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'application/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.ttf': 'font/ttf', '.woff2': 'font/woff2' };
if (!fs.existsSync(path.join(root, 'index.html'))) throw new Error('Jalankan build web terlebih dahulu.');
http.createServer((req, res) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); } catch (_) { res.writeHead(400).end(); return; }
  let target = path.resolve(root, `.${pathname}`);
  if (!target.startsWith(root + path.sep) && target !== root) { res.writeHead(403).end(); return; }
  if (!fs.existsSync(target) || fs.statSync(target).isDirectory()) target = path.join(root, 'index.html');
  res.writeHead(200, { 'Content-Type': mime[path.extname(target)] || 'application/octet-stream', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
  fs.createReadStream(target).pipe(res);
}).listen(port, '127.0.0.1', () => console.log(`Haryata Cargo: http://localhost:${port} (Ctrl+C untuk berhenti)`));
