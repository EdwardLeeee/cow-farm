"""協定 1.4 節的錯誤碼表跟伺服器程式、字串表對得上（不需要資料庫）。

app 依錯誤碼查字串表顯示文案，所以這張表要完整（ceo 2026-10-02，PR #55 之後）：
- 伺服器丟得出來的代碼，每一個都在表上（#55 的 player_not_found 就是漏掉的例子）。
- 表上的代碼，伺服器程式裡都找得到（拿掉的碼要從表上刪，寫進表下的「v2 拿掉的」）。
- 伺服器寫死狀態碼的地方，跟表上的 HTTP 欄一樣（上架以後不換狀態碼）。
- 表上「app 文案」欄的 key 都在 design/m2/i18n/zh-Hant.json。

伺服器程式用 ast 讀 server/*.py，代碼的來源有兩種：
- EMITTERS 列的呼叫：GameError(...)、_err(...)、_close_player_ws(...) 的代碼參數。
- 同時有 "code" 和 "message" 的 dict（配種、借種、出貨預覽的 blockers）。
代碼不是寫死的字串時，只接受 PASS_THROUGH 列的轉手寫法（它們的來源已經被上面兩種收進來）。出現新的寫法，
這裡會失敗：先確認它丟得出的代碼都在表上，再加進 PASS_THROUGH。
"""

from __future__ import annotations

import ast
import json
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pytest

BACKEND = Path(__file__).resolve().parents[1]
ROOT = BACKEND.parent
PROTOCOL = ROOT / "docs" / "protocol.md"
ZH = ROOT / "design" / "m2" / "i18n" / "zh-Hant.json"

# 函式名 → (代碼是第幾個位置參數, 狀態碼是第幾個位置參數, 狀態碼的預設值)。也接受 code=、status= 關鍵字。
# 狀態碼的位置是 None：不是 HTTP 回應（關 WebSocket 前送的錯誤）。
EMITTERS = {"GameError": (0, 2, 409), "_err": (1, 0, None), "_close_player_ws": (1, None, None)}
# (所在函式, 代碼的寫法)
PASS_THROUGH = {
    ("_err", "code"),  # app.py：_err 自己組 JSON
    ("_game_error", "exc.code"),  # app.py：GameError → JSON
    ("ship_preview", "e.code"),  # app.py：出貨預覽把 GameError 放進 blockers
    ("ws", "e.code"),  # app.py：WebSocket 連線時的 GameError
    ("breed", "b['code']"),  # game.py：配種的 blockers
    ("stud_borrow", "b['code']"),  # game.py：借種的 blockers
    ("_close_player_ws", "code"),  # runtime.py：關 WebSocket 前送的錯誤
}
KEY = re.compile(r"[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)*")


def error_table() -> Dict[str, Tuple[Optional[int], str]]:
    """1.4 節的表：代碼 → (HTTP 狀態碼，4xx 這種不固定的是 None；「app 文案」欄)。"""
    text = PROTOCOL.read_text(encoding="utf-8")
    sec = text[text.index("### 1.4") : text.index("### 1.5")]
    rows: Dict[str, Tuple[Optional[int], str]] = {}
    for line in sec.splitlines():
        m = re.match(r"\|\s*(\d{3}|\dxx)\s*\|\s*`([a-z_]+)`\s*\|", line)
        if not m:
            continue
        cols = [c.strip() for c in line.strip().strip("|").split("|")]
        assert len(cols) == 6, f"錯誤碼表這一列的欄數不對：{line}"
        code = m.group(2)
        assert code not in rows, f"錯誤碼表重複：{code}"
        rows[code] = (int(m.group(1)) if m.group(1).isdigit() else None, cols[4])
    assert len(rows) > 30, "找不到 1.4 節的錯誤碼表"
    return rows


