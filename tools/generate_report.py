"""按课程官方模板生成《期末大作业个人报告》Word 文档。

运行： python3 tools/generate_report.py
输出： 工作区根目录 鸿蒙高级应用开发工程师认证-20230313120-徐豪-期末大作业报告.docx
依赖： python-docx、Pillow
"""
import os
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(os.path.dirname(ROOT),
                   '鸿蒙高级应用开发工程师认证-20230313120-徐豪-期末大作业报告.docx')
ARCH = os.path.join(ROOT, 'docs', '系统架构图.png')
FLOW = os.path.join(ROOT, 'docs', '业务流程图.png')

SONG = '宋体'
HEI = '黑体'


def set_font(run, name=SONG, size=10.5, bold=False, color=None):
    run.font.name = name
    run.font.size = Pt(size)
    run.bold = bold
    if color:
        run.font.color.rgb = RGBColor(*color)
    rPr = run._element.get_or_add_rPr()
    rf = rPr.get_or_add_rFonts()
    rf.set(qn('w:eastAsia'), name)
    rf.set(qn('w:ascii'), 'Times New Roman')
    rf.set(qn('w:hAnsi'), 'Times New Roman')


def para(doc, text, size=10.5, bold=False, align=None, indent=True, space_after=5):
    p = doc.add_paragraph()
    if align is not None:
        p.alignment = align
    pf = p.paragraph_format
    pf.space_before = Pt(2)
    pf.space_after = Pt(space_after)
    pf.line_spacing = 1.35
    if indent:
        pf.first_line_indent = Cm(0.74)
    r = p.add_run(text)
    set_font(r, SONG, size, bold)
    return p


def heading(doc, text, level=1):
    p = doc.add_heading(level=level)
    r = p.add_run(text)
    set_font(r, HEI, 15 if level == 1 else (13 if level == 2 else 11.5), True,
             (22, 50, 79))
    p.paragraph_format.space_before = Pt(12 if level == 1 else 8)
    p.paragraph_format.space_after = Pt(6)
    return p


def cell_bg(cell, fill):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), fill)
    tcPr.append(shd)


def table(doc, headers, rows, widths=None, font_size=9):
    t = doc.add_table(rows=1, cols=len(headers))
    t.style = 'Table Grid'
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    hdr = t.rows[0].cells
    for i, h in enumerate(headers):
        hdr[i].text = ''
        r = hdr[i].paragraphs[0].add_run(str(h))
        set_font(r, HEI, font_size, True)
        cell_bg(hdr[i], 'DCE9F5')
    for row in rows:
        cells = t.add_row().cells
        for i, v in enumerate(row):
            cells[i].text = ''
            r = cells[i].paragraphs[0].add_run(str(v))
            set_font(r, SONG, font_size)
    if widths:
        for row in t.rows:
            for i, w in enumerate(widths):
                row.cells[i].width = Cm(w)
    doc.add_paragraph().paragraph_format.space_after = Pt(2)
    return t


def code(doc, text):
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.left_indent = Cm(0.4)
    pf.space_before = Pt(4)
    pf.space_after = Pt(8)
    pf.line_spacing = 1.1
    pPr = p._p.get_or_add_pPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:fill'), 'F2F5F9')
    pPr.append(shd)
    r = p.add_run(text)
    r.font.name = 'Consolas'
    r.font.size = Pt(8.5)
    r._element.get_or_add_rPr().get_or_add_rFonts().set(qn('w:eastAsia'), 'Consolas')
    return p


def caption(doc, text):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(8)
    r = p.add_run(text)
    set_font(r, SONG, 9.5, True)
    return p


def picture(doc, path, width_cm):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(2)
    p.add_run().add_picture(path, width=Cm(width_cm))
    return p


def placeholder(doc, label, note):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(6)
    p.paragraph_format.space_after = Pt(6)
    r = p.add_run('【' + label + '：待本人实机截图补录】')
    set_font(r, HEI, 10.5, True, (170, 90, 20))
    p2 = doc.add_paragraph()
    p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r2 = p2.add_run(note)
    set_font(r2, SONG, 9, False, (110, 110, 110))
    return p


def page_number(paragraph):
    run = paragraph.add_run()
    a = OxmlElement('w:fldChar'); a.set(qn('w:fldCharType'), 'begin')
    b = OxmlElement('w:instrText'); b.set(qn('xml:space'), 'preserve'); b.text = 'PAGE'
    c = OxmlElement('w:fldChar'); c.set(qn('w:fldCharType'), 'end')
    run._r.append(a); run._r.append(b); run._r.append(c)
    set_font(run, SONG, 9)


doc = Document()
sec = doc.sections[0]
sec.page_width = Cm(21)
sec.page_height = Cm(29.7)
sec.top_margin = Cm(2.4)
sec.bottom_margin = Cm(2.2)
sec.left_margin = Cm(2.5)
sec.right_margin = Cm(2.5)
normal = doc.styles['Normal']
normal.font.name = SONG
normal.font.size = Pt(10.5)
normal._element.get_or_add_rPr().get_or_add_rFonts().set(qn('w:eastAsia'), SONG)

footer = sec.footer.paragraphs[0]
footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
page_number(footer)

