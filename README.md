# DormLink 智宿联动实验室

> 《鸿蒙高级应用开发工程师认证》期末大作业 · 主题三「联动实验室：智能宿舍自动化规则编排 App」
>
> **项目成员**：
> - 徐豪（20230313120，23物联1）— [@sober-free](https://github.com/sober-free)
> - 钱志刚（20230313113，23物联1）— [@qianzhigang-free](https://github.com/qianzhigang-free)
>
> **协作方式**：两人组队，按功能模块分工，均以本人 GitHub 账号直接向 `main` 提交。
> **仓库**：https://github.com/sober-free/dormlink-harmony

![系统架构图](docs/系统架构图.png)

> 上图为系统架构示意图（由本仓库脚本绘制，非运行截图）。应用运行截图与录屏见第 8 节说明；想快速读懂代码请看 [`docs/技术文档.md`](docs/技术文档.md)。

---

## 1. 作品简介

宿舍里的灯、空调、窗帘、风扇、加湿器通常各按各的开关，缺少"满足条件就自动联动"的统一编排。DormLink 把这件事做成一个**完全本地、可模拟、可持久化**的 HarmonyOS 应用：用户用 Mock 环境数据（温度、光照、湿度、时段、在室状态）驱动规则引擎，自定义"当…则…"规则，观察设备如何联动、日志如何记录、冲突如何裁决，并在修改规则后立刻复验。

核心体验链路：**新建/修改规则 → 调整 Mock 环境 → 观察设备联动及日志 → 载入冲突场景并调整规则 → 结束进程重启恢复方案**。

不依赖真实硬件、网络或云平台；所有业务判断由本地纯逻辑规则引擎完成。

## 2. 功能清单

| 需求 | 题目要求 | 本作品实现 |
| --- | --- | --- |
| 设备类型 | ≥4 类 | **5 类**：主灯、空调、窗帘、风扇、加湿器 |
| 模拟环境量 | ≥3 项 | **5 项**：温度（-10~50℃）、光照（0~2000lux）、湿度（0~100%）、时段（0~23点）、在室状态 |
| 规则 | ≥4 条，含 1 条双条件规则 | **6 条**默认规则（R001~R006），其中 **R001 / R004 / R006 为双条件**；支持新增、编辑、删除、启停、优先级调整 |
| 规则引擎 | 按实际输入计算，记录触发条件、设备变化、执行顺序 | `evaluate()` 输出设备终态 + `ExecutionRecord`（order / 条件快照 / before→after / 拦截标记）+ `warnings` |
| 冲突处理 | 明确执行顺序或优先级 | 按 `(priority 升序, id 升序)` 稳定排序；同一设备通道仅最高优先级规则写入，其余动作拦截并生成 `ConflictRecord` |
| 场景演练 | ≥2 组 | **4 组**：S1 夏夜归寝、S2 午后无人·冲突、S3 干燥清晨、S4 深夜无人 |
| 持久化 | 设置、规则、执行记录可恢复 | Preferences 单 JSON 快照（`dormlink_state`），保留最近 50 条记录；进程重启自动恢复 |
| 测试 | ≥6 条，覆盖正常/边界/异常 | Node 侧 **23 条全部通过**（正常 9 / 边界 6 / 异常 8，含协作新增 3 条），DevEco `ohosTest` 侧 14 条 |
| 设备控制 | —（超出题目要求） | 设备详情页：电源开关、参数滑杆、**定时关闭（含到点倒计时提示）**、重置参数 |
| 规则管理 | —（超出题目要求） | 规则支持新增 / 编辑 / **一键复制为停用副本** / 删除 / 启停 / 优先级调整 |
| 日志筛选 | —（超出题目要求） | 执行记录支持**「全部 / 只看拦截」筛选**，仅影响展示，不改数据与持久化 |

### 四个页签

- **联动台**：顶部环境摘要（温度 / 湿度 / 光照三列大数字）→ 快捷场景横滑 → 设备网格（5 张实时状态卡）→ 模拟环境调节（4 个滑杆 + 在室开关，执行按钮内聚在卡内）→ 本次演练结果。顶部副标题按当前环境生成一句建议（如「31℃ 偏高，建议开启空调制冷」）。
- **规则**：规则以**行式列表**呈现（名称 + 条件→动作摘要 + 优先级，右侧开关），点行进入**规则详情页**（概览 / 触发条件 / 执行动作 / 操作），编辑、复制、删除收在详情页里。
- **演练**：4 组预设场景行式列表，右侧「载入」即套用环境并执行；出现冲突时显示胜出/被拦截规则，并提供「一键修复：为高温制冷补充『有人在室』条件」验证冲突消除。
- **日志**：存档状态卡 + 执行记录（单卡多行，支持「全部 / 只看拦截」筛选）+ 工具菜单（生成测试报告 / 清空记录 / 恢复出厂方案）。

## 3. 两人分工与贡献记录

两人按功能模块分工，均以**本人 GitHub 账号**直接向 `main` 提交。截至本 README 更新：仓库共 **50 次提交**，其中 `sober-free` 41 次、`qianzhigang-free` 9 次。

| 成员 | 负责范围 | 主要交付 |
| --- | --- | --- |
| 徐豪 [@sober-free](https://github.com/sober-free) | 业务与集成：规则引擎、场景与持久化结构、跨模块集成、文档体系 | `RuleEngine.ts` / `DefaultData.ts` / `DormStore.ets` / `StorageService.ets`；6 条默认规则与 4 组场景；Node 20 条 + ohosTest 14 条用例；需求 / 技术 / 设计 / 录屏文档 |
| 钱志刚 [@qianzhigang-free](https://github.com/qianzhigang-free) | 交互与验证：设备控制增强、列表与详情交互、运行证据、独立测试复核 | 设备定时倒计时（T1）、规则一键复制（T2）、日志拦截筛选（T3）、协作 3 条用例（T4）、模拟器验收截图与测试日志复核（T5）；米家式信息架构改版（分组卡片 + 行式列表 + 列表→详情→操作三段式） |

### `qianzhigang-free` 的提交记录（9 次）

| 类型 | 内容 |
| --- | --- |
| `feat(ui)` | 设备详情页定时关闭倒计时、规则卡片复制、日志「只看拦截」筛选，并修复定时器未清理 |
| `test` | 新增 3 条协作用例（正常 / 边界 / 异常各 1 条，直接 import 产品源码） |
| `docs` | 补录协作测试与编译验证输出（23 pass / 0 fail，BUILD SUCCESSFUL） |
| `fix(ui)` | 修复 `timerActive()` 短路导致 @State 依赖丢失、设定定时后界面不刷新 |
| `docs` | 补录 T1–T3 模拟器验收截图与 README 清单 |
| `style(design)` | 米家风格配色 v2：降饱和橙 + 中性灰 + 卡片轻投影 + 开关/按钮对比度修复 |
| `style(layout)` | 按米家信息架构重排四个页签（分组小标题 + 单卡多行列表） |
| `feat(rule)` | 规则详情页（列表→详情→操作）+ 首页场景化建议文案 |
| `style(device)` | 设备详情页统一为「概览 + 参数 + 定时 + 信息 + 操作」分组列表 |

T1–T5 的改动点与验收标准见 [`docs/协作任务清单.md`](docs/协作任务清单.md)。

## 4. 开发环境

| 项目 | 版本/说明 |
| --- | --- |
| IDE | DevEco Studio 5.0.5 Release（HarmonyOS 5.0.5 / API 17） |
| 语言 / 框架 | ArkTS、ArkUI（声明式 UI）、Stage 模型 |
| SDK | `compatibleSdkVersion: 5.0.5(17)`，`runtimeOS: HarmonyOS` |
| 持久化 | `@kit.ArkData` → `preferences` |
| 测试框架 | `@ohos/hypium`（ohosTest）+ `node:test`（纯逻辑） |
| 纯逻辑测试环境 | Node.js ≥ 22.6（用原生 TypeScript type-stripping 直接执行 `.ts` 源码） |
| 运行载体 | HarmonyOS 模拟器或真机 |

> 若本机 DevEco 的 SDK 版本不同，修改根 `build-profile.json5` 中的 `compatibleSdkVersion` / `targetSdkVersion` 后 Sync 即可。

## 5. 目录结构

```
dormlink-harmony/
├── AppScope/                       应用级配置与图标
├── entry/src/main/
│   ├── ets/entryability/           EntryAbility.ets（窗口与页面加载）
│   ├── ets/pages/Index.ets         ★ 四个页签 UI、@State 状态管理、规则编辑器
│   ├── ets/common/DesignTokens.ets  ★ 设计规范 Token（颜色/字号/间距/圆角/尺寸）
│   ├── ets/engine/RuleEngine.ts    ★ 规则引擎（纯逻辑，不依赖 HarmonyOS API）
│   ├── ets/engine/DefaultData.ts   ★ 默认设备 / 6 条规则 / 4 组场景
│   ├── ets/viewmodel/DormStore.ets ★ 内存态 ↔ 持久化快照、恢复降级
│   ├── ets/repository/StorageService.ets ★ Preferences 读写与异常捕获
│   └── resources/                  页面路由、字符串、颜色、图标
├── entry/src/ohosTest/             ★ DevEco 侧 hypium 单元测试（14 条）
├── tests/node/                     ★ Node 侧测试（23 条，含协作新增 3 条，直接加载上面的业务源码）
├── docs/
│   ├── 技术文档.md                 ★ 接手必读：架构、调用链、函数索引、改动指南、已知坑
│   ├── 软件需求说明书.md           ★ 需求、数据模型、接口、分工、测试、验收
│   ├── 测试运行日志.md             ★ 真实命令输出（23/23 通过）
│   ├── 设计规范.md                 ★ Design System：Token、组件、布局、自查清单
│   ├── 协作任务清单.md             两人分工待办（文件路径 / 改动点 / 验收标准）
│   ├── 运行与录屏指南.md           导入/编译/截图/录屏分镜
│   ├── 编译运行与截图录屏总结.md   实际执行记录、真实参数与已知缺口
│   ├── 系统架构图.png              架构示意图
│   └── 业务流程图.png              规则引擎执行流程图
├── screenshots/                    运行截图与录屏存放目录（由本人实机补录）
└── build-profile.json5 / hvigorfile.ts / oh-package.json5
```

★ 标记核心实现模块。截至 2026-11-09，仓库共 **50 次提交**（`sober-free` 41 次、`qianzhigang-free` 9 次）：徐豪负责规则引擎、场景数据、持久化与文档体系；钱志刚负责设备控制增强、列表/详情交互改版、协作测试与运行证据。两人贡献明细见第 3 节。

## 6. 运行方法

1. 打开 DevEco Studio → `File > Open`，选择本仓库根目录 `dormlink-harmony`。
2. 等待 `Sync` / `ohpm install` 完成；如提示签名，使用 `File > Project Structure > Signing Configs` 开启自动签名。
3. 启动 HarmonyOS 模拟器或连接真机，点击 `Run 'entry'`（▶）。
4. 首次启动加载 6 条默认规则；推荐验收顺序：
   - 联动台拖动温度到 30℃ → 点「执行联动演练」→ 空调变为 ON，顶部提示随环境变化。
   - 点「主灯」设备卡进入详情页 → 定时关闭选「30 分钟」→ 出现「将于 HH:MM:SS 自动关闭」；选「不定时」→ 变回「未设定定时」。
   - 规则页点任意规则行进入**规则详情页** → 操作区点「复制为停用副本」→ 返回列表可见 `R007 … 副本`（默认停用）。
   - 演练页载入 **S2 午后无人·冲突** → 出现冲突提示（R002 胜出 / R005 被拦截）→ 点「一键修复」→ 冲突数归零。
   - 日志页切到「只看拦截」→ 仅保留被拦截记录；切回「全部」→ 完整恢复。
   - 连续执行多次演练 → 日志页记录**累加**（保留最近 50 条、序号连续），不会被后一次覆盖。
   - **结束应用进程后重新打开** → 日志页显示"已从 Preferences 恢复…"，规则、设备状态与执行记录均保留。
5. 纯逻辑测试（无需 DevEco，Node.js ≥ 22.6）：
   ```bash
   cd tests/node && npm test
   ```

## 7. 自动化测试与证据

- `tests/node/rule-engine.test.mjs`：20 条（正常 8 / 边界 5 / 异常 7），`cd tests/node && npm test` 实测 **23 通过 / 0 失败**（含下一条协作新增用例），完整 TAP 输出见 [`docs/测试运行日志.md`](docs/测试运行日志.md)。
- `tests/node/rule-engine.collab.test.mjs`：协作新增 3 条（正常 / 边界 / 异常各 1 条），覆盖环境量归一化、`hour` 取整与端点裁剪、非有限数降级、含中文引号存档的无损往返。
- `entry/src/ohosTest/ets/test/RuleEngine.test.ets`：14 条 `@ohos/hypium` 用例，在 DevEco Studio 中右键 `ohosTest` → `Run 'Tests in entry'` 执行。
- 测试直接 import `entry/src/main/ets/engine/RuleEngine.ts`，即应用实际运行的那份源码，**没有另写模拟实现**。
- 三类覆盖：正常 9 / 边界 6 / 异常 8（Node 侧，含协作新增 3 条），详见需求说明书第 7 节。
- **成员分工（每人 3 条，各自覆盖正常/边界/异常）**：徐豪负责 `[正常 1]` `[边界 1]` `[异常 1]`（`rule-engine.test.mjs`，另维护该文件其余 17 条）；钱志刚负责 `[协作-正常]` `[协作-边界]` `[协作-异常]`（`rule-engine.collab.test.mjs`）。完整对照表见需求说明书 7.4。

## 8. 运行截图与演示视频

在 DevEco Studio 的 **Huawei_Phone 模拟器（HarmonyOS 5.0.5 / API 17）** 上实际编译、安装、运行后采集，全部位于 [`screenshots/`](screenshots/)：

| 文件 | 内容 |
| --- | --- |
| `01-dashboard.jpeg` | 联动台：环境摘要（温度/湿度/光照三列）+ 快捷场景 + 设备网格 |
| `02-rule-list.jpeg` | 规则页：单卡多行列表，右侧开关与「›」，点行进详情 |
| `03-rule-detail.jpeg` | 规则详情：概览（名称/优先级/启用开关）+ 触发条件 + 执行动作 + 操作 |
| `03-rule-editor.jpeg` | 规则编辑器：条件行 + 动作行 + 优先级 |
| `04-scene-s1.jpeg` | 演练页：载入 S1 夏夜归寝，触发 R001 → R002 |
| `04b-scene-s1-result.jpeg` | 联动台：S1 执行后的设备联动结果 |
| `05-conflict-s2.jpeg` | S2 午后无人：检测到 1 处控制冲突（R002 胜出 / R005 被拦截） |
| `06-conflict-fixed.jpeg` | 一键修复后：当前无控制冲突 |
| `07-execution-log.jpeg` | 日志页：执行时间线（全部 11 条，序号连续，含「已拦截」标记） |
| `08-restore-after-restart.jpeg` | 结束进程重启后：已从 Preferences 恢复 17 条执行记录 |
| `09-test-report.jpeg` | 应用内自检报告：12 条断言全部通过（正常 5 / 边界 3 / 异常 4） |
| `10-device-grid.jpeg` | 设备网格：两列卡片 + 实物图标 + 开/关徽章 + 进度条 |
| `11-device-detail.jpeg` | 设备详情：概览 + 参数 + 定时关闭 + 设备信息 + 操作 |
| `13-timer-countdown.jpeg` | 定时关闭：选「30 分钟」后显示「将于 00:38:20 自动关闭」 |
| `14-rule-detail-copy.jpeg` | 规则详情操作区：编辑规则 / 复制为停用副本 / 删除规则 |
| `14-rule-duplicate.jpeg` | 复制后提示「已复制为 R007（默认停用）」，规则数 6 → 7 |
| `14b-rule-duplicate-card.jpeg` | 复制结果：`R007 高温自动制冷 副本`，已停用、开关关闭 |
| `15-log-filter.jpeg` | 日志页「只看拦截」：仅保留被拦截记录 |
| `demo-recording.mp4` | 演示视频（540×1166 / 16 fps / 158 秒）：冷启动 → 规则详情 → 改环境量驱动联动 → S2 冲突与一键修复 → 日志筛选 → 测试报告 → 规则复制 → 重启恢复 |

采集方式：`hvigorw.js assembleHap` 编译未签名 HAP → `hdc install` 安装启动 → `uitest dumpLayout` + `uiInput` 驱动界面（按控件树文本定位，不硬编码坐标）→ `snapshot_display` 截屏。视频用**设备端连续截帧**（`snapshot_display -w 540 -h 1166` 循环，约 16 fps）→ `ffmpeg` 合成 H.264。完整命令、执行记录与踩坑说明见 [`docs/编译运行与截图录屏总结.md`](docs/编译运行与截图录屏总结.md) 与 [`docs/运行与录屏指南.md`](docs/运行与录屏指南.md)。

**诚实说明**：`demo-recording.mp4` 是模拟器**连续截帧后合成**的视频（约 16 fps）——该模拟器镜像不含系统录屏应用、`screenrecord` 命令也不可用，官方录屏链路仅支持真机，故按替代方案产出；帧率为截帧上限，非渲染帧率。`docs/系统架构图.png`、`docs/业务流程图.png` 是设计示意图，不是运行截图。

## 9. 设计规范（Design System）

完整规范见 [`docs/设计规范.md`](docs/设计规范.md)，所有视觉数值的唯一来源是 `entry/src/main/ets/common/DesignTokens.ets`。视觉参考米家：**中性浅灰底 + 白色大圆角卡片 + 柔和橙点缀**。

| 维度 | 内容 |
| --- | --- |
| 色彩 | 21 个语义 Token：背景 5 层、边框 2 级、文字 4 级、品牌 4 个、状态 6 个；主色 `#F2793C`（柔和橙，非高饱和 `#FF6900`） |
| 字体 | 10 个字号 Token：11 / 12 / 13 / 15 / 16 / 17 / 20 / 21 / 24 / 26，字重仅 Regular 与 Medium |
| 间距 | 4px 基准：4 / 8 / 12 / 16 / 20 / 28 |
| 圆角 | 8 / 12 / 18 / pill |
| 阴影 | `ShadowToken`：radius 12 / `#0F000000` / offsetY 2，卡片「浮起」替代重描边 |
| 布局模式 | 分组小标题在卡外 + **单卡多行 + 1px 分隔线** + **列表 → 详情 → 操作** 三段式 |
| 组件 | 按钮、卡片、列表行、状态标签、滑块、开关、输入框、Toast 的尺寸与状态规范 |

落地效果：`Index.ets` 中**硬编码颜色 0 处、硬编码字号 0 处**，全部替换为 Token 引用（Color 242 / Font 129 / Space 125 / Radius 36 / Shadow 63 处）。自查命令：

```bash
grep -nE "'#[0-9A-Fa-f]{6}'" entry/src/main/ets/pages/Index.ets   # 应无输出
grep -nE "\.fontSize\([0-9]+\)" entry/src/main/ets/pages/Index.ets # 应无输出
```

设备图标与 TabBar 图标由 `tools/gen_device_icons.py` 生成（`ORANGE = (242, 121, 60)`），改主色只需改脚本重跑。

## 10. 持久化与异常处理

- 存储：`preferences.getPreferences(context, 'dormlink_state')`，键 `snapshot`（完整 JSON）与 `saved_at`；每次变更 `put → flush` 立即落盘。
- 恢复：`Index.aboutToAppear()` 异步调用 `DormStore.restore()`；存储不可用、无存档、JSON 损坏或字段缺失时安全回退默认方案，并在界面显示原因。
- 引擎侧：越界数值裁剪、NaN/非法规则校验、未知设备忽略、null 输入降级，全部写入 `warnings` 展示在日志页。

## 11. 交付信息

| 项目 | 内容 |
| --- | --- |
| GitHub 仓库 | https://github.com/sober-free/dormlink-harmony |
| 成员账号 | 徐豪 [@sober-free](https://github.com/sober-free) · 钱志刚 [@qianzhigang-free](https://github.com/qianzhigang-free) |
| 需求说明书 | [`docs/软件需求说明书.md`](docs/软件需求说明书.md) |
| 技术文档 | [`docs/技术文档.md`](docs/技术文档.md) |
| 设计规范 | [`docs/设计规范.md`](docs/设计规范.md) |
| 测试证据 | [`docs/测试运行日志.md`](docs/测试运行日志.md)（23 pass / 0 fail） |
| 协作清单 | [`docs/协作任务清单.md`](docs/协作任务清单.md)（T1–T5 改动点与验收标准） |
| 个人报告 | 徐豪：`鸿蒙高级应用开发工程师认证-20230313120-徐豪-期末大作业报告.docx`<br>钱志刚：`鸿蒙高级应用开发工程师认证-20230313113-钱志刚-期末大作业报告.docx`<br>（均仓库外提交） |
