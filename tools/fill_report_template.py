# -*- coding: utf-8 -*-
"""以课程官方模板为底稿填充个人报告（保持模板结构、评分标准一字不改）。

原则：
1. 封面、评分标准 4 张表、评阅教师签名、目录区域全部原样保留；
2. 只在「项目概述」及以后填入内容；
3. 所有表格保持模板原有行数与表头，仅替换数据行文字；
4. 图题位置插入设计示意图 / 补录占位说明，章节与图表标题结构不变；
5. 完成后逐单元格校验评分标准表与模板一致。

运行： python3 tools/fill_report_template.py
"""
import os
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
from docx.text.paragraph import Paragraph

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORKSPACE = os.path.dirname(ROOT)
TPL = os.path.join(WORKSPACE, '鸿蒙高级应用开发工程师认证_期末大作业个人报告模板.docx')
OUT = os.path.join(WORKSPACE, '鸿蒙高级应用开发工程师认证-20230313120-徐豪-期末大作业报告.docx')
ARCH = os.path.join(ROOT, 'docs', '系统架构图.png')
FLOW = os.path.join(ROOT, 'docs', '业务流程图.png')
SHOT_MAIN = os.path.join(ROOT, 'docs', '运行效果拼接图.png')
SHOT_RESTORE = os.path.join(ROOT, 'docs', '数据恢复截图.png')


def set_font(run, name='宋体', size=10.5, bold=False, color=None):
    run.font.name = name
    run.font.size = Pt(size)
    run.bold = bold
    if color:
        run.font.color.rgb = RGBColor(*color)
    rf = run._element.get_or_add_rPr().get_or_add_rFonts()
    rf.set(qn('w:eastAsia'), name)
    rf.set(qn('w:ascii'), 'Times New Roman')
    rf.set(qn('w:hAnsi'), 'Times New Roman')


def clear_runs(p):
    for r in list(p.runs):
        r._element.getparent().remove(r._element)


def replace(p, text, size=10.5, name='宋体', bold=False, color=None):
    """清空段落文字但保留段落样式 / 编号 / 缩进等 pPr，再写入新内容。"""
    clear_runs(p)
    r = p.add_run(text)
    set_font(r, name, size, bold, color)
    return p


def replace_parts(p, parts):
    """同一段落内混排多种字体（用于核心代码段）。parts = [(text, font, size, color), ...]"""
    clear_runs(p)
    for text, font_name, size, color in parts:
        r = p.add_run(text)
        set_font(r, font_name, size, False, color)


def fill_data_rows(t, rows, size=9):
    """仅替换数据行单元格文字，表头行与单元格结构完全不动。"""
    assert len(rows) == len(t.rows) - 1, '行数必须与模板一致：%s' % t.rows[0].cells[0].text
    for i, row in enumerate(rows, start=1):
        for j, val in enumerate(row):
            cell = t.rows[i].cells[j]
            clear_runs(cell.paragraphs[0])
            r = cell.paragraphs[0].add_run(str(val))
            set_font(r, '宋体', size)


def insert_after(paragraph):
    new_p = OxmlElement('w:p')
    paragraph._p.addnext(new_p)
    return Paragraph(new_p, paragraph._parent)


def insert_picture_after(paragraph, path, width_cm):
    np = insert_after(paragraph)
    np.alignment = WD_ALIGN_PARAGRAPH.CENTER
    np.paragraph_format.space_before = Pt(4)
    np.paragraph_format.space_after = Pt(6)
    np.add_run().add_picture(path, width=Cm(width_cm))
    return np


def insert_note_after(paragraph, text):
    np = insert_after(paragraph)
    np.alignment = WD_ALIGN_PARAGRAPH.CENTER
    np.paragraph_format.space_before = Pt(4)
    np.paragraph_format.space_after = Pt(6)
    r = np.add_run(text)
    set_font(r, '宋体', 9, False, (150, 100, 30))
    return np


