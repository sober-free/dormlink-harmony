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
  /**
   * 最近一次演练的摘要（可选：v1 早期存档没有这三个字段，读取时由 records 回算）。
   * 执行记录是累加保留的时间线，摘要只描述「最近一次」，所以必须单独存。
   */
  lastTriggered?: string[];
  lastExecutedCount?: number;
  lastBlockedCount?: number;
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
    }
  }
  triggered.sort(compareRules);
  // 触发顺序以排序后的执行顺序为准；此前直接按输入顺序收集，会与实际执行顺序不一致
  for (const r of triggered) {
    triggeredRuleIds.push(r.id);
  }

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

/* ==================== 应用内自检（测试报告生成） ==================== */

export interface SelfTestCase {
  id: string;
  category: string;
  name: string;
  passed: boolean;
  detail: string;
}

export interface SelfTestReport {
  total: number;
  passed: number;
  failed: number;
  normalCount: number;
  boundaryCount: number;
  exceptionCount: number;
  durationMs: number;
  generatedAt: number;
  cases: SelfTestCase[];
}

function stDevices(): DeviceState[] {
  return [
    { id: 'main_light', name: '主灯', power: false, value: 0, unit: '%' },
    { id: 'ac', name: '空调', power: false, value: 26, unit: '℃' },
    { id: 'curtain', name: '窗帘', power: false, value: 0, unit: '%' },
    { id: 'fan', name: '风扇', power: false, value: 0, unit: '档' },
    { id: 'humidifier', name: '加湿器', power: false, value: 0, unit: '档' }
  ];
}

function stPower(devices: DeviceState[], id: DeviceId): boolean {
  for (const d of devices) {
    if (d.id === id) return d.power;
  }
  return false;
}

function stValue(devices: DeviceState[], id: DeviceId): number {
  for (const d of devices) {
    if (d.id === id) return d.value;
  }
  return -1;
}

function stEnv(t: number, lux: number, hum: number, h: number, occ: boolean): Environment {
  return { temperature: t, illuminance: lux, humidity: hum, hour: h, occupancy: occ };
}

function stRule(id: string, priority: number, conditions: Condition[], actions: DeviceAction[]): AutomationRule {
  return {
    id: id, name: id, enabled: true, priority: priority,
    conditions: conditions, actions: actions, description: ''
  };
}

/**
 * 在设备上真实执行一组规则引擎断言并生成测试报告。
 * 与 tests/node/rule-engine.test.mjs 覆盖同一批业务规则，但完全在应用进程内运行，
 * 用于「日志页 → 生成测试报告」入口，给现场演示和验收留证。
 */
