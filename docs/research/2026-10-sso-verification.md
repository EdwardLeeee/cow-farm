# 伺服器怎麼驗證 Apple、Google 的登入憑證，Apple 登入怎麼撤銷：查證與 spike

- 日期：2026-10-02
- 負責：cow-back（只研究；伺服器程式在 PR 9b）
- 問題（brief 2026-10-01-back.md 3.7）：「先照 tech-decision 查 Apple、Google 官方文件，把驗證步驟和原文寫進 `docs/research/`。要查的是：Apple identity token 和 Google ID token 怎麼驗證，Apple 撤銷登入需要哪些東西。」
- 依據：D22（綁定 Apple／Google 帳號，不做移轉碼）、企劃書 4.11、`docs/research/2026-10-account-transfer.md`（Apple 4.8、5.1.1(v) 的原文）、`docs/protocol.md` 第 5 節草稿（#24）。

## 先說結論

1. **做得到，套件選 PyJWT＋cryptography。** PyJWT 2.15.1 和 cryptography 50.0.2 都支援 Python 3.10，pip-audit 沒有已知漏洞。spike 用自己產生的金鑰照兩家文件的步驟驗：
   - 簽章、`aud`、`iss`、過期都驗得出來；`aud` 錯、`iss` 錯、過期、偽造的 `alg=none` 都擋得住。
   - Apple 要的 client secret（ES256）簽得出來；refresh token 加密後解得回來。
   - 速度：驗一張 token 中位數 0.13–0.17 毫秒。慢的是第一次抓公鑰：Apple 約 0.5 秒、Google 約 0.03 秒。所以公鑰要快取，而且驗證放到背景執行緒，不擋住伺服器。
2. **Apple 撤銷登入要「這個使用者的 refresh token」，只能在綁定當下換到。**
   - 撤銷（`/auth/revoke`）要 refresh token 或 access token。這兩個只能拿 app 登入時拿到的 authorization code（只能用一次、很快過期）去 `/auth/token` 換。
   - 所以綁定 Apple 時，app 除了 identity token 還要送 authorization code。伺服器換到 refresh token 後加密保存，刪除牧場或解除綁定時拿它撤銷。
   - refresh token 是憑證，不是身分資料，照 secrets-custody 保管。資料庫的身分資料仍然只有帳號識別碼（`sub`）和綁定時間。
3. **兩家都要伺服器比對 nonce（防重放），建議加 `POST /v1/account/nonce`。**
   - Apple 的驗證步驟第 2 條是「Verify the `nonce` for the authentication」。
   - Google（Android）：「Ensure that your server-side code validates that the request and response nonces are identical.」
   - nonce 由伺服器發、只能用一次、10 分鐘有效。這是協定草稿（#24）沒有的端點，app 的登入流程多一步：先拿 nonce → 交給登入套件 → 把拿到的 token 和 nonce 一起送給伺服器。
4. **刪除牧場改成「軟刪除」**（ceo 2026-10-02 原則同意，有條件）。
   - 保留一筆沒有個資的空殼：只剩牧場編號和建立、刪除的時間；名字、帳號識別碼、token 雜湊、refresh token 都清掉。其他資料照刪，刪除後任何畫面都看不到它。
   - 好處：不用把成交紀錄（`trades`）的外鍵改成 SET NULL，也不用第三次升存檔格式；牧場編號（#1234）永遠不會被別人重複使用。
   - 為什麼仍然算 Apple 5.1.1(v) 說的「刪除帳號」，見第 1.5 節。
   - Apple 自己要求伺服器保存 refresh token（TN3194），5.1.1(v)「不能把憑證存在裝置外」講的是社群網路的憑證（第 1.4 節）。
5. **分階段**：
   - M3（PR 9b）：伺服器全部流程用假的驗證器測；真的驗證程式另外用自己產生的金鑰測。
   - M4：使用者照 ceo 的步驟在 Apple Developer 建金鑰（.p8）、在 Google Cloud 建 client ID，填進伺服器的環境變數就能用。實機驗收 `aud` 等欄位。

## 名詞

