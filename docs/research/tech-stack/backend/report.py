"""把 results/*.json 彙整成 backend-findings.md 用的表格（Markdown）。

用法：.venv/bin/python report.py > /tmp/tables.md
"""

from __future__ import annotations

import glob
import json
import os

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")


def load(name: str):
    p = os.path.join(R, name)
    return json.load(open(p)) if os.path.exists(p) else None


def f(v, nd=1):
    if v is None:
        return "—"
    if isinstance(v, float):
        return f"{v:,.{nd}f}"
    if isinstance(v, int):
        return f"{v:,}"
    return str(v)


def mixed():
    print("### 混合負載（每次請求新連線；暖身 20 秒後量 60 秒）\n")
    print("| 設定 | 在線人數 | 實際 req/s | p50 ms | p99 ms | 最慢 ms | 錯誤率 | 伺服器 CPU% | 伺服器 RSS MB | PG CPU% | 每請求 CPU ms（伺服器／含 PG） | CPU 2 外部佔用% |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for label, name in [
        ("PG 17", "mixed_pg_1k.json"), ("PG 17", "mixed_pg_10k.json"),
        ("SQLite FULL", "mixed_sqlite_full_1k.json"), ("SQLite FULL", "mixed_sqlite_full_10k.json"),
        ("SQLite NORMAL", "mixed_sqlite_normal_1k.json"), ("SQLite NORMAL", "mixed_sqlite_normal_10k.json"),
        ("SQLite NORMAL（第 2 次）", "mixed_sqlite_normal_10k_run2.json"),
    ]:
        d = load(name)
        if not d:
            continue
        s, y = d["summary"]["ALL"], d["system"]
        other = y.get("cpu2_other_pct")
        if other is None and "server_cpu_pct" in y:
            other = round(y["cpu_busy_pct"]["2"] - y["server_cpu_pct"], 1)
        per = f(d.get("server_cpu_ms_per_req"), 2)
        if d.get("total_cpu_ms_per_req"):
            per += f"／{f(d['total_cpu_ms_per_req'], 2)}"
        print(f"| {label} | {f(d['args']['users'])} | {f(s['rps'])} | {f(s['p50_ms'])} | {f(s['p99_ms'])} | "
              f"{f(s['max_ms'])} | {f(s['error_rate'], 3)} | {f(y['server_cpu_pct'])} | {f(y['server_rss_mb_peak'])} | "
              f"{f(y.get('pg_cpu_pct'))} | {per} | {f(other)} |")
    print()
    print("各端點（10,000 人）p50／p99 ms：\n")
    print("| 設定 | GET farm | GET market | POST collect | POST sell |")
    print("|---|---|---|---|---|")
    for label, name in [("PG 17", "mixed_pg_10k.json"), ("SQLite FULL", "mixed_sqlite_full_10k.json"),
                        ("SQLite NORMAL", "mixed_sqlite_normal_10k.json"),
                        ("SQLite NORMAL（第 2 次）", "mixed_sqlite_normal_10k_run2.json")]:
        d = load(name)
        if not d:
            continue
        cells = []
        for ep in ("farm", "market", "collect", "sell"):
            e = d["summary"][ep]
            cells.append(f"{f(e['p50_ms'])}／{f(e['p99_ms'])}")
        print(f"| {label} | " + " | ".join(cells) + " |")
    print()


