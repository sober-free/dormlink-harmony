"""生成设备实物图标（5 张 PNG），输出到 entry/src/main/resources/base/media/。

改配色或造型只需修改本文件后重跑：
    python3 tools/gen_device_icons.py
"""
from PIL import Image, ImageDraw
import os

OUT = os.path.join(os.path.dirname(__file__), '..', 'entry', 'src', 'main', 'resources', 'base', 'media')
OUT = os.path.abspath(OUT)
os.makedirs(OUT, exist_ok=True)

S = 144
DARK = (58, 63, 71, 255)      # 主体深灰
ORANGE = (255, 105, 0, 255)   # 橙色点缀（米家主色）
CREAM = (255, 236, 220, 255)  # 浅橙填充
GREY = (240, 242, 245, 255)   # 浅灰填充


def new():
    return Image.new('RGBA', (S, S), (0, 0, 0, 0))


# 主灯：灯泡
im = new(); d = ImageDraw.Draw(im)
d.ellipse([38, 18, 106, 90], fill=CREAM, outline=ORANGE, width=6)
d.rectangle([56, 86, 88, 100], fill=DARK)
d.rectangle([60, 102, 84, 108], fill=DARK)
d.rectangle([64, 110, 80, 116], fill=DARK)
for seg in ((52, 6, 52, 20), (20, 40, 34, 40), (110, 40, 124, 40), (26, 14, 36, 24), (108, 14, 118, 24)):
    d.line(seg, fill=ORANGE, width=5)
im.save(os.path.join(OUT, 'dev_light.png'))

# 空调：壁挂机
im = new(); d = ImageDraw.Draw(im)
d.rounded_rectangle([16, 42, 128, 96], radius=12, fill=GREY, outline=DARK, width=6)
d.rounded_rectangle([30, 76, 114, 86], radius=5, fill=DARK)
for y, w in ((104, 22), (112, 18), (120, 14)):
    d.line([(72 - w, y), (72 + w, y)], fill=ORANGE, width=5)
im.save(os.path.join(OUT, 'dev_ac.png'))

# 窗帘
im = new(); d = ImageDraw.Draw(im)
d.rounded_rectangle([12, 20, 132, 30], radius=5, fill=DARK)
d.polygon([(22, 34), (62, 34), (58, 124), (26, 124)], fill=CREAM, outline=ORANGE)
d.polygon([(82, 34), (122, 34), (118, 124), (86, 124)], fill=CREAM, outline=ORANGE)
for x in (36, 46, 96, 106):
    d.line([(x, 40), (x, 118)], fill=ORANGE, width=3)
im.save(os.path.join(OUT, 'dev_curtain.png'))

# 风扇
im = new(); d = ImageDraw.Draw(im)
d.ellipse([20, 20, 124, 124], outline=DARK, width=6)
for start in (0, 120, 240):
    d.pieslice([36, 36, 108, 108], start, start + 90, fill=CREAM, outline=ORANGE, width=4)
d.ellipse([60, 60, 84, 84], fill=DARK)
d.rounded_rectangle([62, 124, 82, 134], radius=4, fill=DARK)
im.save(os.path.join(OUT, 'dev_fan.png'))

# 加湿器
im = new(); d = ImageDraw.Draw(im)
d.rounded_rectangle([34, 46, 110, 128], radius=26, fill=GREY, outline=DARK, width=6)
d.rounded_rectangle([56, 30, 88, 50], radius=8, fill=DARK)
d.ellipse([66, 58, 78, 70], fill=ORANGE)
for cx, cy, r in ((52, 18, 7), (72, 10, 9), (92, 18, 7)):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=ORANGE, width=4)
im.save(os.path.join(OUT, 'dev_humidifier.png'))

print('设备图标已生成 ->', OUT)