- **identity token／ID token**：使用者用 Apple／Google 登入後，Apple／Google 發給 app 的一張 JWT。裡面寫這是哪個帳號（`sub`）、發給哪個 app（`aud`）、誰發的（`iss`）、什麼時候過期（`exp`），並且有 Apple／Google 的數位簽章，別人改不了。
- **JWT**：一種帶簽章的小資料包，格式是三段 base64，用「.」隔開。
- **JWKS（公鑰清單）**：Apple／Google 公開的一組公鑰。伺服器用它檢查 token 的簽章是不是真的。
- **nonce**：一次性的亂數。登入前由伺服器發給 app，登入時會被寫進 token。伺服器收到 token 時比對、用掉，別人拿舊的 token 來重送就會被擋。
- **authorization code**：Apple 登入時給 app 的一次性換票碼，伺服器拿它去 Apple 換 refresh token。
- **refresh token**：Apple 發給伺服器、長期有效的憑證。撤銷登入時要用它。
- **client secret**：伺服器自己用 Apple 金鑰簽的一張 JWT，向 Apple 證明「是這個 app 的伺服器在呼叫」。
- **.p8 金鑰**：在 Apple Developer 建立、只能下載一次的私鑰檔，用來簽 client secret。

## 1. 正確性：官方文件的驗證步驟

### 1.1 Apple identity token

`Verifying a user`（developer.apple.com/documentation/signinwithapple/verifying-a-user）：

> To verify the identity token, your app server must:
> - Verify the JWS E256 signature using the server's public key
> - Verify the `nonce` for the authentication
> - Verify that the `iss` field contains `https://appleid.apple.com`
> - Verify that the `aud` field is the developer's `client_id`
> - Verify that the time is earlier than the `exp` value of the token

- **簽章演算法是 RS256，不是文件寫的「E256」。** Apple 自己公開的設定都寫 RS256：
  - `https://appleid.apple.com/.well-known/openid-configuration` 的 `id_token_signing_alg_values_supported` 是 `["RS256"]`。
  - 公鑰清單 `https://appleid.apple.com/auth/keys` 的 3 把都是 `RSA`、`RS256`（2026-10-02 抓）。
  - 要用 ES256 的是伺服器自己簽的 client secret（1.3 節）。伺服器只接受 RS256，不讓 token 自己指定演算法。
- **公鑰**：`Fetch Apple's public key to verify token signatures`：「The endpoint can return multiple keys, and the count of keys can vary over time. From this set of keys, select the key with the matching key identifier (`kid`)」。
- **`sub`**（`id_token` 說明）：「Consists of a unique, stable string, and serves as the primary identifier of the user」、「Doesn't change if the user stops using Sign in with Apple with your app and later starts using it again」。伺服器只存這個。
- **email 不存**：「Don't use this value as an identifier of the user. For a unique identifier for the user refer to the `sub` value.」email 可能是轉寄用的假地址，伺服器拿到也不存、不寫日誌。
- **nonce**：「A string for associating a client session with the identity token. This value mitigates replay attacks and is present only if you pass it in the authorization request.」另外有 `nonce_supported`：「If this claim returns `true`, treat `nonce` as mandatory and fail the transaction」。
- **`aud`（client_id）**：原生 iOS app 的 client_id 是 App ID，也就是 bundle ID `com.oraclelee.cowfarm`。文件只寫「the `client_id` from your developer account」，M4 實機驗收時再確認一次。

### 1.2 Google ID token

`Verify the Google ID token on your server side`（developers.google.com/identity/gsi/web/guides/verify-google-id-token，2025-12-22 更新）：

> - The ID token is properly signed by Google. Use Google's public keys (available in JWK or PEM format) to verify the token's signature.
> - The value of `aud` in the ID token is equal to one of your app's client IDs.
> - The value of `iss` in the ID token is equal to `accounts.google.com` or `https://accounts.google.com`.
> - The expiry time (`exp`) of the ID token has not passed.

