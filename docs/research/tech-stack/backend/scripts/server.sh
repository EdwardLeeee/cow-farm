#!/usr/bin/env bash
# 啟動／停止實測用 uvicorn（1 個 worker，綁在一顆邏輯 CPU，放進有記憶體上限的 systemd scope）。
# 用法：
#   COW_RUN_DIR=<scratchpad>/run COW_DB=sqlite COW_SQLITE_PATH=... scripts/server.sh start
#   COW_RUN_DIR=<scratchpad>/run scripts/server.sh stop
# 其他環境變數見 cowbench/server.py。PID 寫在 $COW_RUN_DIR/server.pid，並追加到 pids.log。
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
RUN="${COW_RUN_DIR:?set COW_RUN_DIR (outside the repo)}"
PORT="${COW_PORT:-18080}"
CPU="${COW_SERVER_CPU:-2}"
MEM="${COW_SERVER_MEM:-1500M}"
mkdir -p "$RUN"

case "${1:-}" in
start)
  cd "$HERE"
  nohup systemd-run --user --scope --quiet -p MemoryMax="$MEM" -p MemorySwapMax=0 \
    --unit="cowbench-server-$(date +%s%N)" \
    taskset -c "$CPU" .venv/bin/python -m uvicorn cowbench.server:app \
    --host 127.0.0.1 --port "$PORT" --workers 1 \
    --no-access-log --log-level warning \
    --ws-per-message-deflate "${COW_WS_DEFLATE:-false}" \
    >>"$RUN/server.log" 2>&1 &
  PID=$!
  echo "$PID" >"$RUN/server.pid"
  echo "$(date -Is) server pid=$PID db=${COW_DB:-sqlite} cpu=$CPU" >>"$RUN/pids.log"
  for _ in $(seq 1 150); do
    curl -fsS "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1 && break
    sleep 0.1
  done
  curl -fsS "http://127.0.0.1:$PORT/healthz"
  echo " affinity: $(taskset -cp "$PID")"
  ;;
stop)
  PID="$(cat "$RUN/server.pid")"
  if kill -0 "$PID" 2>/dev/null; then
    kill -TERM "$PID"
    for _ in $(seq 1 100); do kill -0 "$PID" 2>/dev/null || break; sleep 0.1; done
    kill -0 "$PID" 2>/dev/null && kill -KILL "$PID"
  fi
  echo "$(date -Is) server pid=$PID stopped" >>"$RUN/pids.log"
  echo "stopped $PID"
  ;;
*)
  echo "usage: $0 start|stop" >&2
  exit 2
  ;;
esac