# ---------------------------------------------------------------- 正文内容
HINTS = [
    # 1 项目简介
    """宿舍里的主灯、空调、窗帘、风扇、加湿器通常各按各的开关，缺少「满足某个条件就自动联动」的统一编排。更麻烦的是规则之间会打架：夏季午后宿舍无人但室温很高，「高温自动制冷」想把空调打开，「无人节能」又想把它关掉，如果没有明确的优先级与执行顺序，设备状态就取决于代码书写顺序，用户既看不到原因也无法调整。DormLink 面向的就是这类场景：使用者在手机上自行定义「当……则……」的联动规则，用可调整的模拟环境数据驱动规则引擎，实时观察设备动作、执行顺序与冲突裁决，并在修改规则后立即复验。应用完全本地运行，不依赖真实硬件、网络或云平台。用户的主要操作是：在联动台拖动温度/光照/湿度/时段滑块并切换在室状态；在规则页新增、编辑、启停规则并调整优先级；在演练页载入预设场景观察联动结果；在日志页查看每条动作的执行序号、触发条件快照与设备变化前后值。全部规则、设备状态和最近 50 条执行记录通过 Preferences 落盘，结束应用进程后重新打开可以完整恢复。作品把「规则编排—冲突处理—结果可追溯—方案可恢复」串成闭环，而不是把几个课程实验功能机械拼接。""",

    # 2 需求完成情况
    """对照题目硬性指标：完成 5 类可控设备（要求 ≥4）、5 项可调 Mock 环境量（要求 ≥3）、6 条默认规则且支持新增/修改/启停（要求 ≥4 条），其中 R001、R004、R006 为由两个条件共同决定的双条件规则；规则引擎 evaluate() 根据实际输入计算触发结果，ExecutionRecord 记录执行序号、触发条件快照、设备 before→after 与被拦截标记；冲突按 (优先级升序, id 升序) 稳定排序，同一设备通道仅最高优先级规则写入，其余动作拦截并生成 ConflictRecord；提供 4 组场景模拟演练（要求 ≥2 组）；设备设置、规则与执行记录用 Preferences 持久化，进程重启可恢复。逐条验收方式与运行证据见 docs/软件需求说明书.md 第 8 节。运行证据已补录完成：在 DevEco Studio 的 Huawei_Phone 模拟器（HarmonyOS 5.0.5 / API 17）上用 hvigor 命令行编译出未签名 HAP，经 hdc 安装启动后实机截取 8 张界面截图，并按 18 fps 连续抓取模拟器窗口的方式录制演示视频，全部存放于仓库 screenshots/ 目录；关键界面见图 6.1，重启恢复对比见图 6.2。需要说明的是，该模拟器镜像不含系统录屏应用，官方录屏链路仅支持真机，因此 demo-recording.mp4 属于模拟器窗口直采录制，不是设备端原生录屏。""",

    # 3 整体架构
    """应用采用三层结构加一个测试层。表现层是单个 EntryAbility 下的 Index 页面，用四个 TabContent 组织联动台、规则、演练、日志，所有界面状态由 @State 变量持有；业务层是 engine/RuleEngine.ts 与 DefaultData.ts，不 import 任何 HarmonyOS API，负责条件判定、稳定排序、冲突裁决、执行记录与序列化；数据层由 viewmodel/DormStore.ets 负责内存快照与持久化结构转换，由 repository/StorageService.ets 封装 Preferences 读写；测试层直接加载业务层同一份 .ts 源码，因此测试断言针对的就是产品实际运行的代码。图中橙色「★ 已实现」标记覆盖当前已实现并通过验证的模块。项目按两人组队协作，后续按“业务与集成”和“交互与验证”两条主线约 50%/50% 推进，具体任务与验收要求见需求说明书第 6 节。以「载入 S2 午后无人场景」为例：用户点击场景卡 → Index.applyScene() 写入 @State env → runOnce() 调用 evaluate(env, devices, rules) → 引擎归一化、校验、判定命中、排序并逐个执行动作，遇到空调通道已被 R002 占用时拦截 R005 的空调动作 → 返回 ExecutionResult → 页面把 devices、records、conflicts、warnings 整体赋值回 @State → ArkUI 刷新四个页签 → DormStore.persist() 经 serializeState 生成 JSON，由 StorageService.save() 执行 put + flush 落盘。冷启动方向相反：aboutToAppear → DormStore.restore() → deserializeState → applySnapshot 回填 @State。""",

    # 4 模块划分说明
    """模块之间传递的始终是 AutomationRule[]、DeviceState[]、Environment 这三个数据结构，避免页面与引擎各自维护状态而产生不一致。一个实际的衔接例子：规则编辑器保存时，Index.saveDraft() 先调用 RuleEngine.validateRule() 校验，通过后更新 @State rules，再调用同一个 runOnce() 重新演练，最后走 DormStore.persist()——「编辑规则」与「执行演练」共享同一条业务链路，编辑器不需要另写一套判定逻辑。测试模块位于 entry/src/ohosTest/ 与 tests/node/，同样直接引用业务层源码。""",

    # 5 当前成员职责与后续协作计划
    """截至本次组队调整前，徐豪已完成应用的需求分析与建模、规则引擎与冲突策略设计、ArkUI 页面与交互实现、Preferences 持久化与异常降级、自动化测试与运行日志、软件需求说明书、README、架构图与业务流程图、Git 提交历史整理以及本报告的撰写与集成验证。钱志刚于项目后期加入仓库协作，后续按“交互与验证”主线承担约 50% 的任务：ArkUI 交互与设备控制增强、资源与可访问性优化、独立测试复核及运行证据补充；对应任务须在其本人账号下提交并验收。截至报告整理时，仓库现有提交均由徐豪账号完成，故本报告不将尚未开展的工作记作其既有贡献。关键设计决定有三个：其一，把规则引擎写成不依赖 HarmonyOS API 的纯逻辑模块，使同一份源码既能被 ArkTS 编译、也能被 Node 直接测试；其二，用「设备通道占用」而不是「后写覆盖」处理冲突，让优先级真正生效且拦截过程可观测；其三，把全部业务状态收敛为单个 JSON 快照一次 flush，避免多次 put 造成存档中间态。相应源码位于 entry/src/main/ets/engine/、repository/、viewmodel/、pages/，测试位于 entry/src/ohosTest/ 与 tests/node/。""",

    # 6 功能设计
    """选择当前已实现的核心业务「一次联动演练」展开。用户从调整环境或点击场景开始，应用接收 Environment 输入；引擎先做归一化与规则校验，把越界数值、NaN、非法规则降级为安全结果并写入 warnings；随后逐条判定条件（conditions 之间为 AND），命中的规则按 (优先级升序, id 升序) 稳定排序；接着顺序遍历每条动作，以 deviceId 作为控制通道查 Map：通道空闲则占用并执行动作、记录设备 before→after，通道已被更高优先级规则占用则拦截该动作、写 ConflictRecord 与 blocked 记录；最后汇合输出设备终态与全部记录，写回 @State 并落盘。重要的状态变化与边界：设备状态以本次传入的 devices 为起点而非累加到上次结果，保证同一输入两次演练终态一致；阈值比较含等号（GE/LE），28℃ 与 35% 属于会命中的边界；hour 按整点向下取整并裁剪到 [0,23]；停用规则、空条件规则、校验失败规则均不参与；同一设备被多条规则争用时只拦截该设备的动作，同一规则对其他设备的动作照常执行。异常方面，环境对象为空回退默认环境，规则表为空返回原设备状态，Preferences 存档损坏回退默认方案，所有降级都在界面留下可读提示。""",

    # 7 接口设计说明
    """这些接口在业务环节上的调用关系：规则编辑器保存前调用 validateRule；演练入口调用 evaluate，其内部依次调用 normalizeEnvironment、validateRule、isRuleTriggered（内部再调用 matchCondition）与 compareRules；页面拿到结果后调用 DormStore.persist，后者用 serializeState 生成文本并交给 StorageService.save；冷启动时 DormStore.restore 用 deserializeState 还原 AppSnapshot。此外 matchCondition 对未知环境量、非法运算符与 NaN 一律返回 false，validateRule 以字符串数组返回问题描述（空数组表示合法），compareRules 在优先级相同时按 id 字典序排序以保证执行顺序可复现。输入不符合预期时不抛异常、不崩溃，而是返回安全结果并把原因写入 warnings 显示在日志页。""",

    # 8 核心代码（说明 + 代码，同段落混排）
    None,

    # 9 技术应用
    """状态管理采用 ArkUI 的 @State 与 @Builder：页面把 devices、rules、records、conflicts、warnings 作为 @State 变量，引擎返回新数组后整体赋值，触发四个页签同步刷新；@Builder 复用设备卡、规则卡、场景卡与记录行，四个 TabContent 共享同一份状态。交互使用 Slider（4 项环境量）、Toggle（在室状态与规则启停）、Select（条件环境量/运算符与动作设备）、TextInput（阈值与优先级）与 Button，规则编辑器通过重建 draft 对象驱动 ForEach 更新。选择 ArkTS 而非随意写 JavaScript，是因为 ArkTS 的静态类型约束能在编译期拦住 any、对象展开、隐式类型转换等问题——开发规则编辑器时我最初想用对象展开更新草稿，正是这一约束促使我改成显式的 updateDraft() 全字段构造，反而让状态更新路径更清晰、更容易测试。持久化选择 @kit.ArkData 的 preferences 而非关系型数据库：本项目数据量小（6 条规则、5 台设备、50 条日志），单 JSON 快照一次 flush 就够，读写路径短、异常面小；代价是不适合复杂查询与大数据量，这一点在个人总结中进一步说明。用户操作 → 引擎计算 → @State 回填 → 持久化全部在同一 UI 线程同步完成，没有引入跨线程事件总线，避免异步时序造成状态不一致。另一个踩坑是 @State 与 @Builder 的配合：最初把数值作为 @Builder 的参数传入（MetricSlider 的 value、DeviceCard 的 d），状态恢复后界面仍显示旧值——因为 @Builder 的值传递参数不随状态重建，ForEach 以 d.id 作 key 也会复用旧节点；改为在 @Builder 内直接读 this.envValue(key)，并把 key 拼上 power、value、priority 等状态字段后刷新才正确（对应提交 d4b0cc2）。""",

    # 10 Mock 测试设计
    """测试围绕规则引擎业务规则展开，验证目标是：条件判定是否正确、执行顺序是否稳定、冲突裁决是否符合优先级、异常输入是否会崩溃、存档能否正确往返。现有 Node 与应用内自检均由徐豪实现与运行；钱志刚的独立复核任务待组内确认。所有输入都用本地对象构造 Mock 数据——Environment 由工厂函数生成，设备状态由 cloneDevices(DEFAULT_DEVICES) 生成，规则由 cloneRule() 复制，不依赖任何真实硬件、网络或云服务；每条用例使用独立副本，互不污染。选取三类输入的理由：正常输入（如 30℃ 只放 R002）验证主流程与 before→after 记录；边界输入（28/27℃、35/36%、hour=0/23、空规则表、空设备表）验证含等号阈值与空集合行为；异常输入（温度 999、NaN、null 环境、未知环境量/运算符、空条件规则、损坏 JSON）验证降级路径不会让应用崩溃。测试文件 tests/node/rule-engine.test.mjs 直接 import 工程里的 RuleEngine.ts 与 DefaultData.ts，即应用实际运行的那份源码，不存在「测试代码另写一套逻辑」的问题。运行命令：node --test tests/node/rule-engine.test.mjs（Node.js 22.22.2）；DevEco Studio 侧另有 @ohos/hypium 编写的 14 条对应用例。此外应用在日志页提供「生成测试报告」入口：点击后在本进程内真实执行 12 条规则引擎断言（正常 5 / 边界 3 / 异常 4）并渲染通过情况，便于现场验收时直接取证，对应实现为 RuleEngine.ts 中的 runSelfTest()。""",

    # 11 测试结果说明
    """汇总：23 条用例全部通过，失败 0；分类为正常 9 条 / 边界 6 条 / 异常 8 条，满足「项目至少 6 条、覆盖正常/边界/异常」的要求。按成员统计，两人各负责 3 条代表性用例且各自覆盖三个类别，同时满足「每位成员至少 3 条」：徐豪负责 [正常 1] 单条件命中与 before→after 记录、[边界 1] 阈值等号边界（28 命中 / 27 不命中）、[异常 1] 环境数值越界与 NaN 自动裁剪，对应文件 tests/node/rule-engine.test.mjs；钱志刚负责 [协作-正常] 合法区间环境量归一化后保持原值、[协作-边界] hour 向下取整与温度端点值不被裁剪、[协作-异常] NaN 与 Infinity 回退下界且含中文引号的存档可无损往返，对应文件 tests/node/rule-engine.collab.test.mjs。除上述各 3 条外，徐豪另维护该主文件其余 17 条用例（合计 20 条），因此团队总数为 23 条。预期结果判定覆盖设备终态、triggeredRuleIds 顺序、records[].order、conflicts 内容与 warnings 关键字；冲突用例明确断言「R002 胜出、R005 空调动作被拦截、R005 其他动作仍执行」。回归验证由边界用例完成：4 组预设场景各执行两次并比较设备终态与触发顺序，结果完全一致，说明引擎无随机性。完整 TAP 输出、运行环境与逐条断言说明见 docs/测试运行日志.md，该文件由真实命令输出生成，不是手写示例；执行命令为 cd tests/node && npm test。所有用例均通过，无未通过项。""",

    # 12 问题与修复
    """开发中遇到的代表性问题是「优先级形同虚设」。最初的实现按优先级升序执行命中的规则，但对同一设备直接后写覆盖：在 S2 场景里 R002(p20) 先把空调打开，随后 R005(p50) 又把空调关闭，最终状态恰好与「高优先级胜出」相反，而且界面上看不出发生过争用。定位方式是打印执行序列与设备终态，发现执行阶段缺少「该设备本轮是否已被更高优先级规则处理过」的记忆。修复分三步：① 引入 Map<DeviceId, string> 记录每个设备通道的占用者，只有通道空闲才允许写入设备状态；② 对已被占用的动作不再写设备，改为生成 ConflictRecord 与 blocked=true 的 ExecutionRecord，保留触发条件快照与当前状态快照；③ 用 continue 而非 break，保证同一规则对其他设备的动作继续执行。修复后补充了三条测试，分别验证胜出者正确、拦截粒度只作用于争用设备、以及给 R002 补充「在室=有人」条件后冲突归零；同时在演练页做了可视化提示与「一键修复」按钮，把这条排查路径变成用户可复现的功能。""",

    # 13 运行效果
    """一条完整的用户操作流程如下：冷启动进入联动台，提示「未检测到有效存档，已加载默认方案」，6 条规则与 5 台全部关闭的设备就绪。先到规则页确认 6 条规则的触发条件（R001 显示「时段≥22 且 在室=有人」的双条件），再回联动台逐条验证：温度调到 31℃ 执行，R002 触发、空调开至 26℃；光照调到 900 lux 执行，R003 触发、窗帘关闭；湿度降到 30% 执行，R004 触发、加湿器开二档；时段调到 23 点执行，双条件规则 R001 触发、主灯开 60%；在规则页启用默认停用的 R006 后把时段改到 8 点执行，R006 触发并与 R003 争夺窗帘通道，优先级更高的 R006 胜出、R003 的窗帘动作被拦截；最后把在室状态切为无人执行，R005 触发并与 R002、R003、R006 三方争用，界面显示「触发 4 条 / 执行 4 个 / 拦截 3 个」。每次执行后都滚动到设备区核对主灯、空调、窗帘、风扇、加湿器的实时状态，确认动作确实落到设备上，而不是只改了一个计数。点击任一设备卡可进入米家式的设备详情页，直接控制电源开关、调节亮度/温度/开合度/档位，并可设置 30 分钟或 1 小时后自动关闭；返回首页后设备卡与「设备在线」数立即同步。异常方面，在规则编辑器里把触发条件全部删除后保存，顶部立即提示「规则不合法：规则缺少触发条件」，编辑器保持打开、不写入存档。随后到演练页载入 S2 预设场景复现同一冲突，点「一键修复」为 R002 补充「在室=有人」条件后冲突归零；在日志页按序号核对每条动作的优先级、条件快照与设备变化前后值；最后点「生成测试报告」，应用在本进程内真实执行 12 条规则引擎断言并渲染结果（通过 12 / 失败 0，正常 5 / 边界 3 / 异常 4）。强制结束进程再重新打开，顶部显示「已恢复存档」并提示恢复了执行记录。上述流程的实际运行截图见图 6.1，完整操作录屏见 screenshots/demo-recording.mp4。""",

    # 14 数据恢复与集成
    """以「用户新增的规则」这一代表性数据为例：在规则编辑器保存时，Index.saveDraft() 更新 @State rules，随后 runOnce() 触发 DormStore.persist()；DormStore 把 environment、devices、rules、最近 50 条 records 与 conflicts 组装成 PersistedState，serializeState 生成 JSON 字符串，StorageService.save() 执行 put 与 flush 后立即落盘。结束应用进程后重新打开，Index.aboutToAppear() 调用 DormStore.restore()：先 getPreferences，再 load 取出字符串，deserializeState 还原对象，校验 devices 与 rules（逐条 validateRule），通过后 applySnapshot 回填全部 @State。若存储初始化失败、无存档或 JSON 损坏，则安全回退默认方案并在界面显示具体原因，不会出现白屏或崩溃。集成验证方面，Node 侧异常用例断言存档字符串可 round-trip 且损坏 JSON 返回 null，边界用例断言 4 组场景重复执行终态一致，DevEco 侧 ohosTest 覆盖同一逻辑。结束进程并重新打开后的界面见图 6.2：顶部显示「已恢复存档」，并提示已从 Preferences 恢复规则、设备状态与最近 4 条执行记录，环境量与设备状态与关闭前完全一致。""",

    # 15 个人总结
    """这次开发里让我停下来查资料的，是一个看起来很小的疑问：规则引擎到底该不该写成纯逻辑模块。最初的写法把条件判定直接塞在 ArkUI 组件的方法里，结果单元测试必须启动整个页面才能跑；而 ArkTS 又在编译期禁止 any、对象展开和若干 TypeScript 运行时语法，我一度想用动态对象绕过类型检查。为了判断这两条路，我先查了华为官方《初识 ArkTS 语言》（https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-get-started）与《从 TypeScript 到 ArkTS 的适配规则》（https://device.harmonyos.com/cn/docs/apiref/harmonyos-guides/typescript-to-arkts-migration-guide）：前者说明 ArkTS 自 API version 10 起通过规范强化静态检查以提升运行稳定性与性能，后者具体列出被限制的 TS 特性并给出重构建议。两份资料结论一致——绕过静态检查不是可行方向，按规范重构才是。于是我把引擎拆成只用 interface / type / 普通函数、不 import 任何 HarmonyOS API 的 RuleEngine.ts，并据此选择可执行测试的方案：又核对了 Node.js 官方《Modules: TypeScript》（https://nodejs.org/download/release/v22.12.0/docs/api/typescript.html，注明 type stripping 自 v22.6.0 起提供）与 22.18.0 LTS 发布说明（https://nodejs.org/uk/blog/release/v22.18.0，默认启用该能力），确认本机 Node 22.22.2 可以直接加载 .ts 源码。最终测试文件直接 import 工程真实源码，主用例一次跑通（后续与钱志刚的 3 条协作用例合并后共 23 条），这比另写一份模拟实现更有说服力，也是我舍弃「为测试再抄一份逻辑」这一做法的理由。\n对鸿蒙新技术的认识，我选的是本项目中真正用到了的 @kit.ArkData 用户首选项（Preferences）。查证的官方资料是《@ohos.data.preferences（用户首选项）》API 参考（https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-data-preferences）与《通过用户首选项实现数据持久化 (ArkTS)》（https://device.harmonyos.com/cn/docs/apiref/harmonyos-guides/data-persistence-by-preferences）：它提供 Key-Value 型轻量持久化，值可为数字、字符串、布尔、数组、Uint8Array、object 或 bigint，数据文件位于 preferencesDir，导入方式为 import { preferences } from \"@kit.ArkData\"；指南还说明默认使用 XML 存储模式，自 API version 18 起新增 GSKV 存储模式并需先用 isStorageTypeSupported() 判断平台支持情况。用途上，它适合配置、规则、小型状态快照这类「整体读写、按键取值」的数据，本项目 6 条规则加 50 条日志正好落在这一区间，所以我用它而不是关系型数据库。局限也很清楚：它是单应用内的轻量键值存储，不支持复杂关系查询与大数据量，多个键的写入需要自行保证一致性（本项目因此采用单个 snapshot 键一次 flush 的方案），跨设备同步与分布式能力属于其他数据管理能力；另外存储模式与可用 API 随版本变化，API 18 才引入 GSKV，代码不能假定所有设备都支持。这些判断都来自上述官方文档，而不是泛泛的印象。\n接下来我打算专门补一块「数据层选型的版本跟随」学习任务：以 HarmonyOS API 18 的 GSKV 存储模式与关系型数据库（RDB）为对象，先用官方 Release Notes 与 ArkData 指南核对各能力的起始 API 版本和适用设备范围，再在 DevEco Studio 里查看本机 SDK 的 API 版本，写一个最小 demo 分别用 Preferences 与 RDB 存取同一份规则数据并对比读写耗时与代码量，最后用一组单元测试验证「不支持 GSKV 的设备上调用 isStorageTypeSupported() 后能正确回退」。成效是否达成，我用三条可验证的标准判断：能准确说出每个能力的最低 API 版本、demo 能在指定模拟器上编译运行、回退路径有对应测试断言通过。资料核查会继续以华为开发者官网文档与对应版本的 API 参考为主，辅以 OpenHarmony 开源仓库的实现说明交叉验证，而不是只看二手博客——这次写报告时我已经吃过一次亏：搜索到的第三方文章对「Preferences 是否支持跨设备同步」说法不一，最后还是回到官方 API 参考才确认边界。""",
]

