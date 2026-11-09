/**
 * DormLink 规则引擎单元测试（Node 环境）
 *
 * 重要说明：本测试直接 import 的是 HarmonyOS 工程中真实的业务源码
 *   entry/src/main/ets/engine/RuleEngine.ts
 *   entry/src/main/ets/engine/DefaultData.ts
 * 借助 Node 22 的 TypeScript type-stripping 能力执行，
 * 因此测试结果反映的是应用实际运行的逻辑，而不是另写的模拟实现。
 *
 * 运行： node --test tests/node/rule-engine.test.mjs
 */
import test from 'node:test';
import assert from 'node:assert/strict';

import {
  evaluate, matchCondition, isRuleTriggered, validateRule, clampMetric,
  normalizeEnvironment, serializeState, deserializeState, compareRules,
  cloneDevices, cloneRule
} from '../../entry/src/main/ets/engine/RuleEngine.ts';
import {
  DEFAULT_DEVICES, DEFAULT_RULES, SCENE_PRESETS
} from '../../entry/src/main/ets/engine/DefaultData.ts';

const ENV = (over = {}) => ({
  temperature: 26, illuminance: 320, humidity: 52, hour: 20, occupancy: true, ...over
});
const ruleById = (id) => cloneRule(DEFAULT_RULES.find((r) => r.id === id));
const deviceOf = (devices, id) => devices.find((d) => d.id === id);

// ---------------------------------------------------------------- 正常用例

test('[正常 1] 单条件规则命中后设备状态按动作改变，并记录 before -> after', () => {
  const env = ENV({ temperature: 30 });
  const result = evaluate(env, cloneDevices(DEFAULT_DEVICES), [ruleById('R002')]);
  const ac = deviceOf(result.devices, 'ac');
  assert.equal(ac.power, true);
  assert.equal(ac.value, 26);
  assert.equal(result.executedCount, 1);
  assert.equal(result.records.length, 1);
  assert.equal(result.records[0].order, 1);
  assert.equal(result.records[0].change.beforePower, false);
  assert.equal(result.records[0].change.afterPower, true);
  assert.deepEqual(result.triggeredRuleIds, ['R002']);
});

test('[正常 2] 双条件规则为 AND 关系，任一条件不满足即不触发', () => {
  const r1 = ruleById('R001'); // hour>=22 且 occupancy=1
  assert.equal(isRuleTriggered(ENV({ hour: 23, occupancy: true }), r1), true);
  assert.equal(isRuleTriggered(ENV({ hour: 21, occupancy: true }), r1), false, '仅时段不满足');
  assert.equal(isRuleTriggered(ENV({ hour: 23, occupancy: false }), r1), false, '仅在室不满足');
  const result = evaluate(ENV({ hour: 23, occupancy: true }), cloneDevices(DEFAULT_DEVICES), [r1]);
  assert.equal(deviceOf(result.devices, 'main_light').power, true);
  assert.equal(deviceOf(result.devices, 'main_light').value, 60);
});

test('[正常 3] 多条规则按 (优先级升序, id 升序) 稳定排序执行', () => {
  const result = evaluate(SCENE_PRESETS[0].env, cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES);
  // S1 夏夜归寝：R001(p10) 与 R002(p20) 命中
  assert.deepEqual(result.triggeredRuleIds, ['R001', 'R002']);
  assert.equal(result.records[0].ruleId, 'R001');
  assert.equal(result.records[1].ruleId, 'R002');
  assert.equal(result.records[0].order, 1);
  assert.equal(result.records[1].order, 2);
  assert.ok(compareRules(ruleById('R001'), ruleById('R002')) < 0);
});

test('[正常 4] 冲突裁决：高优先级规则胜出，低优先级动作被拦截并生成冲突记录', () => {
  // S2 午后无人：R002(温度>=28, p20) 与 R005(无人, p50) 争夺空调
  const result = evaluate(SCENE_PRESETS[1].env, cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES);
  assert.equal(deviceOf(result.devices, 'ac').power, true, 'R002 优先级更高，空调保持开启');
  assert.equal(result.conflicts.length, 1);
  assert.equal(result.conflicts[0].deviceId, 'ac');
  assert.equal(result.conflicts[0].winnerRuleId, 'R002');
  assert.equal(result.conflicts[0].loserRuleId, 'R005');
  assert.equal(result.blockedCount, 1);
  assert.equal(result.records.find((r) => r.ruleId === 'R005' && r.change.deviceId === 'ac').blocked, true);
});

test('[正常 5] 冲突只拦截争用的设备，同一规则的其他设备动作照常执行', () => {
  const result = evaluate(SCENE_PRESETS[1].env, cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES);
  assert.equal(deviceOf(result.devices, 'main_light').power, false, 'R005 对主灯生效');
  assert.equal(deviceOf(result.devices, 'fan').power, false, 'R005 对风扇生效');
  assert.equal(deviceOf(result.devices, 'curtain').power, false, 'R003 强光遮阳生效');
  const r005Records = result.records.filter((r) => r.ruleId === 'R005');
  assert.equal(r005Records.length, 3, 'R005 的 3 个动作都进入执行记录');
  assert.equal(r005Records.filter((r) => r.blocked).length, 1, '仅空调动作被拦截');
});