- **公鑰**：`https://www.googleapis.com/oauth2/v3/certs`（JWK），「examine the `Cache-Control` header in the response to determine when you should retrieve them again」。
- **只用 `sub`**：「Only use Google ID token `sub` field as identifier for the user as it is unique among all Google Accounts and never reused」；「don't use email address as an identifier because a Google Account can have multiple email addresses at different points in time」。
- **手機 app 的 `aud` 是伺服器（Web）的 client ID**：
  - iOS（developers.google.com/identity/sign-in/ios/backend-auth，2025-05-19 更新）：「Specify the WEB_CLIENT_ID of the app that accesses the backend」。
  - Android（Credential Manager，developer.android.com/identity/sign-in/credential-manager-siwg-implementation，2026-09-16 更新）：`setServerClientId(WEB_CLIENT_ID)`。
  - 所以伺服器設定的 Google client ID 是 Web 那一個（M4 在 Google Cloud 建）。
- **不能只收使用者編號**（iOS backend-auth）：「Do not accept plain user IDs … A modified client application can send arbitrary user IDs to your server to impersonate users.」所以 app 一定要送整張 ID token，伺服器自己驗。
- **nonce**（Android）：「To prevent replay attacks, you can include a nonce for server-side verification with `setNonce()`. Ensure that your server-side code validates that the request and response nonces are identical.」
- Google 官方的 Python 套件 `google-auth` 有 `id_token.verify_oauth2_token(...)`，「verifies the JWT signature, the `aud` claim, and the `exp` claim」。我們不用它的理由見第 4 節。

### 1.3 Apple 撤銷登入要什麼

`Token revocation`（developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens）：

> In order to revoke authorization for a user, you must obtain a valid refresh token or access token. If you don't have either token for the user, you can generate tokens when validating an authorization code.

- 撤銷：`POST https://appleid.apple.com/auth/revoke`，表單欄位 `client_id`、`client_secret`、`token`（refresh token）、`token_type_hint=refresh_token`。「the `revoke` endpoint returns a `200` response code without a response body after the server invalidates the `token` value, or if the `token` value was previously invalidated」，所以重試是安全的。
- 換 refresh token（`Token validation`）：`POST https://appleid.apple.com/auth/token`，`client_id`、`client_secret`、`code`、`grant_type=authorization_code`，回應有 `refresh_token`。
  - authorization code 只能用一次（`ErrorResponse` 的 `invalid_grant`：「invalid code (expired or previously used authorization code)」）。所以伺服器要在綁定當下換，不能之後再換。
  - 「You may continue to use the same refresh token until it's invalidated」。伺服器不需要定期去 Apple 驗它（文件說一天最多一次，太多會被限流）；只在撤銷時用。
- **client secret**（`Creating a client secret`，developer.apple.com/documentation/accountorganizationaldatasharing/creating-a-client-secret）。這頁是 Apple 另一個 API 的說明，格式跟 Sign in with Apple 一樣；Sign in with Apple 原本那一頁搬家後找不到：
  - 標頭 `alg: ES256`、`kid`：金鑰的 10 字元識別碼。
  - 內容：`iss`（10 字元的 Team ID）、`iat`、`exp`（「more than `15777000` seconds (six months) in the future」是錯的）、`aud: https://appleid.apple.com`、`sub`（「the same App ID or Services ID that you use as the `client_id`」）。
  - 「sign it using the Elliptic Curve Digital Signature Algorithm (ECDSA) with the P-256 curve and the SHA-256 hash algorithm」。
  - 伺服器每次要用時現簽一張（有效 1 小時就夠），不用存。

### 1.4 伺服器保存 Apple 的 refresh token 合不合規定

- App Store 審核準則 5.1.1(v) 最後兩句：「The app must also include a mechanism to revoke social network credentials and disable data access between the app and social network from within the app. An app may not store credentials or tokens to social networks off of the device …」
- 這兩句講的是社群網路的帳號（同一段列的例子是「Facebook, WeChat, Weibo, X」），不是 Sign in with Apple。Apple 自己的技術說明要求伺服器保存 Apple 的 token：
  - TN3194（2025-10-03 發布，developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple）：「securely store user credentials—for example, identity tokens and refresh tokens—and consider using a server infrastructure to handle token generation, validation, and revocation」。
  - 同一份的建立帳號步驟：「Once the authorization code is validated, securely store the token response — including the identity token, refresh token, and access token.」
- 所以伺服器加密保存 refresh token、刪除時撤銷，是照 Apple 的建議做。identity token 驗完就丟，不存（我們只要 `sub`）。