class _Scan(ast.NodeVisitor):
    def __init__(self, name: str):
        self.name = name
        self.func: List[str] = []
        self.found: List[Tuple[str, Optional[int], str]] = []  # (代碼, HTTP 狀態碼或 None, 位置)
        self.unknown: List[str] = []

    def visit_FunctionDef(self, node):
        self.func.append(node.name)
        self.generic_visit(node)
        self.func.pop()

    visit_AsyncFunctionDef = visit_FunctionDef

    def _code(self, node, arg: ast.expr, status: Optional[int]) -> None:
        where = f"{self.name}:{node.lineno}"
        fn = self.func[-1] if self.func else "<module>"
        if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
            self.found.append((arg.value, status, where))
        elif (fn, ast.unparse(arg)) not in PASS_THROUGH:
            self.unknown.append(f"{where} {fn}()：{ast.unparse(arg)}")

    def visit_Call(self, node):
        f = node.func
        name = f.id if isinstance(f, ast.Name) else f.attr if isinstance(f, ast.Attribute) else None
        if name in EMITTERS:
            code_i, status_i, default = EMITTERS[name]
            code = _arg(node, code_i, "code")
            if code is not None:
                status = None
                if status_i is not None:
                    s = _arg(node, status_i, "status")
                    if s is None:
                        status = default
                    elif isinstance(s, ast.Constant) and isinstance(s.value, int):
                        status = s.value
                self._code(node, code, status)
        self.generic_visit(node)

    def visit_Dict(self, node):
        d = {k.value: v for k, v in zip(node.keys, node.values) if isinstance(k, ast.Constant)}
        if "code" in d and "message" in d:
            self._code(node, d["code"], None)
        self.generic_visit(node)


def _arg(call: ast.Call, i: int, keyword: str) -> Optional[ast.expr]:
    if len(call.args) > i:
        return call.args[i]
    return next((k.value for k in call.keywords if k.arg == keyword), None)


def scan(sources: Dict[str, str]) -> Tuple[List[Tuple[str, Optional[int], str]], List[str]]:
    found: List[Tuple[str, Optional[int], str]] = []
    unknown: List[str] = []
    for name, text in sources.items():
        s = _Scan(name)
        s.visit(ast.parse(text))
        found += s.found
        unknown += s.unknown
    return found, unknown


def server_sources() -> Dict[str, str]:
    return {p.name: p.read_text(encoding="utf-8") for p in sorted((BACKEND / "server").glob("*.py"))}


def test_scanner_finds_codes_and_flags_new_dynamic_sources():
    """測試本身會抓：寫死的代碼收進來（含狀態碼），不認得的轉手寫法列出來。"""
    found, unknown = scan(
        {
            "x.py": (
                "def f(pid, why):\n"
                "    raise GameError('player_not_found', '找不到', 404)\n"
                "def g(b):\n"
                "    out = [{'code': 'pen_full', 'message': '滿了'}]\n"
                "    raise GameError(why, '?')\n"
                "def h():\n"
                "    return _err(503, code='maintenance', message='維護中')\n"
            )
        }
    )
    assert ("player_not_found", 404, "x.py:2") in found and ("pen_full", None, "x.py:4") in found
    assert ("maintenance", 503, "x.py:7") in found
    assert unknown == ["x.py:5 g()：why"]


def test_every_code_the_server_sends_is_in_the_table():
    table = error_table()
    found, unknown = scan(server_sources())
    assert not unknown, "代碼不是寫死的字串，也不在 PASS_THROUGH（見檔頭說明）：\n" + "\n".join(unknown)
    missing = sorted({f"{c}（{w}）" for c, _, w in found if c not in table})
    assert not missing, "伺服器丟得出、協定 1.4 節的表上沒有：" + "、".join(missing)


def test_every_code_in_the_table_is_sent_by_the_server():
    sent = {c for c, _, _ in scan(server_sources())[0]}
    extra = sorted(set(error_table()) - sent)
    assert not extra, "協定 1.4 節的表上有、伺服器程式找不到（拿掉的碼要從表上刪）：" + "、".join(extra)


def test_http_status_matches_the_table():
    table = error_table()
    wrong = sorted(
        {
            f"{c}：程式 {s}、表上 {table[c][0]}（{w}）"
            for c, s, w in scan(server_sources())[0]
            if s is not None and c in table and table[c][0] is not None and s != table[c][0]
        }
    )
    assert not wrong, "狀態碼跟協定 1.4 節的表不一樣：" + "、".join(wrong)


def test_app_copy_keys_are_in_the_string_table():
    if not ZH.exists():
        pytest.skip(f"找不到 {ZH}")
    keys = set(json.loads(ZH.read_text(encoding="utf-8")))
    bad = []
    for code, (_, copy) in error_table().items():
        names = [k for k in re.findall(r"`([^`]+)`", copy) if not k.startswith("{")]  # {n} 這種是佔位符
        if not names and not re.search(r"畫面 S\d|見 \d", copy):
            bad.append(f"{code}：app 文案欄沒有 key，也沒有指到畫面")
        bad += [f"{code}：{k}" for k in names if not KEY.fullmatch(k) or k not in keys]
    assert not bad, "app 文案的 key 不在 zh-Hant.json：" + "、".join(bad)
