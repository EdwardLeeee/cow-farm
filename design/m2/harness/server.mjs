// 行程內的靜態伺服器：讓 ES module 能載入（file:// 會被 Chrome 擋）。不另開程式，腳本結束就關。
// /app-fonts/<檔名>：app 內建的字型（app/assets/fonts，只給 .ttf）。設計稿的泰文用 app 同一個可變字型檔（base.css 的 @font-face），
// 量到的寬度才跟手機上一樣（cow-app #120：這台電腦的 Noto Sans Thai 只有 Regular、Bold，標 900 的泰文其實畫成 Bold）。
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { basename, dirname, extname, join, normalize, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.png': 'image/png', '.json': 'application/json; charset=utf-8', '.svg': 'image/svg+xml',
  '.ttf': 'font/ttf',
};
const APP_FONTS = resolve(dirname(fileURLToPath(import.meta.url)), '../../../app/assets/fonts');

export async function startServer(root, port = 0) {
  const base = resolve(root);
  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://local');
      const path = decodeURIComponent(url.pathname);
      if (path.startsWith('/app-fonts/')) {
        const name = basename(path);
        if (extname(name) !== '.ttf') throw new Error('only .ttf');
        const data = await readFile(join(APP_FONTS, name));
        res.writeHead(200, { 'content-type': TYPES['.ttf'], 'cache-control': 'no-store' });
        res.end(data);
        return;
      }
      const rel = normalize(path).replace(/^[/\\]+/, '');
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
