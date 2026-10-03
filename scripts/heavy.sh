#!/usr/bin/env bash
# 重的工作都用這個包：flutter test／build web、Playwright 走查、整套重拍設計稿、長時間模擬。
#
#   scripts/heavy.sh <指令…>          例：scripts/heavy.sh ~/development/flutter/bin/flutter test
#
# 1. 排隊：整台電腦一次只跑一個（所有 session 共用 ~/.cache/cow-farm/heavy.lock，最多等 2 小時）。
#    2026-10-03 兩個 session 同時跑重的工作，記憶體剩 1 GB，走查和重拍都被系統停掉。
# 2. 輪到以後再看記憶體：available 少於 1000 MB 就每 30 秒再看一次，10 分鐘後還不夠就放棄
#    （使用者 2026-10-03：「不夠1Gb再來緊張，2gb還很多」）。
# 3. 用 systemd-run 限制 1500 MB、不用 swap（這台電腦 2026-09-30 因記憶體耗盡當機過）。
# 輪不到或記憶體不夠時結束碼 75（EX_TEMPFAIL），其他照指令本身的結束碼。
set -euo pipefail

if [ "$#" -eq 0 ]; then sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 2; fi

lock="${COWFARM_HEAVY_LOCK:-${XDG_CACHE_HOME:-$HOME/.cache}/cow-farm/heavy.lock}"
mkdir -p "$(dirname "$lock")"
exec 9>"$lock"
if ! flock -n 9; then
  echo "heavy.sh：前面有重的工作在跑，排隊中（最多 2 小時）…" >&2
  if ! flock -w 7200 9; then echo "heavy.sh：等了 2 小時還輪不到，先不跑" >&2; exit 75; fi
fi

avail=0
for i in $(seq 1 20); do
  avail="$(free -m | awk '/^Mem:/ {print $7}')"
  if [ "$avail" -ge 1000 ]; then break; fi
  if [ "$i" -eq 20 ]; then echo "heavy.sh：可用記憶體只有 ${avail} MB（< 1000 MB），10 分鐘都沒好轉，先不跑" >&2; exit 75; fi
  echo "heavy.sh：可用記憶體 ${avail} MB（< 1000 MB），30 秒後再看" >&2
  sleep 30
done

echo "heavy.sh：available=${avail} MB，開始：$*" >&2
# 鎖（fd 9）會傳給指令和它的子行程，整個指令跑完才放開
systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0 "$@"
