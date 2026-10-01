# cow-farm Agent Guide

## 專案

- 連線養成遊戲 app，平台是 iOS 和 Android，不做網站版。另外只做商店規定的隱私權政策和刪除帳號申請兩頁說明。
- 技術：app 用 Flutter，牧場畫面用 Flame；後端以 FastAPI 為主（M0 實測後確認）。
- 裁示和決定記在 `docs/decisions.md`；durable memory 的範圍是 `project:cow-farm`。
- 回覆使用者用繁體中文、白話。術語第一次出現時附一句解釋。

## 負責範圍

session 照進度分批開，名稱用 `cow-<角色>`。

| 角色 | 路徑 | 什麼時候開 |
|---|---|---|
| ceo（主 session） | `docs/`、全案協調、企劃與經濟平衡 | 現在 |
| cow-ui | `design/` | 2026-09-30 開（使用者提議，提前到畫風探索階段） |
| cow-back | `backend/`、`tests/`、協定文件 | M3 |
| cow-app | `app/` | M3 |
| cow-release | `.github/workflows/`、簽章、商店資料 | M4 |

每個角色都在自己的 worktree（`~/Desktop/cow-farm-worktrees/<角色>`）開分支，開 PR 給 ceo 讀過 diff 再合併，不直接推 main。ceo 在 `~/Desktop/cow-farm` 開分支，一樣走 PR。

記憶體安全：這台電腦 2026-09-30 因記憶體耗盡當機過。開 Playwright、headless Chrome、大型建置或長時間模擬之前，先看 `free -m`（available 少於 2000 MB 就等），指令用 `systemd-run --user --scope -q -p MemoryMax=1500M -p MemorySwapMax=0` 包起來，一次只跑一個。

## CI

- main 有分支保護：必要檢查 `backend`、`app` 全綠才能合併，只能 squash，管理員也不能略過（`.github/workflows/ci.yml`）。
  - `backend`：ruff、shellcheck、pip-audit、經濟引擎單元測試、伺服器 pytest（含 PostgreSQL 17）。
  - `app`：flutter analyze、flutter test。
- 本機只跑和改動相關的單一測試檔；完整測試、lint、建置交給 CI。PR 回報以 CI 結果為準，CI 紅燈才在本機重現那一項。
- 只留在本機做的：需要私人金鑰的 dry-run、實機驗收、對照設計稿的比對。
- 排版檢查還沒加：cow-back 開工的第一個 PR 用 ruff format 排好 `backend/`，cow-app 的第一個 PR 用 dart format 排好 `app/`，各自把檢查加進 CI。
- Dependabot 的 minor、patch 更新在必要檢查全綠後自動合併；major 由 ceo 看。

## 規則

- 所有帳都由伺服器算。用戶端不回報產量或結果，只負責顯示。
- 原創：不用「養豬場」「MIX」，也不沿用其他遊戲的名稱、畫風或畫面配置；股市裡的公司全部虛構。
- 牧場名稱由玩家自己取（D23，2026-10-01 取代「只能從詞庫挑」）。第一版不做過濾、檢舉、封鎖；被退件時照 D23 的備案補上。
- 不賣用真錢買的隨機商品。
- 牛肉用「出貨」呈現，畫面上不出現屠宰。
- 正式畫面要等使用者核准完整設計稿才能做；原型只能用色塊和文字。
- 不提交金鑰、憑證、簽章檔或 `.env`。處理金鑰照 secrets-custody 的規則。
- 技術決定照 tech-decision：引用官方文件原文，實測數字寫進 `docs/research/`。