def ramp():
    print("### 固定速率階梯（單一 uvicorn worker 綁 1 顆邏輯 CPU；每階 20 秒；延遲從預定送出時間算）\n")
    print("| 設定 | 目標 req/s | 實際 req/s | p50 ms | p99 ms | 錯誤率 | 伺服器 CPU% | PG CPU% | 產生器 CPU%（各程序） |")
    print("|---|---|---|---|---|---|---|---|---|")
    for label, name in [("PG 17", "ramp_pg.json"), ("SQLite FULL", "ramp_sqlite_full.json"),
                        ("SQLite NORMAL", "ramp_sqlite_normal.json")]:
        d = load(name)
        if not d:
            continue
        for st in d["steps"]:
            s, y = st["summary_all"], st["system"]
            print(f"| {label} | {f(st['target_rps'], 0)} | {f(s['rps'])} | {f(s['p50_ms'])} | {f(s['p99_ms'])} | "
                  f"{f(s['error_rate'], 3)} | {f(y['server_cpu_pct'])} | {f(y.get('pg_cpu_pct'))} | "
                  f"{'／'.join(str(x) for x in st['generator_cpu_pct_each'])} |")
    print()


def sell():
    print("### 只打 POST /v1/sell（closed-loop、keep-alive、每個 worker 不同玩家；每級 15 秒）\n")
    print("| 設定 | 併發 | 成功 tx/s | p50 ms | p99 ms | 伺服器 CPU% | PG CPU% |")
    print("|---|---|---|---|---|---|---|")
    for label, name in [("PG 17", "sell_pg.json"), ("SQLite FULL", "sell_sqlite_full.json"),
                        ("SQLite NORMAL", "sell_sqlite_normal.json")]:
        d = load(name)
        if not d:
            continue
        for lv in d["levels"]:
            s, y = lv["summary"], lv["system"]
            ok = s["classes"].get("ok", 0) / y["window_s"]
            print(f"| {label} | {lv['concurrency']} | {f(ok)} | {f(s['p50_ms'])} | {f(s['p99_ms'])} | "
                  f"{f(y['server_cpu_pct'])} | {f(y.get('pg_cpu_pct'))} |")
    print()


def dbbench():
    print("### 純資料庫 sell 交易（不經 HTTP；每級 10 秒）\n")
    print("| 設定 | 熱點列 | 併發 | tx/s | p50 ms | p99 ms | 程序 CPU% | PG CPU% |")
    print("|---|---|---|---|---|---|---|---|")
    for label, name in [("PG 17", "dbbench_pg_hotrow.json"), ("PG 17", "dbbench_pg_append.json"),
                        ("SQLite FULL", "dbbench_sqlite_full.json"),
                        ("SQLite NORMAL（第 1 次）", "dbbench_sqlite_normal.json"),
                        ("SQLite NORMAL（第 2 次，順序相反）", "dbbench_sqlite_normal_rerun.json"),
                        ("SQLite NORMAL（第 3 次，干擾小）", "dbbench_sqlite_normal_rerun2.json")]:
        d = load(name)
        if not d:
            continue
        for m in d["modes"]:
            for lv in m["levels"]:
                y = lv["system"]
                print(f"| {label} | {'是' if m['hotrow'] else '否（只寫 trades）'} | {lv['concurrency']} | "
                      f"{f(lv['tx_per_s'])} | {f(lv['p50_ms'], 2)} | {f(lv['p99_ms'], 2)} | "
                      f"{f(y['server_cpu_pct'])} | {f(y.get('pg_cpu_pct'))} |")
    print()


def misc():
    print("### 其他\n")
    for name in ("seed_pg.json", "seed_sqlite_full.json"):
        d = load(name)
        if d:
            s = d["summary"]["ALL"]
            print(f"- {name}：{f(d['sessions_per_s'])} 個帳號/秒，p50 {f(s['p50_ms'])} ms，p99 {f(s['p99_ms'])} ms，{s['classes']}")
    d = load("fsync.json")
    if d:
        for k, v in d["results"].items():
            print(f"- {k}（4 KiB，{v['n']} 次）：p50 {v['p50_ms']} ms，p90 {v['p90_ms']} ms，p99 {v['p99_ms']} ms，最慢 {v['max_ms']} ms")
    print()