# ============================== 封面 ==============================
p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_before = Pt(60)
r = p.add_run('大 作 业（报 告）'); set_font(r, HEI, 24, True, (22, 50, 79))
p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
p.paragraph_format.space_after = Pt(40)
r = p.add_run('鸿蒙高级应用开发工程师认证 · 期末大作业'); set_font(r, HEI, 13, False, (90, 110, 130))

cover = [
    ('课程名称', '鸿蒙高级应用开发工程师认证'),
    ('学    院', '信息工程学院'),
    ('专    业', '物联网工程（华为班）'),
    ('班    级', '23物联1'),
    ('学生姓名', '徐豪'),
    ('学    号', '20230313120'),
    ('指导教师', '王  旗'),
    ('成    绩', '________________'),
    ('开课时间', '2026—2027 学年  第一学期'),
]
for k, v in cover:
    p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(9)
    r = p.add_run(k + '：' + v); set_font(r, SONG, 13)

doc.add_paragraph()
p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run('作品名称：DormLink 智宿联动实验室　｜　选题：主题三 联动实验室')
set_font(r, SONG, 11, False, (90, 110, 130))
p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
r = p.add_run('GitHub 账号：sober-free　｜　仓库：https://github.com/sober-free/dormlink-harmony')
set_font(r, SONG, 10.5, False, (90, 110, 130))
doc.add_page_break()

# ============================== 评分标准表 ==============================
heading(doc, '评分标准', 1)
table(doc, ['指标', '评价内容（摘要）', '分值', '分数'], [
    ['目标一（16分）', '需求与问题分析 / 数据与状态分析 / 边界与异常分析', '16', ''],
    ['目标二（28分）', '架构与模块设计 / 核心功能实现 / 页面与交互体验', '28', ''],
    ['目标三（36分）', 'ArkTS与ArkUI开发 / 数据持久化与异常处理 / 单元测试与Mock / GitHub贡献与项目交付', '36', ''],
    ['目标四（20分）', '新技术认识与适用局限 / 自主学习与资料分析 / 持续学习与更新计划', '20', ''],
    ['独立完成奖励', '仅独立完成者可申请，基础分 90 分以上可奖励 0—10 分', '0—10', ''],
    ['总分', '实际计入奖励后不超过 100 分', '100', ''],
], widths=[2.8, 8.4, 1.6, 1.6], font_size=9)
para(doc, '成绩认定前提：期末提交时须在学习通作业答案处同时填写有效的 GitHub 仓库链接与本人 GitHub 账号名称，缺少任意一项无法核查源代码与个人贡献，整个大作业成绩计 0 分。', 9.5)
doc.add_page_break()

# ============================== 目录 ==============================
heading(doc, '目  录', 1)
toc = [
    '1. 项目概述', '  1.1 基本信息', '  1.2 项目简介', '  1.3 需求完成情况',
    '2. 系统架构', '  2.1 整体架构', '  2.2 模块划分', '  2.3 本人职责',
    '3. 模块设计', '  3.1 功能设计', '  3.2 数据设计', '  3.3 接口设计',
    '4. 代码实现与贡献', '  4.1 核心代码', '  4.2 技术应用', '  4.3 Git 提交记录',
    '5. 模块测试', '  5.1 Mock 测试设计', '  5.2 测试结果', '  5.3 问题与修复',
    '6. 运行与总结', '  6.1 运行效果', '  6.2 数据恢复与集成', '  6.3 个人总结',
]
for t in toc:
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(3)
    r = p.add_run(t); set_font(r, SONG, 10.5, t[0].isdigit() and not t.startswith(' '))
doc.add_page_break()

# ============================== 1 项目概述 ==============================
heading(doc, '1. 项目概述', 1)
heading(doc, '1.1 基本信息', 2)
table(doc, ['项目要素', '填写内容'], [
    ['作品名称', 'DormLink 智宿联动实验室'],
    ['指定主题', '主题三：联动实验室（智能宿舍自动化规则编排 App）'],
    ['姓名（学号）', '徐豪（20230313120）'],
    ['GitHub 账号', 'sober-free'],
    ['GitHub 仓库链接', 'https://github.com/sober-free/dormlink-harmony'],
    ['小组成员', '无（独立完成；如后续调整为组队，按需求说明书第 6 节补充成员与模块接口约定）'],
    ['开发环境', 'DevEco Studio（HarmonyOS 5.0 / API 12）、ArkTS + ArkUI（Stage 模型）、@kit.ArkData Preferences；单元测试附加 Node.js 22.22.2'],
], widths=[4.0, 10.4])
caption(doc, '表1.1  项目基本信息')

heading(doc, '1.2 项目简介', 2)
para(doc, '宿舍里的主灯、空调、窗帘、风扇、加湿器通常各按各的开关，缺少"满足某个条件就自动联动"的统一编排。更麻烦的是规则之间会打架：夏季午后宿舍无人但室温很高，"高温自动制冷"想把空调打开，"无人节能"又想把它关掉，如果没有明确的优先级与执行顺序，设备状态就取决于代码书写顺序，用户既看不到原因也无法调整。DormLink 面向的就是这类场景：它让使用者在手机上自行定义"当……则……"的联动规则，用可调整的模拟环境数据驱动规则引擎，实时观察设备动作、执行顺序与冲突裁决，并在修改规则后立即复验。')
para(doc, '应用完全本地运行，不依赖真实硬件、网络或云平台。用户的主要操作是：在「联动台」拖动温度/光照/湿度/时段滑块并切换在室状态；在「规则」页新增、编辑、启停规则并调整优先级；在「演练」页载入预设场景观察联动结果；在「日志」页查看每条动作的执行序号、触发条件快照与设备变化前后值。全部规则、设备状态和最近 50 条执行记录通过 Preferences 落盘，结束应用进程后重新打开可以完整恢复。作品的价值在于把"规则编排—冲突处理—结果可追溯—方案可恢复"串成一条闭环，而不是把几个课程实验功能拼在一起。')

