/**
 * DormLink 智宿联动实验室 —— 规则引擎核心（纯业务逻辑）
 *
 * 设计约定：
 * 1. 本文件不 import 任何 HarmonyOS / ArkUI API，只使用可被类型擦除的 TypeScript 语法
 *    （interface / type / 普通函数），不使用 enum、namespace、装饰器等运行时语法。
 * 2. 因此同一份源码既被 DevEco Studio 的 ArkTS 工程编译，也能被 Node 22 的
 *    type-stripping 直接加载运行，用于无设备环境下的真实单元测试与日志留证。
 * 3. 冲突策略：命中规则按 (priority 升序, id 升序) 稳定排序后顺序执行；
 *    同一设备在一个演练周期内只允许优先级最高的规则写入，
 *    后续低优先级规则对该设备的动作被拦截并记入 ConflictRecord。
 */

export type MetricKey = 'temperature' | 'illuminance' | 'humidity' | 'hour' | 'occupancy';
export type CompareOp = 'LT' | 'LE' | 'GT' | 'GE' | 'EQ' | 'NE';
export type DeviceId = 'main_light' | 'ac' | 'curtain' | 'fan' | 'humidifier';

/** 可调整的模拟环境数据（5 项，超过题目要求的 3 项） */
export interface Environment {
  temperature: number;   // 摄氏度，合法区间 [-10, 50]
  illuminance: number;   // 光照强度 lux，合法区间 [0, 2000]
  humidity: number;      // 相对湿度 %，合法区间 [0, 100]
  hour: number;          // 24 小时制时段，合法区间 [0, 23]
  occupancy: boolean;    // 宿舍是否有人
}

/** 可控设备状态（5 类，超过题目要求的 4 类） */
export interface DeviceState {
  id: DeviceId;
  name: string;
  power: boolean;        // 设备是否开启
  value: number;         // 目标设定值：亮度% / 目标温度℃ / 开合度% / 风速档 / 加湿档
  unit: string;
}

/** 单条触发条件；occupancy 用 1 表示真、0 表示假 */
export interface Condition {
  metric: MetricKey;
  op: CompareOp;
  value: number;
}

/** 单条设备动作：把某设备设为指定开关状态与设定值 */
export interface DeviceAction {
  deviceId: DeviceId;
  power: boolean;
  value: number;
}

/** 联动规则：conditions 之间为 AND 关系，>=2 条即双条件规则 */
export interface AutomationRule {
  id: string;
  name: string;
  enabled: boolean;
  priority: number;      // 数值越小优先级越高
  conditions: Condition[];
  actions: DeviceAction[];
  description: string;
}

/** 一次动作造成的设备变化（记录 before -> after，作为执行日志证据） */
export interface DeviceChange {
  deviceId: DeviceId;
  deviceName: string;
  beforePower: boolean;
  afterPower: boolean;
  beforeValue: number;
  afterValue: number;
}

/** 执行记录：含触发条件快照、执行序号、设备变化、是否被拦截 */
export interface ExecutionRecord {
  order: number;
  ruleId: string;
  ruleName: string;
  priority: number;
  conditions: Condition[];
  change: DeviceChange;
  blocked: boolean;
  note: string;
}

/** 冲突记录：同一设备被多条规则竞争时，记录胜出与被拦截的规则 */
export interface ConflictRecord {
  deviceId: DeviceId;
  winnerRuleId: string;
  loserRuleId: string;
  reason: string;
}

/** 一次完整演练的结果 */
export interface ExecutionResult {
  devices: DeviceState[];
  records: ExecutionRecord[];
  conflicts: ConflictRecord[];
  triggeredRuleIds: string[];
  executedCount: number;
  blockedCount: number;
  warnings: string[];
}

/** 持久化快照 */
export interface PersistedState {
  version: number;
  environment: Environment;
  devices: DeviceState[];
  rules: AutomationRule[];
  records: ExecutionRecord[];
  conflicts: ConflictRecord[];
  savedAt: number;
}

const DEFAULT_ENV: Environment = {
  temperature: 22, illuminance: 300, humidity: 50, hour: 12, occupancy: false
};

export function metricLabel(metric: MetricKey): string {
  switch (metric) {
    case 'temperature': return '温度';
    case 'illuminance': return '光照';
    case 'humidity': return '湿度';
    case 'hour': return '时段';
    case 'occupancy': return '在室';
    default: return '未知环境量';
  }
}

