import 'dart:io';

import 'package:cowfarm/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('S01 顯示的版本跟 pubspec.yaml 一樣', () {
    final m = RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(appVersion, m![1]);
  });
}