def realtime():
    print("### WebSocket 廣播（每 5 秒一次）與 HTTP 輪詢（每 10 秒一次）\n")
    print("| 方式 | N | 連上／失敗 | 送出→收到 p50／p99 ms | 一次扇出 p50／最慢 ms | 伺服器 CPU% | 伺服器 RSS MB | 伺服器 KB/連線 | 客戶端 KB/連線 | lo 流量 KB/s |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for name in sorted(glob.glob(os.path.join(R, "ws_*.json")), key=lambda p: int(p.split("_")[-1].split(".")[0].replace("k", "000"))):
        d = json.load(open(name))
        L, y = d["latency_ms_send_to_recv"], d["system"]
        fo = d["fanout_s"]
        print(f"| WebSocket | {f(d['args']['n'])} | {f(d['connected'])}／{f(d['failed'])} | {f(L['p50'])}／{f(L['p99'])} | "
              f"{f(fo['p50'])}／{f(fo['max'])} | {f(y['server_cpu_pct'])} | {f(d['server_rss_mb_connected'])} | "
              f"{f(d['server_kb_per_conn'])} | {f(d['client_kb_per_conn'])} | {f(d['lo_bytes_per_s_net'] / 1024)} |"
              + (f" ⚠ {d['stopped_for_mem']}" if d["stopped_for_mem"] else ""))
    print()
    print("| 方式 | N | req/s | 回應 p50／p99 ms | 資料新鮮度（發布→拿到）p50／p99 ms | 漏掉的更新 | 伺服器 CPU% | 伺服器 RSS MB | lo 流量 KB/s |")
    print("|---|---|---|---|---|---|---|---|---|")
    for name in sorted(glob.glob(os.path.join(R, "poll_*.json")), key=lambda p: int(p.split("_")[-1].split(".")[0].replace("k", "000"))):
        d = json.load(open(name))
        L, F, y, c = d["latency_ms"], d["freshness_ms_publish_to_recv"], d["system"], d["counts"]
        print(f"| 輪詢 | {f(d['args']['n'])} | {f(d['req_per_s'])} | {f(L['p50'])}／{f(L['p99'])} | {f(F['p50'])}／{f(F['p99'])} | "
              f"{c['missed_ticks']}/{c['missed_ticks'] + c['new_tick']} | {f(y['server_cpu_pct'])} | {f(y['server_rss_mb_peak'])} | "
              f"{f(d['lo_bytes_per_s_net'] / 1024)} |")
    print()
    print("### 斷線重連（1,000 條 WebSocket；SIGKILL 伺服器、5 秒後重啟）\n")
    print("| 退避策略 | 重啟到健康 s | 連回 | 伺服器起來後多久連回 p50／p99／最慢 ms | 從斷線算 p50／p99／最慢 ms | 每人嘗試次數 p50／最多 | 起來後前 5 秒每秒連線嘗試 |")
    print("|---|---|---|---|---|---|---|")
    for name, label in [("reconnect_1k_jitter.json", "指數退避＋full jitter，0.5 秒起、上限 30 秒"),
                        ("reconnect_1k_jitter_cap5.json", "指數退避＋full jitter，0.5 秒起、上限 5 秒"),
                        ("reconnect_1k_fixed1.json", "固定每 1 秒重試（無 jitter）")]:
        d = load(name)
        if not d:
            continue
        a, b, c = d["reconnect_ms_since_server_up"], d["reconnect_ms_since_drop"], d["attempts_per_client"]
        print(f"| {label} | {f(d['restart_to_healthy_s'], 2)} | {d['reconnected']}/{d['n']} | {f(a['p50'], 0)}／{f(a['p99'], 0)}／{f(a['max'], 0)} | "
              f"{f(b['p50'], 0)}／{f(b['p99'], 0)}／{f(b['max'], 0)} | {c['p50']}／{c['max']} | "
              f"{', '.join(str(x) for x in d['attempts_per_s_after_up_first10s'][:5])} |")
    print()


if __name__ == "__main__":
    mixed()
    ramp()
    sell()
    dbbench()
    misc()
    realtime()
