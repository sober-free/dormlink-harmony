# 运行截图与录屏存放目录

本目录存放本人在 DevEco Studio 的 Huawei_Phone 模拟器（HarmonyOS 5.0.5 / API 17）上**实际运行**后采集的证据：hvigor 命令行编译未签名 HAP → hdc 安装启动 → `uitest` 驱动界面 → `snapshot_display` 截屏。

## 文件清单（已采集）

```
01-dashboard.jpeg             联动台：环境调节、演练结果摘要、设备状态
02-rule-list.jpeg             规则列表：6 条规则，R001 显示双条件
03-rule-editor.jpeg           规则编辑器：条件行 + 动作行 + 优先级
04-scene-s1.jpeg              S1 夏夜归寝：触发 R001 → R002，执行 2 个动作
05-conflict-s2.jpeg           S2 冲突提示：空调 R002 胜出、R005 被拦截
06-conflict-fixed.jpeg        一键修复后：当前无控制冲突
07-execution-log.jpeg         执行日志：#1~#5，含「已拦截」与设备 before→after
08-restore-after-restart.jpeg 结束进程重启后：已恢复存档 + 恢复提示
demo-recording.mp4            演示视频（18 fps / 61 秒，一镜到底）
```

> 说明：`demo-recording.mp4` 由 Win32 `PrintWindow` 直接抓取模拟器窗口、18 fps 连续录制后合成（1093 帧 / 61 秒），流程为：桌面冷启动 → 调整 Mock 环境 → 执行联动 → 新增规则 → 载入 S2 冲突场景 → 一键修复 → 查看执行日志 → 强制结束进程 → 重启恢复。该模拟器镜像不含系统录屏应用（`pm list packages` 查不到 screenrecorder），官方录屏链路仅支持真机，故采用替代方案，并在报告与 README 中如实标注。

拍摄位置、分镜脚本与常见问题见 [`../docs/运行与录屏指南.md`](../docs/运行与录屏指南.md)。

> 注意：`docs/系统架构图.png` 与 `docs/业务流程图.png` 属于**设计示意图**，应在 README 与个人报告中明确标注，不得当作运行截图使用。
