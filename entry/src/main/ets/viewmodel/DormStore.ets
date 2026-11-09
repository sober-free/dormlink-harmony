import { common } from '@kit.AbilityKit';
import {
  AutomationRule, DeviceState, Environment, ExecutionRecord, ConflictRecord,
  PersistedState, serializeState, deserializeState, cloneDevices, cloneRule,
  normalizeEnvironment, validateRule
} from '../engine/RuleEngine';
import { DEFAULT_DEVICES, DEFAULT_ENVIRONMENT, DEFAULT_RULES } from '../engine/DefaultData';
import { StorageService } from '../repository/StorageService';

/** 应用内存态快照：页面 @State 与 Preferences 之间的统一数据契约 */
export interface AppSnapshot {
  environment: Environment;
  devices: DeviceState[];
  rules: AutomationRule[];
  records: ExecutionRecord[];
  conflicts: ConflictRecord[];
  warnings: string[];
  savedAt: number;
}

export interface RestoreResult {
  snapshot: AppSnapshot;
  message: string;
  restored: boolean;
}

/**
 * 状态仓库：负责"内存态 <-> 持久化快照"的转换与异常降级。
 * 纯逻辑，不持有 @Observed / @State，UI 刷新由 Index 中的 @State 赋值驱动。
 */
export class DormStore {
  static defaultSnapshot(): AppSnapshot {
    const rules: AutomationRule[] = [];
    for (const r of DEFAULT_RULES) rules.push(cloneRule(r));
    return {
      environment: normalizeEnvironment(DEFAULT_ENVIRONMENT),
      devices: cloneDevices(DEFAULT_DEVICES),
      rules: rules,
      records: [],
      conflicts: [],
      warnings: [],
      savedAt: 0
    };
  }

  /** 冷启动恢复：存储不可用、无存档、存档损坏三种情况都安全降级 */
  static async restore(context: common.Context): Promise<RestoreResult> {
    const storage = StorageService.getInstance();
    const ok = await storage.init(context);
    if (!ok) {
      return {
        snapshot: DormStore.defaultSnapshot(),
        message: '存储服务不可用，已加载默认方案（未恢复）',
        restored: false
      };
    }
    const text = await storage.load();
    const state: PersistedState | null = deserializeState(text);
    if (!state) {
      return {
        snapshot: DormStore.defaultSnapshot(),
        message: '未检测到有效存档，已加载默认方案',
        restored: false
      };
    }

    const devices = cloneDevices(state.devices);
    const rules: AutomationRule[] = [];
    for (const r of state.rules) {
      if (validateRule(r).length === 0) rules.push(cloneRule(r));
    }
    if (devices.length === 0 || rules.length === 0) {
      return {
        snapshot: DormStore.defaultSnapshot(),
        message: '存档内容损坏或不完整，已安全回退默认方案',
        restored: false
      };
    }

    const records: ExecutionRecord[] = state.records ? state.records.slice(0, 50) : [];
    const conflicts: ConflictRecord[] = state.conflicts ? state.conflicts.slice(0, 50) : [];
    const snapshot: AppSnapshot = {
      environment: normalizeEnvironment(state.environment),
      devices: devices,
      rules: rules,
      records: records,
      conflicts: conflicts,
      warnings: [],
      savedAt: state.savedAt ? state.savedAt : 0
    };
    return {
      snapshot: snapshot,
      message: '已从 Preferences 恢复规则、设备状态与最近 ' + records.length + ' 条执行记录',
      restored: true
    };
  }

  /** 每次业务变更后立即落盘，savedAt 由调用方传入以保证界面显示一致 */
  static async persist(context: common.Context, snap: AppSnapshot, savedAt: number): Promise<boolean> {
    const state: PersistedState = {
      version: 1,
      environment: snap.environment,
      devices: snap.devices,
      rules: snap.rules,
      records: snap.records.slice(0, 50),
      conflicts: snap.conflicts.slice(0, 50),
      savedAt: savedAt
    };
    const text = serializeState(state);
    if (text.length === 0) return false;
    return await StorageService.getInstance().save(text, savedAt);
  }
}
