// 牛怎麼畫的實測腳本 10：pubspec 的 asset transformer（vector_graphics_compiler）在 flutter test 也會跑嗎？
// 會的話，rootBundle 讀到的是編好的 .vec（不是 '<' 開頭的 SVG 文字），AssetBytesLoader 也解得開。
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics/vector_graphics.dart' show AssetBytesLoader;

void main() {
  testWidgets('asset transformer 在 flutter test 會跑', (tester) async {
    await tester.runAsync(() async {
      final data = await rootBundle.load('assets/test_cow.svg');
      final first = data.getUint8(0);
      // ignore: avoid_print
      print(
        'assets/test_cow.svg：${data.lengthInBytes} bytes，第一個 byte 0x${first.toRadixString(16)}',
      );
      expect(first, isNot(0x3C), reason: '讀到的還是 SVG 文字（< 開頭），transformer 沒跑');
      final info = await vg.loadPicture(
        const AssetBytesLoader('assets/test_cow.svg'),
        null,
      );
      // ignore: avoid_print
      print('解得開：${info.size}');
      expect(info.size.width, greaterThan(0));
    });
  });
}