test('[正常 6] 调整规则条件后冲突被消除（发现冲突 -> 修改 -> 复测）', () => {
  const fixed = DEFAULT_RULES.map((r) => {
    if (r.id !== 'R002') return cloneRule(r);
    const copy = cloneRule(r);
    copy.conditions = [
      { metric: 'temperature', op: 'GE', value: 28 },
      { metric: 'occupancy', op: 'EQ', value: 1 }
    ];
    return copy;
  });
  const result = evaluate(SCENE_PRESETS[1].env, cloneDevices(DEFAULT_DEVICES), fixed);
  assert.equal(result.conflicts.length, 0, '补充在室条件后 R002 不再命中，冲突消失');
  assert.equal(deviceOf(result.devices, 'ac').power, false, '无人时空调按 R005 关闭');
});

test('[正常 7] 停用规则不参与判定；重新启用后恢复生效', () => {
  const off = DEFAULT_RULES.map((r) => {
    const copy = cloneRule(r);
    if (copy.id === 'R002') copy.enabled = false;
    return copy;
  });
  const a = evaluate(ENV({ temperature: 30 }), cloneDevices(DEFAULT_DEVICES), off);
  assert.equal(a.triggeredRuleIds.includes('R002'), false);
  const b = evaluate(ENV({ temperature: 30 }), cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES);
  assert.equal(b.triggeredRuleIds.includes('R002'), true);
});

test('[正常 8] 输入顺序与优先级相反时，触发顺序仍按优先级升序（回归）', () => {
  const r2 = ruleById('R002'); // priority 20
  const r1 = ruleById('R001'); // priority 10
  const result = evaluate(
    ENV({ temperature: 30, hour: 23, occupancy: true }),
    cloneDevices(DEFAULT_DEVICES),
    [r2, r1] // 故意把低优先级的 R002 放在前面
  );
  assert.deepEqual(result.triggeredRuleIds, ['R001', 'R002'], '触发顺序必须按优先级，而不是输入顺序');
  assert.equal(result.records[0].ruleId, 'R001');
  assert.equal(result.records[1].ruleId, 'R002');
});

// ---------------------------------------------------------------- 边界用例

test('[边界 1] 比较阈值边界：28 命中，27 不命中；LE 边界 35 命中，36 不命中', () => {
  const r2 = ruleById('R002');
  assert.equal(isRuleTriggered(ENV({ temperature: 28 }), r2), true);
  assert.equal(isRuleTriggered(ENV({ temperature: 27 }), r2), false);
  const r4 = ruleById('R004');
  assert.equal(isRuleTriggered(ENV({ humidity: 35, occupancy: true }), r4), true);
  assert.equal(isRuleTriggered(ENV({ humidity: 36, occupancy: true }), r4), false);
});

test('[边界 2] 时段边界：hour=0 与 hour=23 均可被正确归一化并判定', () => {
  assert.equal(normalizeEnvironment(ENV({ hour: 0 })).hour, 0);
  assert.equal(normalizeEnvironment(ENV({ hour: 23 })).hour, 23);
  assert.equal(isRuleTriggered(ENV({ hour: 23, occupancy: true }), ruleById('R001')), true);
  assert.equal(isRuleTriggered(ENV({ hour: 0, occupancy: true }), ruleById('R001')), false);
  assert.equal(clampMetric('hour', 23.9), 23, '小时按整点向下取整');
});

test('[边界 3] 空规则列表 / 全部规则停用：设备状态不变、无执行记录', () => {
  const devices = cloneDevices(DEFAULT_DEVICES);
  const empty = evaluate(ENV(), devices, []);
  assert.deepEqual(empty.devices, devices);
  assert.equal(empty.records.length, 0);
  assert.equal(empty.executedCount, 0);
  assert.ok(empty.warnings.length > 0, '应给出告警说明');
  const allOff = DEFAULT_RULES.map((r) => { const c = cloneRule(r); c.enabled = false; return c; });
  const disabled = evaluate(ENV({ temperature: 40 }), devices, allOff);
  assert.equal(disabled.executedCount, 0);
  assert.equal(disabled.triggeredRuleIds.length, 0);
});

test('[边界 4] 空设备列表时演练安全返回，不抛异常', () => {
  const result = evaluate(ENV({ temperature: 30 }), [], DEFAULT_RULES);
  assert.equal(result.devices.length, 0);
  assert.ok(result.warnings.some((w) => w.includes('设备列表为空')));
});

