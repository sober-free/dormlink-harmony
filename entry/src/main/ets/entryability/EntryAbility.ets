import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 应用入口。业务数据的恢复放在 Index.aboutToAppear 中异步完成，
 * 这里只负责窗口与页面加载，保证冷启动时 UI 先出现、存档后回填。
 */
export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'DormLink', '%{public}s', 'DormLink 应用启动');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'DormLink', '加载页面失败: %{public}d', err.code);
        return;
      }
      hilog.info(0x0000, 'DormLink', '%{public}s', '联动台页面加载完成');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'DormLink', '%{public}s', 'WindowStage 销毁');
  }

  onForeground(): void {
    hilog.info(0x0000, 'DormLink', '%{public}s', '应用回到前台');
  }
}
