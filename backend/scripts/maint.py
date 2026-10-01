"""安排、查詢、結束伺服器維護（協定第 6 節）。

直接寫資料庫 meta 的 maintenance，再 NOTIFY 頻道 cowfarm_admin，執行中的伺服器馬上生效（另外每 30 秒自己讀一次）。
不經過 API，所以不用另外一套管理用的認證和金鑰：能連資料庫的人才能改。

用法（在 backend/ 下；資料庫照伺服器的設定：COWFARM_PG_DSN，沒有就讀 ~/.config/cow-farm/pg.env）：
  .venv/bin/python scripts/maint.py schedule <開始> <預計結束>   # 預告維護（開始時間到了就進入維護中）
  .venv/bin/python scripts/maint.py status
  .venv/bin/python scripts/maint.py end                          # 結束維護，或取消預告

時間的寫法：
  開始：now、+30m、+2h（從現在算）、2026-10-03 03:00（台灣時間）、Unix 秒
  預計結束：+1h、+90m（從開始算）、2026-10-03 05:00（台灣時間）、Unix 秒
過了預計結束時間還沒 end，伺服器照樣維持維護中（app 會看到過去的時間）：要延長就重新 schedule。
"""

from __future__ import annotations

import asyncio
import json
import re
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import asyncpg  # noqa: E402

from server.config import default_dsn  # noqa: E402

CHANNEL = "cowfarm_admin"  # 跟 server/runtime.py 的 ADMIN_CHANNEL 一樣
TW = timezone(timedelta(hours=8))  # 台灣時間，沒有日光節約


def parse_time(text: str, base: float) -> float:
    """「now」「+30m」「+2h」（從 base 算）、「2026-10-03 03:00」（台灣時間）、Unix 秒 → Unix 秒。"""
    text = text.strip()
    if text == "now":
        return base
    m = re.fullmatch(r"\+(\d+(?:\.\d+)?)([mh])", text)
    if m:
        return base + float(m.group(1)) * (60 if m.group(2) == "m" else 3600)
    if re.fullmatch(r"\d+(\.\d+)?", text):
        return float(text)
    for fmt in ("%Y-%m-%d %H:%M", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(text, fmt).replace(tzinfo=TW).timestamp()
        except ValueError:
            pass
    raise SystemExit(f"看不懂的時間：{text}")


def show(t: float) -> str:
    return datetime.fromtimestamp(t, TW).strftime("%Y-%m-%d %H:%M:%S（台灣時間）")


async def main(argv) -> int:
    if not argv or argv[0] not in ("schedule", "status", "end"):
        print(__doc__)
        return 2
    conn = await asyncpg.connect(default_dsn())
    try:
        if argv[0] == "schedule":
            if len(argv) != 3:
                raise SystemExit("用法：maint.py schedule <開始> <預計結束>")
            now = time.time()
            start = parse_time(argv[1], now)
            end = parse_time(argv[2], start)
            if end <= start:
                raise SystemExit("預計結束要比開始晚")
            value = {"starts_at_real": start, "ends_at_real": end, "set_at_real": now}
            await conn.execute(
                "INSERT INTO meta(key, value) VALUES('maintenance', $1::jsonb) "
                "ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value, updated_at=now()",
                json.dumps(value),
            )
            await conn.execute("SELECT pg_notify($1, 'maintenance')", CHANNEL)
            print(f"已安排維護：{show(start)} 開始，預計 {show(end)} 結束")
        elif argv[0] == "end":
            await conn.execute("DELETE FROM meta WHERE key='maintenance'")
            await conn.execute("SELECT pg_notify($1, 'maintenance')", CHANNEL)
            print("已結束維護（或取消預告）")
        else:
            raw = await conn.fetchval("SELECT value::text FROM meta WHERE key='maintenance'")
            if raw is None:
                print("沒有安排維護")
            else:
                v = json.loads(raw)
                state = "維護中" if time.time() >= v["starts_at_real"] else "預告中"
                print(f"{state}：{show(v['starts_at_real'])} 開始，預計 {show(v['ends_at_real'])} 結束")
    finally:
        await conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main(sys.argv[1:])))
