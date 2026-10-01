// CI 驗證用：故意失敗，確認 flutter test 會擋（之後拿掉）。
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ci canary', () {
    expect(1, 2, reason: '故意失敗：確認 CI 會擋');
  });
}