heading(doc, '1.3 需求完成情况', 2)
table(doc, ['题目要求', '完成情况', '运行证据'], [
    ['≥4 类可控设备', '完成 5 类：主灯、空调、窗帘、风扇、加湿器', '联动台 5 张设备状态卡，演练后 ON/OFF 与设定值实时变化'],
    ['≥3 项可调模拟环境数据', '完成 5 项：温度、光照、湿度、时段、在室状态', '联动台 4 个 Slider + 1 个 Toggle'],
    ['≥4 条规则，可新增/修改/启停，含 1 条双条件规则', '默认 6 条（R001~R006），R001/R004/R006 为双条件；支持 CRUD、启停、优先级', '规则页卡片、编辑弹层、保存前 validateRule 校验'],
    ['引擎按实际输入计算并记录条件、设备变化、执行顺序', 'evaluate() 输出 ExecutionResult，含 records（order / 条件快照 / before→after / 拦截标记）', '日志页执行时间线；测试 [正常 1][正常 3]'],
    ['冲突控制有明确执行顺序或优先级', '按 (priority 升序, id 升序) 稳定排序；同一设备通道仅最高优先级规则写入，其余拦截并记 ConflictRecord', 'S2 场景冲突提示；测试 [正常 4][正常 5]'],
    ['≥2 组环境场景模拟演练', '完成 4 组：S1 夏夜归寝、S2 午后无人·冲突、S3 干燥清晨、S4 深夜无人', '演练页 4 张场景卡，点击即载入并执行'],
    ['保存设置/规则/记录，进程重启恢复', 'Preferences 单 JSON 快照 + flush；冷启动 restore 带三级降级', '日志页存档时间与恢复提示；测试 [异常 5]'],
    ['≥6 条自动化测试，覆盖正常/边界/异常', 'Node 侧 19 条实测全通过（正常 7/边界 5/异常 7），DevEco ohosTest 侧 14 条', 'docs/测试运行日志.md 含完整 TAP 输出'],
], widths=[3.6, 6.4, 4.4], font_size=8.5)
para(doc, '尚未由本人完成的部分：真实运行截图与完整录屏需在 DevEco Studio 模拟器/真机上补录，补录清单与分镜脚本已写入 docs/运行与录屏指南.md 与 screenshots/README.md。仓库中的两张 PNG 是设计示意图，报告中已明确标注，不作为运行截图使用。', 9.5)

# ============================== 2 系统架构 ==============================
doc.add_page_break()
heading(doc, '2. 系统架构', 1)
heading(doc, '2.1 整体架构', 2)
para(doc, '应用采用三层结构加一个测试层。表现层是单个 EntryAbility 下的 Index 页面，用四个 TabContent 组织联动台、规则、演练、日志四个页签，所有界面状态由 @State 变量持有；业务层是 RuleEngine.ts 与 DefaultData.ts，是不 import 任何 HarmonyOS API 的纯逻辑模块，负责条件判定、稳定排序、冲突裁决、执行记录与序列化；数据层由 DormStore.ets 负责内存快照与持久化结构的转换、由 StorageService.ets 封装 Preferences 读写；测试层直接加载业务层同一份 .ts 源码，因此测试断言针对的就是产品实际运行的代码。图中橙色「★ 本人负责」标记覆盖全部四层，本项目由本人独立完成。')
picture(doc, ARCH, 16.0)
caption(doc, '图2.1  系统架构图（设计示意图；★ 为本人负责部分）')
para(doc, '以"载入 S2 午后无人场景"这一典型操作为例说明数据流：用户点击场景卡 → Index.applyScene() 把场景环境写入 @State env → runOnce() 调用 evaluate(env, devices, rules) → 引擎归一化环境、校验规则、判定命中、按优先级排序并逐个执行动作，遇到空调通道已被 R002 占用时拦截 R005 的空调动作 → 返回 ExecutionResult → 页面把 devices、records、conflicts、warnings、triggeredRuleIds 整体赋值回 @State → ArkUI 自动刷新四个页签 → DormStore.persist() 经 serializeState 生成 JSON，由 StorageService.save() 执行 put + flush 落盘。冷启动时方向相反：aboutToAppear → DormStore.restore() → Preferences.get → deserializeState → applySnapshot 回填 @State。')

