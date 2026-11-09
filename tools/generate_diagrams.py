"""生成报告用的系统架构图与业务流程图（设计示意图，非运行截图）。

运行： python3 tools/generate_diagrams.py
依赖： Pillow；Windows 下优先使用微软雅黑字体。
"""
from PIL import Image, ImageDraw, ImageFont
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def F(size, bold=False):
    paths = (['C:/Windows/Fonts/msyhbd.ttc', 'C:/Windows/Fonts/msyh.ttc',
              'C:/Windows/Fonts/simhei.ttf'] if bold
             else ['C:/Windows/Fonts/msyh.ttc', 'C:/Windows/Fonts/simhei.ttf'])
    for p in paths:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size, index=0)
            except Exception:
                pass
    return ImageFont.load_default()


BG = '#FFFFFF'
TITLE = '#16324F'
SUB = '#5A6E82'
LAYER = '#F2F7FC'
LAYER_B = '#9CBBD8'
BOX = '#FFFFFF'
BOX_B = '#2E7FB8'
ACC = '#C46A0C'
ACC_BG = '#FFF1D8'
ACC_B = '#E5A54B'
TEAL = '#0F766E'
TEAL_BG = '#E3F5F0'
TEAL_B = '#5BB5A2'
ARROW = '#2E7FB8'

FT = F(30, True)
FS = F(15)
FL = F(18, True)
FB = F(16, True)
FN = F(13)
FTAG = F(13, True)


def rbox(d, xy, fill, outline, w=2, r=12):
    d.rounded_rectangle(xy, radius=r, fill=fill, outline=outline, width=w)


def ctext(d, xy, text, f, color):
    x1, y1, x2, y2 = xy
    bb = d.textbbox((0, 0), text, font=f)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    d.text((x1 + (x2 - x1 - tw) / 2 - bb[0], y1 + (y2 - y1 - th) / 2 - bb[1]),
           text, font=f, fill=color)


def arrow(d, p1, p2, color=ARROW, w=2):
    x1, y1 = p1
    x2, y2 = p2
    d.line([p1, p2], fill=color, width=w)
    a = math.atan2(y2 - y1, x2 - x1)
    L = 11
    q1 = (x2 - L * math.cos(a - 0.5), y2 - L * math.sin(a - 0.5))
    q2 = (x2 - L * math.cos(a + 0.5), y2 - L * math.sin(a + 0.5))
    d.polygon([(x2, y2), q1, q2], fill=color)


def badge(d, y):
    rbox(d, (1160, y + 16, 1350, y + 48), ACC_BG, ACC_B, w=2, r=8)
    ctext(d, (1160, y + 16, 1350, y + 48), '★ 已实现', FTAG, ACC)


def build_architecture():
    img = Image.new('RGB', (1400, 950), BG)
    d = ImageDraw.Draw(img)
    d.text((60, 26), '图2.1  系统架构图 — DormLink 智宿联动实验室', font=FT, fill=TITLE)
    d.text((60, 72), '★ 橙色标记 = 当前已实现并通过验证的模块',
           font=FS, fill=SUB)

    def layer(y1, y2, title, boxes, bx_y, box_h):
        rbox(d, (60, y1, 1140, y2), LAYER, LAYER_B, w=2, r=16)
        d.text((82, y1 + 14), title, font=FL, fill=TITLE)
        badge(d, y1)
        for item in boxes:
            if len(item) == 5:
                x, w, head, body, special = item
            else:
                x, w, head, body = item
                special = False
            fill = TEAL_BG if special else BOX
            outline = TEAL_B if special else BOX_B
            rbox(d, (x, bx_y, x + w, bx_y + box_h), fill, outline, w=2, r=10)
            ctext(d, (x + 8, bx_y + 8, x + w - 8, bx_y + 32), head, FB, TITLE)
            for i, t in enumerate(body):
                ctext(d, (x + 8, bx_y + 32 + i * 20, x + w - 8, bx_y + 52 + i * 20),
                      t, FN, SUB)

    layer(110, 300, '表现层 · ArkUI 声明式 UI / @State 状态管理 · pages/Index.ets',
          [(80, 200, '联动台', ['环境滑块 / 演练按钮', '设备实时状态']),
           (292, 200, '规则页', ['6 条规则 CRUD', '启停 / 优先级']),
           (504, 200, '演练页', ['4 组场景', '冲突提示与修复']),
           (716, 200, '日志页', ['执行时间线', '存档 / 恢复信息']),
           (928, 200, '规则编辑器', ['条件行 + 动作行', '保存前合法性校验'])], 180, 100)

    layer(340, 530, '业务层 · 纯逻辑，不依赖 HarmonyOS API（可被 Node 直接测试） · engine/',
          [(80, 510, '★ RuleEngine.ts',
            ['条件判定 / 稳定排序 / 冲突裁决', '执行记录 / 异常降级 / 序列化'], True),
           (610, 510, '★ DefaultData.ts',
            ['5 类设备 / 6 条规则 / 4 组场景', '环境量合法区间'], True)], 410, 100)

    layer(570, 760, '数据层 · 持久化与恢复 · viewmodel / repository',
          [(80, 330, '★ DormStore.ets', ['AppSnapshot ↔ PersistedState', '恢复降级'], True),
           (430, 330, '★ StorageService.ets', ['Preferences put / flush', 'try-catch 安全降级'], True),
           (780, 330, 'Preferences 存储', ['dormlink_state', 'snapshot + saved_at'])], 640, 100)

    layer(800, 920, '测试层 · 直接 import 业务层同一份 .ts 源码',
          [(80, 510, '★ ohosTest (hypium)', ['DevEco Studio / 设备运行，14 条'], True),
           (610, 510, '★ tests/node (node:test)', ['20 条实测通过，见 测试运行日志.md'], True)], 850, 58)

    for a, b in [((600, 300), (600, 340)), ((600, 530), (600, 570)), ((600, 760), (600, 800))]:
        arrow(d, a, b, w=3)

    d.text((1160, 866), '测试直接加载业务层源码', font=FN, fill=TEAL)
    d.text((1160, 890), '→ 测试即产品逻辑', font=FTAG, fill=TEAL)
    d.text((60, 930),
           '数据流向：用户操作 → @State env → evaluate() → ExecutionResult → @State 回填 → ArkUI 刷新 → DormStore.persist() → Preferences.flush()',
           font=FN, fill=SUB)
    path = os.path.join(ROOT, 'docs', '系统架构图.png')
    img.save(path)
    print('saved', path)


