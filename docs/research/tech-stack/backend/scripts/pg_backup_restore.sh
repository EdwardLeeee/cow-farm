#!/usr/bin/env bash
# PostgreSQL 備份→還原實測（線上備份，不停機）。
#   1) 容器內 pg_dump -Fc（custom 格式，可選擇性還原）
#   2) 建新資料庫，用 pg_restore 還原
#   3) 兩邊比對列數與內容雜湊
#   4) 附帶示範：主機的 pg_dump 14 連不上 17 版伺服器（版本不符會拒絕）
# 用法：COW_RUN_DIR=<scratchpad>/run COW_BACKUP_DIR=<scratchpad>/backups scripts/pg_backup_restore.sh
set -euo pipefail
RUN="${COW_RUN_DIR:?}"
BK="${COW_BACKUP_DIR:?}"
NAME="${COW_PG_NAME:-cowbench-pg}"
PORT="${COW_PG_PORT:-55432}"
mkdir -p "$BK"
psqlc() { podman exec -i "$NAME" psql -U postgres -h 127.0.0.1 -p "$PORT" -At "$@"; }

CHECK_SQL="SELECT 'players', count(*), md5(string_agg(encode(token_hash,'hex'), ',' ORDER BY id)) FROM players
UNION ALL SELECT 'farms', count(*), md5(string_agg(player_id||':'||milk||':'||coins, ',' ORDER BY player_id)) FROM farms
UNION ALL SELECT 'trades', count(*), md5(string_agg(id||':'||player_id||':'||qty||':'||price, ',' ORDER BY id)) FROM trades
UNION ALL SELECT 'market', count(*), '-' FROM market;"

echo "== 1. pg_dump（線上）"
T0=$(date +%s.%N)
podman exec "$NAME" pg_dump -U postgres -h 127.0.0.1 -p "$PORT" -Fc cowfarm >"$BK/cowfarm.dump"
T1=$(date +%s.%N)
psqlc -d cowfarm -c "$CHECK_SQL" >"$BK/src_check.txt"
echo "dump 秒數: $(echo "$T1 - $T0" | bc)  大小: $(stat -c %s "$BK/cowfarm.dump") bytes"
podman exec "$NAME" psql -U postgres -h 127.0.0.1 -p "$PORT" -At -d cowfarm \
  -c "SELECT pg_size_pretty(pg_database_size('cowfarm'))" | sed 's/^/資料庫大小: /'

echo "== 2. 還原到新資料庫 cowfarm_restore"
psqlc -d postgres -c "DROP DATABASE IF EXISTS cowfarm_restore" >/dev/null
psqlc -d postgres -c "CREATE DATABASE cowfarm_restore" >/dev/null
T0=$(date +%s.%N)
podman exec -i "$NAME" pg_restore -U postgres -h 127.0.0.1 -p "$PORT" -d cowfarm_restore --exit-on-error <"$BK/cowfarm.dump"
T1=$(date +%s.%N)
echo "restore 秒數: $(echo "$T1 - $T0" | bc)"
psqlc -d cowfarm_restore -c "$CHECK_SQL" >"$BK/restore_check.txt"

echo "== 3. 比對（market 每秒 tick 會變，只比列數）"
paste -d'|' "$BK/src_check.txt" "$BK/restore_check.txt"
if diff -q "$BK/src_check.txt" "$BK/restore_check.txt" >/dev/null; then
  echo "RESULT: 來源與還原完全一致"
else
  echo "RESULT: 有差異（見上表）"
fi

echo "== 4. 主機 pg_dump（$(pg_dump --version)）直接連 17 版伺服器"
PGPASSWORD="$(cat "$RUN/pg.pw")" pg_dump -h 127.0.0.1 -p "$PORT" -U postgres -Fc cowfarm >/dev/null 2>"$BK/host_pgdump_err.txt" \
  && echo "（意外成功）" || { echo "失敗訊息："; cat "$BK/host_pgdump_err.txt"; }