heading(doc, '2.2 模块划分', 2)
table(doc, ['模块名称', '主要职责', '输入 → 输出', '负责人'], [
    ['pages/Index.ets', '四页签 UI、用户交互、@State 状态管理、规则编辑器', '用户操作 / AppSnapshot → 界面状态与持久化请求', '徐豪'],
    ['engine/RuleEngine.ts', '条件判定、稳定排序、冲突裁决、执行记录、异常降级、序列化', '(env, devices, rules) → ExecutionResult', '徐豪'],
    ['engine/DefaultData.ts', '默认设备、6 条规则、4 组场景、环境量合法区间', '常量 → DEFAULT_* / SCENE_PRESETS', '徐豪'],
    ['viewmodel/DormStore.ets', '内存态 ↔ 持久化快照、恢复降级', 'Context / AppSnapshot → RestoreResult / boolean', '徐豪'],
    ['repository/StorageService.ets', 'Preferences 读写、flush、异常捕获', '(string, number) → boolean / string', '徐豪'],
    ['ohosTest + tests/node', '单元测试与真实运行日志', 'Mock 输入 → 断言结果', '徐豪'],
], widths=[3.8, 5.0, 4.2, 1.4], font_size=8.5)
caption(doc, '表2.1  系统模块及接口关系')
para(doc, '模块衔接的一个实际例子：规则编辑器保存时，Index.saveDraft() 先调用 RuleEngine.validateRule() 校验，校验通过才更新 @State rules，再调用同一个 runOnce() 重新演练，最后走 DormStore.persist()。也就是说"编辑规则"与"执行演练"共享同一条业务链路，编辑器不需要另写一套判定逻辑；接口之间传递的始终是 AutomationRule[]、DeviceState[]、Environment 这三个数据结构，避免了页面与引擎各自维护一份状态而产生不一致。')

heading(doc, '2.3 本人职责', 2)
para(doc, '本人独立承担完整应用的需求分析与建模、规则引擎与冲突策略设计、ArkUI 四页签界面与交互实现、Preferences 持久化与异常降级、两套单元测试与真实运行日志、软件需求说明书、README、架构图与业务流程图、Git 提交历史整理以及本报告的撰写与集成验证。关键设计决定有三个：其一，把规则引擎写成不依赖 HarmonyOS API 的纯逻辑模块，使同一份源码既能被 ArkTS 编译、也能被 Node 直接测试；其二，用「设备通道占用」而不是"后写覆盖"来处理冲突，让优先级真正生效且拦截过程可观测；其三，把全部业务状态收敛为单个 JSON 快照一次 flush，避免多次 put 造成存档状态中间态。相应源码位置为 entry/src/main/ets/engine/、repository/、viewmodel/、pages/，测试位于 entry/src/ohosTest/ 与 tests/node/。')

# ============================== 3 模块设计 ==============================
doc.add_page_break()
heading(doc, '3. 模块设计', 1)
heading(doc, '3.1 功能设计', 2)
para(doc, '选择本人负责的核心业务「一次联动演练」展开。用户从调整环境或点击场景开始，应用接收 Environment 输入；引擎先做归一化与规则校验，把越界数值、NaN、非法规则降级为安全结果并写入 warnings；随后逐条判定条件（conditions 之间为 AND），命中的规则按 (优先级升序, id 升序) 稳定排序；接着顺序遍历每条动作，以 deviceId 作为控制通道查 Map：通道空闲则占用并执行动作、记录设备 before→after，通道已被更高优先级规则占用则拦截该动作、写 ConflictRecord 与 blocked 记录；最后汇合输出设备终态与全部记录，写回 @State 并落盘。')
picture(doc, FLOW, 14.5)
caption(doc, '图3.1  模块业务流程图（设计示意图）')
para(doc, '重要的状态变化与边界：设备状态以本次传入的 devices 为起点而非累加到上次结果，保证同一输入两次演练终态一致；阈值比较含等号（GE/LE），28℃ 与 35% 属于会命中的边界；hour 按整点向下取整并裁剪到 [0,23]；停用规则、空条件规则、校验失败规则均不参与；同一设备被多条规则争用时只拦截该设备的动作，同一规则对其他设备的动作照常执行。异常方面，环境对象为空回退默认环境，规则表为空返回原设备状态，Preferences 存档损坏回退默认方案，所有降级都在界面留下可读提示。')

heading(doc, '3.2 数据设计', 2)
table(doc, ['类 / 数据对象', '关键字段与类型', '业务含义', '存储与读取方式'], [
    ['Environment', 'temperature:number, illuminance:number, humidity:number, hour:number, occupancy:boolean', '5 项可调模拟环境输入', '内存 @State + Preferences 快照'],
    ['DeviceState', 'id:DeviceId, name:string, power:boolean, value:number, unit:string', '5 类设备当前状态；power 开关，value 为亮度%/目标温度℃/开合度%/档位', '内存 @State + Preferences 快照'],
    ['Condition', 'metric:MetricKey, op:CompareOp, value:number', '单条触发条件；occupancy 用 1/0 参与统一比较', '随规则持久化'],
    ['DeviceAction', 'deviceId:DeviceId, power:boolean, value:number', '单条设备动作', '随规则持久化'],
    ['AutomationRule', 'id, name, enabled:boolean, priority:number, conditions:Condition[], actions:DeviceAction[], description', '联动规则；条件 AND，priority 越小越优先', 'Preferences 快照'],
    ['ExecutionRecord', 'order, ruleId, priority, conditions, change:DeviceChange, blocked:boolean, note', '一次动作的执行证据（序号/条件快照/before→after/拦截）', 'Preferences 保留最近 50 条'],
    ['ConflictRecord', 'deviceId, winnerRuleId, loserRuleId, reason', '冲突裁决证据', 'Preferences 保留最近 50 条'],
    ['PersistedState', 'version, environment, devices, rules, records, conflicts, savedAt', 'Preferences 中单个 JSON 快照的完整结构', 'getPreferences(ctx,"dormlink_state")'],
], widths=[2.8, 5.0, 4.2, 2.4], font_size=8)
caption(doc, '表3.1  主要数据模型')