export function metricUnit(metric: MetricKey): string {
  switch (metric) {
    case 'temperature': return '℃';
    case 'illuminance': return 'lux';
    case 'humidity': return '%';
    case 'hour': return '点';
    case 'occupancy': return '';
    default: return '';
  }
}

export function opLabel(op: CompareOp): string {
  switch (op) {
    case 'LT': return '<';
    case 'LE': return '≤';
    case 'GT': return '>';
    case 'GE': return '≥';
    case 'EQ': return '=';
    case 'NE': return '≠';
    default: return '?';
  }
}

export function isMetric(v: string): boolean {
  switch (v) {
    case 'temperature': case 'illuminance': case 'humidity': case 'hour': case 'occupancy': return true;
    default: return false;
  }
}

export function isOp(v: string): boolean {
  switch (v) {
    case 'LT': case 'LE': case 'GT': case 'GE': case 'EQ': case 'NE': return true;
    default: return false;
  }
}

export function isDeviceId(v: string): boolean {
  switch (v) {
    case 'main_light': case 'ac': case 'curtain': case 'fan': case 'humidifier': return true;
    default: return false;
  }
}

/** 边界防护：非法/越界数值被裁剪到合法区间，非数值回退到下限 */
export function clampMetric(metric: MetricKey, raw: number): number {
  let min = 0;
  let max = 0;
  switch (metric) {
    case 'temperature': min = -10; max = 50; break;
    case 'illuminance': min = 0; max = 2000; break;
    case 'humidity': min = 0; max = 100; break;
    case 'hour': min = 0; max = 23; break;
    case 'occupancy': min = 0; max = 1; break;
    default: min = 0; max = 0; break;
  }
  if (!Number.isFinite(raw)) return min;
  const rounded = metric === 'hour' ? Math.floor(raw) : raw;
  if (rounded < min) return min;
  if (rounded > max) return max;
  return rounded;
}

/** 环境输入归一化：任何异常输入都不会让引擎崩溃 */
export function normalizeEnvironment(raw: Environment): Environment {
  if (!raw) return cloneEnvironment(DEFAULT_ENV);
  return {
    temperature: clampMetric('temperature', raw.temperature),
    illuminance: clampMetric('illuminance', raw.illuminance),
    humidity: clampMetric('humidity', raw.humidity),
    hour: clampMetric('hour', raw.hour),
    occupancy: raw.occupancy === true
  };
}

export function cloneEnvironment(e: Environment): Environment {
  return {
    temperature: e.temperature, illuminance: e.illuminance, humidity: e.humidity,
    hour: e.hour, occupancy: e.occupancy
  };
}

/** 读取环境量，未知量返回 NaN（后续条件判定为 false） */
export function readMetric(env: Environment, metric: MetricKey): number {
  switch (metric) {
    case 'temperature': return env.temperature;
    case 'illuminance': return env.illuminance;
    case 'humidity': return env.humidity;
    case 'hour': return env.hour;
    case 'occupancy': return env.occupancy ? 1 : 0;
    default: return Number.NaN;
  }
}

/** 单条件判定：非法运算符或非法阈值一律返回 false，不抛异常 */
export function matchCondition(env: Environment, condition: Condition): boolean {
  if (!condition) return false;
  const actual = readMetric(env, condition.metric);
  const expected = condition.value;
  if (!Number.isFinite(actual) || !Number.isFinite(expected)) return false;
  switch (condition.op) {
    case 'LT': return actual < expected;
    case 'LE': return actual <= expected;
    case 'GT': return actual > expected;
    case 'GE': return actual >= expected;
    case 'EQ': return actual === expected;
    case 'NE': return actual !== expected;
    default: return false;
  }
}

/** 规则命中判定：停用、无条件的规则永不触发；条件之间为 AND */
export function isRuleTriggered(env: Environment, rule: AutomationRule): boolean {
  if (!rule) return false;
  if (!rule.enabled) return false;
  const conditions: Condition[] = rule.conditions ? rule.conditions : [];
  if (conditions.length === 0) return false;
  for (const c of conditions) {
    if (!matchCondition(env, c)) return false;
  }
  return true;
}

