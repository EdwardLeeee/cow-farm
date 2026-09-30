// 手動預覽：node harness/serve.mjs [port]，再用瀏覽器開 http://127.0.0.1:<port>/src/screen-a.html
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { startServer } from './server.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const srv = await startServer(root, Number(process.argv[2] || 8123));
console.log(`serving ${root} at ${srv.base}/src/screen-a.html (Ctrl+C 結束)`);