export function runSelfTest(): SelfTestReport {
  const started = Date.now();
  const cases: SelfTestCase[] = [];

  // ---------- 正常 5 条 ----------
  const n1 = evaluate(stEnv(31, 320, 52, 20, true), stDevices(), [
    stRule('R002', 20, [{ metric: 'temperature', op: 'GE', value: 28 }],
      [{ deviceId: 'ac', power: true, value: 26 }])
  ]);
  cases.push({
    id: 'N1', category: '正常', name: '单条件触发后设备按动作改变',
    passed: stPower(n1.devices, 'ac') === true && stValue(n1.devices, 'ac') === 26 && n1.records.length === 1,
    detail: '空调 ' + (stPower(n1.devices, 'ac') ? '开' : '关') + ' ' + stValue(n1.devices, 'ac') + '℃，记录 ' + n1.records.length + ' 条'
  });

  const r001 = stRule('R001', 10,
    [{ metric: 'hour', op: 'GE', value: 22 }, { metric: 'occupancy', op: 'EQ', value: 1 }],
    [{ deviceId: 'main_light', power: true, value: 60 }]);
  const n2a = isRuleTriggered(stEnv(26, 300, 50, 23, true), r001);
  const n2b = isRuleTriggered(stEnv(26, 300, 50, 21, true), r001);
  const n2c = isRuleTriggered(stEnv(26, 300, 50, 23, false), r001);
  cases.push({
    id: 'N2', category: '正常', name: '双条件规则为 AND 关系',
    passed: n2a === true && n2b === false && n2c === false,
    detail: '23点+有人=' + n2a + '，21点=' + n2b + '，无人=' + n2c
  });

  const n3 = evaluate(stEnv(30, 60, 58, 23, true), stDevices(), [
    stRule('R002', 20, [{ metric: 'temperature', op: 'GE', value: 28 }],
      [{ deviceId: 'ac', power: true, value: 26 }]),
    r001
  ]);
  cases.push({
    id: 'N3', category: '正常', name: '多条规则按优先级升序执行',
    passed: n3.triggeredRuleIds.length === 2 && n3.triggeredRuleIds[0] === 'R001' && n3.triggeredRuleIds[1] === 'R002',
    detail: '触发顺序 ' + n3.triggeredRuleIds.join(' → ')
  });

  const r005 = stRule('R005', 50, [{ metric: 'occupancy', op: 'EQ', value: 0 }],
    [{ deviceId: 'ac', power: false, value: 26 }]);
  const r002b = stRule('R002', 20, [{ metric: 'temperature', op: 'GE', value: 28 }],
    [{ deviceId: 'ac', power: true, value: 26 }]);
  const n4 = evaluate(stEnv(31, 900, 42, 14, false), stDevices(), [r002b, r005]);
  cases.push({
    id: 'N4', category: '正常', name: '冲突裁决：高优先级规则胜出',
    passed: stPower(n4.devices, 'ac') === true && n4.conflicts.length === 1 && n4.conflicts[0].winnerRuleId === 'R002',
    detail: '空调 ' + (stPower(n4.devices, 'ac') ? '开' : '关') + '，冲突 ' + n4.conflicts.length + ' 处，胜出 ' + (n4.conflicts.length > 0 ? n4.conflicts[0].winnerRuleId : '无')
  });

  const r005b = stRule('R005', 50, [{ metric: 'occupancy', op: 'EQ', value: 0 }],
    [{ deviceId: 'main_light', power: false, value: 0 },
     { deviceId: 'ac', power: false, value: 26 },
     { deviceId: 'fan', power: false, value: 0 }]);
  const n5 = evaluate(stEnv(31, 900, 42, 14, false), stDevices(), [r002b, r005b]);
  let blocked = 0;
  for (const rec of n5.records) {
    if (rec.blocked) blocked = blocked + 1;
  }
  cases.push({
    id: 'N5', category: '正常', name: '冲突只拦截争用设备，其余动作照常执行',
    passed: blocked === 1 && stPower(n5.devices, 'main_light') === false && stPower(n5.devices, 'fan') === false,
    detail: '拦截 ' + blocked + ' 个，主灯/风扇仍执行关闭'
  });

  // ---------- 边界 3 条 ----------
  const b1a = isRuleTriggered(stEnv(28, 300, 50, 20, true), r002b);
  const b1b = isRuleTriggered(stEnv(27, 300, 50, 20, true), r002b);
  cases.push({
    id: 'B1', category: '边界', name: '阈值等号边界：28 命中、27 不命中',
    passed: b1a === true && b1b === false,
    detail: '28℃=' + b1a + '，27℃=' + b1b
  });

  const b2a = normalizeEnvironment(stEnv(26, 300, 50, 0, true)).hour;
  const b2b = normalizeEnvironment(stEnv(26, 300, 50, 23, true)).hour;
  const b2c = isRuleTriggered(stEnv(26, 300, 50, 23, true), r001);
  cases.push({
    id: 'B2', category: '边界', name: '时段边界 hour=0 与 23 归一化正确',
    passed: b2a === 0 && b2b === 23 && b2c === true,
    detail: 'hour0=' + b2a + '，hour23=' + b2b + '，R001 命中=' + b2c
  });

  const b3 = evaluate(stEnv(26, 300, 50, 20, true), stDevices(), []);
  cases.push({
    id: 'B3', category: '边界', name: '空规则列表时设备状态不变',
    passed: b3.records.length === 0 && b3.devices.length === 5 && b3.warnings.length > 0,
    detail: '记录 ' + b3.records.length + ' 条，告警 ' + b3.warnings.length + ' 条'
  });

  // ---------- 异常 4 条 ----------
  const e1 = normalizeEnvironment(stEnv(999, -50, 200, 30, true));
  cases.push({
    id: 'E1', category: '异常', name: '环境数值越界自动裁剪到合法区间',
    passed: e1.temperature === 50 && e1.illuminance === 0 && e1.humidity === 100 && e1.hour === 23,
    detail: '999→' + e1.temperature + '，-50→' + e1.illuminance + '，200→' + e1.humidity
  });

  const e2a = matchCondition(stEnv(26, 300, 50, 20, true), { metric: 'temperature', op: 'GE', value: Number.NaN });
  const e2b = matchCondition(stEnv(Number.NaN, 300, 50, 20, true), { metric: 'temperature', op: 'GE', value: 10 });
  cases.push({
    id: 'E2', category: '异常', name: 'NaN 阈值 / NaN 环境值判定为 false 且不抛异常',
    passed: e2a === false && e2b === false,
    detail: 'NaN阈值=' + e2a + '，NaN环境=' + e2b
  });

  const bad = stRule('RBAD', 20, [], []);
  const issues = validateRule(bad);
  const e3 = evaluate(stEnv(31, 300, 50, 20, true), stDevices(), [bad]);
  cases.push({
    id: 'E3', category: '异常', name: '非法规则被校验拦截且不参与演练',
    passed: issues.length >= 2 && e3.executedCount === 0,
    detail: '问题 ' + issues.length + ' 项，执行动作 ' + e3.executedCount + ' 个'
  });

  const e4a = deserializeState('{ broken json');
  const e4b = deserializeState('');
  cases.push({
    id: 'E4', category: '异常', name: '损坏存档反序列化返回 null',
    passed: e4a === null && e4b === null,
    detail: '损坏 JSON=' + (e4a === null ? 'null' : 'object') + '，空串=' + (e4b === null ? 'null' : 'object')
  });

  let passed = 0;
  let normalCount = 0;
  let boundaryCount = 0;
  let exceptionCount = 0;
  for (const c of cases) {
    if (c.passed) passed = passed + 1;
    if (c.category === '正常') normalCount = normalCount + 1;
    if (c.category === '边界') boundaryCount = boundaryCount + 1;
    if (c.category === '异常') exceptionCount = exceptionCount + 1;
  }

  return {
    total: cases.length,
    passed: passed,
    failed: cases.length - passed,
    normalCount: normalCount,
    boundaryCount: boundaryCount,
    exceptionCount: exceptionCount,
    durationMs: Date.now() - started,
    generatedAt: Date.now(),
    cases: cases
  };
}