/** 规则合法性校验：编辑器与异常测试共用 */
export function validateRule(rule: AutomationRule): string[] {
  const issues: string[] = [];
  if (!rule) return ['规则对象为空'];
  if (!rule.id || rule.id.length === 0) issues.push('规则 id 为空');
  if (!Number.isFinite(rule.priority)) issues.push('优先级不是有效数值');
  const conditions: Condition[] = rule.conditions ? rule.conditions : [];
  const actions: DeviceAction[] = rule.actions ? rule.actions : [];
  if (conditions.length === 0) issues.push('规则缺少触发条件');
  if (actions.length === 0) issues.push('规则缺少设备动作');
  for (const c of conditions) {
    if (!Number.isFinite(c.value)) issues.push('条件阈值不是有效数值');
    if (!isMetric(c.metric)) issues.push('未知环境量 ' + c.metric);
    if (!isOp(c.op)) issues.push('未知比较运算符 ' + c.op);
  }
  for (const a of actions) {
    if (!isDeviceId(a.deviceId)) issues.push('未知设备 ' + a.deviceId);
    if (!Number.isFinite(a.value)) issues.push('动作目标值不是有效数值');
  }
  return issues;
}

/** 稳定排序：优先级升序，优先级相同按 id 升序，保证执行顺序可复现 */
export function compareRules(a: AutomationRule, b: AutomationRule): number {
  if (a.priority !== b.priority) return a.priority - b.priority;
  if (a.id < b.id) return -1;
  if (a.id > b.id) return 1;
  return 0;
}

export function cloneDevices(devices: DeviceState[]): DeviceState[] {
  const out: DeviceState[] = [];
  const list: DeviceState[] = devices ? devices : [];
  for (const d of list) {
    out.push({ id: d.id, name: d.name, power: d.power, value: d.value, unit: d.unit });
  }
  return out;
}

export function findDeviceIndex(devices: DeviceState[], id: DeviceId): number {
  for (let i = 0; i < devices.length; i++) {
    if (devices[i].id === id) return i;
  }
  return -1;
}

export function cloneRule(rule: AutomationRule): AutomationRule {
  const conditions: Condition[] = [];
  const actions: DeviceAction[] = [];
  for (const c of rule.conditions) conditions.push({ metric: c.metric, op: c.op, value: c.value });
  for (const a of rule.actions) actions.push({ deviceId: a.deviceId, power: a.power, value: a.value });
  return {
    id: rule.id, name: rule.name, enabled: rule.enabled, priority: rule.priority,
    conditions: conditions, actions: actions, description: rule.description
  };
}

/**
 * 执行一次联动演练（引擎主入口）。
 *
 * 流程：环境归一化 -> 规则校验 -> 命中判定 -> 稳定排序 -> 顺序执行 + 冲突裁决
 *      -> 输出设备终态、执行记录、冲突记录与告警。
 * 任何异常输入都被降级为"安全结果"并写入 warnings，不向 UI 抛异常。
 */