### 1.5 刪除帳號的規則，和「軟刪除」為什麼仍然算刪除

- 準則 5.1.1(v)：「If your app supports account creation, you must also offer account deletion within the app.」
- `Offering account deletion in your app`（developer.apple.com/support/offering-account-deletion-in-your-app，頁面沒有更新日期）：
  - 「Offer to delete the entire account record, along with associated personal data. You may include additional options, but only offering to temporarily deactivate or disable an account is insufficient.」
  - 「Deleting an account removes the account from the developer's records, along with any data associated with the account that the developer isn't legally required to maintain.」
  - 「Apps that support Sign in with Apple should use the Sign in with Apple REST API to revoke user tokens.」
- TN3194 列出刪除時要清的東西：「Delete all user-related account data, including: The token used for token revocation; Any user-related data stored in your app servers; …」。
- 拿不到 token 時的做法（TN3194）：「If you don't have the user's refresh token, access token, or authorization code, you must still fulfill the user's account deletion request … Delete the user's account data from your systems. Direct the user to manually revoke access for your client.」
  - 對我們的意思：Apple 撤銷失敗（例如 Apple 連不上），刪除照樣完成，撤銷放進佇列之後重試。

**軟刪除為什麼仍然算刪除帳號**（第 5.3 節的做法；ceo 2026-10-02 的條件）：

- 刪掉的：
  - 牧場名、登入憑證的雜湊、所有 Apple／Google 綁定（帳號識別碼）、Apple 的 refresh token（撤銷後刪除）。
  - 牧場的全部進度（牛、金幣、倉庫、田地、圖鑑、等級），以及排行榜和借種市場上的資料。
  - request_id 的記錄：裡面存著當時的回應，含牧場名。
  - 失效憑證的記錄。
  - 別人借種紀錄裡指向他的編號也改成空的。
- 留下的只有一列空殼：牧場編號（一個數字）、建立和刪除的時間。它沒有任何能對應到這個人的資料，也不能恢復：沒有登入憑證、沒有進度，也沒有綁定可以找回。所以不是 Apple 說的「暫時停用」。
- 留空殼的唯一目的，是讓編號不會被下一個新牧場重複使用。不然「#1234」會一下是 A、一下是 B，出現在別人的借種紀錄或之後的客服紀錄裡就會混淆。
- 市場的成交紀錄（`trades`）留著那個編號，因為伺服器當機回復要靠它重算行情。這些紀錄只有數量、價格、時間，連到的是空殼。
- **M5 隱私權政策要寫**：
  - 刪除牧場後，伺服器會刪掉牧場名、Apple／Google 帳號識別碼和所有遊戲資料，並撤銷 Apple 登入。
  - 只留下一個不含個人資料的牧場編號（避免編號重複使用），和匿名的市場成交數量與價格（計算行情用）。
  - 刪除馬上生效。只有 Apple 撤銷暫時失敗時，伺服器會在背景重試。

## 2. 速度

量法：`docs/research/sso/sso_spike.py`，結果在 `docs/research/sso/result-2026-10-02.json`。環境：開發機 Intel i5-8250U、Python 3.10.12、PyJWT 2.15.1，網路是家用寬頻（台灣）。

| 項目 | 結果 |
|---|---|
| 第一次抓 Apple 公鑰（`/auth/keys`） | 454–513 毫秒（跑三次） |
| 第一次抓 Google 公鑰（`/oauth2/v3/certs`） | 22–35 毫秒 |
| 驗一張 RS256 token（公鑰已在記憶體，1,000 次） | 中位數 0.13–0.17 毫秒，最慢 0.4–0.8 毫秒 |

- 公鑰用 `PyJWKClient(cache_keys=True, lifespan=3600)` 快取。遇到不認得的 `kid` 再重抓：Apple 會換鑰，文件說「the count of keys can vary over time」。
- 抓公鑰、呼叫 Apple 的 `/auth/token`、`/auth/revoke` 都是網路呼叫，用 `asyncio.to_thread` 或非同步的 httpx 做，不擋住處理其他玩家的事件迴圈。
- 綁定、找回一個玩家一輩子沒幾次，負載可以忽略。

## 3. 大小與依賴

