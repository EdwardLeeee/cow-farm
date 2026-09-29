# cow-farm（養牛遊戲，暫名）

iOS 與 Android 的連線養成遊戲：養牛、配種收集，賣牛奶和牛肉。牛奶和牛肉的收購價由全部玩家共用，會像股票一樣漲跌。

- 目前階段：M0 立項（2026-09-30 開始）。
- 裁示與決定：[`docs/decisions.md`](docs/decisions.md)
- 協作規則：[`AGENTS.md`](AGENTS.md)

## 資料夾

| 路徑 | 內容 |
|---|---|
| `docs/design/` | 企劃書 |
| `docs/research/` | 研究筆記、經濟模擬與實測程式 |
| `docs/decisions.md` | 使用者裁示與技術決定 |
| `design/artboards/` | 設計稿，每輪一個資料夾 |

M1 之後會再加上 `backend/`（FastAPI 伺服器）、`app/`（Flutter app）和 `tests/`。
