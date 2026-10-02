#!/usr/bin/env python3
"""從 design/m4/icon/（D32 娟珊）產生 app 的圖示：iOS、Android、網頁版。不要手改產生出來的檔案，改了 design/m4/icon/ 就重跑。

用法（在 app/ 底下）：python3 tool/gen_icons.py
- iOS：AppIcon.appiconset 的 1024 直接複製 ios-1024.png（逐位元相同，test/app_icon_test.dart 會比對）；
  其他尺寸從 1024 縮（Lanczos），一樣不透明（沒有 alpha）。
- Android：adaptive icon（Android 8 以上）的前景、背景各 5 種密度：xxxhdpi 直接複製 432 的原圖，其他從 432 縮；
  Android 7 以下用的 ic_launcher.png 是前景疊在背景上、取中間看得到的 72dp（108dp 畫布的中間 2/3），再縮成 48dp。
- 網頁版（內部試玩）：favicon、manifest 的一般和 maskable 圖示直接複製。
"""
import os
import shutil

from PIL import Image

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(APP, '..', 'design', 'm4', 'icon')
IOS = os.path.join(APP, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
RES = os.path.join(APP, 'android', 'app', 'src', 'main', 'res')
WEB = os.path.join(APP, 'web')

# iOS：AppIcon.appiconset/Contents.json 列的每一張（點數 × 倍數）
IOS_SIZES = {
    'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40, 'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29, 'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80, 'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120, 'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76, 'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
}
# Android 的密度：1dp 幾個像素
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
ADAPTIVE_XML = '''<?xml version="1.0" encoding="utf-8"?>
<!-- tool/gen_icons.py 產生（D32 娟珊）。前景、背景都是 108dp 的畫布，看得到的是中間 72dp。 -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'''
WEB_COPIES = {
    'web-favicon-32.png': 'favicon.png',
    'web-192.png': 'icons/Icon-192.png',
    'web-512.png': 'icons/Icon-512.png',
    'web-maskable-192.png': 'icons/Icon-maskable-192.png',
    'web-maskable-512.png': 'icons/Icon-maskable-512.png',
}


def save(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)
    print('寫入', os.path.relpath(path, APP))


def main():
    # iOS
    src = os.path.join(SRC, 'ios-1024.png')
    big = Image.open(src)
    assert big.size == (1024, 1024) and big.mode == 'RGB', 'ios-1024.png 要 1024×1024、不透明'
    shutil.copyfile(src, os.path.join(IOS, 'Icon-App-1024x1024@1x.png'))
    print('複製', 'ios-1024.png')
    for name, px in IOS_SIZES.items():
        save(big.resize((px, px), Image.LANCZOS), os.path.join(IOS, name))

    # Android adaptive icon
    fg = Image.open(os.path.join(SRC, 'android-前景-432.png')).convert('RGBA')
    bg = Image.open(os.path.join(SRC, 'android-背景-432.png')).convert('RGB')
    assert fg.size == bg.size == (432, 432), 'Android 的前景、背景要 432×432（108dp × 4）'
    for d, k in DENSITIES.items():
        px = round(108 * k)
        for layer, im, name in (('前景', fg, 'ic_launcher_foreground.png'), ('背景', bg, 'ic_launcher_background.png')):
            out = os.path.join(RES, f'mipmap-{d}', name)
            if px == 432:  # xxxhdpi 就是原圖：直接複製（逐位元相同）
                shutil.copyfile(os.path.join(SRC, f'android-{layer}-432.png'), out)
                print('複製', f'android-{layer}-432.png')
            else:
                save(im.resize((px, px), Image.LANCZOS), out)
    xml = os.path.join(RES, 'mipmap-anydpi-v26', 'ic_launcher.xml')
    os.makedirs(os.path.dirname(xml), exist_ok=True)
    with open(xml, 'w', encoding='utf-8') as f:
        f.write(ADAPTIVE_XML)
    print('寫入', os.path.relpath(xml, APP))
    # Android 7 以下：前景疊背景，取中間 72dp（432 的中間 288）
    flat = bg.convert('RGBA')
    flat.alpha_composite(fg)
    flat = flat.convert('RGB').crop((72, 72, 360, 360))
    for d, k in DENSITIES.items():
        px = round(48 * k)
        save(flat.resize((px, px), Image.LANCZOS), os.path.join(RES, f'mipmap-{d}', 'ic_launcher.png'))

    # 網頁版
    for s, t in WEB_COPIES.items():
        shutil.copyfile(os.path.join(SRC, s), os.path.join(WEB, t))
        print('複製', s, '→', 'web/' + t)


if __name__ == '__main__':
    main()