- 新增 `pyjwt==2.15.1`（純 Python）和 `cryptography==50.0.2`。cryptography 有 CPython 3.10 的 manylinux 預編譯檔（x86_64、aarch64），不用在主機上編譯。
- 呼叫 Apple 用 requirements 裡已經有的 `httpx`，不另外加套件。
- pip-audit（2026-10-02，requirements＋這兩個套件）：「No known vulnerabilities found」。

## 4. 替代方案比較

| | A. PyJWT＋cryptography（建議） | B. google-auth（Google 官方 Python 套件） | C. Firebase Authentication |
|---|---|---|---|
| Apple | 可以（同一套程式） | 不行，要另外找 | 可以 |
| Google | 可以 | 可以（官方） | 可以 |
| 新增依賴 | 2 個 | google-auth、requests（Apple 還要另一套） | 另一個雲端服務、帳號和主控台 |
| 資料去哪裡 | 只在我們的伺服器 | 只在我們的伺服器 | 使用者資料經過 Google 的服務 |
| Apple 撤銷 | 自己呼叫 `/auth/revoke` | 一樣要自己做 | 一樣要自己存 refresh token、自己呼叫 |

nonce 的做法：

| | 伺服器發 nonce（建議） | app 自己產生 nonce、跟 token 一起送 | 不用 nonce |
|---|---|---|---|
| 防重放 | 有：nonce 只能用一次 | 弱：偷得到 token 的人通常也拿得到 nonce | 沒有 |
| 跟文件 | 符合 Apple 第 2 條、Google 的建議 | 形式上符合 | 不符合 Apple 的步驟 |
| app 多做的事 | 登入前多打一個請求 | 沒有 | 沒有 |

**不建議**：
- B：只解決 Google 一半，Apple 還是要 A 的做法，等於兩套程式。
- C：為了驗證兩張 token 多一個雲端服務、多一份資料外流的說明，撤銷 Apple 還是要自己做。
- 不用 nonce：Apple 的驗證步驟明寫要比對。

## 5. 對現有架構的影響

### 5.1 協定（`docs/protocol.md` 第 5 節，這個 PR 一起改）

- 新增 `POST /v1/account/nonce`（不用 token）：回 `nonce`、`expires_at_real`。只能用一次，10 分鐘有效。
- 綁定、找回要送 `nonce`。比對規則：token 裡的 `nonce` 等於原值，或等於原值的 SHA-256（十六進位小寫）都算對。有些登入套件會先做 SHA-256 再交給 Apple，這樣兩種都接得上。
- 綁定 Apple 要送 `authorization_code`（第 1.3 節）。
- `request_id`（選填）：綁定、換回、找回、刪除都可以帶，10 分鐘內重送回第一次的回應（ceo 2026-10-02 要求換回、刪除要有）。這跟建立牧場（2.1 節）不一樣，差別如下：
  - 建立牧場的 request_id 記在資料庫，重送會發一個新的 token。
  - 這四個只記在記憶體，重送回的是**同一個**回應（換回、找回的回應裡有新的 token），伺服器重開就沒有了。
  - 換回、刪除成功以後，舊 token 已經失效，所以這兩個端點要先查重送記錄再驗 token。記錄的 key 是 request_id 加舊 token 的雜湊，別人拿不到。
- `sign_in_failed` 的 `reason`：`token_invalid`、`token_expired`、`nonce_invalid`、`code_invalid`、`ticket_invalid`、`ticket_expired`、`not_configured`（伺服器還沒設定 Apple／Google，M4 以前的開發伺服器就是這樣）。

### 5.2 資料

| 表 | 內容 | 不放的東西 |
|---|---|---|
| `account_links` | provider、`sub`、牧場編號、綁定時間；Apple 另有加密的 refresh token | email、姓名、identity token |
| `revoked_tokens` | 失效登入憑證的雜湊、牧場編號、原因（在另一支手機找回） | 原本的 token |
| `apple_revoke_queue` | 待撤銷的 refresh token（加密）、試了幾次。Apple 暫時連不上時，伺服器之後自己重試 | — |

