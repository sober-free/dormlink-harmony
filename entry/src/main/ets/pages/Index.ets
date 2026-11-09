import { common } from '@kit.AbilityKit';
import {
  AutomationRule, Condition, DeviceAction, DeviceState, Environment,
  ExecutionRecord, ConflictRecord, MetricKey, CompareOp, DeviceId,
  evaluate, normalizeEnvironment, cloneDevices, cloneRule, validateRule,
  describeCondition, metricLabel, opLabel, runSelfTest, SelfTestCase
} from '../engine/RuleEngine';
import {
  DEFAULT_ENVIRONMENT, DEFAULT_DEVICES, SCENE_PRESETS, ScenePreset
} from '../engine/DefaultData';
import { DormStore, AppSnapshot, RestoreResult } from '../viewmodel/DormStore';
import { StorageService } from '../repository/StorageService';
import { ColorToken, FontToken, SpaceToken, RadiusToken, SizeToken, ShadowToken } from '../common/DesignTokens';

const METRIC_KEYS: MetricKey[] = ['temperature', 'illuminance', 'humidity', 'hour', 'occupancy'];
const METRIC_TEXTS: string[] = ['温度', '光照', '湿度', '时段', '在室'];
const OP_KEYS: CompareOp[] = ['LT', 'LE', 'GT', 'GE', 'EQ', 'NE'];
const OP_TEXTS: string[] = ['<', '≤', '>', '≥', '=', '≠'];
const DEVICE_KEYS: DeviceId[] = ['main_light', 'ac', 'curtain', 'fan', 'humidifier'];
const DEVICE_TEXTS: string[] = ['主灯', '空调', '窗帘', '风扇', '加湿器'];

const METRIC_SELECT: SelectOption[] = [
  { value: '温度' }, { value: '光照' }, { value: '湿度' }, { value: '时段' }, { value: '在室' }
];
const OP_SELECT: SelectOption[] = [
  { value: '<' }, { value: '≤' }, { value: '>' }, { value: '≥' }, { value: '=' }, { value: '≠' }
];
const DEVICE_SELECT: SelectOption[] = [
  { value: '主灯' }, { value: '空调' }, { value: '窗帘' }, { value: '风扇' }, { value: '加湿器' }
];

function makeNewRule(): AutomationRule {
  return {
    id: 'R' + Date.now().toString(),
    name: '新建联动规则',
    enabled: true,
    priority: 40,
    conditions: [{ metric: 'temperature', op: 'GE', value: 28 }],
    actions: [{ deviceId: 'main_light', power: true, value: 60 }],
    description: '用户自定义规则'
  };
}

function pad2(n: number): string {
  return n < 10 ? '0' + n.toString() : n.toString();
}

@Entry
@Component
struct Index {
  @State env: Environment = normalizeEnvironment(DEFAULT_ENVIRONMENT);
  @State devices: DeviceState[] = cloneDevices(DEFAULT_DEVICES);
  @State rules: AutomationRule[] = [];
  @State records: ExecutionRecord[] = [];
  @State conflicts: ConflictRecord[] = [];
  @State warnings: string[] = [];
  @State triggered: string[] = [];
  @State executedCount: number = 0;
  @State blockedCount: number = 0;
  @State currentTab: number = 0;
  @State savedAt: number = 0;
  @State restoreMessage: string = '正在读取本地存档…';
  @State restored: boolean = false;
  @State toast: string = '';
  /** 恢复阶段置 true：避免 Slider 初始化触发的保存覆盖「已从 Preferences 恢复…」提示 */
  @State restoring: boolean = true;
  @State showEditor: boolean = false;
  @State editorIsNew: boolean = true;
  /** 规则详情覆盖层（米家：列表行只留开关，操作进详情） */
  @State showRuleDetail: boolean = false;
  @State detailRuleId: string = '';
  @State draft: AutomationRule = makeNewRule();
  @State activeScene: string = '';
  // ---- 应用内自检报告 ----
  @State showReport: boolean = false;
  @State reportCases: SelfTestCase[] = [];
  @State reportTotal: number = 0;
  @State reportPassed: number = 0;
  @State reportNormal: number = 0;
  @State reportBoundary: number = 0;
  @State reportException: number = 0;
  @State reportDuration: number = 0;
  @State reportTime: number = 0;
  // ---- 设备详情 ----
  @State showDetail: boolean = false;
  @State detailId: string = 'main_light';
  @State timerMinutes: number = 0;
  /** 定时关闭的到点时间戳，0 表示当前设备未设定定时（T1） */
  @State timerEndAt: number = 0;
  /** 日志页筛选：只显示被拦截的记录（T3） */
  @State logOnlyBlocked: boolean = false;
  private timerId: number = -1;
  /** 定时器归属设备：切换设备后不再显示别的设备的倒计时（T1） */
  @State timerDeviceId: string = '';
  /** toast 定时器句柄：连续提示时先清掉上一个，避免提前清空后一条 */
  private toastTimerId: number = -1;

  async aboutToAppear(): Promise<void> {
    const result: RestoreResult = await DormStore.restore(this.getCtx());
    this.applySnapshot(result.snapshot);
    this.restoreMessage = result.message;
    this.restored = result.restored;
    this.restoring = false;
  }

