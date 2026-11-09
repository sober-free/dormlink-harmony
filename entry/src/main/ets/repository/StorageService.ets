import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const STORE_NAME: string = 'dormlink_state';
const KEY_SNAPSHOT: string = 'snapshot';
const KEY_SAVED_AT: string = 'saved_at';

/**
 * 基于 Preferences 的本地持久化服务（单例）。
 *
 * 设计要点：
 * - 全部读写包在 try/catch 中，存储不可用时返回安全值而不是让应用崩溃；
 * - 业务数据以单个 JSON 快照写入，避免多次 put 造成状态不一致；
 * - 每次写入后 flush() 立即落盘，保证"结束应用进程后重开仍能恢复"。
 */
export class StorageService {
  private static instance: StorageService = new StorageService();
  private pref: preferences.Preferences | null = null;
  private ready: boolean = false;

  static getInstance(): StorageService {
    return StorageService.instance;
  }

  async init(context: common.Context): Promise<boolean> {
    try {
      this.pref = await preferences.getPreferences(context, STORE_NAME);
      this.ready = true;
      hilog.info(0x0000, 'DormLink', '%{public}s', 'Preferences 初始化成功');
      return true;
    } catch (err) {
      this.ready = false;
      hilog.error(0x0000, 'DormLink', 'Preferences 初始化失败: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  isReady(): boolean {
    return this.ready;
  }

  async save(snapshot: string, savedAt: number): Promise<boolean> {
    if (!this.pref) return false;
    try {
      await this.pref.put(KEY_SNAPSHOT, snapshot);
      await this.pref.put(KEY_SAVED_AT, savedAt);
      await this.pref.flush();
      hilog.info(0x0000, 'DormLink', '存档写入成功，长度 %{public}d', snapshot.length);
      return true;
    } catch (err) {
      hilog.error(0x0000, 'DormLink', '存档写入失败: %{public}s', JSON.stringify(err));
      return false;
    }
  }

  async load(): Promise<string> {
    if (!this.pref) return '';
    try {
      const value = await this.pref.get(KEY_SNAPSHOT, '');
      if (typeof value === 'string') return value;
      return '';
    } catch (err) {
      hilog.error(0x0000, 'DormLink', '存档读取失败: %{public}s', JSON.stringify(err));
      return '';
    }
  }

  async loadSavedAt(): Promise<number> {
    if (!this.pref) return 0;
    try {
      const value = await this.pref.get(KEY_SAVED_AT, 0);
      if (typeof value === 'number') return value;
      return 0;
    } catch (err) {
      return 0;
    }
  }

  async clear(): Promise<boolean> {
    if (!this.pref) return false;
    try {
      await this.pref.clear();
      await this.pref.flush();
      hilog.info(0x0000, 'DormLink', '%{public}s', '存档已清空');
      return true;
    } catch (err) {
      hilog.error(0x0000, 'DormLink', '清空存档失败: %{public}s', JSON.stringify(err));
      return false;
    }
  }
}