test('[边界 5] 四组预设场景逐一演练，结果都可复现', () => {
  for (const scene of SCENE_PRESETS) {
    const a = evaluate(scene.env, cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES);
    const b = evaluate(scene.env, cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES);
    assert.deepEqual(a.devices, b.devices, scene.id + ' 两次执行终态必须一致');
    assert.deepEqual(a.triggeredRuleIds, b.triggeredRuleIds, scene.id + ' 触发顺序必须一致');
  }
  assert.equal(SCENE_PRESETS.length, 4, '满足 >=2 组场景演练要求');
});

// ---------------------------------------------------------------- 异常用例

test('[异常 1] 环境数值越界 / NaN：自动裁剪到合法区间并写入 warnings', () => {
  const result = evaluate(
    ENV({ temperature: 999, illuminance: -50, humidity: Number.NaN }),
    cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES
  );
  const env = normalizeEnvironment(ENV({ temperature: 999, illuminance: -50, humidity: Number.NaN }));
  assert.equal(env.temperature, 50);
  assert.equal(env.illuminance, 0);
  assert.equal(env.humidity, 0);
  assert.ok(result.warnings.some((w) => w.includes('温度越界')));
  assert.ok(result.warnings.some((w) => w.includes('光照越界')));
  assert.equal(result.devices.length, 5, '异常输入不应导致引擎崩溃');
});

test('[异常 2] 未知环境量 / 非法运算符 / NaN 阈值：条件判定为 false 且不抛异常', () => {
  assert.equal(matchCondition(ENV(), { metric: 'UNKNOWN_METRIC', op: 'GE', value: 10 }), false);
  assert.equal(matchCondition(ENV(), { metric: 'temperature', op: 'BAD_OP', value: 10 }), false);
  assert.equal(matchCondition(ENV(), { metric: 'temperature', op: 'GE', value: Number.NaN }), false);
  assert.equal(matchCondition(ENV(), { metric: 'temperature', op: 'GE', value: 30 }), false);
  assert.equal(matchCondition(ENV(), { metric: 'temperature', op: 'GE', value: 20 }), true);
});

test('[异常 3] 非法规则（空条件 / 空动作 / 未知设备 / 非数值优先级）被校验拦截', () => {
  const base = ruleById('R002');
  const bad1 = cloneRule(base); bad1.conditions = [];
  const bad2 = cloneRule(base); bad2.actions = [];
  const bad3 = cloneRule(base); bad3.actions = [{ deviceId: 'not_exist', power: true, value: 1 }];
  const bad4 = cloneRule(base); bad4.priority = Number.NaN;
  assert.ok(validateRule(bad1).some((x) => x.includes('缺少触发条件')));
  assert.ok(validateRule(bad2).some((x) => x.includes('缺少设备动作')));
  assert.ok(validateRule(bad3).some((x) => x.includes('未知设备')));
  assert.ok(validateRule(bad4).some((x) => x.includes('优先级')));
  const result = evaluate(ENV({ temperature: 30 }), cloneDevices(DEFAULT_DEVICES), [bad1, bad2, bad4]);
  assert.equal(result.executedCount, 0, '非法规则不参与演练');
  assert.ok(result.warnings.length >= 3, '每条非法规则都应留下告警');
});

test('[异常 4] 规则引用不存在的设备：动作被忽略并记录告警，设备列表保持完整', () => {
  const rule = ruleById('R002');
  const result = evaluate(ENV({ temperature: 30 }), [], [rule]);
  assert.equal(result.devices.length, 0);
  assert.ok(result.warnings.some((w) => w.includes('引用不存在的设备')));
});

test('[异常 5] 损坏存档字符串：deserializeState 返回 null，不抛异常；正常存档可 round-trip', () => {
  assert.equal(deserializeState(''), null);
  assert.equal(deserializeState('{ broken json'), null);
  assert.equal(deserializeState('{"foo":1}'), null, '缺少必需字段视为损坏');
  const snapshot = {
    version: 1,
    environment: ENV(),
    devices: cloneDevices(DEFAULT_DEVICES),
    rules: DEFAULT_RULES.map((r) => cloneRule(r)),
    records: [], conflicts: [], savedAt: 1760000000000
  };
  const text = serializeState(snapshot);
  const restored = deserializeState(text);
  assert.equal(restored.rules.length, 6);
  assert.equal(restored.savedAt, 1760000000000);
  assert.deepEqual(restored.devices, snapshot.devices);
  assert.equal(serializeState(null), '', '空对象序列化返回空串而不是抛错');
});

test('[异常 6] 环境对象整体为空：回退默认环境且不崩溃', () => {
  const result = evaluate(null, cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES);
  assert.equal(result.devices.length, 5);
  assert.ok(result.warnings.some((w) => w.includes('环境输入为空')));
});

test('[异常 7] 规则列表为 null：安全降级为空演练', () => {
  const result = evaluate(ENV(), cloneDevices(DEFAULT_DEVICES), null);
  assert.equal(result.executedCount, 0);
  assert.ok(result.warnings.some((w) => w.includes('规则列表为空')));
});
