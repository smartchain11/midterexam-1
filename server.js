import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
const root = resolve(import.meta.dirname);
const types = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.png': 'image/png', '.json': 'application/json' };
http.createServer(async (req, res) => {
  let file;
  try {
    const pathname = new URL(req.url, 'http://localhost').pathname;
    file = resolve(root, '.' + decodeURIComponent(pathname === '/' ? '/index.html' : pathname));
  } catch { res.writeHead(400).end('Bad request'); return; }
  if (!file.startsWith(root + sep) || !['index.html','styles.css','app.js','domain.js','settings.js','catalogue.js','config.js',`assets${sep}adssu-logo.png`,`data${sep}scholarship-reference.json`].includes(file.slice(root.length + 1))) {
    res.writeHead(403).end('Forbidden'); return;
  }
  try {
    const content = await readFile(file);
    res.writeHead(200, { 'Content-Type': types[extname(file)], 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' }).end(content);
  } catch { res.writeHead(404).end('Not found'); }
}).listen(3000, '127.0.0.1', () => console.log('Open http://127.0.0.1:3000'));