export function evaluate(rawEnv: Environment, devices: DeviceState[], rules: AutomationRule[]): ExecutionResult {
  const warnings: string[] = [];
  const working: DeviceState[] = cloneDevices(devices);
  const records: ExecutionRecord[] = [];
  const conflicts: ConflictRecord[] = [];
  const triggeredRuleIds: string[] = [];

  const env = normalizeEnvironment(rawEnv);
  if (!rawEnv) {
    warnings.push('环境输入为空，已回退默认环境 22℃ / 300lux / 50% / 12点 / 无人');
  } else {
    if (rawEnv.temperature !== env.temperature) warnings.push('温度越界或非数值，已裁剪为 ' + env.temperature);
    if (rawEnv.illuminance !== env.illuminance) warnings.push('光照越界或非数值，已裁剪为 ' + env.illuminance);
    if (rawEnv.humidity !== env.humidity) warnings.push('湿度越界或非数值，已裁剪为 ' + env.humidity);
    if (rawEnv.hour !== env.hour) warnings.push('时段越界或非数值，已裁剪为 ' + env.hour);
    if (rawEnv.occupancy !== env.occupancy) warnings.push('在室状态非布尔值，已按无人处理');
  }

  const ruleList: AutomationRule[] = rules ? rules : [];
  if (ruleList.length === 0) warnings.push('规则列表为空，本次演练不产生任何设备动作');
  if (working.length === 0) warnings.push('设备列表为空，本次演练无可用设备');

  const triggered: AutomationRule[] = [];
  for (const rule of ruleList) {
    const issues = validateRule(rule);
    for (const msg of issues) warnings.push('规则 ' + (rule ? rule.id : '?') + ' 校验失败：' + msg);
    if (issues.length > 0) continue;
    if (isRuleTriggered(env, rule)) {
      triggered.push(rule);
      triggeredRuleIds.push(rule.id);
    }
  }
  triggered.sort(compareRules);

  const occupied = new Map<DeviceId, string>();
  let order = 0;
  let executedCount = 0;
  let blockedCount = 0;

  for (const rule of triggered) {
    const actions: DeviceAction[] = rule.actions ? rule.actions : [];
    for (const action of actions) {
      const idx = findDeviceIndex(working, action.deviceId);
      if (idx < 0) {
        warnings.push('规则 ' + rule.id + ' 引用不存在的设备 ' + action.deviceId + '，动作已忽略');
        continue;
      }
      const target = working[idx];
      const snapshot: DeviceChange = {
        deviceId: target.id, deviceName: target.name,
        beforePower: target.power, afterPower: target.power,
        beforeValue: target.value, afterValue: target.value
      };
      order = order + 1;

      let winner = '';
      if (occupied.has(action.deviceId)) {
        const cached = occupied.get(action.deviceId);
        winner = cached === undefined ? '' : cached;
      }
      if (winner !== '') {
        blockedCount = blockedCount + 1;
        conflicts.push({
          deviceId: action.deviceId,
          winnerRuleId: winner,
          loserRuleId: rule.id,
          reason: '设备「' + target.name + '」已被优先级更高的规则 ' + winner +
                  ' 占用，规则 ' + rule.id + ' 对该设备的动作被拦截'
        });
        records.push({
          order: order, ruleId: rule.id, ruleName: rule.name, priority: rule.priority,
          conditions: rule.conditions, change: snapshot, blocked: true,
          note: '冲突拦截，' + winner + ' 优先，设备状态保持不变'
        });
        continue;
      }

      occupied.set(action.deviceId, rule.id);
      const change: DeviceChange = {
        deviceId: target.id, deviceName: target.name,
        beforePower: target.power, afterPower: action.power,
        beforeValue: target.value, afterValue: action.value
      };
      working[idx] = {
        id: target.id, name: target.name, power: action.power,
        value: action.value, unit: target.unit
      };
      executedCount = executedCount + 1;
      records.push({
        order: order, ruleId: rule.id, ruleName: rule.name, priority: rule.priority,
        conditions: rule.conditions, change: change, blocked: false,
        note: action.power ? '开启并设为 ' + action.value + target.unit : '关闭'
      });
    }
  }

  return {
    devices: working, records: records, conflicts: conflicts,
    triggeredRuleIds: triggeredRuleIds, executedCount: executedCount,
    blockedCount: blockedCount, warnings: warnings
  };
}

export function describeCondition(c: Condition): string {
  if (c.metric === 'occupancy') {
    return '在室 ' + opLabel(c.op) + ' ' + (c.value === 1 ? '有人' : '无人');
  }
  return metricLabel(c.metric) + ' ' + opLabel(c.op) + ' ' + c.value + metricUnit(c.metric);
}

export function describeRecord(r: ExecutionRecord): string {
  const head = '#' + r.order + ' [' + r.ruleId + '] ' + r.ruleName;
  const detail = r.change.deviceName + '：' +
    (r.change.beforePower ? '开 ' : '关 ') + r.change.beforeValue +
    ' → ' + (r.change.afterPower ? '开 ' : '关 ') + r.change.afterValue;
  return head + ' | ' + detail + ' | ' + r.note;
}

/** 持久化序列化：异常输入返回空串而不是抛错 */
export function serializeState(state: PersistedState): string {
  if (!state) return '';
  try {
    return JSON.stringify(state);
  } catch (error) {
    return '';
  }
}

/** 持久化反序列化：损坏的存档返回 null，由调用方回退默认数据 */
export function deserializeState(text: string): PersistedState | null {
  if (!text || text.length === 0) return null;
  try {
    const obj = JSON.parse(text) as PersistedState;
    if (!obj || !obj.environment || !obj.devices || !obj.rules) return null;
    return obj;
  } catch (error) {
    return null;
  }
}