heading(doc, '3.3 接口设计', 2)
table(doc, ['接口 / 方法', '输入参数', '返回值', '异常 / 边界处理'], [
    ['evaluate(rawEnv, devices, rules)', 'Environment, DeviceState[], AutomationRule[]', 'ExecutionResult', 'null 环境回退默认值；null/空规则返回原设备 + warnings；越界数值裁剪'],
    ['isRuleTriggered(env, rule)', 'Environment, AutomationRule', 'boolean', '停用 / 空条件 / 非法条件返回 false'],
    ['matchCondition(env, cond)', 'Environment, Condition', 'boolean', '未知量、非法运算符、NaN 一律 false'],
    ['validateRule(rule)', 'AutomationRule', 'string[]', '返回问题描述数组，空数组表示合法'],
    ['compareRules(a, b)', '两条 AutomationRule', 'number', '优先级相同按 id 字典序，保证稳定'],
    ['serializeState / deserializeState', 'PersistedState / string', 'string / PersistedState|null', 'null 返回空串；损坏 JSON 或缺字段返回 null'],
    ['DormStore.restore(ctx)', 'common.Context', 'RestoreResult', '存储失败 / 无存档 / 损坏 → 默认方案 + 原因文本'],
    ['DormStore.persist(ctx, snap, savedAt)', 'Context, AppSnapshot, number', 'boolean', '序列化失败或写入异常返回 false'],
    ['StorageService.save(text, savedAt)', 'string, number', 'boolean', '未初始化或异常返回 false，不向上抛'],
], widths=[3.7, 3.5, 2.7, 4.5], font_size=8)
caption(doc, '表3.2  模块接口')
para(doc, '这些接口在业务环节上的调用关系：规则编辑器在保存前调用 validateRule；演练入口调用 evaluate；evaluate 内部依次调用 normalizeEnvironment、validateRule、isRuleTriggered（内部再调用 matchCondition）与 compareRules；页面拿到结果后调用 DormStore.persist，后者用 serializeState 生成文本并交给 StorageService.save；冷启动时 DormStore.restore 用 deserializeState 还原 AppSnapshot。输入不符合预期时不抛异常、不崩溃，而是返回安全结果并把原因写入 warnings 显示在日志页。')

# ============================== 4 代码实现与贡献 ==============================
doc.add_page_break()
heading(doc, '4. 代码实现与贡献', 1)
heading(doc, '4.1 核心代码', 2)
para(doc, '最能代表本人工作的是规则引擎中的冲突裁决与执行记录部分，位于 entry/src/main/ets/engine/RuleEngine.ts 的 evaluate() 方法（对应提交 1c14416）。它解决的问题是：当多条规则同时命中并争用同一台设备时，如何让优先级真正生效，同时把"谁被采纳、谁被拦截"变成可查证的日志，而不是静默覆盖。')
code(doc, '''const occupied = new Map<DeviceId, string>();
let order = 0;
for (const rule of triggered) {                 // 已按 (priority, id) 稳定排序
  for (const action of rule.actions) {
    let winner = '';
    if (occupied.has(action.deviceId)) {
      const cached = occupied.get(action.deviceId);
      winner = cached === undefined ? '' : cached;
    }
    order = order + 1;
    if (winner !== '') {
      conflicts.push({
        deviceId: action.deviceId, winnerRuleId: winner, loserRuleId: rule.id,
        reason: '设备「' + target.name + '」已被优先级更高的规则 ' + winner + ' 占用'
      });
      records.push({ order, ruleId: rule.id, conditions: rule.conditions,
                     change: snapshot, blocked: true, note: '冲突拦截' });
      continue;                                // 只拦截该设备动作，不中断整条规则
    }
    occupied.set(action.deviceId, rule.id);     // 高优先级规则占用通道
    working[idx] = { ...target, power: action.power, value: action.value };
    records.push({ order, ruleId: rule.id, change, blocked: false, note: '开启并设为 ...' });
  }
}''')
para(doc, '实现思路：先把命中规则按优先级排好序，再以 deviceId 为键维护一张"通道占用表"。排序保证第一个写入该设备的规则一定是优先级最高的；后续规则若发现通道已占用，就不再写设备状态，而是生成一条 ConflictRecord 和一条 blocked=true 的 ExecutionRecord，然后 continue 继续处理该规则的其他动作。这样既满足"明确执行顺序"，又让拦截粒度精确到单台设备。实际效果：载入 S2（31℃、无人）时日志显示 R002 胜出、空调保持开启，R005 的空调动作被拦截，但 R005 对主灯和风扇的关闭动作仍正常执行；点击「一键修复」为 R002 补充"在室=有人"条件后，无人场景 R002 不再命中，冲突数归零。')
para(doc, '注释：上方代码为报告展示做了省略（working[idx] 的完整对象构造、告警收集与 snapshot 定义见源码），完整实现以仓库 entry/src/main/ets/engine/RuleEngine.ts 为准。', 9)

