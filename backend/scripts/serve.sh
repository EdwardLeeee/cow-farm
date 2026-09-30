#!/usr/bin/env bash
# 在背景啟動／停止 cow-farm M1 伺服器（0.0.0.0:8787）。
#
#   scripts/serve.sh start [倍率]   背景啟動（預設倍率讀 COWFARM_TIME_SCALE，沒設就是 1；試玩建議 144）
#   scripts/serve.sh stop           用 PID 停止（先 SIGTERM，10 秒後還在才 SIGKILL）
#   scripts/serve.sh status         PID、記憶體、/healthz
#   scripts/serve.sh logs           看最後 50 行日誌
#
# 用 systemd-run --scope 限制記憶體 1500 MB、不用 swap（這台電腦 2026-09-30 因記憶體耗盡當機過）。
# PID 與日誌放在 ~/.cache/cow-farm/（COWFARM_RUN_DIR 可以換，例如同時跑第二台驗證用的伺服器：
#   COWFARM_RUN_DIR=/tmp/cowfarm-verify COWFARM_PORT=8789 COWFARM_PG_DSN=... scripts/serve.sh start 144）。
# 前景執行（看得到日誌）用：cd backend && .venv/bin/python -m server
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
RUN_DIR="${COWFARM_RUN_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/cow-farm}"
PID_FILE="$RUN_DIR/server.pid"
LOG_FILE="$RUN_DIR/server.log"
PORT="${COWFARM_PORT:-8787}"
mkdir -p "$RUN_DIR"

alive() { [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; }

case "${1:-}" in
start)
  if alive; then echo "已經在跑（PID $(cat "$PID_FILE")）"; exit 0; fi
  if [ -n "${2:-}" ]; then export COWFARM_TIME_SCALE="$2"; fi
  avail="$(free -m | awk '/^Mem:/ {print $7}')"
  if [ "$avail" -lt 2000 ] && [ "${COWFARM_FORCE:-0}" != "1" ]; then
    echo "可用記憶體只有 ${avail} MB（< 2000 MB），先不啟動；確定要跑就加 COWFARM_FORCE=1" >&2
    exit 3
  fi
  cd "$HERE"
  nohup systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 \
    .venv/bin/python -m server >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  for _ in $(seq 1 40); do
    if curl -fsS "http://127.0.0.1:$PORT/healthz" >/dev/null 2>&1; then break; fi
    sleep 0.5
  done
  echo "伺服器 PID $(cat "$PID_FILE")，倍率 ${COWFARM_TIME_SCALE:-1}，日誌 $LOG_FILE"
  if ! curl -fsS "http://127.0.0.1:$PORT/healthz"; then echo "還沒回應，看日誌：tail $LOG_FILE" >&2; exit 1; fi
  echo
  ip -4 -o addr show scope global 2>/dev/null | awk '{split($4,a,"/"); print "區網網址：http://" a[1] ":'"$PORT"'/"}'
  ;;
stop)
  if ! alive; then echo "沒有在跑"; rm -f "$PID_FILE"; exit 0; fi
  pid="$(cat "$PID_FILE")"
  kill -TERM "$pid"
  for _ in $(seq 1 20); do kill -0 "$pid" 2>/dev/null || break; sleep 0.5; done
  if kill -0 "$pid" 2>/dev/null; then kill -KILL "$pid"; echo "SIGKILL $pid"; fi
  rm -f "$PID_FILE"
  echo "已停止（PID $pid）"
  ;;
status)
  if alive; then
    pid="$(cat "$PID_FILE")"
    echo "PID $pid，RSS $(( $(awk '/VmRSS/ {print $2}' "/proc/$pid/status") / 1024 )) MB"
    curl -fsS "http://127.0.0.1:$PORT/healthz" && echo
  else
    echo "沒有在跑"
  fi
  ;;
logs)
  tail -n 50 "$LOG_FILE"
  ;;
*)
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
  ;;
esac