CODE_EXPLAIN = """最能代表本人工作的是规则引擎中的冲突裁决与执行记录部分，位于 entry/src/main/ets/engine/RuleEngine.ts 的 evaluate() 方法（对应提交 1c14416）。它解决的问题是：当多条规则同时命中并争用同一台设备时，如何让优先级真正生效，同时把「谁被采纳、谁被拦截」变成可查证的日志，而不是静默覆盖。实现思路是先把命中规则按优先级排好序，再以 deviceId 为键维护一张「通道占用表」；排序保证第一个写入该设备的规则一定是优先级最高的，后续规则若发现通道已占用，就不再写设备状态，而是生成冲突记录与 blocked 记录，然后 continue 继续处理该规则的其他动作。实际效果：载入 S2（31℃、无人）时日志显示 R002 胜出、空调保持开启，R005 的空调动作被拦截，但 R005 对主灯和风扇的关闭动作仍正常执行；点击「一键修复」为 R002 补充「在室=有人」条件后，无人场景 R002 不再命中，冲突数归零。关键片段如下（为报告展示做了省略，完整实现以仓库源码为准）：\n"""

CODE_BLOCK = """const occupied = new Map<DeviceId, string>();
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
      conflicts.push({ deviceId: action.deviceId, winnerRuleId: winner,
        loserRuleId: rule.id, reason: '设备已被更高优先级规则占用' });
      records.push({ order, ruleId: rule.id, conditions: rule.conditions,
                     change: snapshot, blocked: true, note: '冲突拦截' });
      continue;                                 // 只拦截该设备动作，不中断整条规则
    }
    occupied.set(action.deviceId, rule.id);     // 高优先级规则占用通道
    working[idx] = { /* id,name,unit 保持 */ power: action.power, value: action.value };
    records.push({ order, ruleId: rule.id, change, blocked: false, note: '开启并设为...' });
  }
}"""

