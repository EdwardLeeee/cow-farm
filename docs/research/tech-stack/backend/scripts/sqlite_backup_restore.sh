#!/usr/bin/env bash
# SQLite 備份→還原實測（伺服器執行中、WAL 模式）。
#   1) 1,000 人負載進行中做線上備份（Online Backup API），檢查 integrity_check
#   2) 反例：負載結束後直接 cp 主檔（不含 -wal），比對少了哪些資料
#   3) 靜止時再備份一次，逐表比對列數與內容雜湊
#   4) 還原：停伺服器 → 舊檔（含 -wal/-shm）移走 → 放回備份 → 啟動 → 用同一玩家驗證 API
# 用法：COW_RUN_DIR=... COW_BACKUP_DIR=... COW_SQLITE_PATH=... COW_TOKENS=... scripts/sqlite_backup_restore.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
RUN="${COW_RUN_DIR:?}"
BK="${COW_BACKUP_DIR:?}"
DB="${COW_SQLITE_PATH:?}"
TOK="${COW_TOKENS:?}"
PY=.venv/bin/python
B=http://127.0.0.1:${COW_PORT:-18080}
mkdir -p "$BK"
SPID="$(cat "$RUN/server.pid")"
T="$($PY -c "import json;print(json.load(open('$TOK'))['tokens'][123])")"

echo "== 1. 負載進行中的線上備份"
systemd-run --user --scope --quiet -p MemoryMax=400M -p MemorySwapMax=0 --unit="cowbench-gen-bk-$(date +%s)" \
  taskset -c 3,7 $PY loadgen.py --server-pid "$SPID" --mem-floor 450 --label backup_during_load \
  --out "$RUN/backup_during_load.json" mixed --tokens "$TOK" --users 1000 --warmup 5 --duration 30 --conn close \
  >"$RUN/backup_load.log" 2>&1 &
LG=$!
echo "$(date -Is) loadgen(backup) pid=$LG" >>"$RUN/pids.log"
sleep 15
echo "WAL 大小（備份前）: $(stat -c %s "$DB-wal" 2>/dev/null || echo 0) bytes"
taskset -c 3,7 $PY sqlite_backup.py backup "$DB" "$BK/live.db"
wait "$LG"
$PY -c "import json;d=json.load(open('$RUN/backup_during_load.json'));s=d['summary']['ALL'];print('同時段負載：',s['count'],'requests, p99',s['p99_ms'],'ms, classes',s['classes'])"

echo "== 2. 反例：只 cp 主檔（不含 -wal）"
WAL_BYTES="$(stat -c %s "$DB-wal" 2>/dev/null || echo 0)"
cp "$DB" "$BK/cp_only.db"
$PY sqlite_backup.py check "$DB" >"$BK/src_now.json"
$PY sqlite_backup.py check "$BK/cp_only.db" >"$BK/cp_only.json"
echo "當下 WAL 大小: $WAL_BYTES bytes"
$PY - "$BK/src_now.json" "$BK/cp_only.json" <<'EOF'
import json, sys
a, b = (json.load(open(x)) for x in sys.argv[1:3])
for t in a:
    print(f"  {t:8s} 來源 {a[t][0]:>7} 列  cp 副本 {b[t][0]:>7} 列  {'相同' if a[t] == b[t] else '不同'}")
EOF

echo "== 3. 靜止時的線上備份與逐表比對"
taskset -c 3,7 $PY sqlite_backup.py backup "$DB" "$BK/quiet.db"
$PY sqlite_backup.py check "$DB" >"$BK/src_quiet.json"
$PY sqlite_backup.py check "$BK/quiet.db" >"$BK/quiet.json"
$PY - "$BK/src_quiet.json" "$BK/quiet.json" <<'EOF'
import json, sys
a, b = (json.load(open(x)) for x in sys.argv[1:3])
same = all(a[t] == b[t] for t in a)
for t in a:
    print(f"  {t:8s} 來源 {a[t]}  備份 {b[t]}")
print("RESULT:", "來源與備份完全一致" if same else "有差異")
EOF
BEFORE="$(curl -fsS "$B/v1/farm" -H "Authorization: Bearer $T")"
echo "還原前 GET /v1/farm: $BEFORE"

echo "== 4. 還原"
COW_RUN_DIR="$RUN" scripts/server.sh stop
mkdir -p "$BK/lost"
mv "$DB" "$DB-wal" "$DB-shm" "$BK/lost/" 2>/dev/null || true
cp "$BK/quiet.db" "$DB"
COW_RUN_DIR="$RUN" scripts/server.sh start >/dev/null
AFTER="$(curl -fsS "$B/v1/farm" -H "Authorization: Bearer $T")"
echo "還原後 GET /v1/farm: $AFTER"
$PY - "$BEFORE" "$AFTER" <<'EOF'
import json, sys
a, b = (json.loads(x) for x in sys.argv[1:3])
keys = ("player_id", "cows", "milk", "coins")
print("RESULT:", "玩家資料一致" if all(a[k] == b[k] for k in keys) else "不一致", {k: (a[k], b[k]) for k in keys})
EOF
echo "還原後 POST /v1/sell: $(curl -fsS -XPOST "$B/v1/sell" -H "Authorization: Bearer $T" -H 'content-type: application/json' -d '{"qty":1}')"
