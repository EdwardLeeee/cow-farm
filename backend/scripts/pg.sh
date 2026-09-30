#!/usr/bin/env bash
# cow-farm M1 的 PostgreSQL 17：rootless podman，本機開發與區網試玩用。
#
#   scripts/pg.sh up        建立或啟動容器（可以重跑；第一次會產生密碼檔 ~/.config/cow-farm/pg.env，權限 600）
#   scripts/pg.sh status    容器、資料卷、連線狀態
#   scripts/pg.sh stop      停止容器（資料留在資料卷）
#   scripts/pg.sh psql      進資料庫的 psql
#   scripts/pg.sh dump F    線上備份成 F（pg_dump -Fc，在容器裡跑：主機的 pg_dump 14 不能備份 17）
#   scripts/pg.sh resetdb [名稱]  清掉一個資料庫重建成空的（預設 cowfarm；伺服器下次啟動會建立新世界）。
#                                 要輸入資料庫名稱確認，或加 --yes。舊（v0.1）世界不相容 v0.2 伺服器時用這個。
#   scripts/pg.sh destroy   刪除容器、資料卷與密碼檔（所有遊戲資料都會消失；要輸入 DESTROY 確認，或加 --yes）
#
# 設計
# - 容器名 cowfarm-pg，資料放 named volume cowfarm-pgdata，--memory 256m（這台電腦 2026-09-30 因記憶體耗盡當機過）。
# - --network host，PostgreSQL 只聽 127.0.0.1:55433：不經過 rootless 的轉發代理，也不對區網開放（區網只開 API 的 8787）。
# - 密碼每台電腦產生一次，只放在 pg.env；本腳本不會把密碼印出來。
set -euo pipefail

NAME="${COWFARM_PG_NAME:-cowfarm-pg}"
VOLUME="${COWFARM_PG_VOLUME:-cowfarm-pgdata}"
PORT="${COWFARM_PG_PORT:-55433}"
IMAGE="${COWFARM_PG_IMAGE:-docker.io/library/postgres:17}"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cow-farm"
ENV_FILE="$CONF_DIR/pg.env"
MIN_AVAILABLE_MB="${COWFARM_MIN_AVAILABLE_MB:-2000}"

exists_container() { podman container exists "$NAME"; }
exists_volume() { podman volume exists "$VOLUME"; }
running() { [ "$(podman inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null || echo false)" = "true" ]; }
available_mb() { free -m | awk '/^Mem:/ {print $7}'; }

wait_ready() {
  for _ in $(seq 1 120); do
    if podman exec "$NAME" pg_isready -q -h 127.0.0.1 -p "$PORT" -U cowfarm -d cowfarm 2>/dev/null; then
      echo "PostgreSQL 已就緒（127.0.0.1:$PORT）"
      return 0
    fi
    sleep 0.5
  done
  echo "等了 60 秒還沒就緒；看 podman logs $NAME" >&2
  return 1
}

check_memory() {
  local avail
  avail="$(available_mb)"
  if [ "${FORCE:-0}" != "1" ] && [ "$avail" -lt "$MIN_AVAILABLE_MB" ]; then
    echo "可用記憶體只有 ${avail} MB（< ${MIN_AVAILABLE_MB} MB），先不啟動。關掉一些程式再試，或加 --force。" >&2
    exit 3
  fi
}

write_env() {
  mkdir -p "$CONF_DIR"
  chmod 700 "$CONF_DIR"
  local pw
  pw="$(od -An -tx1 -N24 /dev/urandom | tr -d ' \n')"
  (
    umask 077
    cat >"$ENV_FILE" <<EOF
# cow-farm 本機 PostgreSQL（backend/scripts/pg.sh 產生）。權限 600，不要複製進 repo。
POSTGRES_PASSWORD=$pw
COWFARM_PG_DSN=postgresql://cowfarm:$pw@127.0.0.1:$PORT/cowfarm
EOF
  )
  chmod 600 "$ENV_FILE"
  echo "產生密碼檔 $ENV_FILE（權限 600）"
}

cmd_up() {
  if exists_container; then
    if running; then
      echo "$NAME 已經在跑"
    else
      check_memory
      podman start "$NAME" >/dev/null
      echo "啟動既有容器 $NAME"
    fi
    wait_ready
    return
  fi
  if [ ! -f "$ENV_FILE" ]; then
    if exists_volume; then
      echo "資料卷 $VOLUME 已經存在，但找不到密碼檔 $ENV_FILE。" >&2
      echo "密碼只在第一次建立資料卷時設定；請找回 pg.env，或用 scripts/pg.sh destroy 清掉資料重來。" >&2
      exit 2
    fi
    write_env
  fi
  check_memory
  podman image exists "$IMAGE" || podman pull "$IMAGE"
  podman run -d --name "$NAME" --network host \
    --memory 256m --memory-swap 256m \
    -v "$VOLUME":/var/lib/postgresql/data \
    --env-file "$ENV_FILE" -e POSTGRES_USER=cowfarm -e POSTGRES_DB=cowfarm \
    "$IMAGE" \
    -c listen_addresses=127.0.0.1 -c port="$PORT" \
    -c shared_buffers=64MB -c max_connections=30 >/dev/null
  echo "建立容器 $NAME（資料卷 $VOLUME，--memory 256m）"
  wait_ready
  podman exec "$NAME" postgres --version
}