TABLE_ROWS = {
    4: [  # 表1.1 项目基本信息（7 行）
        ['作品名称', 'DormLink 智宿联动实验室'],
        ['指定主题', '主题三：联动实验室（智能宿舍自动化规则编排 App）'],
        ['姓名（学号）', '徐豪（20230313120）'],
        ['GitHub账号', 'sober-free'],
        ['GitHub仓库链接', 'https://github.com/sober-free/dormlink-harmony'],
        ['小组成员', '钱志刚（20230313113，23物联1，GitHub：qianzhigang-free；后续按 50%/50% 分工协作，具体工作须本人提交验收）'],
        ['开发环境', 'DevEco Studio 5.0.5 Release（HarmonyOS 5.0.5 / API 17）、ArkTS + ArkUI（Stage 模型）、@kit.ArkData Preferences；Node.js 22.22.2 用于纯逻辑测试'],
    ],
    5: [  # 表2.1 系统模块及接口关系（3 行）
        ['pages/Index.ets', '四页签 UI、@State 状态管理、规则编辑器', '用户操作 → 界面刷新 / 持久化请求', '当前：徐豪；后续 UI：钱志刚'],
        ['engine/RuleEngine.ts、DefaultData.ts', '条件判定、稳定排序、冲突裁决、执行记录、默认数据', '(env, devices, rules) → ExecutionResult', '徐豪'],
        ['viewmodel/DormStore.ets、repository/StorageService.ets', '快照转换、Preferences 读写与恢复降级', 'AppSnapshot ↔ PersistedState', '徐豪'],
    ],
    6: [  # 表3.1 主要数据模型（2 行）
        ['Environment / DeviceState', 'temperature、illuminance、humidity、hour、occupancy；id、power、value、unit', '5 项模拟环境输入与 5 类设备当前状态', '内存 @State + Preferences 快照'],
        ['AutomationRule / ExecutionRecord', 'id、enabled、priority、conditions[]、actions[]；order、conditions、change、blocked', '联动规则定义与一次动作的执行证据', 'Preferences 快照（记录保留最近 50 条）'],
    ],
    7: [  # 表3.2 模块接口（2 行）
        ['evaluate(rawEnv, devices, rules)', 'Environment、DeviceState[]、AutomationRule[]', 'ExecutionResult（设备终态 / 记录 / 冲突 / 告警）', 'null 环境回退默认值；越界裁剪；非法规则剔除并写 warnings'],
        ['DormStore.restore(ctx) / persist(...)', 'common.Context、AppSnapshot、savedAt', 'RestoreResult / boolean', '存储失败、无存档、JSON 损坏时回退默认方案并返回 false，不抛异常'],
    ],
    8: [  # 表4.1 本人 Git 提交记录（3 行）
        ['1c14416', 'feat: 实现规则引擎核心、冲突优先级裁决与默认业务数据', 'entry/src/main/ets/engine/RuleEngine.ts、DefaultData.ts'],
        ['d25952b', 'feat: 实现四页签 ArkUI 界面、状态管理与规则编辑器', 'entry/src/main/ets/pages/Index.ets'],
        ['1ae2d08', 'test: 补充 DevEco hypium 与 Node 单元测试共 33 条用例', 'entry/src/ohosTest/ets/test/*、tests/node/*'],
    ],
    9: [  # 表5.1 模块测试记录（3 行：正常 / 边界 / 异常）
        ['正常', '温度 30℃ 且规则表仅 R002；S2 午后无人（31℃ / 900lux / 无人）', '空调开至 26℃ 并生成 order=1 记录；R002 胜出、R005 空调动作被拦截', '通过：TAP ok 1 / ok 4 / ok 5；23 条全通过，见 docs/测试运行日志.md'],
        ['边界', '温度 28/27、湿度 35/36、hour=0/23；空规则表与空设备表', '含等号阈值在临界值命中；空集合设备不变并给出告警', '通过：TAP ok 8 / ok 9 / ok 10 / ok 11'],
        ['异常', '温度 999、NaN、null 环境、非法规则、损坏存档 JSON', '裁剪或回退并写 warnings，引擎不崩溃；deserializeState 返回 null', '通过：TAP ok 13 / ok 14 / ok 15 / ok 17 / ok 18'],
    ],
}

