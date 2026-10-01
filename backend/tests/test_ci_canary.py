"""CI 驗證用：故意失敗，確認 pytest 會擋（之後拿掉）。"""


def test_ci_canary():
    assert 1 == 2, "故意失敗：確認 CI 會擋"