cmd_status() {
  if exists_container; then
    podman ps -a --filter "name=^${NAME}\$" --format '容器 {{.Names}}：{{.Status}}（{{.Image}}）'
    if running; then
      podman exec "$NAME" pg_isready -h 127.0.0.1 -p "$PORT" -U cowfarm -d cowfarm || true
      podman stats --no-stream --format '記憶體 {{.MemUsage}}' "$NAME" 2>/dev/null || true
    fi
  else
    echo "沒有容器 $NAME"
  fi
  if exists_volume; then echo "資料卷 $VOLUME：存在"; else echo "資料卷 $VOLUME：不存在"; fi
  if [ -f "$ENV_FILE" ]; then echo "密碼檔 $ENV_FILE：存在（$(stat -c %a "$ENV_FILE")）"; else echo "密碼檔 $ENV_FILE：不存在"; fi
}

cmd_stop() {
  if exists_container && running; then
    podman stop "$NAME" >/dev/null
    echo "已停止 $NAME（資料還在資料卷 $VOLUME；scripts/pg.sh up 可以再啟動）"
  else
    echo "$NAME 沒有在跑"
  fi
}

cmd_psql() {
  running || { echo "$NAME 沒有在跑，先 scripts/pg.sh up" >&2; exit 1; }
  exec podman exec -it "$NAME" psql -h 127.0.0.1 -p "$PORT" -U cowfarm -d "${1:-cowfarm}"
}

cmd_dump() {
  local out="${1:?用法：scripts/pg.sh dump <檔名>}"
  running || { echo "$NAME 沒有在跑" >&2; exit 1; }
  podman exec "$NAME" pg_dump -h 127.0.0.1 -p "$PORT" -U cowfarm -Fc cowfarm >"$out"
  echo "備份到 $out（$(du -h "$out" | cut -f1)）"
}

cmd_resetdb() {
  local db="${1:-cowfarm}"
  [ "${1:-}" = "--yes" ] && db="cowfarm"
  local yes="0"
  for a in "$@"; do [ "$a" = "--yes" ] && yes="1"; done
  running || { echo "$NAME 沒有在跑，先 scripts/pg.sh up" >&2; exit 1; }
  echo "會清掉資料庫 $db 的所有內容（牧場、行情、成交紀錄），重建成空的。請先停掉用這個資料庫的伺服器。"
  if [ "$yes" != "1" ]; then
    read -r -p "確定的話輸入資料庫名稱（$db）：" ans
    if [ "$ans" != "$db" ]; then
      echo "取消，什麼都沒動。"
      exit 1
    fi
  fi
  podman exec "$NAME" psql -q -h 127.0.0.1 -p "$PORT" -U cowfarm -d postgres \
    -c "DROP DATABASE IF EXISTS \"$db\" WITH (FORCE)" -c "CREATE DATABASE \"$db\""
  echo "已重建空的資料庫 $db"
}

cmd_destroy() {
  echo "會刪除：容器 $NAME、資料卷 $VOLUME（全部遊戲資料）、密碼檔 $ENV_FILE"
  if [ "${1:-}" != "--yes" ]; then
    read -r -p "確定的話輸入 DESTROY：" ans
    if [ "$ans" != "DESTROY" ]; then
      echo "取消，什麼都沒刪。"
      exit 1
    fi
  fi
  if exists_container; then podman rm -f "$NAME" >/dev/null && echo "刪除容器 $NAME"; fi
  if exists_volume; then podman volume rm "$VOLUME" >/dev/null && echo "刪除資料卷 $VOLUME"; fi
  if [ -f "$ENV_FILE" ]; then rm -f "$ENV_FILE" && echo "刪除密碼檔 $ENV_FILE"; fi
}

ARGS=()
FORCE=0
for a in "$@"; do
  if [ "$a" = "--force" ]; then FORCE=1; else ARGS+=("$a"); fi
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

case "${1:-}" in
  up) cmd_up ;;
  status) cmd_status ;;
  stop | down) cmd_stop ;;
  psql) shift; cmd_psql "$@" ;;
  dump) shift; cmd_dump "$@" ;;
  resetdb) shift; cmd_resetdb "$@" ;;
  destroy) shift; cmd_destroy "$@" ;;
  *)
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
