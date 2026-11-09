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
demo-recording.mp4            演示视频（18 fps / 89 秒，逐变量联动演示，一镜到底）
```

> 说明：`demo-recording.mp4` 由 Win32 `PrintWindow` 直接抓取模拟器窗口、18 fps 连续录制后合成（1609 帧 / 89 秒）。演示主线是「改一个环境变量 → 触发对应规则 → 设备状态变化」：默认环境 0 条 → 温度 31℃ 触发 R002 → 光照 900lux 触发 R003 → 湿度 30% 触发 R004 → 时段 23 点触发双条件 R001 → 启用 R006 后 8 点触发晨间唤醒（与 R003 争窗帘）→ 切换无人触发 R005（与 R002/R003/R006 三方争用，拦截 3 个）→ S2 场景一键修复 → 日志 → 重启恢复。该模拟器镜像不含系统录屏应用（`pm list packages` 查不到 screenrecorder），官方录屏链路仅支持真机，故采用替代方案，并在报告与 README 中如实标注。

拍摄位置、分镜脚本与常见问题见 [`../docs/运行与录屏指南.md`](../docs/运行与录屏指南.md)。

> 注意：`docs/系统架构图.png` 与 `docs/业务流程图.png` 属于**设计示意图**，应在 README 与个人报告中明确标注，不得当作运行截图使用。
