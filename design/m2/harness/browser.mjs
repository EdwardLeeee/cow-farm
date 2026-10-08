// 出設計稿的瀏覽器：capture.mjs、anim.mjs（和各輪草稿的 make.mjs）都用這個開 Chromium，確保每台電腦拍出來的圖一樣。
// 1. 字型：要有 Noto Sans CJK TC 的 Regular、Bold、Black（設計稿的字重 900 靠 Black）。少了就停下來，不要拍出別的字重。
//    2026-10-08 換新電腦時系統只有 Regular、Bold，「12,480」這類 900 的字整個變細；裝 Black 的方法見 README「重新出圖」。
// 2. 反鋸齒：用 harness/fonts.conf（灰階，不要彩色次像素）。
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { chromium } from '@playwright/test';

const HERE = dirname(fileURLToPath(import.meta.url));
export const FONTS_CONF = join(HERE, 'fonts.conf');

export function checkFonts() {
  let styles = '';
  try { styles = execFileSync('fc-list', ['Noto Sans CJK TC', 'style'], { encoding: 'utf8', env: { ...process.env, FONTCONFIG_FILE: FONTS_CONF } }); } catch { /* 沒有 fc-list */ }
  const missing = ['Regular', 'Bold', 'Black'].filter((w) => !new RegExp(`\\b${w}\\b`).test(styles));
  if (missing.length) {
    console.error(`字型不齊：Noto Sans CJK TC 少了 ${missing.join('、')}。設計稿的字重會跟以前不一樣，先照 design/m2/README.md「重新出圖」裝好字型再拍。`);
    process.exit(3);
  }
}

export async function launchBrowser(opts = {}) {
  checkFonts();
  return chromium.launch({ ...opts, env: { ...process.env, FONTCONFIG_FILE: FONTS_CONF } });
}