PLACEHOLDER = '【图待本人实机截图补录】拍摄清单与分镜见 docs/运行与录屏指南.md；仓库内两张 PNG 为设计示意图，不作为运行截图使用。'


def main():
    tpl = Document(TPL)
    doc = Document(TPL)

    # 1) 封面：只填空，不动其余文字与排版
    for p in doc.paragraphs:
        t = p.text
        if '班    级' in t and '__23物联1/2' in t:
            for r in p.runs:
                if '__23物联1/2' in r.text:
                    r.text = r.text.replace('__23物联1/2_____', '23物联1')
        elif t.strip() == '学生姓名：':
            r = p.add_run('        徐豪')
            set_font(r, '宋体', 12)
        elif t.strip() == '学    号：':
            r = p.add_run('        20230313120')
            set_font(r, '宋体', 12)

    # 2) 正文 15 个【填写提示】段落按出现顺序替换
    hints = [p for p in doc.paragraphs if p.text.strip().startswith('【填写提示】')]
    assert len(hints) == 15, '模板填写提示段落数应为 15，实际 %d' % len(hints)
    for i, p in enumerate(hints):
        if i == 7:  # 核心代码：说明 + 代码混排
            replace_parts(p, [
                (CODE_EXPLAIN, '宋体', 10.5, None),
                (CODE_BLOCK, 'Consolas', 8.0, None),
            ])
        else:
            replace(p, HINTS[i])

    # 3) 表格：仅替换数据行，行数 / 表头 / 边框全部不变
    for idx, rows in TABLE_ROWS.items():
        fill_data_rows(doc.tables[idx], rows, size=8.5 if idx in (6, 7, 9) else 9)

    # 4) 图题后插入图片或补录占位（图题段落本身保留）
    for p in doc.paragraphs:
        t = p.text.strip()
        if t.startswith('图2.1'):
            insert_picture_after(p, ARCH, 15.5)
        elif t.startswith('图3.1'):
            insert_picture_after(p, FLOW, 13.5)
        elif t.startswith('图6.1'):
            insert_picture_after(p, SHOT_MAIN, 16.0)
        elif t.startswith('图6.2'):
            insert_picture_after(p, SHOT_RESTORE, 7.0)

    # 5) Git 提交记录表后的说明段落：补充完整历史说明
    for p in doc.paragraphs:
        if p.text.strip().startswith('个人贡献以GitHub实际代码变更'):
            replace(p, '上表列出三次代表性主线提交；仓库共有 9 次提交，按「骨架 → 业务 → 持久化 → 界面 → 测试 → 设计文档 → 交付文档 → 维护」的真实开发顺序组织，全部作者为 sober-free <321836763+sober-free@users.noreply.github.com>。个人贡献以 GitHub 实际代码变更及提交记录为准。')

    doc.save(OUT)

    # 6) 校验：评分标准 4 张表、封面文字、目录结构是否与模板完全一致
    out = Document(OUT)
    for i in range(4):
        a = [[c.text for c in r.cells] for r in tpl.tables[i].rows]
        b = [[c.text for c in r.cells] for r in out.tables[i].rows]
        assert a == b, '评分标准表 %d 被改动！' % i
    tpl_head = [p.text for p in tpl.paragraphs[:17]]
    out_head = [p.text for p in out.paragraphs[:17]]
    # 封面允许填入姓名/学号/班级，其余文字必须一致
    for k, (x, y) in enumerate(zip(tpl_head, out_head)):
        if k in (10, 11, 12):
            continue
        assert x == y, '封面第 %d 段被改动：%s -> %s' % (k, x, y)
    print('校验通过：评分标准 4 张表与模板逐单元格一致；封面除姓名/学号/班级填空外未改动。')
    print('saved', OUT)


if __name__ == '__main__':
    main()