  /** 页面销毁时统一释放定时器，避免后台回调继续改已卸载页面的状态 */
  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    if (this.toastTimerId >= 0) {
      clearTimeout(this.toastTimerId);
      this.toastTimerId = -1;
    }
  }

  private getCtx(): common.Context {
    return getContext(this) as common.Context;
  }

  private applySnapshot(s: AppSnapshot): void {
    this.env = s.environment;
    this.devices = s.devices;
    this.rules = s.rules;
    this.records = s.records;
    this.conflicts = s.conflicts;
    this.warnings = s.warnings;
    this.savedAt = s.savedAt;
    // 由恢复的执行记录回算摘要，避免界面显示「0 条」与日志内容不一致
    let executed = 0;
    const trig: string[] = [];
    for (const r of s.records) {
      if (!r.blocked) executed++;
      if (trig.indexOf(r.ruleId) < 0) trig.push(r.ruleId);
    }
    this.executedCount = executed;
    this.blockedCount = s.conflicts.length;
    this.triggered = trig;
  }

  private async persistAll(): Promise<void> {
    const now = Date.now();
    const snap: AppSnapshot = {
      environment: this.env,
      devices: this.devices,
      rules: this.rules,
      records: this.records,
      conflicts: this.conflicts,
      warnings: this.warnings,
      savedAt: now
    };
    const ok = await DormStore.persist(this.getCtx(), snap, now);
    if (ok) {
      this.savedAt = now;
      if (!this.restoring) {
        this.restoreMessage = '本次改动已写入 Preferences 存档，结束进程后重开可恢复';
      }
    } else {
      this.showToast('存档写入失败，请检查应用存储权限');
    }
  }

  private showToast(msg: string): void {
    this.toast = msg;
    if (this.toastTimerId >= 0) {
      clearTimeout(this.toastTimerId);
    }
    this.toastTimerId = setTimeout(() => {
      this.toast = '';
      this.toastTimerId = -1;
    }, 2400);
  }

  private formatTime(ts: number): string {
    if (ts <= 0) return '未保存';
    const d = new Date(ts);
    return pad2(d.getHours()) + ':' + pad2(d.getMinutes()) + ':' + pad2(d.getSeconds());
  }

  private deviceName(id: DeviceId): string {
    for (let i = 0; i < DEVICE_KEYS.length; i++) {
      if (DEVICE_KEYS[i] === id) return DEVICE_TEXTS[i];
    }
    return id;
  }

  private indexIn(list: string[], v: string): number {
    for (let i = 0; i < list.length; i++) {
      if (list[i] === v) return i;
    }
    return 0;
  }

  private setEnvValue(key: MetricKey, value: number): void {
    const e = this.env;
    this.env = {
      temperature: key === 'temperature' ? value : e.temperature,
      illuminance: key === 'illuminance' ? value : e.illuminance,
      humidity: key === 'humidity' ? value : e.humidity,
      hour: key === 'hour' ? Math.floor(value) : e.hour,
      occupancy: e.occupancy
    };
  }

  private setOccupancy(on: boolean): void {
    if (on === this.env.occupancy) {
      return; // 初始化回填回调，值未变化，不触发保存
    }
    const e = this.env;
    this.env = {
      temperature: e.temperature, illuminance: e.illuminance, humidity: e.humidity,
      hour: e.hour, occupancy: on
    };
    this.persistAll();
  }

  /** 执行一次联动演练：调用纯逻辑引擎，把结果整体写回 @State 触发 UI 刷新 */
  private runOnce(): void {
    const result = evaluate(this.env, this.devices, this.rules);
    this.devices = result.devices;
    this.records = result.records;
    this.conflicts = result.conflicts;
    this.warnings = result.warnings;
    this.triggered = result.triggeredRuleIds;
    this.executedCount = result.executedCount;
    this.blockedCount = result.blockedCount;
    this.showToast('演练完成：执行 ' + result.executedCount + ' 个动作，拦截 ' + result.blockedCount + ' 个冲突动作');
    this.persistAll();
  }

  private applyScene(scene: ScenePreset): void {
    this.env = normalizeEnvironment(scene.env);
    this.activeScene = scene.id + ' · ' + scene.name;
    this.runOnce();
  }

  /**
   * 冲突修复：为 R002「高温自动制冷」补充「有人在室」条件。
   * 调整后高温且无人的场景里 R002 不再命中，与 R005 的空调争用消失。
   */
  private fixConflict(): void {
    const next: AutomationRule[] = [];
    let changed = false;
    for (const r of this.rules) {
      if (r.id === 'R002') {
        const conditions: Condition[] = [
          { metric: 'temperature', op: 'GE', value: 28 },
          { metric: 'occupancy', op: 'EQ', value: 1 }
        ];
        next.push({
          id: r.id, name: r.name, enabled: r.enabled, priority: r.priority,
          conditions: conditions, actions: r.actions,
          description: r.description + '（已补充在室条件以消除与无人节能的冲突）'
        });
        changed = true;
      } else {
        next.push(cloneRule(r));
      }
    }
    if (!changed) {
      this.showToast('未找到 R002，请手动编辑规则');
      return;
    }
    this.rules = next;
    this.showToast('已为 R002 补充「在室=有人」条件，重新演练中');
    this.runOnce();
    this.persistAll();
  }

  private toggleRule(id: string, on: boolean): void {
    const next: AutomationRule[] = [];
    for (const r of this.rules) {
      const c = cloneRule(r);
      if (c.id === id) {
        c.enabled = on;
        c.priority = r.priority;
        c.conditions = r.conditions;
        c.actions = r.actions;
        c.description = r.description;
        c.name = r.name;
      }
      next.push(c);
    }
    this.rules = next;
    this.runOnce();
    this.persistAll();
  }

  private deleteRule(id: string): void {
    const next: AutomationRule[] = [];
    for (const r of this.rules) {
      if (r.id !== id) next.push(cloneRule(r));
    }
    this.rules = next;
    this.showToast('已删除规则 ' + id);
    this.persistAll();
  }

  /** 生成下一个规则 id：取现有 Rxxx 的最大序号 +1，冲突时继续递增（T2） */
  private nextRuleId(): string {
    let max = 0;
    for (const r of this.rules) {
      if (r.id.length === 4 && r.id.charAt(0) === 'R') {
        const n = Number.parseInt(r.id.substring(1), 10);
        if (Number.isFinite(n) && n > max) {
          max = n;
        }
      }
    }
    let seq = max + 1;
    let id = 'R' + this.padSeq(seq);
    while (this.hasRule(id)) {
      seq = seq + 1;
      id = 'R' + this.padSeq(seq);
    }
    return id;
  }

  private padSeq(n: number): string {
    if (n < 10) return '00' + n.toString();
    if (n < 100) return '0' + n.toString();
    return n.toString();
  }

  private hasRule(id: string): boolean {
    for (const r of this.rules) {
      if (r.id === id) return true;
    }
    return false;
  }

  /** 按 id 取规则：详情页渲染用；找不到时退回第一条，避免空引用 */
  private findRuleById(id: string): AutomationRule {
    for (const r of this.rules) {
      if (r.id === id) return r;
    }
    if (this.rules.length > 0) {
      return this.rules[0];
    }
    return makeNewRule();
  }

  /**
   * 复制规则为「停用副本」：条件/动作/优先级与源规则一致，仅 id、名称、启停不同（T2）。
   * 副本默认停用，避免复制后立即参与演练造成意外联动。
   */
  private duplicateRule(id: string): void {
    let sourceIndex = -1;
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].id === id) {
        sourceIndex = i;
      }
    }
    if (sourceIndex < 0) {
      this.showToast('未找到规则 ' + id);
      return;
    }
    const source = this.rules[sourceIndex];
    const copy = cloneRule(source);
    copy.id = this.nextRuleId();
    copy.name = source.name + ' 副本';
    copy.enabled = false;
    const next: AutomationRule[] = [];
    for (const r of this.rules) next.push(cloneRule(r));
    next.push(copy);
    this.rules = next;
    this.showToast('已复制为 ' + copy.id + '（默认停用）');
    this.persistAll();
  }

  private openNewEditor(): void {
    this.draft = makeNewRule();
    this.editorIsNew = true;
    this.showEditor = true;
  }

  private openEditor(rule: AutomationRule): void {
    this.draft = cloneRule(rule);
    this.editorIsNew = false;
    this.showEditor = true;
  }

  private updateDraft(conditions: Condition[], actions: DeviceAction[]): void {
    const d = this.draft;
    this.draft = {
      id: d.id, name: d.name, enabled: d.enabled, priority: d.priority,
      conditions: conditions, actions: actions, description: d.description
    };
  }

  private setDraftName(v: string): void {
    const d = this.draft;
    this.draft = {
      id: d.id, name: v, enabled: d.enabled, priority: d.priority,
      conditions: d.conditions, actions: d.actions, description: d.description
    };
  }

  private setDraftPriority(v: string): void {
    const n = Number(v);
    const d = this.draft;
    this.draft = {
      id: d.id, name: d.name, enabled: d.enabled,
      priority: Number.isFinite(n) ? Math.floor(n) : d.priority,
      conditions: d.conditions, actions: d.actions, description: d.description
    };
  }

  private setConditionMetric(idx: number, sel: number): void {
    const list: Condition[] = [];
    for (let i = 0; i < this.draft.conditions.length; i++) {
      const c = this.draft.conditions[i];
      list.push({
        metric: i === idx ? METRIC_KEYS[sel] : c.metric,
        op: c.op, value: c.value
      });
    }
    this.updateDraft(list, this.draft.actions);
  }

  private setConditionOp(idx: number, sel: number): void {
    const list: Condition[] = [];
    for (let i = 0; i < this.draft.conditions.length; i++) {
      const c = this.draft.conditions[i];
      list.push({ metric: c.metric, op: i === idx ? OP_KEYS[sel] : c.op, value: c.value });
    }
    this.updateDraft(list, this.draft.actions);
  }

  private setConditionValue(idx: number, v: string): void {
    const n = Number(v);
    const list: Condition[] = [];
    for (let i = 0; i < this.draft.conditions.length; i++) {
      const c = this.draft.conditions[i];
      list.push({ metric: c.metric, op: c.op, value: i === idx ? (Number.isFinite(n) ? n : 0) : c.value });
    }
    this.updateDraft(list, this.draft.actions);
  }

  private addCondition(): void {
    if (this.draft.conditions.length >= 3) {
      this.showToast('一条规则最多支持 3 个条件');
      return;
    }
    const list: Condition[] = [];
    for (const c of this.draft.conditions) list.push({ metric: c.metric, op: c.op, value: c.value });
    list.push({ metric: 'hour', op: 'GE', value: 7 });
    this.updateDraft(list, this.draft.actions);
  }

  private removeCondition(idx: number): void {
    const list: Condition[] = [];
    for (let i = 0; i < this.draft.conditions.length; i++) {
      if (i !== idx) {
        const c = this.draft.conditions[i];
        list.push({ metric: c.metric, op: c.op, value: c.value });
      }
    }
    this.updateDraft(list, this.draft.actions);
  }

  private setActionDevice(idx: number, sel: number): void {
    const list: DeviceAction[] = [];
    for (let i = 0; i < this.draft.actions.length; i++) {
      const a = this.draft.actions[i];
      list.push({ deviceId: i === idx ? DEVICE_KEYS[sel] : a.deviceId, power: a.power, value: a.value });
    }
    this.updateDraft(this.draft.conditions, list);
  }

  private setActionPower(idx: number, on: boolean): void {
    const list: DeviceAction[] = [];
    for (let i = 0; i < this.draft.actions.length; i++) {
      const a = this.draft.actions[i];
      list.push({ deviceId: a.deviceId, power: i === idx ? on : a.power, value: a.value });
    }
    this.updateDraft(this.draft.conditions, list);
  }

  private setActionValue(idx: number, v: string): void {
    const n = Number(v);
    const list: DeviceAction[] = [];
    for (let i = 0; i < this.draft.actions.length; i++) {
      const a = this.draft.actions[i];
      list.push({
        deviceId: a.deviceId, power: a.power,
        value: i === idx ? (Number.isFinite(n) ? n : 0) : a.value
      });
    }
    this.updateDraft(this.draft.conditions, list);
  }

  private addAction(): void {
    if (this.draft.actions.length >= 3) {
      this.showToast('一条规则最多支持 3 个动作');
      return;
    }
    const list: DeviceAction[] = [];
    for (const a of this.draft.actions) list.push({ deviceId: a.deviceId, power: a.power, value: a.value });
    list.push({ deviceId: 'fan', power: true, value: 2 });
    this.updateDraft(this.draft.conditions, list);
  }

  private removeAction(idx: number): void {
    const list: DeviceAction[] = [];
    for (let i = 0; i < this.draft.actions.length; i++) {
      if (i !== idx) {
        const a = this.draft.actions[i];
        list.push({ deviceId: a.deviceId, power: a.power, value: a.value });
      }
    }
    this.updateDraft(this.draft.conditions, list);
  }

  private saveDraft(): void {
    const issues = validateRule(this.draft);
    if (issues.length > 0) {
      this.showToast('规则不合法：' + issues[0]);
      return;
    }
    const next: AutomationRule[] = [];
    let found = false;
    for (const r of this.rules) {
      if (r.id === this.draft.id) {
        next.push(cloneRule(this.draft));
        found = true;
      } else {
        next.push(cloneRule(r));
      }
    }
    if (!found) next.push(cloneRule(this.draft));
    this.rules = next;
    this.showEditor = false;
    this.showToast(this.editorIsNew ? '已新增规则 ' + this.draft.id : '已保存规则 ' + this.draft.id);
    this.runOnce();
    this.persistAll();
  }

  private async resetAll(): Promise<void> {
    await StorageService.getInstance().clear();
    const snap = DormStore.defaultSnapshot();
    this.applySnapshot(snap);
    this.triggered = [];
    this.executedCount = 0;
    this.blockedCount = 0;
    this.activeScene = '';
    this.restored = false;
    this.restoreMessage = '已清空存档并恢复出厂方案';
    this.showToast('已恢复出厂方案');
    await this.persistAll();
  }

  private clearRecords(): void {
    this.records = [];
    this.conflicts = [];
    this.warnings = [];
    this.triggered = [];
    this.executedCount = 0;
    this.blockedCount = 0;
    this.persistAll();
  }

  /** 日志页当前展示的记录：只看拦截时过滤出 blocked === true（T3，只影响展示，不改数据） */
  private visibleRecords(): ExecutionRecord[] {
    if (!this.logOnlyBlocked) {
      return this.records;
    }
    const list: ExecutionRecord[] = [];
    for (const r of this.records) {
      if (r.blocked) {
        list.push(r);
      }
    }
    return list;
  }

  /** 被拦截记录条数，用于筛选药丸上的计数（T3） */
  private blockedRecords(): number {
    let n = 0;
    for (const r of this.records) {
      if (r.blocked) {
        n = n + 1;
      }
    }
    return n;
  }

  /** 应用内自检：在本进程真实执行规则引擎断言并生成报告 */
  private generateReport(): void {
    const r = runSelfTest();
    this.reportTotal = r.total;
    this.reportPassed = r.passed;
    this.reportNormal = r.normalCount;
    this.reportBoundary = r.boundaryCount;
    this.reportException = r.exceptionCount;
    this.reportDuration = r.durationMs;
    this.reportTime = r.generatedAt;
    this.reportCases = r.cases;
    this.showReport = true;
    this.showToast('自检完成：' + r.passed + ' / ' + r.total + ' 通过');
  }

  private conditionText(r: AutomationRule): string {
    const parts: string[] = [];
    for (const c of r.conditions) parts.push(describeCondition(c));
    return parts.join(' 且 ');
  }

  private actionText(r: AutomationRule): string {
    const parts: string[] = [];
    for (const a of r.actions) {
      parts.push(this.deviceName(a.deviceId) + (a.power ? ' 开至 ' : ' 关闭 ') + a.value);
    }
    return parts.join('，');
  }

  private conditionList(list: Condition[]): string {
    const parts: string[] = [];
    for (const c of list) parts.push(describeCondition(c));
    return parts.join(' 且 ');
  }

  private onlineCount(): number {
    let n = 0;
    for (const d of this.devices) {
      if (d.power) {
        n = n + 1;
      }
    }
    return n;
  }

  /** 顶部场景化提示：按当前环境量给一句建议（对应米家顶部「今天晴 26℃，适合开窗」） */
  private envAdvice(): string {
    const t: number = this.env.temperature;
    const lux: number = this.env.illuminance;
    const hum: number = this.env.humidity;
    const hour: number = this.env.hour;
    if (t >= 28) {
      return t.toString() + '℃ 偏高，建议开启空调制冷';
    }
    if (t <= 16) {
      return t.toString() + '℃ 偏低，建议开启空调制热';
    }
    if (hum <= 35) {
      return '湿度 ' + hum.toString() + '%，偏干，建议开启加湿器';
    }
    if (lux >= 800) {
      return '光照 ' + lux.toString() + ' lux 偏强，建议放下窗帘';
    }
    if (this.env.occupancy && hour >= 22) {
      return hour.toString() + ' 点且有人在室，可开启归寝照明';
    }
    if (!this.env.occupancy) {
      return '当前无人，节能规则将关闭耗能设备';
    }
    return t.toString() + '℃ · 湿度 ' + hum.toString() + '%，体感舒适，保持当前设置即可';
  }

  private sceneIcon(id: string): string {
    if (id === 'S1') {
      return '月';
    }
    if (id === 'S2') {
      return '日';
    }
    if (id === 'S3') {
      return '晨';
    }
    return '夜';
  }

  @Builder
  SceneShortcut(s: ScenePreset) {
    Column() {
      Text(this.sceneIcon(s.id))
        .fontSize(FontToken.icon).fontColor(ColorToken.brand)
        .width(40).height(40).textAlign(TextAlign.Center)
        .backgroundColor(ColorToken.accentSubtle).borderRadius(RadiusToken.pill)
      Text(s.name)
        .fontSize(FontToken.label).fontColor(ColorToken.textPrimary).margin({ top: SpaceToken.sm })
      Text(s.id + ' · ' + s.env.hour.toString() + ' 点')
        .fontSize(FontToken.caption).fontColor(ColorToken.textTertiary).margin({ top: 2 })
    }
    .width(116).padding(SpaceToken.md)
    .backgroundColor(ColorToken.surface)
    .borderRadius(RadiusToken.lg)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => { this.applyScene(s); })
  }

  @Builder
  HeaderBar() {
    Row() {
      Column() {
        Row() {
          Text('DormLink 智宿')
            .fontSize(FontToken.display).fontWeight(FontWeight.Medium).fontColor(ColorToken.textPrimary)
          Text(' ▾')
            .fontSize(FontToken.label).fontColor(ColorToken.textTertiary)
        }
        Text(this.envAdvice())
          .fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ top: 3 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Column() {
        Text(this.onlineCount().toString())
          .fontSize(FontToken.count).fontWeight(FontWeight.Medium).fontColor(ColorToken.textPrimary)
        Text('设备在线')
          .fontSize(FontToken.caption).fontColor(ColorToken.textSecondary)
      }.alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: SpaceToken.lg, right: SpaceToken.lg, top: SpaceToken.lg, bottom: SpaceToken.md })
    .backgroundColor(ColorToken.surfaceHigh)
  }

  /** 直接从 @State 读取环境量：@Builder 的值传递参数不会随状态刷新，必须走 this */
  private envValue(key: MetricKey): number {
    switch (key) {
      case 'temperature': return this.env.temperature;
      case 'illuminance': return this.env.illuminance;
      case 'humidity': return this.env.humidity;
      case 'hour': return this.env.hour;
      default: return 0;
    }
  }

  @Builder
  MetricSlider(label: string, key: MetricKey, min: number, max: number, step: number, unit: string) {
    Column() {
      Row() {
        Text(label).fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
        Text(this.envValue(key).toString() + unit).fontSize(FontToken.body).fontColor(ColorToken.accent)
      }.width('100%')
      Slider({ value: this.envValue(key), min: min, max: max, step: step, style: SliderStyle.OutSet })
        .width('100%')
        .trackColor(ColorToken.borderStrong)
        .selectedColor(ColorToken.accent)
        .onChange((v: number, mode: SliderChangeMode) => {
          const nv = Math.round(v);
          if (nv === this.envValue(key)) {
            return; // 初始化回填与状态恢复时的回调，值未变化，不触发保存
          }
          this.setEnvValue(key, nv);
          if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
            this.persistAll();
          }
        })
    }.width('100%')
  }

  private deviceImage(id: string): Resource {
    if (id === 'main_light') {
      return $r('app.media.dev_light');
    }
    if (id === 'ac') {
      return $r('app.media.dev_ac');
    }
    if (id === 'curtain') {
      return $r('app.media.dev_curtain');
    }
    if (id === 'fan') {
      return $r('app.media.dev_fan');
    }
    return $r('app.media.dev_humidifier');
  }

  private resolveNavColor(index: number): string {
    if (this.currentTab === index) {
      return ColorToken.brand;
    }
    return ColorToken.textTertiary;
  }

  @Builder
  TabCell(label: string, iconOn: Resource, iconOff: Resource, index: number) {
    Column() {
      Image(this.currentTab === index ? iconOn : iconOff)
        .width(24).height(24)
        .objectFit(ImageFit.Contain)
      Text(label)
        .fontSize(FontToken.caption)
        .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.resolveNavColor(index))
        .margin({ top: 3 })
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  DeviceCard(d: DeviceState) {
    Column() {
      Row() {
        Column() {
          Image(this.deviceImage(d.id))
            .width(28).height(28)
            .objectFit(ImageFit.Contain)
            .opacity(d.power ? 1 : 0.45)
        }
        .width(SizeToken.iconBox).height(SizeToken.iconBox)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(d.power ? ColorToken.accentSubtle : ColorToken.surfaceAlt)
        .borderRadius(RadiusToken.pill)
        Blank()
        Text(d.power ? '开' : '关')
          .fontSize(FontToken.caption)
          .fontColor(d.power ? ColorToken.textInverse : ColorToken.textTertiary)
          .backgroundColor(d.power ? ColorToken.success : ColorToken.surfaceAlt)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(RadiusToken.pill)
      }.width('100%').alignItems(VerticalAlign.Center)
      Text(d.name)
        .fontSize(FontToken.title).fontColor(ColorToken.textPrimary).margin({ top: SpaceToken.md })
      Text(d.power ? d.value.toString() + d.unit : '已关闭')
        .fontSize(FontToken.caption)
        .fontColor(d.power ? ColorToken.success : ColorToken.textTertiary)
        .margin({ top: 2 })
      if (d.power) {
        Progress({ value: d.value, total: 100, type: ProgressType.Linear })
          .color(ColorToken.brand)
          .backgroundColor(ColorToken.surfaceAlt)
          .width('100%').height(3).margin({ top: SpaceToken.sm })
      }
    }
    .width('100%').padding(SpaceToken.lg)
    .backgroundColor(ColorToken.surface)
    .borderRadius(RadiusToken.lg)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      // 倒计时展示由 timerDeviceId 判定，切换设备时无需清状态：回到原设备仍能看到剩余定时
      this.detailId = d.id;
      this.showDetail = true;
    })
  }

  /** 分组小标题：米家式 11px 灰字，贴在卡片上方（而非卡内加粗标题） */
  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(FontToken.caption)
      .fontColor(ColorToken.textSecondary)
      .width('100%')
      .padding({ left: SpaceToken.xs })
      .margin({ top: SpaceToken.sm })
  }

  /** 环境摘要卡：三个大数字横排，米家「室内环境」的写法 */
  @Builder
  EnvSummaryCard() {
    Row() {
      Column() {
        Row() {
          Text(this.env.temperature.toString())
            .fontSize(FontToken.metric).fontWeight(FontWeight.Medium).fontColor(ColorToken.textPrimary)
          Text('℃').fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ left: 2, bottom: 3 })
        }.alignItems(VerticalAlign.Bottom)
        Text('温度').fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      Column() {
        Row() {
          Text(this.env.humidity.toString())
            .fontSize(FontToken.metric).fontWeight(FontWeight.Medium).fontColor(ColorToken.textPrimary)
          Text('%').fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ left: 2, bottom: 3 })
        }.alignItems(VerticalAlign.Bottom)
        Text('湿度').fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      Column() {
        Row() {
          Text(this.env.illuminance.toString())
            .fontSize(FontToken.metric).fontWeight(FontWeight.Medium).fontColor(ColorToken.textPrimary)
          Text('lux').fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ left: 2, bottom: 3 })
        }.alignItems(VerticalAlign.Bottom)
        Text('光照').fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ top: 2 })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(SpaceToken.lg)
    .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
    .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
  }

  @Builder
  DashboardPanel() {
    Scroll() {
      Column({ space: SpaceToken.md }) {
        this.SectionTitle('宿舍环境')
        this.EnvSummaryCard()

        this.SectionTitle('快捷场景')
        Scroll() {
          Row({ space: SpaceToken.md }) {
            ForEach(SCENE_PRESETS, (s: ScenePreset) => {
              this.SceneShortcut(s)
            }, (s: ScenePreset) => s.id)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        this.SectionTitle('设备')
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.devices, (d: DeviceState) => {
            Column() {
              this.DeviceCard(d)
            }.width('48%').margin({ bottom: SpaceToken.md })
          }, (d: DeviceState) => d.id + '|' + (d.power ? '1' : '0') + '|' + d.value.toString())
        }.width('100%')

        this.SectionTitle('模拟环境')
        Column({ space: SpaceToken.md }) {
          this.MetricSlider('温度', 'temperature', -10, 50, 1, '℃')
          this.MetricSlider('光照', 'illuminance', 0, 2000, 20, ' lux')
          this.MetricSlider('湿度', 'humidity', 0, 100, 1, '%')
          this.MetricSlider('时段', 'hour', 0, 23, 1, ' 点')
          Row() {
            Text('宿舍在室状态').fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
            Text(this.env.occupancy ? '有人' : '无人').fontSize(FontToken.body).fontColor(ColorToken.accent)
            Toggle({ type: ToggleType.Switch, isOn: this.env.occupancy })
              .selectedColor(ColorToken.brand)
              .onChange((on: boolean) => { this.setOccupancy(on); })
          }.width('100%')
          Row({ space: SpaceToken.md }) {
            Button('执行联动演练')
              .fontSize(FontToken.heading).layoutWeight(1).backgroundColor(ColorToken.brand)
              .onClick(() => { this.runOnce(); })
            Button('重置环境')
              .fontSize(FontToken.body).backgroundColor(ColorToken.surfaceAlt).fontColor(ColorToken.textPrimary)
              .onClick(() => {
                this.env = normalizeEnvironment(DEFAULT_ENVIRONMENT);
                this.activeScene = '';
                this.showToast('环境已重置');
                this.persistAll();
              })
          }.width('100%').margin({ top: SpaceToken.md })
        }.width('100%').padding(SpaceToken.lg).backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg).border({ width: SizeToken.borderWidth, color: ColorToken.border }).shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })

        this.SectionTitle('本次演练')
        Column() {
          Row() {
            Column() {
              Text(this.triggered.length.toString())
                .fontSize(FontToken.metricLg).fontWeight(FontWeight.Medium).fontColor(ColorToken.textPrimary)
              Text('触发规则').fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ top: 2 })
            }.layoutWeight(1).alignItems(HorizontalAlign.Center)
            Column() {
              Text(this.executedCount.toString())
                .fontSize(FontToken.metricLg).fontWeight(FontWeight.Medium).fontColor(ColorToken.textPrimary)
              Text('执行动作').fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ top: 2 })
            }.layoutWeight(1).alignItems(HorizontalAlign.Center)
            Column() {
              Text(this.blockedCount.toString())
                .fontSize(FontToken.metricLg).fontWeight(FontWeight.Medium)
                .fontColor(this.blockedCount > 0 ? ColorToken.warning : ColorToken.textTertiary)
              Text('冲突拦截').fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ top: 2 })
            }.layoutWeight(1).alignItems(HorizontalAlign.Center)
          }.width('100%').margin({ top: SpaceToken.md })
          Text('触发顺序：' + (this.triggered.length > 0 ? this.triggered.join(' → ') : '暂无'))
            .fontSize(FontToken.label).fontColor(ColorToken.accent).margin({ top: SpaceToken.sm })
        }
        .width('100%').padding(SpaceToken.lg).backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg).border({ width: SizeToken.borderWidth, color: ColorToken.border }).shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
        .alignItems(HorizontalAlign.Start)
      }.padding(SpaceToken.lg).margin({ bottom: 80 })
    }.layoutWeight(1)
  }

  /**
   * 规则行（米家列表行式）：左侧名称 + 条件/动作摘要 + 元信息，右侧开关。
   * 整行可点进入详情页，编辑/复制/删除都收在详情里，列表保持干净。
   */
  @Builder
  RuleRow(r: AutomationRule) {
    Row() {
      Column() {
        Text(r.name)
          .fontSize(FontToken.heading).fontWeight(FontWeight.Medium)
          .fontColor(r.enabled ? ColorToken.textPrimary : ColorToken.textTertiary)
        Text('当 ' + this.conditionText(r) + ' → ' + this.actionText(r))
          .fontSize(FontToken.caption).fontColor(ColorToken.textSecondary)
          .margin({ top: 4 })
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(r.id + ' · 优先级 ' + r.priority + ' · ' + r.conditions.length + ' 个条件')
          .fontSize(FontToken.caption).fontColor(ColorToken.textTertiary).margin({ top: 3 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: r.enabled })
        .selectedColor(ColorToken.brand)
        .onChange((on: boolean) => { this.toggleRule(r.id, on); })
        .margin({ left: SpaceToken.md })
      Text('›')
        .fontSize(FontToken.heading).fontColor(ColorToken.textTertiary)
        .margin({ left: SpaceToken.sm })
    }
    .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
    .alignItems(VerticalAlign.Top)
    .onClick(() => {
      this.detailRuleId = r.id;
      this.showRuleDetail = true;
    })
  }

  @Builder
  RulePanel() {
    Scroll() {
      Column({ space: SpaceToken.md }) {
        Row() {
          Text('联动规则').fontSize(FontToken.heading).fontWeight(FontWeight.Medium)
            .fontColor(ColorToken.textPrimary).layoutWeight(1)
          Text('＋ 新增').fontSize(FontToken.body).fontColor(ColorToken.brand)
            .onClick(() => { this.openNewEditor(); })
        }.width('100%').margin({ top: SpaceToken.sm })
        Text('共 ' + this.rules.length + ' 条 · 按优先级从小到大执行，冲突时高优先级胜出')
          .fontSize(FontToken.caption).fontColor(ColorToken.textSecondary)
        if (this.rules.length === 0) {
          Column() {
            Text('暂无规则').fontSize(FontToken.body).fontColor(ColorToken.textTertiary)
            Text('点击右上角「＋ 新增」创建第一条联动规则').fontSize(FontToken.caption).fontColor(ColorToken.textTertiary).margin({ top: 4 })
          }
          .width('100%').padding(SpaceToken.xl)
          .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
        } else {
          Column() {
            ForEach(this.rules, (r: AutomationRule, idx: number) => {
              if (idx > 0) {
                Divider().color(ColorToken.border).strokeWidth(1)
              }
              this.RuleRow(r)
            }, (r: AutomationRule) => r.id + '|' + (r.enabled ? '1' : '0') + '|' + r.priority.toString())
          }
          .width('100%')
          .padding({ left: SpaceToken.lg, right: SpaceToken.lg })
          .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
          .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
        }
      }.padding(SpaceToken.lg).margin({ bottom: 80 })
    }.layoutWeight(1)
  }

  /** 演练场景行：整行可点，右侧「载入」文字按钮，风格同规则/日志列表 */
  @Builder
  SceneRow(s: ScenePreset) {
    Row() {
      Column() {
        Text(s.name)
          .fontSize(FontToken.heading).fontWeight(FontWeight.Medium).fontColor(ColorToken.textPrimary)
        Text(s.env.temperature + '℃ · ' + s.env.illuminance + 'lux · ' + s.env.humidity + '% · ' +
             s.env.hour + ' 点 · ' + (s.env.occupancy ? '有人' : '无人'))
          .fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ top: 4 })
        Text(s.note)
          .fontSize(FontToken.caption).fontColor(ColorToken.textTertiary).margin({ top: 3 })
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('载入')
        .fontSize(FontToken.body).fontColor(ColorToken.brand)
        .margin({ left: SpaceToken.md })
        .onClick(() => { this.applyScene(s); })
    }
    .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  ScenePanel() {
    Scroll() {
      Column({ space: SpaceToken.md }) {
        Row() {
          Text('演练场景').fontSize(FontToken.heading).fontWeight(FontWeight.Medium)
            .fontColor(ColorToken.textPrimary).layoutWeight(1)
          Text(this.activeScene.length > 0 ? '当前 ' + this.activeScene : '未载入')
            .fontSize(FontToken.caption).fontColor(ColorToken.textSecondary)
        }.width('100%').margin({ top: SpaceToken.sm })
        Text('点击「载入」即套用该组环境并执行一次联动演练')
          .fontSize(FontToken.caption).fontColor(ColorToken.textSecondary)

        Column() {
          ForEach(SCENE_PRESETS, (s: ScenePreset, idx: number) => {
            if (idx > 0) {
              Divider().color(ColorToken.border).strokeWidth(1)
            }
            this.SceneRow(s)
          }, (s: ScenePreset) => s.id)
        }
        .width('100%').padding({ left: SpaceToken.lg, right: SpaceToken.lg })
        .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
        .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })

        if (this.conflicts.length > 0) {
          Column() {
            Text('检测到 ' + this.conflicts.length + ' 处控制冲突')
              .fontSize(FontToken.heading).fontColor(ColorToken.warning)
            ForEach(this.conflicts, (c: ConflictRecord, idx: number) => {
              Text(this.deviceName(c.deviceId) + '：' + c.winnerRuleId + ' 胜出，' +
                   c.loserRuleId + ' 被拦截')
                .fontSize(FontToken.label).fontColor(ColorToken.warning).margin({ top: 6 })
            }, (c: ConflictRecord, idx: number) => idx.toString() + c.loserRuleId)
            Text('修复原理：R002 原本只看温度，高温且无人时会与 R005「无人节能」争夺空调。补充在室条件后，无人场景 R002 不再命中，冲突消失。')
              .fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ top: 8 })
          }
          .width('100%').padding(SpaceToken.lg).backgroundColor(ColorToken.warningBg).borderRadius(RadiusToken.lg)
          .alignItems(HorizontalAlign.Start)

          this.SectionTitle('工具')
          Column() {
            Row() {
              Text('一键修复：为高温制冷补充「有人在室」条件')
                .fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
              Text('›').fontSize(FontToken.caption).fontColor(ColorToken.textTertiary)
            }
            .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
            .onClick(() => { this.fixConflict(); })
          }
          .width('100%').padding({ left: SpaceToken.lg, right: SpaceToken.lg })
          .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
          .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
        } else {
          Column() {
            Text('当前无控制冲突').fontSize(FontToken.body).fontColor(ColorToken.success)
            Text('载入「午后无人·冲突」场景可观察优先级裁决过程。')
              .fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ top: 4 })
          }
          .width('100%').padding(SpaceToken.lg).backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
          .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
          .alignItems(HorizontalAlign.Start)
        }
      }.padding(SpaceToken.lg).margin({ bottom: 80 })
    }.layoutWeight(1)
  }

  /** 执行记录行（米家列表行式）：外层由 LogPanel 统一包卡 + 分隔线 */
  @Builder
  RecordRow(r: ExecutionRecord) {
    Column() {
      Row() {
        Text('#' + r.order).fontSize(FontToken.label).fontColor(ColorToken.textTertiary)
        Text(r.ruleName)
          .fontSize(FontToken.body).fontWeight(FontWeight.Medium).fontColor(ColorToken.textPrimary)
          .layoutWeight(1).margin({ left: SpaceToken.sm })
        Text(r.blocked ? '已拦截' : '已执行')
          .fontSize(FontToken.caption).fontColor(r.blocked ? ColorToken.warning : ColorToken.success)
      }.width('100%')
      Text(r.ruleId + ' · 优先级 ' + r.priority + ' · ' + this.conditionList(r.conditions))
        .fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ top: 5 })
      Text(r.change.deviceName + '：' + (r.change.beforePower ? '开 ' : '关 ') +
           r.change.beforeValue + ' → ' + (r.change.afterPower ? '开 ' : '关 ') +
           r.change.afterValue + (r.blocked ? '（保持原状）' : ''))
        .fontSize(FontToken.caption).fontColor(r.blocked ? ColorToken.warning : ColorToken.textSecondary)
        .margin({ top: 3 })
    }
    .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
    .alignItems(HorizontalAlign.Start)
  }

  /** 日志筛选药丸：全部 / 只看拦截（T3） */
  @Builder
  LogFilterPill(label: string, onlyBlocked: boolean) {
    Text(label)
      .fontSize(FontToken.label)
      .fontColor(this.logOnlyBlocked === onlyBlocked ? ColorToken.textInverse : ColorToken.textSecondary)
      .backgroundColor(this.logOnlyBlocked === onlyBlocked ? ColorToken.brand : ColorToken.surfaceAlt)
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .borderRadius(RadiusToken.pill)
      .onClick(() => { this.logOnlyBlocked = onlyBlocked; })
  }

  @Builder
  LogPanel() {
    Scroll() {
      Column({ space: SpaceToken.md }) {
        // 存档状态：米家式「一行标签 + 右侧值」，说明文字降为副标题
        Column() {
          Row() {
            Text('本地存档').fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
            Text(this.savedAt > 0 ? this.formatTime(this.savedAt) : '未保存')
              .fontSize(FontToken.body).fontColor(ColorToken.textSecondary)
          }.width('100%')
          Text(this.restoreMessage)
            .fontSize(FontToken.caption)
            .fontColor(this.restored ? ColorToken.success : ColorToken.warning)
            .margin({ top: 4 })
          Text('Preferences / dormlink_state · 结束进程后重开自动恢复')
            .fontSize(FontToken.caption).fontColor(ColorToken.textTertiary).margin({ top: 2 })
        }
        .width('100%').padding(SpaceToken.lg)
        .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
        .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
        .alignItems(HorizontalAlign.Start)

        this.SectionTitle('执行记录')
        Row({ space: SpaceToken.sm }) {
          this.LogFilterPill('全部 ' + this.records.length, false)
          this.LogFilterPill('只看拦截 ' + this.blockedRecords(), true)
        }.width('100%')

        if (this.visibleRecords().length === 0) {
          Text(this.logOnlyBlocked ? '当前没有拦截记录' : '尚未执行演练，请到「联动台」或「演练」页运行一次')
            .fontSize(FontToken.body).fontColor(ColorToken.textTertiary)
            .width('100%').padding(SpaceToken.xl)
            .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
        } else {
          Column() {
            ForEach(this.visibleRecords(), (r: ExecutionRecord, idx: number) => {
              if (idx > 0) {
                Divider().color(ColorToken.border).strokeWidth(1)
              }
              this.RecordRow(r)
            }, (r: ExecutionRecord) => r.order.toString() + r.ruleId + '|' + r.change.afterValue.toString())
          }
          .width('100%')
          .padding({ left: SpaceToken.lg, right: SpaceToken.lg })
          .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
          .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
        }

        if (this.warnings.length > 0) {
          Column() {
            Text('引擎告警（' + this.warnings.length + ' 条）')
              .fontSize(FontToken.body).fontColor(ColorToken.warning)
            ForEach(this.warnings, (w: string, idx: number) => {
              Text('· ' + w).fontSize(FontToken.caption).fontColor(ColorToken.warning).margin({ top: 4 })
            }, (w: string, idx: number) => idx.toString() + w)
          }
          .width('100%').padding(SpaceToken.md).backgroundColor(ColorToken.warningBg).borderRadius(RadiusToken.lg)
          .alignItems(HorizontalAlign.Start)
        }

        this.SectionTitle('工具')
        Column() {
          Row() {
            Text('生成测试报告').fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
            Text('12 条断言 ›').fontSize(FontToken.caption).fontColor(ColorToken.textSecondary)
          }
          .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
          .onClick(() => { this.generateReport(); })
          Divider().color(ColorToken.border).strokeWidth(1)
          Row() {
            Text('清空执行记录').fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
            Text('›').fontSize(FontToken.caption).fontColor(ColorToken.textTertiary)
          }
          .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
          .onClick(() => { this.clearRecords(); })
          Divider().color(ColorToken.border).strokeWidth(1)
          Row() {
            Text('恢复出厂方案').fontSize(FontToken.body).fontColor(ColorToken.danger).layoutWeight(1)
            Text('›').fontSize(FontToken.caption).fontColor(ColorToken.textTertiary)
          }
          .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
          .onClick(() => { this.resetAll(); })
        }
        .width('100%').padding({ left: SpaceToken.lg, right: SpaceToken.lg })
        .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
        .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
        .alignItems(HorizontalAlign.Start)
      }.padding(SpaceToken.lg).margin({ bottom: 80 })
    }.layoutWeight(1)
  }

  /** 规则详情覆盖层：米家「列表 → 详情 → 操作」的三段式，列表行不再塞操作按钮 */
  @Builder
  RuleDetailPanel() {
    Column() {
      Row() {
        Text('‹ 返回')
          .fontSize(FontToken.body).fontColor(ColorToken.textSecondary)
          .onClick(() => { this.showRuleDetail = false; })
        Blank()
        Text('规则详情')
          .fontSize(FontToken.title).fontWeight(FontWeight.Medium).fontColor(ColorToken.textPrimary)
        Blank()
        Text('   ').fontSize(FontToken.body)
      }
      .width('100%').padding({ top: SpaceToken.sm, bottom: SpaceToken.md })

      Scroll() {
        Column({ space: SpaceToken.md }) {
          // 概览卡
          Column() {
            Text(this.findRuleById(this.detailRuleId).name)
              .fontSize(FontToken.display).fontWeight(FontWeight.Medium).fontColor(ColorToken.textPrimary)
            Text(this.findRuleById(this.detailRuleId).id + ' · 优先级 ' +
                 this.findRuleById(this.detailRuleId).priority + ' · ' +
                 (this.findRuleById(this.detailRuleId).enabled ? '已启用' : '已停用'))
              .fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ top: 6 })
            Row() {
              Text(this.findRuleById(this.detailRuleId).enabled ? '启用联动' : '已停用')
                .fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.findRuleById(this.detailRuleId).enabled })
                .selectedColor(ColorToken.brand)
                .onChange((on: boolean) => { this.toggleRule(this.detailRuleId, on); })
            }.width('100%').margin({ top: SpaceToken.lg })
          }
          .width('100%').padding(SpaceToken.lg).backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
          .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
          .alignItems(HorizontalAlign.Start)

          this.SectionTitle('触发条件（全部满足才触发）')
          Column() {
            ForEach(this.findRuleById(this.detailRuleId).conditions, (c: Condition, idx: number) => {
              if (idx > 0) {
                Divider().color(ColorToken.border).strokeWidth(1)
              }
              Row() {
                Text('条件 ' + (idx + 1).toString())
                  .fontSize(FontToken.caption).fontColor(ColorToken.textTertiary).width(56)
                Text(describeCondition(c))
                  .fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
              }
              .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
            }, (c: Condition, idx: number) => idx.toString() + c.metric + c.op + c.value.toString())
          }
          .width('100%').padding({ left: SpaceToken.lg, right: SpaceToken.lg })
          .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
          .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })

          this.SectionTitle('执行动作')
          Column() {
            ForEach(this.findRuleById(this.detailRuleId).actions, (a: DeviceAction, idx: number) => {
              if (idx > 0) {
                Divider().color(ColorToken.border).strokeWidth(1)
              }
              Row() {
                Text(this.deviceName(a.deviceId))
                  .fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
                Text(a.power ? '开启 · ' + a.value.toString() : '关闭')
                  .fontSize(FontToken.body).fontColor(ColorToken.textSecondary)
              }
              .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
            }, (a: DeviceAction, idx: number) => idx.toString() + a.deviceId + a.value.toString())
          }
          .width('100%').padding({ left: SpaceToken.lg, right: SpaceToken.lg })
          .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
          .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })

          if (this.findRuleById(this.detailRuleId).description.length > 0) {
            Text(this.findRuleById(this.detailRuleId).description)
              .fontSize(FontToken.caption).fontColor(ColorToken.textTertiary)
              .width('100%').padding({ left: SpaceToken.xs })
          }

          this.SectionTitle('操作')
          Column() {
            Row() {
              Text('编辑规则').fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
              Text('›').fontSize(FontToken.caption).fontColor(ColorToken.textTertiary)
            }
            .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
            .onClick(() => {
              this.showRuleDetail = false;
              this.openEditor(this.findRuleById(this.detailRuleId));
            })
            Divider().color(ColorToken.border).strokeWidth(1)
            Row() {
              Text('复制为停用副本').fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
              Text('›').fontSize(FontToken.caption).fontColor(ColorToken.textTertiary)
            }
            .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
            .onClick(() => {
              this.duplicateRule(this.detailRuleId);
              this.showRuleDetail = false;
            })
            Divider().color(ColorToken.border).strokeWidth(1)
            Row() {
              Text('删除规则').fontSize(FontToken.body).fontColor(ColorToken.danger).layoutWeight(1)
              Text('›').fontSize(FontToken.caption).fontColor(ColorToken.textTertiary)
            }
            .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
            .onClick(() => {
              this.deleteRule(this.detailRuleId);
              this.showRuleDetail = false;
            })
          }
          .width('100%').padding({ left: SpaceToken.lg, right: SpaceToken.lg })
          .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
          .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
          .alignItems(HorizontalAlign.Start)
        }
        .padding({ bottom: 40 })
        .width('100%')
        .justifyContent(FlexAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%').height('100%')
    .padding({ left: SpaceToken.lg, right: SpaceToken.lg })
    .backgroundColor(ColorToken.canvas)
  }

  @Builder
  RuleEditorPanel() {
    Column() {
      Scroll() {
        Column({ space: SpaceToken.md }) {
          Text(this.editorIsNew ? '新增联动规则' : '编辑规则 ' + this.draft.id)
            .fontSize(FontToken.title).fontColor(ColorToken.textPrimary)
          Text('规则名称').fontSize(FontToken.label).fontColor(ColorToken.textSecondary)
          TextInput({ text: this.draft.name, placeholder: '请输入规则名称' })
            .width('100%').backgroundColor(ColorToken.surface).fontColor(ColorToken.textPrimary)
            .onChange((v: string) => { this.setDraftName(v); })
          Row() {
            Text('优先级（数值越小越优先）').fontSize(FontToken.label).fontColor(ColorToken.textSecondary).layoutWeight(1)
            TextInput({ text: this.draft.priority.toString() })
              .type(InputType.Number).width(80).backgroundColor(ColorToken.surface).fontColor(ColorToken.textPrimary)
              .onChange((v: string) => { this.setDraftPriority(v); })
          }.width('100%')

          Text('触发条件（全部满足才触发）').fontSize(FontToken.body).fontColor(ColorToken.accent)
          ForEach(this.draft.conditions, (c: Condition, idx: number) => {
            Column() {
              Row({ space: 6 }) {
                Select(METRIC_SELECT)
                  .selected(this.indexIn(METRIC_TEXTS, metricLabel(c.metric)))
                  .value(metricLabel(c.metric))
                  .font({ size: 12 }).backgroundColor(ColorToken.surface)
                  .onSelect((i: number) => { this.setConditionMetric(idx, i); })
                Select(OP_SELECT)
                  .selected(this.indexIn(OP_TEXTS, opLabel(c.op)))
                  .value(opLabel(c.op))
                  .font({ size: 12 }).backgroundColor(ColorToken.surface)
                  .onSelect((i: number) => { this.setConditionOp(idx, i); })
                TextInput({ text: c.value.toString() })
                  .type(InputType.Number).width(70).backgroundColor(ColorToken.surface).fontColor(ColorToken.textPrimary)
                  .onChange((v: string) => { this.setConditionValue(idx, v); })
                Button('×').fontSize(FontToken.body).backgroundColor(ColorToken.dangerBg).fontColor(ColorToken.danger)
                  .onClick(() => { this.removeCondition(idx); })
              }.width('100%')
              Text(describeCondition(c)).fontSize(FontToken.caption).fontColor(ColorToken.textTertiary).margin({ top: 4 })
            }
            .width('100%').padding(SpaceToken.md).backgroundColor(ColorToken.surfaceAlt).borderRadius(RadiusToken.md)
            .alignItems(HorizontalAlign.Start)
          }, (c: Condition, idx: number) => idx.toString() + c.metric)
          Button('+ 添加条件（最多 3 条）').fontSize(FontToken.label).backgroundColor(ColorToken.surfaceAlt).fontColor(ColorToken.textPrimary)
            .onClick(() => { this.addCondition(); })

          Text('执行动作').fontSize(FontToken.body).fontColor(ColorToken.accent)
          ForEach(this.draft.actions, (a: DeviceAction, idx: number) => {
            Row({ space: 6 }) {
              Select(DEVICE_SELECT)
                .selected(this.indexIn(DEVICE_TEXTS, this.deviceName(a.deviceId)))
                .value(this.deviceName(a.deviceId))
                .font({ size: 12 }).backgroundColor(ColorToken.surface)
                .onSelect((i: number) => { this.setActionDevice(idx, i); })
              Text('开关').fontSize(FontToken.caption).fontColor(ColorToken.textSecondary)
              Toggle({ type: ToggleType.Switch, isOn: a.power })
                .selectedColor(ColorToken.brand)
                .onChange((on: boolean) => { this.setActionPower(idx, on); })
              TextInput({ text: a.value.toString() })
                .type(InputType.Number).width(64).backgroundColor(ColorToken.surface).fontColor(ColorToken.textPrimary)
                .onChange((v: string) => { this.setActionValue(idx, v); })
              Button('×').fontSize(FontToken.body).backgroundColor(ColorToken.dangerBg).fontColor(ColorToken.danger)
                .onClick(() => { this.removeAction(idx); })
            }.width('100%').padding(SpaceToken.md).backgroundColor(ColorToken.surfaceAlt).borderRadius(RadiusToken.md)
          }, (a: DeviceAction, idx: number) => idx.toString() + a.deviceId)
          Button('+ 添加动作（最多 3 个）').fontSize(FontToken.label).backgroundColor(ColorToken.surfaceAlt).fontColor(ColorToken.textPrimary)
            .onClick(() => { this.addAction(); })

          Row({ space: SpaceToken.md }) {
            Button('保存并重新演练').fontSize(FontToken.heading).backgroundColor(ColorToken.brand).layoutWeight(1)
              .onClick(() => { this.saveDraft(); })
            Button('取消').fontSize(FontToken.heading).backgroundColor(ColorToken.surfaceAlt).fontColor(ColorToken.textPrimary).layoutWeight(1)
              .onClick(() => { this.showEditor = false; })
          }.width('100%').margin({ top: 6 })
        }.padding(SpaceToken.lg)
      }.layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor(ColorToken.canvas)
  }

  private findDevice(id: string): DeviceState {
    for (const d of this.devices) {
      if (d.id === id) {
        return d;
      }
    }
    return { id: 'main_light', name: '主灯', power: false, value: 0, unit: '%' };
  }

  private deviceMin(id: string): number {
    if (id === 'ac') {
      return 16;
    }
    if (id === 'fan' || id === 'humidifier') {
      return 0;
    }
    return 0;
  }

  private deviceMax(id: string): number {
    if (id === 'ac') {
      return 30;
    }
    if (id === 'fan' || id === 'humidifier') {
      return 3;
    }
    return 100;
  }

  private setDevicePower(id: string, on: boolean): void {
    const list: DeviceState[] = [];
    for (const d of this.devices) {
      if (d.id === id) {
        list.push({ id: d.id, name: d.name, power: on, value: d.value, unit: d.unit });
      } else {
        list.push(d);
      }
    }
    this.devices = list;
    this.persistAll();
  }

  private setDeviceValue(id: string, value: number): void {
    const list: DeviceState[] = [];
    for (const d of this.devices) {
      if (d.id === id) {
        list.push({ id: d.id, name: d.name, power: d.power, value: value, unit: d.unit });
      } else {
        list.push(d);
      }
    }
    this.devices = list;
    this.persistAll();
  }

  /** 设备的出厂设定值（取 DEFAULT_DEVICES 的初始值） */
  private defaultDeviceValue(id: string): number {
    for (const d of DEFAULT_DEVICES) {
      if (d.id === id) {
        return d.value;
      }
    }
    return 0;
  }

  /** 重置单个设备：关闭电源并恢复出厂设定值 */
  private resetDeviceValue(id: string): void {
    const list: DeviceState[] = [];
    for (const d of this.devices) {
      if (d.id === id) {
        list.push({ id: d.id, name: d.name, power: false, value: this.defaultDeviceValue(id), unit: d.unit });
      } else {
        list.push(d);
      }
    }
    this.devices = list;
    this.showToast(this.deviceName(id as DeviceId) + ' 已恢复默认值');
    this.persistAll();
  }

  /** 定时关闭：选择后按分钟数在后台触发，可再次选择取消；同时记录到点时间用于界面倒计时（T1） */
  private setDeviceTimer(minutes: number): void {
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
    this.timerMinutes = minutes;
    if (minutes > 0) {
      const targetId: string = this.detailId;
      this.timerDeviceId = targetId;
      this.timerEndAt = Date.now() + minutes * 60000;
      this.timerId = setTimeout(() => {
        this.setDevicePower(targetId, false);
        this.timerMinutes = 0;
        this.timerEndAt = 0;
        this.timerDeviceId = '';
        this.timerId = -1;
        this.showToast('定时关闭已执行：' + this.deviceName(targetId as DeviceId));
      }, minutes * 60000);
      this.showToast('已设定 ' + minutes + ' 分钟后关闭');
    } else {
      this.timerEndAt = 0;
      this.timerDeviceId = '';
      this.showToast('已取消定时');
    }
  }

  /**
   * 当前设备是否有生效中的定时（T1）。
   * 注意：必须先把 timerEndAt 读出来再做短路判断——若写成 `a && this.timerEndAt > 0`，
   * 首次渲染时 a 为 false 会短路，timerEndAt 不会被读取，ArkUI 建立不了状态依赖，
   * 导致设定定时后界面不刷新（本项目已知坑：@Builder/方法内状态依赖丢失）。
   */
  private timerActive(): boolean {
    const endAt: number = this.timerEndAt;
    const owner: string = this.timerDeviceId;
    return owner === this.detailId && endAt > 0;
  }

  /** 定时状态文案：有定时显示到点时刻，否则提示未设定（T1） */
  private timerHint(): string {
    const endAt: number = this.timerEndAt;
    if (this.timerDeviceId !== this.detailId || endAt <= 0) {
      return '未设定定时';
    }
    return '将于 ' + this.formatTime(endAt) + ' 自动关闭';
  }

  private timerPillStyle(m: number): string {
    if (this.timerActive() && this.timerMinutes === m) {
      return ColorToken.brand;
    }
    return ColorToken.surfaceAlt;
  }

  private timerPillColor(m: number): string {
    if (this.timerActive() && this.timerMinutes === m) {
      return ColorToken.textInverse;
    }
    return ColorToken.textSecondary;
  }

  /** 定时档位药丸：三档共用一套样式，避免三处重复（T1） */
  @Builder
  TimerPill(minutes: number, label: string) {
    Text(label)
      .fontSize(FontToken.label)
      .fontColor(this.timerPillColor(minutes))
      .backgroundColor(this.timerPillStyle(minutes))
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .borderRadius(RadiusToken.pill)
      .onClick(() => { this.setDeviceTimer(minutes); })
  }

  @Builder
  DeviceDetailPanel() {
    Column() {
      Row() {
        Text('‹ 返回')
          .fontSize(FontToken.body).fontColor(ColorToken.textSecondary)
          .onClick(() => { this.showDetail = false; })
        Blank()
        Text(this.findDevice(this.detailId).name)
          .fontSize(FontToken.title).fontWeight(FontWeight.Medium).fontColor(ColorToken.textPrimary)
        Blank()
        Text('   ')
          .fontSize(FontToken.body)
      }
      .width('100%').padding({ top: SpaceToken.sm, bottom: SpaceToken.md })

      Scroll() {
        Column({ space: SpaceToken.md }) {
          // 概览：图标 + 名称/状态 + 电源开关（米家把开关放在设备头部）
          Row() {
            Column() {
              Image(this.deviceImage(this.detailId))
                .width(52).height(52)
                .objectFit(ImageFit.Contain)
                .opacity(this.findDevice(this.detailId).power ? 1 : 0.45)
            }
            .width(80).height(80)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.findDevice(this.detailId).power ? ColorToken.accentSubtle : ColorToken.surfaceAlt)
            .borderRadius(RadiusToken.pill)

            Column() {
              Text(this.findDevice(this.detailId).name)
                .fontSize(FontToken.display).fontWeight(FontWeight.Medium).fontColor(ColorToken.textPrimary)
              Text(this.findDevice(this.detailId).power
                ? '已开启 · ' + this.findDevice(this.detailId).value.toString() + this.findDevice(this.detailId).unit
                : '已关闭')
                .fontSize(FontToken.caption)
                .fontColor(this.findDevice(this.detailId).power ? ColorToken.success : ColorToken.textTertiary)
                .margin({ top: 4 })
            }
            .layoutWeight(1).alignItems(HorizontalAlign.Start).margin({ left: SpaceToken.lg })

            Toggle({ type: ToggleType.Switch, isOn: this.findDevice(this.detailId).power })
              .selectedColor(ColorToken.brand)
              .onChange((on: boolean) => {
                if (on !== this.findDevice(this.detailId).power) {
                  this.setDevicePower(this.detailId, on);
                }
              })
          }
          .width('100%').padding(SpaceToken.lg)
          .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
          .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
          .alignItems(VerticalAlign.Center)

          this.SectionTitle('参数')
          Column() {
            Row() {
              Text(this.detailId === 'ac' ? '目标温度' : (this.detailId === 'curtain' ? '开合度' :
                   (this.detailId === 'main_light' ? '亮度' : '档位')))
                .fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
              Text(this.findDevice(this.detailId).value.toString() + this.findDevice(this.detailId).unit)
                .fontSize(FontToken.body).fontColor(ColorToken.brand)
            }.width('100%')
            Slider({
              value: this.findDevice(this.detailId).value,
              min: this.deviceMin(this.detailId),
              max: this.deviceMax(this.detailId),
              step: 1,
              style: SliderStyle.OutSet
            })
              .selectedColor(ColorToken.brand)
              .trackColor(ColorToken.surfaceAlt)
              .width('100%').margin({ top: SpaceToken.sm })
              .onChange((v: number, mode: SliderChangeMode) => {
                const nv = Math.round(v);
                if (nv !== this.findDevice(this.detailId).value) {
                  this.setDeviceValue(this.detailId, nv);
                }
              })
          }
          .width('100%').padding(SpaceToken.lg)
          .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
          .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
          .alignItems(HorizontalAlign.Start)

          this.SectionTitle('定时关闭')
          Column() {
            Row({ space: SpaceToken.sm }) {
              this.TimerPill(0, '不定时')
              this.TimerPill(30, '30 分钟')
              this.TimerPill(60, '1 小时')
            }.width('100%')
            Text(this.timerHint())
              .fontSize(FontToken.caption)
              .fontColor(this.timerActive() ? ColorToken.success : ColorToken.textTertiary)
              .width('100%').margin({ top: SpaceToken.sm })
          }
          .width('100%').padding(SpaceToken.lg)
          .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
          .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
          .alignItems(HorizontalAlign.Start)

          this.SectionTitle('设备信息')
          Column() {
            Row() {
              Text('设备 ID').fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
              Text(this.detailId).fontSize(FontToken.body).fontColor(ColorToken.textSecondary)
            }.width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
            Divider().color(ColorToken.border).strokeWidth(1)
            Row() {
              Text('计量单位').fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
              Text(this.findDevice(this.detailId).unit).fontSize(FontToken.body).fontColor(ColorToken.textSecondary)
            }.width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
            Divider().color(ColorToken.border).strokeWidth(1)
            Row() {
              Text('出厂设定').fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
              Text(this.defaultDeviceValue(this.detailId).toString() + this.findDevice(this.detailId).unit)
                .fontSize(FontToken.body).fontColor(ColorToken.textSecondary)
            }.width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
          }
          .width('100%').padding({ left: SpaceToken.lg, right: SpaceToken.lg })
          .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
          .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
          .alignItems(HorizontalAlign.Start)

          this.SectionTitle('操作')
          Column() {
            Row() {
              Text('重置参数').fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
              Text('恢复出厂 ' + this.defaultDeviceValue(this.detailId).toString() +
                   this.findDevice(this.detailId).unit + '  ›')
                .fontSize(FontToken.caption).fontColor(ColorToken.textTertiary)
            }
            .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
            .onClick(() => { this.resetDeviceValue(this.detailId); })
            Divider().color(ColorToken.border).strokeWidth(1)
            Row() {
              Text('取消定时').fontSize(FontToken.body).fontColor(ColorToken.textPrimary).layoutWeight(1)
              Text(this.timerActive() ? '生效中 ›' : '未设定 ›')
                .fontSize(FontToken.caption).fontColor(ColorToken.textTertiary)
            }
            .width('100%').padding({ top: SpaceToken.md, bottom: SpaceToken.md })
            .onClick(() => {
              if (this.timerActive()) {
                this.setDeviceTimer(0);
              } else {
                this.showToast('当前没有生效中的定时');
              }
            })
          }
          .width('100%').padding({ left: SpaceToken.lg, right: SpaceToken.lg })
          .backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg)
          .shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
          .alignItems(HorizontalAlign.Start)
        }
        .padding({ bottom: 40 })
        .width('100%')
        .justifyContent(FlexAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%').height('100%')
    .padding({ left: SpaceToken.lg, right: SpaceToken.lg })
    .backgroundColor(ColorToken.canvas)
  }

  @Builder
  ReportPanel() {
    Column() {
      Column({ space: SpaceToken.sm }) {
        Text('规则引擎自检报告').fontSize(FontToken.display).fontColor(ColorToken.textPrimary)
        Text('生成时间 ' + this.formatTime(this.reportTime) + ' · 耗时 ' + this.reportDuration + ' ms')
          .fontSize(FontToken.caption).fontColor(ColorToken.textSecondary)
        Row({ space: 18 }) {
          Text('通过 ' + this.reportPassed).fontSize(FontToken.title).fontColor(ColorToken.success)
          Text('失败 ' + (this.reportTotal - this.reportPassed))
            .fontSize(FontToken.title).fontColor(this.reportTotal - this.reportPassed > 0 ? ColorToken.danger : ColorToken.textTertiary)
          Text('共 ' + this.reportTotal + ' 条').fontSize(FontToken.title).fontColor(ColorToken.textPrimary)
        }.width('100%').margin({ top: 4 })
        Text('正常 ' + this.reportNormal + ' 条 · 边界 ' + this.reportBoundary + ' 条 · 异常 ' + this.reportException + ' 条')
          .fontSize(FontToken.label).fontColor(ColorToken.accent)
      }
      .width('100%').padding(SpaceToken.lg).backgroundColor(ColorToken.surface).borderRadius(RadiusToken.lg).border({ width: SizeToken.borderWidth, color: ColorToken.border }).shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
      .alignItems(HorizontalAlign.Start)

      Scroll() {
        Column({ space: SpaceToken.sm }) {
          ForEach(this.reportCases, (c: SelfTestCase) => {
            Row() {
              Text(c.passed ? '✓' : '✗')
                .fontSize(FontToken.heading).fontColor(c.passed ? ColorToken.success : ColorToken.danger).width(22)
              Column() {
                Text(c.category + ' · ' + c.name)
                  .fontSize(FontToken.body).fontColor(ColorToken.textPrimary)
                Text(c.detail).fontSize(FontToken.caption).fontColor(ColorToken.textSecondary).margin({ top: 3 })
              }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            }
            .width('100%').padding(SpaceToken.md).backgroundColor(ColorToken.surface).borderRadius(RadiusToken.md).border({ width: SizeToken.borderWidth, color: ColorToken.border }).shadow({ radius: ShadowToken.cardRadius, color: ShadowToken.cardColor, offsetY: ShadowToken.cardOffsetY })
            .alignItems(VerticalAlign.Top)
          }, (c: SelfTestCase) => c.id + (c.passed ? '1' : '0'))
        }.padding({ left: 16, right: 16, top: 12, bottom: 12 })
      }
      .layoutWeight(1)

      Button('关闭')
        .fontSize(FontToken.heading).backgroundColor(ColorToken.surfaceAlt).fontColor(ColorToken.textPrimary).width('100%').margin({ bottom: 18 })
        .onClick(() => { this.showReport = false; })
    }
    .width('100%').height('100%').backgroundColor(ColorToken.canvas)
    .padding({ top: 16, left: 16, right: 16 })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.HeaderBar()
        Tabs({ barPosition: BarPosition.End }) {
          TabContent() { this.DashboardPanel() }.tabBar(this.TabCell('联动台', $r('app.media.tab_home_on'), $r('app.media.tab_home_off'), 0))
          TabContent() { this.RulePanel() }.tabBar(this.TabCell('规则', $r('app.media.tab_rule_on'), $r('app.media.tab_rule_off'), 1))
          TabContent() { this.ScenePanel() }.tabBar(this.TabCell('演练', $r('app.media.tab_scene_on'), $r('app.media.tab_scene_off'), 2))
          TabContent() { this.LogPanel() }.tabBar(this.TabCell('日志', $r('app.media.tab_log_on'), $r('app.media.tab_log_off'), 3))
        }
        .barHeight(58)
        .layoutWeight(1)
        .backgroundColor(ColorToken.canvas)
        .onChange((index: number) => { this.currentTab = index; })
      }
      .width('100%').height('100%').backgroundColor(ColorToken.canvas)

      if (this.showRuleDetail) {
        this.RuleDetailPanel()
      }
      if (this.showEditor) {
        this.RuleEditorPanel()
      }
      if (this.showReport) {
        this.ReportPanel()
      }
      if (this.showDetail) {
        this.DeviceDetailPanel()
      }
      // toast 放在 Stack 最上层，保证规则编辑器等覆盖层打开时也能看到提示
      if (this.toast.length > 0) {
        Column() {
          Text(this.toast)
            .fontSize(FontToken.body).fontColor(ColorToken.canvas).backgroundColor(ColorToken.success)
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .borderRadius(RadiusToken.md)
        }
        .width('100%').padding({ left: 16, right: 16 })
        .margin({ top: 104 })
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%').height('100%')
  }
}