- 加密：cryptography 的 Fernet（AES-128-CBC＋HMAC-SHA256）。金鑰從檔案讀（環境變數 `COWFARM_TOKEN_KEY_FILE`，權限 600），不進 git、不寫日誌。金鑰不見了，存的 refresh token 就解不開，那時只能等使用者自己到 Apple 帳號設定解除。
- 日誌不寫 identity token、authorization code、refresh token、nonce（伺服器原本就不記存取日誌）。

### 5.3 刪除牧場：軟刪除

原本的做法是「`trades` 的外鍵改 SET NULL，刪掉牧場那一列」（ceo 2026-10-02 同意過）。查證後改成軟刪除；ceo 2026-10-02 原則同意，條件是空殼不能留任何個資、刪除後任何畫面都看不到（第 1.5 節）。

- 做法（同一個資料庫交易）：
  - `players` 加 `deleted_at`。這一列留著，`ranch_name` 清空、`token_sha256` 設成 NULL。
  - 刪掉：`farms`（全部進度）、`account_links`（綁定和帳號識別碼）、`revoked_tokens`（失效憑證的雜湊）、`processed_requests` 和 `session_requests`（request_id 的記錄，裡面有牧場名）。
  - `stud_log` 裡指向他的出借方、借入方改成 NULL。
  - 他上架的公牛下架；Apple 的 refresh token 移到撤銷佇列，撤銷成功就刪。
  - 記憶體：從玩家、登入憑證、排行榜快取拿掉；開著的 WebSocket 用 4401 關掉。
  - 載入世界時跳過已刪除的；新牧場的編號接在「含已刪除的最大編號」後面。
- 好處：
  - 不用改 `trades`、`stud_log` 的外鍵，也就不用第三次升存檔格式（現在是 4）。
  - 牧場編號永遠不會被別人重複使用，「#1234」不會一下是 A、一下是 B。
  - 別人的借種紀錄照樣顯示「已刪除的牧場」：那一筆的對方是 NULL，回 `ranch: null`。
- 排行榜、借種市場、任何回應都不會再出現這個牧場（記憶體裡已經沒有它）。企劃書 4.11「伺服器刪除帳號、進度與排行榜紀錄」照樣成立。

### 5.4 Apple 帳號那邊被撤銷時（ceo 2026-10-02 同意：M4 做）

- 使用者也可以自己到 Apple 帳號設定，停止讓我們的 app 使用 Apple 登入。TN3194：iOS app 可以收 `credentialRevokedNotification`；伺服器可以登記一個網址收 Apple 的 server-to-server 通知（`consent-revoked`）。
- 對我們的意思：那個 Apple 綁定失效了，牧場本身還在（訪客帳號照樣能玩）。
- M4 有正式主機和 HTTPS 時，在 Apple Developer 登記通知網址；伺服器收到「停用」（`consent-revoked`）或「刪除 Apple 帳號」（`account-delete`）就解除那個綁定、刪掉 refresh token（ceo 2026-10-02 同意，記在 m3-backlog 的 M4 一節）。這要多一個公開的端點和 Apple 的設定，所以不放在 M3 的 9b。

### 5.5 設定（M4 由使用者照 ceo 的步驟做，這裡只列伺服器要讀的）

| 環境變數 | 內容 |
|---|---|
| `COWFARM_APPLE_CLIENT_IDS` | Apple 的 client_id（App ID：`com.oraclelee.cowfarm`） |
| `COWFARM_GOOGLE_CLIENT_IDS` | Google 的 Web client ID |
| `COWFARM_APPLE_TEAM_ID`、`COWFARM_APPLE_KEY_ID`、`COWFARM_APPLE_KEY_FILE` | Team ID、金鑰 ID、.p8 檔的路徑（權限 600，不進 git） |
| `COWFARM_TOKEN_KEY_FILE` | 加密 refresh token 的金鑰檔（第一次啟動時沒有就產生，權限 600） |

沒設定的那一家，綁定和找回回 `sign_in_failed`（`reason: not_configured`），其他功能照常。

## 6. 建議與分階段

