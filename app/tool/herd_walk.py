#!/usr/bin/env python3
"""算牧場 40 個位置的走法（A-11），印出 walk.dart 的 kHerdWalk 表。用法（在 app/ 底下）：python3 tool/herd_walk.py

前 8 個位置照設計稿 anims.js 的 WALK（walk.dart 的 kDesignWalk）。其他 32 個設計稿沒畫到，照 ceo 2026-10-03 同意的規則：
- 往面向的方向走，最多 18。
- 跟同一排（上下差 40 以內）前面最近的位置至少隔 12：對面的牛也朝這邊走的話，兩頭走的距離加起來算。
- 腳底不進池塘、水槽、乾草捆（外面再留 12），也不走出草地（x 20–760）。
- 空間不到 8 就原地不走，只一搖一搖（距離 0）。
- 節奏用位置編號錯開：第 i 個位置是 i × 0.618 × 4 秒（黃金比例），相鄰的牛不會同時動。
障礙物的範圍跟排位置時一樣（herd.dart 的說明）：池塘是 (560, 474) 半徑 150 × 62 的橢圓、水槽 |x − 640| < 50 且 y < 370、
乾草捆 |x − 366| < 40 且 y > 490。
"""
import math
import os
import re

APP = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HERD = open(os.path.join(APP, 'lib/ui/ranch/herd.dart'), encoding='utf-8').read()
WALK = open(os.path.join(APP, 'lib/ui/ranch/walk.dart'), encoding='utf-8').read()

slots = [(float(x), float(y), r == 'true') for x, y, r in
         re.findall(r'HerdSlot\((\d+), (\d+), right: (true|false)', HERD)]
design = [(float(d), float(p)) for d, p in re.findall(r'WalkPlan\((\d+(?:\.\d+)?), (\d+(?:\.\d+)?)\), // #', WALK)]
assert len(slots) == 40 and len(design) == 8, (len(slots), len(design))

MAX, GAP, MIN, MARGIN, BAND = 18.0, 12.0, 8.0, 12.0, 40.0


def blocked(x, y):
    """腳底在 (x, y) 會不會碰到障礙物（外面再留 MARGIN）或走出草地。"""
    pond = ((x - 560) / (150 + MARGIN)) ** 2 + ((y - 474) / (62 + MARGIN)) ** 2 < 1
    trough = abs(x - 640) < 50 + MARGIN and y < 370 + MARGIN
    hay = abs(x - 366) < 40 + MARGIN and y > 490 - MARGIN
    return pond or trough or hay or x < 20 or x > 760


def room(i):
    """第 i 個位置往前最多能走多遠：障礙物、草地邊界，最多 MAX。"""
    x, y, right = slots[i]
    step = 1 if right else -1
    d = 0.0
    while d < MAX and not blocked(x + step * (d + 1), y):
        d += 1
    return d


dist = [design[i][0] if i < 8 else room(i) for i in range(40)]

# 同一排前面最近的位置：兩頭牛的距離要留 GAP。對面朝這邊走的話，兩頭的距離一起算（設計稿的 8 頭不改，只縮後面的）。
for _ in range(5):
    for i in range(8, 40):
        x, y, right = slots[i]
        step = 1 if right else -1
        for j in range(40):
            if j == i:
                continue
            xj, yj, rj = slots[j]
            ahead = (xj - x) * step
            if abs(yj - y) > BAND or ahead <= 0:
                continue
            toward = rj != right  # 對面的牛朝這邊走
            free = ahead - GAP - (dist[j] if toward else 0)
            if j >= 8 and toward:
                # 兩頭都可以縮：各分一半
                share = (ahead - GAP) / 2
                dist[i] = min(dist[i], share)
                dist[j] = min(dist[j], share)
            else:
                dist[i] = min(dist[i], free)

plans = []
for i in range(40):
    if i < 8:
        plans.append(design[i])
        continue
    d = math.floor(max(0.0, dist[i]))
    if d < MIN:
        d = 0
    phase = round((i * 0.618034 * 4) % 4, 2)
    plans.append((d, phase))

print('const kHerdWalk = <WalkPlan>[')
for i, (d, p) in enumerate(plans):
    x, y, right = slots[i]
    note = '設計稿 WALK' if i < 8 else ('原地一搖一搖' if d == 0 else '')
    tail = f' // {i}：({x:g}, {y:g}) {"右" if right else "左"}' + (f'，{note}' if note else '')
    print(f'  WalkPlan({d:g}, {p:g}),{tail}')
print('];')