heading(doc, '4.2 技术应用', 2)
para(doc, '状态管理采用 ArkUI 的 @State 与 @Builder：页面把 devices、rules、records、conflicts、warnings 等作为 @State 变量，引擎返回新数组后整体赋值，触发四个页签同步刷新；@Builder 复用设备卡、规则卡、场景卡与记录行，四个 TabContent 共享同一份状态，避免跨页面传参造成的数据副本。交互使用 Slider（4 项环境量）、Toggle（在室状态与规则启停）、Select（条件环境量/运算符与动作设备）、TextInput（阈值与优先级）与 Button，规则编辑器通过重建 draft 对象来驱动 ForEach 更新。')
para(doc, '选择 ArkTS 而非在 .ets 里随意写 JavaScript，是因为 ArkTS 的静态类型约束能在编译期拦住 any、对象展开、隐式类型转换等问题——开发规则编辑器时我最初想用对象展开来更新草稿，正是这一约束促使我改成显式的 updateDraft() 全字段构造，反而让状态更新路径更清晰、更容易测试。数据持久化选择 @kit.ArkData 的 preferences 而非关系型数据库：本项目数据量小（6 条规则、5 台设备、50 条日志），单 JSON 快照一次 flush 就够，读写路径短、异常面小；代价是不适合复杂查询与大数据量，这一点在个人总结中进一步说明。事件通信上，用户操作 → 引擎计算 → @State 回填 → 持久化 全部在同一 UI 线程同步完成，没有引入跨线程事件总线，避免异步时序带来的状态不一致。')

heading(doc, '4.3 Git 提交记录', 2)
table(doc, ['Commit 短哈希', '提交说明', '涉及文件 / 功能'], [
    ['6d55b76', 'chore: 初始化 HarmonyOS Stage 工程骨架与构建配置', '.gitignore、AppScope/、build-profile.json5、hvigor*、module.json5、resources'],
    ['1c14416', 'feat: 实现规则引擎核心、冲突优先级裁决与默认业务数据', 'engine/RuleEngine.ts、engine/DefaultData.ts'],
    ['074aca2', 'feat: 实现 Preferences 持久化与冷启动恢复降级', 'repository/StorageService.ets、viewmodel/DormStore.ets'],
    ['d25952b', 'feat: 实现四页签 ArkUI 界面、状态管理与规则编辑器', 'pages/Index.ets'],
    ['1ae2d08', 'test: 补充 DevEco hypium 与 Node 单元测试共 33 条用例', 'ohosTest/ets/test/*、tests/node/*'],
    ['692ba50', 'docs: 编写软件需求说明书并生成架构图与业务流程图', 'docs/软件需求说明书.md、两张 PNG、tools/generate_diagrams.py'],
    ['b0cd5e0', 'docs: 补充 README、真实测试运行日志与运行录屏指南', 'README.md、docs/测试运行日志.md、docs/运行与录屏指南.md'],
], widths=[2.6, 5.6, 6.2], font_size=8.5)
caption(doc, '表4.1  本人 Git 提交记录（作者 sober-free，邮箱 321836763+sober-free@users.noreply.github.com）')
para(doc, '下表列出应用与文档交付的七次主线提交，按"骨架 → 业务 → 持久化 → 界面 → 测试 → 设计文档 → 交付文档"的真实开发顺序组织，可在仓库提交历史中逐条查看 diff；此外还有报告生成脚本等维护性提交，完整历史以仓库 Commit 记录为准。个人贡献以 GitHub 实际代码变更及提交记录为准。')

# ============================== 5 模块测试 ==============================
doc.add_page_break()
heading(doc, '5. 模块测试', 1)
heading(doc, '5.1 Mock 测试设计', 2)
para(doc, '测试围绕本人负责的规则引擎业务规则展开，验证目标是：条件判定是否正确、执行顺序是否稳定、冲突裁决是否符合优先级、异常输入是否会崩溃、存档能否正确往返。所有输入都用本地对象构造 Mock 数据——Environment 由 makeEnv / ENV() 生成，设备状态由 cloneDevices(DEFAULT_DEVICES) 生成，规则由 cloneRule() 复制，不依赖任何真实硬件、网络或云服务；每条用例使用独立副本，互不污染。')
para(doc, '选取三类输入的理由：正常输入（如 30℃ 只放 R002）验证主流程与 before→after 记录；边界输入（28/27℃、35/36%、hour=0/23、空规则表、空设备表）验证含等号阈值与空集合行为；异常输入（温度 999、NaN、null 环境、未知环境量/运算符、空条件规则、损坏 JSON）验证降级路径不会让应用崩溃。测试文件 tests/node/rule-engine.test.mjs 直接 import 工程里的 RuleEngine.ts 与 DefaultData.ts，即应用实际运行的那份源码，不存在"测试代码另写一套逻辑"的问题。')
para(doc, '运行命令：node --test tests/node/rule-engine.test.mjs（Node.js 22.22.2）。DevEco Studio 侧另有 entry/src/ohosTest/ets/test/RuleEngine.test.ets，用 @ohos/hypium 编写 14 条对应用例，可在设备/模拟器上运行。')