1. **PR 9a（這個）**：研究文件＋協定第 5 節修訂。ceo 審過、通知 cow-app，app 才照新的登入流程寫。
2. **PR 9b**：伺服器程式。
   - 範圍：nonce、綁定、解除、找回、換回、刪除（軟刪除，第 5.3 節的清單）、舊手機 `signed_in_elsewhere`、Apple 撤銷佇列與重試。
   - 驗收：
     - 全部流程用假的驗證器測；舊 token 回 401 和 4401；Apple 撤銷有被呼叫，失敗會重試。
     - 資料庫掃一遍：沒有 email、姓名；刪除後空殼只剩編號和時間，所有表都找不到他的帳號識別碼、token 雜湊、牧場名。
     - 真的驗證程式另外用自己產生的金鑰和假的公鑰清單測（`aud`、`iss`、過期、nonce、alg）。
     - 呼叫 Apple 的程式用 httpx 的假傳輸層測請求格式。
3. **M4**：
   - 使用者建 Apple 金鑰（.p8）和 Google 的 Web client ID，填進主機的環境變數。
   - 實機驗收：iPhone「綁定 Apple → 刪掉 app → 重裝 → 找回牧場」；「刪除牧場 → Apple 帳號設定裡看不到這個 app」。Google 先用 Android 模擬器。

## 附錄

### 重現

```bash
cd backend
.venv/bin/pip install pyjwt==2.15.1 cryptography==50.0.2
.venv/bin/python ../docs/research/sso/sso_spike.py > ../docs/research/sso/result-$(date +%F).json
curl -s https://appleid.apple.com/.well-known/openid-configuration | python3 -m json.tool | grep -A2 signing_alg
(cat requirements.txt; echo pyjwt==2.15.1; echo cryptography==50.0.2) > /tmp/req.txt && .venv/bin/pip-audit -r /tmp/req.txt
```

### 限制

- 沒有用真的 Apple、Google 帳號試，要等 M4 建好金鑰和 client ID。spike 的 token 是自己的金鑰簽的，證明的是「驗證程式照文件的步驟擋得住錯的 token」。
- Apple 文件寫「JWS E256」，跟 Apple 自己的設定（RS256）不一致，以設定為準（第 1.1 節）。
- Sign in with Apple 自己的「Creating a client secret」頁搬家後找不到，引用的是另一個 API 同格式的頁面。M4 第一次換 refresh token 時就能確認。
- 原生 iOS app 的 `aud` 是不是 bundle ID，文件沒有直接寫，M4 實機確認。
- Google ID token 預設會帶 email、名字、頭像。伺服器不存；app 端能不能少要一點，由 cow-app 查（m3-backlog）。

### 來源（2026-10-02 讀取）

- Apple：Verifying a user — developer.apple.com/documentation/signinwithapple/verifying-a-user
- Apple：id_token — developer.apple.com/documentation/signinwithapplejs/authorizationi/id_token
- Apple：Token validation — developer.apple.com/documentation/signinwithapplerestapi/generate-and-validate-tokens
- Apple：Token revocation — developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens
- Apple：ErrorResponse — developer.apple.com/documentation/signinwithapplerestapi/errorresponse
- Apple：Fetch Apple's public key — developer.apple.com/documentation/signinwithapplerestapi/fetch-apple's-public-key-for-verifying-token-signature
- Apple：Creating a client secret — developer.apple.com/documentation/accountorganizationaldatasharing/creating-a-client-secret
- Apple：OpenID 設定 — appleid.apple.com/.well-known/openid-configuration；公鑰 appleid.apple.com/auth/keys
- Apple：App Store Review Guidelines 5.1.1(v) — developer.apple.com/app-store/review/guidelines
- Apple：Offering account deletion in your app — developer.apple.com/support/offering-account-deletion-in-your-app
- Apple：TN3194 Handling account deletions and revoking tokens for Sign in with Apple（2025-10-03）— developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple
- Google：Verify the Google ID token on your server side — developers.google.com/identity/gsi/web/guides/verify-google-id-token
- Google：Authenticate with a backend server（iOS）— developers.google.com/identity/sign-in/ios/backend-auth
- Android：Implement Sign in with Google（Credential Manager）— developer.android.com/identity/sign-in/credential-manager-siwg-implementation
- PyPI：pyjwt 2.15.1（requires-python ≥3.9）、cryptography 50.0.2（requires-python ≥3.9）
