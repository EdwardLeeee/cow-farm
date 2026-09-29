#!/usr/bin/env bash
# rootless podman 的 PostgreSQL 17（實測用，做完即移除）。
# - --network host：避開 rootless 的 port 轉發代理（rootlessport/slirp4netns），只聽 127.0.0.1:55432。
# - 用 taskset 啟動 podman，讓 conmon 與 postgres 繼承 CPU 綁定（使用者 cgroup 沒有委派 cpuset）。
# - 密碼每次隨機產生，存在 $COW_RUN_DIR/pg.pw（不進 repo）。
# 用法：COW_RUN_DIR=<scratchpad>/run scripts/pg.sh up|down|dsn|pid
set -euo pipefail
RUN="${COW_RUN_DIR:?set COW_RUN_DIR (outside the repo)}"
NAME="${COW_PG_NAME:-cowbench-pg}"
PORT="${COW_PG_PORT:-55432}"
CPU="${COW_PG_CPU:-6}"
IMAGE="${COW_PG_IMAGE:-docker.io/library/postgres:17}"
mkdir -p "$RUN"

case "${1:-}" in
up)
  PW="$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')"
  umask 077
  echo "$PW" >"$RUN/pg.pw"
  taskset -c "$CPU" podman run -d --name "$NAME" --network host \
    --memory 512m --memory-swap 512m \
    -e POSTGRES_PASSWORD="$PW" -e POSTGRES_DB=cowfarm \
    "$IMAGE" -c listen_addresses=127.0.0.1 -c port="$PORT" >/dev/null
  for _ in $(seq 1 120); do
    podman exec "$NAME" pg_isready -h 127.0.0.1 -p "$PORT" -U postgres >/dev/null 2>&1 && break
    sleep 0.5
  done
  # 官方映像初始化時會先起一個暫時的 server 再重啟；等正式的 postmaster 穩定
  sleep 2
  podman exec "$NAME" pg_isready -h 127.0.0.1 -p "$PORT" -U postgres
  PGPID="$(podman inspect -f '{{.State.Pid}}' "$NAME")"
  CONMON="$(podman inspect -f '{{.State.ConmonPid}}' "$NAME")"
  echo "$PGPID" >"$RUN/pg.pid"
  echo "$(date -Is) pg container=$NAME postmaster=$PGPID conmon=$CONMON cpu=$CPU" >>"$RUN/pids.log"
  # 實測發現 taskset podman run 只傳到 conmon，容器裡的 postgres 仍是 0-7。
  # postgres 的 UID 是 subuid，要進 rootless user namespace（podman unshare）才能改；
  # 之後 postmaster fork 出的新 backend 會繼承這個設定。
  for p in "$PGPID" $(pgrep -P "$PGPID"); do podman unshare taskset -cp "$CPU" "$p" >/dev/null; done
  echo "postmaster $PGPID: $(taskset -cp "$PGPID")"
  for c in $(pgrep -P "$PGPID" | head -3); do echo "child $c $(tr '\0' ' ' </proc/"$c"/cmdline): $(taskset -cp "$c")"; done
  echo "userspace proxies: $(pgrep -u "$(id -u)" -x rootlessport || true) $(pgrep -u "$(id -u)" -x slirp4netns || true) (應為空)"
  podman exec "$NAME" postgres --version
  ;;
down)
  podman rm -f "$NAME" >/dev/null && echo "removed $NAME"
  echo "$(date -Is) pg container=$NAME removed" >>"$RUN/pids.log"
  ;;
dsn)
  echo "postgresql://postgres:$(cat "$RUN/pg.pw")@127.0.0.1:$PORT/cowfarm"
  ;;
pid)
  cat "$RUN/pg.pid"
  ;;
*)
  echo "usage: $0 up|down|dsn|pid" >&2
  exit 2
  ;;
esac