heading(doc, '5.2 测试结果', 2)
table(doc, ['类别', 'Mock 输入 / 前置条件', '预期结果', '实际运行结果与证据'], [
    ['正常', '温度 30℃，规则表仅 R002', '空调开启并设为 26℃，生成 1 条 order=1 的记录，beforePower=false / afterPower=true', '通过。TAP 输出 ok 1；见 docs/测试运行日志.md'],
    ['正常', 'S1 夏夜归寝：23 点、有人、30℃', 'R001(p10) → R002(p20) 顺序执行，触发顺序可复现', '通过。ok 3，triggeredRuleIds = [R001, R002]'],
    ['正常', 'S2 午后无人：31℃、900lux、无人', 'R002 胜出保留空调开启；R005 空调动作被拦截；主灯/风扇仍关闭', '通过。ok 4 / ok 5，conflicts=1，blockedCount=1'],
    ['边界', '温度 28 / 27，湿度 35 / 36；hour=0 / 23', '含等号阈值在临界值命中，其余不命中；hour 正确归一化', '通过。ok 8 / ok 9'],
    ['边界', '空规则列表 / 全部停用 / 空设备列表', '设备状态不变、无执行记录、给出 warnings', '通过。ok 10 / ok 11'],
    ['异常', '温度 999、湿度 NaN、环境对象为 null', '裁剪/回退默认值并写 warnings，引擎不崩溃', '通过。ok 13 / ok 18，设备列表仍为 5'],
    ['异常', '未知环境量、非法运算符、空条件规则、损坏存档 JSON', '条件判定 false；非法规则被拦截；deserializeState 返回 null', '通过。ok 14 / ok 15 / ok 17'],
], widths=[1.5, 4.4, 4.7, 3.8], font_size=8)
caption(doc, '表5.1  模块测试记录（完整 TAP 输出见 docs/测试运行日志.md）')
para(doc, '汇总：19 条用例全部通过，失败 0，耗时约 246 ms；分类为正常 7 条 / 边界 5 条 / 异常 7 条，超过"每人至少 3 条、团队至少 6 条"的要求。回归验证由 [边界 5] 完成：4 组预设场景各执行两次并比较设备终态与触发顺序，结果完全一致，说明引擎无随机性。所有用例均通过，无未通过项。')

heading(doc, '5.3 问题与修复', 2)
para(doc, '开发中遇到的代表性问题是"优先级形同虚设"。最初的实现按优先级升序执行命中的规则，但对同一设备直接后写覆盖：在 S2 场景里 R002(p20) 先把空调打开，随后 R005(p50) 又把空调关闭，最终状态恰好与"高优先级胜出"相反，而且界面上看不出发生过争用。定位方式是打印执行序列与设备终态，发现 execute 阶段缺少"该设备本轮是否已被更高优先级规则处理过"的记忆。')
para(doc, '修复分三步：① 引入 Map<DeviceId, string> 记录每个设备通道的占用者，只有通道空闲才允许写入设备状态；② 对已被占用的动作不再写设备，改为生成 ConflictRecord 与 blocked=true 的 ExecutionRecord，保留触发条件快照与当前状态快照；③ 用 continue 而非 break，保证同一规则对其他设备的动作继续执行。修复后补充了 [正常 4]、[正常 5]、[正常 6] 三条测试：分别验证胜出者正确、拦截粒度只作用于争用设备、以及给 R002 补充"在室=有人"条件后冲突归零。此外在演练页做了可视化提示与「一键修复」按钮，把这条排查路径变成了用户可复现的功能。')

# ============================== 6 运行与总结 ==============================
doc.add_page_break()
heading(doc, '6. 运行与总结', 1)
heading(doc, '6.1 运行效果', 2)
para(doc, '一条完整的用户操作流程如下：冷启动进入联动台，顶部提示"未检测到有效存档，已加载默认方案"，6 条默认规则与 5 台全部关闭的设备就绪；把温度滑块拖到 30℃ 并点击「执行联动演练」，结果摘要显示触发 1 条规则、执行 1 个动作，空调卡片由 OFF 变为 ON·26℃；切到规则页，R001 卡片显示"当 时段≥22点 且 在室=有人"，点「+ 新增规则」配置一个双条件规则并保存，页面立即重新演练；切到演练页载入 S2 午后无人，出现"检测到 1 处控制冲突：空调 R002 胜出，R005 被拦截"，点击「一键修复」后提示"当前无控制冲突"且空调变为关闭；切到日志页，执行时间线按 #1、#2… 列出每条动作的优先级、触发条件快照、设备变化前后值与拦截标记；最后修改一条规则的优先级，强制结束应用进程再重新打开，顶部出现"已恢复存档"，规则、设备状态与执行记录全部保留。')
placeholder(doc, '图6.1  应用运行效果', '此处应放入联动台、规则页、S2 冲突提示与日志页的实机截图，拍摄清单见 docs/运行与录屏指南.md 第 3 节。')

heading(doc, '6.2 数据恢复与集成', 2)
para(doc, '以"用户新增的规则"这一代表性数据为例：在规则编辑器保存时，Index.saveDraft() 更新 @State rules，随后 runOnce() 触发 DormStore.persist()；DormStore 把 environment、devices、rules、最近 50 条 records 与 conflicts 组装成 PersistedState，serializeState 生成 JSON 字符串，StorageService.save() 执行 preferences.put("snapshot", text) 与 put("saved_at", now) 后调用 flush() 立即落盘。结束应用进程后重新打开，Index.aboutToAppear() 调用 DormStore.restore()：先 getPreferences，再 load 取出字符串，deserializeState 还原对象，校验 devices 与 rules（逐条 validateRule），通过后 applySnapshot 回填全部 @State。若存储初始化失败、无存档或 JSON 损坏，则安全回退默认方案并在界面显示具体原因，不会出现白屏或崩溃。')
para(doc, '集成验证方面，Node 侧 [异常 5] 断言存档字符串可 round-trip 且损坏 JSON 返回 null；[边界 5] 断言 4 组场景重复执行终态一致；DevEco 侧 ohosTest 的 exception_corrupted_snapshot_returns_null 覆盖同一逻辑。真实界面上"结束进程 → 重启 → 数据恢复"的截图与录屏由本人在模拟器/真机上补录，补录方法见 docs/运行与录屏指南.md 第 4 节分镜脚本。')
placeholder(doc, '图6.2  数据恢复与集成结果', '此处应放入重启前后对比截图：修改规则后的界面、强制结束进程、重启后"已恢复存档"提示与日志页恢复说明。')

