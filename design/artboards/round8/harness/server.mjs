// 行程內的靜態伺服器：讓 ES module 能載入（file:// 會被 Chrome 擋）。不另開程式，腳本結束就關。
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize, resolve } from 'node:path';

const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.png': 'image/png', '.json': 'application/json; charset=utf-8', '.svg': 'image/svg+xml',
};

export async function startServer(root, port = 0) {
  const base = resolve(root);
  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://local');
      const rel = normalize(decodeURIComponent(url.pathname)).replace(/^[/\\]+/, '');
      const file = resolve(join(base, rel));
      if (!file.startsWith(base)) throw new Error('outside root');
      const data = await readFile(file);
      res.writeHead(200, { 'content-type': TYPES[extname(file)] || 'application/octet-stream', 'cache-control': 'no-store' });
      res.end(data);
    } catch {
      res.writeHead(404, { 'content-type': 'text/plain' });
      res.end('not found');
    }
  });
  await new Promise((r) => server.listen(port, '127.0.0.1', r));
  const { port: actual } = server.address();
  return { base: `http://127.0.0.1:${actual}`, close: () => new Promise((r) => server.close(r)) };
}
