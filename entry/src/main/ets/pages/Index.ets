import { common } from '@kit.AbilityKit';
import {
  AutomationRule, Condition, DeviceAction, DeviceState, Environment,
  ExecutionRecord, ConflictRecord, MetricKey, CompareOp, DeviceId,
  evaluate, normalizeEnvironment, cloneDevices, cloneRule, validateRule,
  describeCondition, metricLabel, opLabel
} from '../engine/RuleEngine';
import {
  DEFAULT_ENVIRONMENT, DEFAULT_DEVICES, SCENE_PRESETS, ScenePreset
} from '../engine/DefaultData';
import { DormStore, AppSnapshot, RestoreResult } from '../viewmodel/DormStore';
import { StorageService } from '../repository/StorageService';

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
  @State draft: AutomationRule = makeNewRule();
  @State activeScene: string = '';

  async aboutToAppear(): Promise<void> {
    const result: RestoreResult = await DormStore.restore(this.getCtx());
    this.applySnapshot(result.snapshot);
    this.restoreMessage = result.message;
    this.restored = result.restored;
    this.restoring = false;
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
    setTimeout(() => {
      this.toast = '';
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

  @Builder
  HeaderBar() {
    Column() {
      Row() {
        Column() {
          Text('DormLink 智宿联动实验室')
            .fontSize(19).fontWeight(FontWeight.Bold).fontColor('#E6F1FB')
          Text('智能宿舍自动化规则编排 · 主题三')
            .fontSize(12).fontColor('#9FB3C8').margin({ top: 2 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Column() {
          Text(this.restored ? '已恢复存档' : (this.savedAt > 0 ? '已保存方案' : '当前方案'))
            .fontSize(11).fontColor(this.restored || this.savedAt > 0 ? '#6FD3A8' : '#F5B971')
          Text('存档 ' + this.formatTime(this.savedAt))
            .fontSize(11).fontColor('#9FB3C8').margin({ top: 2 })
        }.alignItems(HorizontalAlign.End)
      }.width('100%')
      Text(this.restoreMessage)
        .fontSize(11).fontColor('#9FB3C8').margin({ top: 8 })
      if (this.toast.length > 0) {
        Text(this.toast)
          .fontSize(12).fontColor('#0B1220').backgroundColor('#6FD3A8')
          .padding(8).borderRadius(6).width('100%').margin({ top: 8 })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 10 })
    .backgroundColor('#132238')
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
        Text(label).fontSize(13).fontColor('#C9D8E8').layoutWeight(1)
        Text(this.envValue(key).toString() + unit).fontSize(13).fontColor('#4FC3E8')
      }.width('100%')
      Slider({ value: this.envValue(key), min: min, max: max, step: step, style: SliderStyle.OutSet })
        .width('100%')
        .trackColor('#2C435C')
        .selectedColor('#4FC3E8')
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

  @Builder
  DeviceCard(d: DeviceState) {
    Row() {
      Column() {
        Text(d.name).fontSize(15).fontColor('#E6F1FB')
        Text(d.power ? '运行中 · ' + d.value.toString() + d.unit : '已关闭')
          .fontSize(12).fontColor(d.power ? '#6FD3A8' : '#8497AC').margin({ top: 3 })
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      Text(d.power ? 'ON' : 'OFF')
        .fontSize(12).fontColor(d.power ? '#6FD3A8' : '#8497AC')
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor(d.power ? '#1C4038' : '#22334A').borderRadius(10)
    }
    .width('100%').padding(14).backgroundColor('#16263B').borderRadius(12)
  }

  @Builder
  DashboardPanel() {
    Scroll() {
      Column({ space: 12 }) {
        Text('模拟环境（可直接调整）').fontSize(15).fontColor('#E6F1FB')
        Column({ space: 10 }) {
          this.MetricSlider('温度', 'temperature', -10, 50, 1, '℃')
          this.MetricSlider('光照', 'illuminance', 0, 2000, 20, ' lux')
          this.MetricSlider('湿度', 'humidity', 0, 100, 1, '%')
          this.MetricSlider('时段', 'hour', 0, 23, 1, ' 点')
          Row() {
            Text('宿舍在室状态').fontSize(13).fontColor('#C9D8E8').layoutWeight(1)
            Text(this.env.occupancy ? '有人' : '无人').fontSize(13).fontColor('#4FC3E8')
            Toggle({ type: ToggleType.Switch, isOn: this.env.occupancy })
              .onChange((on: boolean) => { this.setOccupancy(on); })
          }.width('100%')
        }.width('100%').padding(14).backgroundColor('#16263B').borderRadius(12)

        Row({ space: 10 }) {
          Button('执行联动演练')
            .fontSize(14).layoutWeight(1).backgroundColor('#2E7FB8')
            .onClick(() => { this.runOnce(); })
          Button('重置环境')
            .fontSize(13).backgroundColor('#2C435C')
            .onClick(() => {
              this.env = normalizeEnvironment(DEFAULT_ENVIRONMENT);
              this.activeScene = '';
              this.showToast('环境已重置');
              this.persistAll();
            })
        }.width('100%')

        Column() {
          Text('本次演练结果').fontSize(14).fontColor('#E6F1FB')
          Text('触发规则 ' + this.triggered.length + ' 条 · 执行动作 ' + this.executedCount +
               ' 个 · 冲突拦截 ' + this.blockedCount + ' 个')
            .fontSize(12).fontColor('#C9D8E8').margin({ top: 6 })
          Text('触发顺序：' + (this.triggered.length > 0 ? this.triggered.join(' → ') : '暂无'))
            .fontSize(12).fontColor('#4FC3E8').margin({ top: 4 })
        }
        .width('100%').padding(14).backgroundColor('#16263B').borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        Text('设备实时状态').fontSize(15).fontColor('#E6F1FB')
        ForEach(this.devices, (d: DeviceState) => {
          this.DeviceCard(d)
        }, (d: DeviceState) => d.id + '|' + (d.power ? '1' : '0') + '|' + d.value.toString())
      }.padding(16)
    }.layoutWeight(1)
  }

  @Builder
  RuleCard(r: AutomationRule) {
    Column() {
      Row() {
        Column() {
          Text(r.id + '  ' + r.name)
            .fontSize(15).fontColor(r.enabled ? '#E6F1FB' : '#7E90A5')
          Text('优先级 ' + r.priority + ' · ' + (r.enabled ? '已启用' : '已停用') + ' · ' +
               r.conditions.length + ' 个条件')
            .fontSize(11).fontColor('#9FB3C8').margin({ top: 3 })
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: r.enabled })
          .onChange((on: boolean) => { this.toggleRule(r.id, on); })
      }.width('100%')
      Text('当 ' + this.conditionText(r))
        .fontSize(12).fontColor('#4FC3E8').margin({ top: 10 })
      Text('则 ' + this.actionText(r))
        .fontSize(12).fontColor('#B8CDDF').margin({ top: 4 })
      Text(r.description)
        .fontSize(11).fontColor('#8497AC').margin({ top: 6 })
      Row({ space: 10 }) {
        Button('编辑').fontSize(12).backgroundColor('#2C435C')
          .onClick(() => { this.openEditor(r); })
        Button('删除').fontSize(12).backgroundColor('#5A2B33')
          .onClick(() => { this.deleteRule(r.id); })
      }.margin({ top: 12 })
    }
    .width('100%').padding(14).backgroundColor('#16263B').borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  RulePanel() {
    Scroll() {
      Column({ space: 12 }) {
        Row() {
          Text('联动规则（' + this.rules.length + ' 条）')
            .fontSize(15).fontColor('#E6F1FB').layoutWeight(1)
          Button('+ 新增规则').fontSize(13).backgroundColor('#2E7FB8')
            .onClick(() => { this.openNewEditor(); })
        }.width('100%')
        Text('规则按「优先级数值」从小到大顺序执行；同一设备同时被多条规则控制时，高优先级规则胜出，低优先级动作被拦截并记入冲突日志。')
          .fontSize(11).fontColor('#9FB3C8')
        if (this.rules.length === 0) {
          Text('暂无规则，请点击右上角新增').fontSize(13).fontColor('#8497AC')
        }
        ForEach(this.rules, (r: AutomationRule) => {
          this.RuleCard(r)
        }, (r: AutomationRule) => r.id + '|' + (r.enabled ? '1' : '0') + '|' + r.priority.toString())
      }.padding(16)
    }.layoutWeight(1)
  }

  @Builder
  SceneCard(s: ScenePreset) {
    Column() {
      Text(s.id + ' · ' + s.name).fontSize(15).fontColor('#E6F1FB')
      Text('温度 ' + s.env.temperature + '℃   光照 ' + s.env.illuminance + 'lux   湿度 ' +
           s.env.humidity + '%   ' + s.env.hour + '点   ' + (s.env.occupancy ? '有人' : '无人'))
        .fontSize(11).fontColor('#9FB3C8').margin({ top: 6 })
      Text(s.note).fontSize(11).fontColor('#F5B971').margin({ top: 6 })
      Button('载入并演练').fontSize(13).backgroundColor('#2E7FB8').margin({ top: 10 })
        .onClick(() => { this.applyScene(s); })
    }
    .width('100%').padding(14).backgroundColor('#16263B').borderRadius(12)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ScenePanel() {
    Scroll() {
      Column({ space: 12 }) {
        Text('模拟演练场景（4 组，点击即载入环境并执行）')
          .fontSize(15).fontColor('#E6F1FB')
        ForEach(SCENE_PRESETS, (s: ScenePreset) => {
          this.SceneCard(s)
        }, (s: ScenePreset) => s.id)
        if (this.activeScene.length > 0) {
          Text('当前场景：' + this.activeScene).fontSize(13).fontColor('#4FC3E8')
        }
        if (this.conflicts.length > 0) {
          Column() {
            Text('检测到 ' + this.conflicts.length + ' 处控制冲突')
              .fontSize(14).fontColor('#F5B971')
            ForEach(this.conflicts, (c: ConflictRecord, idx: number) => {
              Text(this.deviceName(c.deviceId) + '：' + c.winnerRuleId + ' 胜出，' +
                   c.loserRuleId + ' 被拦截')
                .fontSize(12).fontColor('#E6D2AE').margin({ top: 6 })
            }, (c: ConflictRecord, idx: number) => idx.toString() + c.loserRuleId)
            Button('一键修复：为高温制冷补充「有人在室」条件')
              .fontSize(13).backgroundColor('#8A5A18').margin({ top: 12 })
              .onClick(() => { this.fixConflict(); })
            Text('修复原理：R002 原本只看温度，高温且无人时会与 R005「无人节能」争夺空调。补充在室条件后，无人场景 R002 不再命中，冲突消失。')
              .fontSize(11).fontColor('#9FB3C8').margin({ top: 8 })
          }
          .width('100%').padding(14).backgroundColor('#3A2C18').borderRadius(12)
          .alignItems(HorizontalAlign.Start)
        } else {
          Column() {
            Text('当前无控制冲突').fontSize(14).fontColor('#6FD3A8')
            Text('可载入「S2 午后无人·冲突」场景观察优先级裁决过程。')
              .fontSize(11).fontColor('#9FB3C8').margin({ top: 6 })
          }
          .width('100%').padding(14).backgroundColor('#16263B').borderRadius(12)
          .alignItems(HorizontalAlign.Start)
        }
      }.padding(16)
    }.layoutWeight(1)
  }

  @Builder
  RecordRow(r: ExecutionRecord) {
    Column() {
      Row() {
        Text('#' + r.order).fontSize(12).fontColor('#4FC3E8')
        Text(r.ruleId + ' ' + r.ruleName)
          .fontSize(13).fontColor('#E6F1FB').layoutWeight(1).margin({ left: 8 })
        Text(r.blocked ? '已拦截' : '已执行')
          .fontSize(11).fontColor(r.blocked ? '#F5B971' : '#6FD3A8')
      }.width('100%')
      Text('优先级 ' + r.priority + ' · 条件 ' + this.conditionList(r.conditions))
        .fontSize(11).fontColor('#9FB3C8').margin({ top: 6 })
      Text(r.change.deviceName + '：' + (r.change.beforePower ? '开 ' : '关 ') +
           r.change.beforeValue + ' → ' + (r.change.afterPower ? '开 ' : '关 ') +
           r.change.afterValue)
        .fontSize(11).fontColor('#B8CDDF').margin({ top: 4 })
      Text(r.note).fontSize(11).fontColor('#8497AC').margin({ top: 4 })
    }
    .width('100%').padding(12).backgroundColor('#16263B').borderRadius(10)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  LogPanel() {
    Scroll() {
      Column({ space: 10 }) {
        Text('执行记录与存档').fontSize(15).fontColor('#E6F1FB')
        Text('持久化：Preferences / dormlink_state · 存档时间 ' + this.formatTime(this.savedAt))
          .fontSize(11).fontColor('#9FB3C8')
        Text(this.restoreMessage).fontSize(11).fontColor(this.restored ? '#6FD3A8' : '#F5B971')
        if (this.records.length === 0) {
          Text('尚未执行演练，请到「联动台」或「演练」页运行一次')
            .fontSize(13).fontColor('#8497AC')
        }
        ForEach(this.records, (r: ExecutionRecord) => {
          this.RecordRow(r)
        }, (r: ExecutionRecord) => r.order.toString() + r.ruleId + '|' + r.change.afterValue.toString())

        if (this.warnings.length > 0) {
          Column() {
            Text('引擎告警 / 异常降级记录（' + this.warnings.length + ' 条）')
              .fontSize(13).fontColor('#F5B971')
            ForEach(this.warnings, (w: string, idx: number) => {
              Text('· ' + w).fontSize(11).fontColor('#E6D2AE').margin({ top: 4 })
            }, (w: string, idx: number) => idx.toString() + w)
          }
          .width('100%').padding(12).backgroundColor('#3A2C18').borderRadius(10)
          .alignItems(HorizontalAlign.Start)
        }
        Row({ space: 10 }) {
          Button('清空执行记录').fontSize(13).backgroundColor('#2C435C').layoutWeight(1)
            .onClick(() => { this.clearRecords(); })
          Button('恢复出厂方案').fontSize(13).backgroundColor('#5A2B33').layoutWeight(1)
            .onClick(() => { this.resetAll(); })
        }.width('100%').margin({ top: 8 })
        Text('提示：结束应用进程后重新打开，规则、设备状态与最近 50 条执行记录会自动恢复。')
          .fontSize(11).fontColor('#8497AC')
      }.padding(16)
    }.layoutWeight(1)
  }

  @Builder
  RuleEditorPanel() {
    Column() {
      Scroll() {
        Column({ space: 12 }) {
          Text(this.editorIsNew ? '新增联动规则' : '编辑规则 ' + this.draft.id)
            .fontSize(17).fontColor('#E6F1FB')
          Text('规则名称').fontSize(12).fontColor('#9FB3C8')
          TextInput({ text: this.draft.name, placeholder: '请输入规则名称' })
            .width('100%').backgroundColor('#16263B').fontColor('#E6F1FB')
            .onChange((v: string) => { this.setDraftName(v); })
          Row() {
            Text('优先级（数值越小越优先）').fontSize(12).fontColor('#9FB3C8').layoutWeight(1)
            TextInput({ text: this.draft.priority.toString() })
              .type(InputType.Number).width(80).backgroundColor('#16263B').fontColor('#E6F1FB')
              .onChange((v: string) => { this.setDraftPriority(v); })
          }.width('100%')

          Text('触发条件（全部满足才触发）').fontSize(13).fontColor('#4FC3E8')
          ForEach(this.draft.conditions, (c: Condition, idx: number) => {
            Column() {
              Row({ space: 6 }) {
                Select(METRIC_SELECT)
                  .selected(this.indexIn(METRIC_TEXTS, metricLabel(c.metric)))
                  .value(metricLabel(c.metric))
                  .font({ size: 12 }).backgroundColor('#16263B')
                  .onSelect((i: number) => { this.setConditionMetric(idx, i); })
                Select(OP_SELECT)
                  .selected(this.indexIn(OP_TEXTS, opLabel(c.op)))
                  .value(opLabel(c.op))
                  .font({ size: 12 }).backgroundColor('#16263B')
                  .onSelect((i: number) => { this.setConditionOp(idx, i); })
                TextInput({ text: c.value.toString() })
                  .type(InputType.Number).width(70).backgroundColor('#16263B').fontColor('#E6F1FB')
                  .onChange((v: string) => { this.setConditionValue(idx, v); })
                Button('×').fontSize(13).backgroundColor('#5A2B33')
                  .onClick(() => { this.removeCondition(idx); })
              }.width('100%')
              Text(describeCondition(c)).fontSize(11).fontColor('#8497AC').margin({ top: 4 })
            }
            .width('100%').padding(10).backgroundColor('#1B2E47').borderRadius(8)
            .alignItems(HorizontalAlign.Start)
          }, (c: Condition, idx: number) => idx.toString() + c.metric)
          Button('+ 添加条件（最多 3 条）').fontSize(12).backgroundColor('#2C435C')
            .onClick(() => { this.addCondition(); })

          Text('执行动作').fontSize(13).fontColor('#4FC3E8')
          ForEach(this.draft.actions, (a: DeviceAction, idx: number) => {
            Row({ space: 6 }) {
              Select(DEVICE_SELECT)
                .selected(this.indexIn(DEVICE_TEXTS, this.deviceName(a.deviceId)))
                .value(this.deviceName(a.deviceId))
                .font({ size: 12 }).backgroundColor('#16263B')
                .onSelect((i: number) => { this.setActionDevice(idx, i); })
              Text('开关').fontSize(11).fontColor('#9FB3C8')
              Toggle({ type: ToggleType.Switch, isOn: a.power })
                .onChange((on: boolean) => { this.setActionPower(idx, on); })
              TextInput({ text: a.value.toString() })
                .type(InputType.Number).width(64).backgroundColor('#16263B').fontColor('#E6F1FB')
                .onChange((v: string) => { this.setActionValue(idx, v); })
              Button('×').fontSize(13).backgroundColor('#5A2B33')
                .onClick(() => { this.removeAction(idx); })
            }.width('100%').padding(10).backgroundColor('#1B2E47').borderRadius(8)
          }, (a: DeviceAction, idx: number) => idx.toString() + a.deviceId)
          Button('+ 添加动作（最多 3 个）').fontSize(12).backgroundColor('#2C435C')
            .onClick(() => { this.addAction(); })

          Row({ space: 10 }) {
            Button('保存并重新演练').fontSize(14).backgroundColor('#2E7FB8').layoutWeight(1)
              .onClick(() => { this.saveDraft(); })
            Button('取消').fontSize(14).backgroundColor('#2C435C').layoutWeight(1)
              .onClick(() => { this.showEditor = false; })
          }.width('100%').margin({ top: 6 })
        }.padding(16)
      }.layoutWeight(1)
    }
    .width('100%').height('100%').backgroundColor('#0B1220')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.HeaderBar()
        Tabs({ barPosition: BarPosition.End }) {
          TabContent() { this.DashboardPanel() }.tabBar('联动台')
          TabContent() { this.RulePanel() }.tabBar('规则')
          TabContent() { this.ScenePanel() }.tabBar('演练')
          TabContent() { this.LogPanel() }.tabBar('日志')
        }
        .barHeight(58)
        .layoutWeight(1)
        .backgroundColor('#0B1220')
        .onChange((index: number) => { this.currentTab = index; })
      }
      .width('100%').height('100%').backgroundColor('#0B1220')

      if (this.showEditor) {
        this.RuleEditorPanel()
      }
    }
    .width('100%').height('100%')
  }
}
