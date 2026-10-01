"""牛怎麼畫的實測腳本 4：逐像素比對兩組 PNG（例：flutter_svg 對 Chromium），量跟核准圖的一致程度。

用法：python3 docs/research/cow-render/compare.py <標準 PNG 資料夾> <受測 PNG 資料夾> <輸出資料夾> [--rsvg <svg 資料夾>]
- 兩組都先疊在白底上再比，差值取 RGB 三個通道裡最大的那個（0–255）。
- 只算牛的範圍（任一邊不透明度 > 0 的像素）。
- 輸出：fidelity.csv（每張一列）、summary.json、worst.png（差最多的 4 張：標準｜受測｜差異放大 4 倍）。
- --rsvg：另外用 librsvg 畫同一批 SVG（同樣的尺寸算法），跟標準比一次，當「兩個不同繪圖程式本來就有的邊緣差異」的對照組。
- --mirror：只比標準裡朝右的圖（檔名有 _right_），受測改用同名朝左的圖左右翻轉；量「朝右只靠翻轉朝左的圖」跟核准圖差多少。
"""

import csv
import json
import math
import re
import sys
from pathlib import Path

import numpy as np
from PIL import Image


def load(path):
    a = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32)
    alpha = a[..., 3:4] / 255.0
    rgb = a[..., :3] * alpha + 255.0 * (1 - alpha)  # 疊在白底上
    return rgb, a[..., 3]


def compare(ref_dir, test_dir, mirror=False):
    rows = []
    for ref in sorted(Path(ref_dir).glob("*.png")):
        if mirror and "_right_" not in ref.name:
            continue
        test = Path(test_dir) / (ref.name.replace("_right_", "_left_") if mirror else ref.name)
        if not test.exists():
            rows.append({"name": ref.stem, "missing": True})
            continue
        r_rgb, r_a = load(ref)
        t_rgb, t_a = load(test)
        if mirror:
            t_rgb, t_a = t_rgb[:, ::-1], t_a[:, ::-1]
        if r_rgb.shape != t_rgb.shape:
            rows.append(
                {
                    "name": ref.stem,
                    "size_mismatch": f"{r_rgb.shape[:2]} vs {t_rgb.shape[:2]}",
                }
            )
            continue
        area = (r_a > 0) | (t_a > 0)
        d = np.abs(r_rgb - t_rgb).max(axis=2)[area]
        rm, tm = r_a > 127, t_a > 127
        iou = (rm & tm).sum() / max(1, (rm | tm).sum())
        rows.append(
            {
                "name": ref.stem,
                "pixels": int(area.sum()),
                "mean_diff": round(float(d.mean()), 3),
                "pct_gt16": round(100 * float((d > 16).mean()), 3),
                "pct_gt64": round(100 * float((d > 64).mean()), 3),
                "pct_gt128": round(100 * float((d > 128).mean()), 3),
                "alpha_iou": round(float(iou), 5),
            }
        )
    return rows


def summarize(rows):
    ok = [r for r in rows if "pixels" in r]
    out = {
        "images": len(rows),
        "compared": len(ok),
        "problems": [r for r in rows if "pixels" not in r],
    }
    for k in ("mean_diff", "pct_gt16", "pct_gt64", "pct_gt128", "alpha_iou"):
        v = sorted(r[k] for r in ok)
        out[k] = {"median": v[len(v) // 2], "min": v[0], "max": v[-1]}
    out["worst_by_pct_gt64"] = [r["name"] for r in sorted(ok, key=lambda r: -r["pct_gt64"])[:8]]
    return out


def montage(ref_dir, test_dir, names, path, mirror=False):
    tiles = []
    for n in names:
        tn = n.replace("_right_", "_left_") if mirror else n
        r = Image.open(Path(ref_dir) / f"{n}.png").convert("RGBA")
        t = Image.open(Path(test_dir) / f"{tn}.png").convert("RGBA")
        r_rgb, _ = load(Path(ref_dir) / f"{n}.png")
        t_rgb, _ = load(Path(test_dir) / f"{tn}.png")
        if mirror:
            t = t.transpose(Image.FLIP_LEFT_RIGHT)
            t_rgb = t_rgb[:, ::-1]
        d = np.clip(np.abs(r_rgb - t_rgb).max(axis=2) * 4, 0, 255).astype(np.uint8)
        heat = Image.fromarray(255 - d).convert("RGBA")
        row = Image.new("RGBA", (r.width * 3 + 20, r.height), (255, 255, 255, 255))
        for i, im in enumerate((r, t, heat)):
            row.alpha_composite(im, (i * (r.width + 10), 0))
        tiles.append(row)
    W, H = max(t.width for t in tiles), sum(t.height + 10 for t in tiles)
    sheet = Image.new("RGBA", (W, H), (255, 255, 255, 255))
    y = 0
    for t in tiles:
        sheet.alpha_composite(t, (0, y))
        y += t.height + 10
    sheet.convert("RGB").save(path)


def rsvg_render(svg_dir, out_dir, scale=3.0):
    import cairo
    import gi

    gi.require_version("Rsvg", "2.0")
    from gi.repository import Rsvg

    Path(out_dir).mkdir(parents=True, exist_ok=True)
    for svg in sorted(Path(svg_dir).glob("*.svg")):
        text = svg.read_text()
        w = float(re.search(r' width="([\d.]+)"', text).group(1))
        h = float(re.search(r' height="([\d.]+)"', text).group(1))
        W, H = math.ceil(w * scale), math.ceil(h * scale)
        handle = Rsvg.Handle.new_from_data(text.encode())
        surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
        ctx = cairo.Context(surf)
        vp = Rsvg.Rectangle()
        vp.x, vp.y, vp.width, vp.height = 0, 0, w * scale, h * scale
        handle.render_document(ctx, vp)
        surf.write_to_png(str(Path(out_dir) / f"{svg.stem}.png"))


def main():
    args = sys.argv[1:]
    mirror = "--mirror" in args
    if mirror:
        args.remove("--mirror")
    rsvg_dir = None
    if "--rsvg" in args:
        i = args.index("--rsvg")
        rsvg_dir = args[i + 1]
        del args[i : i + 2]
    ref_dir, test_dir, out = args
    Path(out).mkdir(parents=True, exist_ok=True)
    rows = compare(ref_dir, test_dir, mirror)
    with open(Path(out) / "fidelity.csv", "w", newline="") as fh:
        w = csv.DictWriter(
            fh,
            fieldnames=sorted({k for r in rows for k in r}, key=lambda k: (k != "name", k)),
        )
        w.writeheader()
        w.writerows(rows)
    summary = {"test_vs_ref": summarize(rows)}
    montage(
        ref_dir,
        test_dir,
        summary["test_vs_ref"]["worst_by_pct_gt64"][:4],
        Path(out) / "worst.png",
        mirror,
    )
    if rsvg_dir:
        rdir = Path(out) / "rsvg-png"
        rsvg_render(rsvg_dir, rdir)
        summary["rsvg_vs_ref"] = summarize(compare(ref_dir, rdir))
    (Path(out) / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1))
    print(json.dumps(summary, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