def build_flow():
    img = Image.new('RGB', (1200, 1200), BG)
    d = ImageDraw.Draw(img)
    d.text((50, 24), '图3.1  规则引擎业务流程图（当前已实现的核心业务）', font=FT, fill=TITLE)
    d.text((50, 68), '从用户操作到设备联动、冲突裁决、界面刷新与落盘的完整状态变化', font=FS, fill=SUB)

    def step(y, head, body, fill=BOX, outline=BOX_B):
        rbox(d, (320, y, 880, y + 62), fill, outline, w=2, r=10)
        ctext(d, (330, y + 5, 870, y + 28), head, FB, TITLE)
        ctext(d, (330, y + 30, 870, y + 56), body, FN, SUB)

    ys = [110, 206, 302, 398, 494, 590, 686]
    heads = [
        '① 用户输入', '② evaluate(env, devices, rules)', '③ 环境归一化 normalizeEnvironment',
        '④ 规则校验 validateRule', '⑤ 条件判定 isRuleTriggered', '⑥ 稳定排序 compareRules',
        '⑦ 遍历动作：该设备通道是否已被占用？'
    ]
    bodies = [
        '调整 5 项 Mock 环境量 / 编辑规则 / 点击「执行联动演练」',
        '纯逻辑引擎入口，输入为内存态快照，输出 ExecutionResult',
        '越界数值裁剪、NaN 降级、null 回退默认环境 → warnings',
        '剔除空条件 / 空动作 / 未知设备 / NaN 优先级的规则 → warnings',
        'conditions 之间 AND；停用规则、空条件规则不命中',
        '按 (priority 升序, id 升序) 排序，保证执行顺序可复现',
        '以 deviceId 为控制通道，Map 记录已被占用的设备'
    ]
    for i, y in enumerate(ys):
        fill = ACC_BG if i == 6 else (TEAL_BG if i == 1 else BOX)
        outline = ACC_B if i == 6 else (TEAL_B if i == 1 else BOX_B)
        step(y, heads[i], bodies[i], fill, outline)
    for i in range(6):
        arrow(d, (600, ys[i] + 62), (600, ys[i + 1]), w=2)

    rbox(d, (40, 790, 350, 872), '#FDECEC', '#D97070', w=2, r=10)
    ctext(d, (48, 798, 342, 826), '是 · 通道已占用', FB, '#A33A3A')
    ctext(d, (48, 830, 342, 862), '拦截动作，写 ConflictRecord', FN, '#7E4B4B')
    rbox(d, (850, 790, 1160, 872), TEAL_BG, TEAL_B, w=2, r=10)
    ctext(d, (858, 798, 1152, 826), '否 · 通道空闲', FB, TEAL)
    ctext(d, (858, 830, 1152, 862), '占用通道，写 DeviceChange', FN, '#3B6B63')
    arrow(d, (470, 748), (195, 790), color='#D97070', w=2)
    arrow(d, (730, 748), (1005, 790), color=TEAL, w=2)
    ctext(d, (330, 752, 470, 776), '是', FN, '#A33A3A')
    ctext(d, (740, 752, 880, 776), '否', FN, TEAL)

    step(910, '⑧ 汇合：输出 ExecutionResult',
         '设备终态 + records + conflicts + warnings + triggeredRuleIds', TEAL_BG, TEAL_B)
    arrow(d, (195, 872), (450, 910), color='#D97070', w=2)
    arrow(d, (1005, 872), (750, 910), color=TEAL, w=2)
    step(1006, '⑨ 写回 @State → ArkUI 刷新四个页签',
         'devices / records / conflicts / warnings 整体赋值触发 UI 更新')
    arrow(d, (600, 972), (600, 1006), w=2)
    step(1102, '⑩ DormStore.persist → Preferences.flush()',
         '规则、设备、最近 50 条执行记录落盘；进程重启可恢复')
    arrow(d, (600, 1068), (600, 1102), w=2)
    d.text((50, 1172), '异常处理贯穿 ③~⑦：任何非法输入均降级为安全结果并写入 warnings，不向 UI 抛异常。',
           font=FN, fill=SUB)
    path = os.path.join(ROOT, 'docs', '业务流程图.png')
    img.save(path)
    print('saved', path)


if __name__ == '__main__':
    build_architecture()
    build_flow()