heading(doc, '6.3 个人总结', 2)
para(doc, '这次开发里让我停下来查资料的，是一个看起来很小的疑问：规则引擎到底该不该写成纯逻辑模块。最初的写法把条件判定直接塞在 ArkUI 组件的方法里，结果单元测试必须启动整个页面才能跑；而 ArkTS 又在编译期禁止 any、对象展开和若干 TypeScript 运行时语法，我一度想用动态对象绕过类型检查。为了判断这两条路，我先查了华为官方的《初识 ArkTS 语言》（https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-get-started）和《从 TypeScript 到 ArkTS 的适配规则》（https://device.harmonyos.com/cn/docs/apiref/harmonyos-guides/typescript-to-arkts-migration-guide）：前者说明 ArkTS 自 API version 10 起通过规范强化静态检查以提升运行稳定性与性能，后者具体列出被限制的 TS 特性并给出重构建议。两份资料结论一致——绕过静态检查不是可行方向，按规范重构才是。于是我把引擎拆成只用 interface / type / 普通函数、不 import 任何 HarmonyOS API 的 RuleEngine.ts，并据此选择了可执行测试的方案：又核对了 Node.js 官方《Modules: TypeScript》（https://nodejs.org/download/release/v22.12.0/docs/api/typescript.html，注明 type stripping 自 v22.6.0 起提供）与 22.18.0 LTS 发布说明（https://nodejs.org/uk/blog/release/v22.18.0，默认启用该能力），确认本机 Node 22.22.2 可以直接加载 .ts 源码。最终测试文件直接 import 工程真实源码，19 条用例一次跑通，这比另写一份模拟实现更有说服力，也是我舍弃"为测试再抄一份逻辑"这一做法的理由。')
para(doc, '对鸿蒙新技术的认识，我选的是本项目中真正用到了的 @kit.ArkData 用户首选项（Preferences）。查证的官方资料是《@ohos.data.preferences（用户首选项）》API 参考（https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-data-preferences）与《通过用户首选项实现数据持久化 (ArkTS)》（https://device.harmonyos.com/cn/docs/apiref/harmonyos-guides/data-persistence-by-preferences）：它提供 Key-Value 型轻量持久化，值可为数字、字符串、布尔、数组、Uint8Array、object 或 bigint，数据文件位于 preferencesDir，导入方式为 import { preferences } from "@kit.ArkData"；指南还说明默认使用 XML 存储模式，自 API version 18 起新增 GSKV 存储模式并需先用 isStorageTypeSupported() 判断平台支持情况。用途上，它适合配置、规则、小型状态快照这类"整体读写、按键取值"的数据，本项目 6 条规则加 50 条日志正好落在这一区间，所以我用它而不是关系型数据库。局限也很清楚：它是单应用内的轻量键值存储，不支持复杂关系查询与大数据量，多个键的写入需要自行保证一致性（本项目因此采用单个 snapshot 键一次 flush 的方案），跨设备同步与分布式能力属于其他数据管理能力，不能指望 Preferences 提供；另外存储模式与可用 API 随版本变化，API 18 才引入 GSKV，代码不能假定所有设备都支持。这些判断都来自上述官方文档，而不是泛泛的印象。')
para(doc, '接下来我打算专门补一块"数据层选型的版本跟随"学习任务：以 HarmonyOS API 18 的 GSKV 存储模式与关系型数据库（RDB）为对象，先用官方 Release Notes 与 ArkData 指南核对各能力的起始 API 版本和适用设备范围，再在 DevEco Studio 里查看本机 SDK 的 API 版本，写一个最小 demo 分别用 Preferences 与 RDB 存取同一份规则数据并对比读写耗时与代码量，最后用一组单元测试验证"不支持 GSKV 的设备上调用 isStorageTypeSupported() 后能正确回退"。成效是否达成，我用三条可验证的标准判断：能准确说出每个能力的最低 API 版本、demo 能在指定模拟器上编译运行、回退路径有对应测试断言通过。资料核查会继续以华为开发者官网文档与对应版本的 API 参考为主，辅以 OpenHarmony 开源仓库的实现说明交叉验证，而不是只看二手博客——这次写报告时我已经吃过一次亏：搜索到的第三方文章对"Preferences 是否支持跨设备同步"说法不一，最后还是回到官方 API 参考才确认边界。')

doc.add_paragraph()
para(doc, '附：仓库地址 https://github.com/sober-free/dormlink-harmony　｜　本人 GitHub 账号 sober-free　｜　需求说明书 docs/软件需求说明书.md　｜　测试证据 docs/测试运行日志.md', 9,
     align=WD_ALIGN_PARAGRAPH.CENTER, indent=False)

doc.save(OUT)
print('saved', OUT)
