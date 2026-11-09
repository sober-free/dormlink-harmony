import { describe, it, expect } from '@ohos/hypium';
import {
  AutomationRule, DeviceState, Environment, Condition, PersistedState, MetricKey, CompareOp,
  evaluate, matchCondition, isRuleTriggered, validateRule, normalizeEnvironment,
  cloneDevices, cloneRule, serializeState, deserializeState
} from '../../../main/ets/engine/RuleEngine';
import {
  DEFAULT_DEVICES, DEFAULT_RULES, SCENE_PRESETS
} from '../../../main/ets/engine/DefaultData';

function makeEnv(t: number, lux: number, hum: number, hour: number, occ: boolean): Environment {
  return { temperature: t, illuminance: lux, humidity: hum, hour: hour, occupancy: occ };
}

function findRule(id: string): AutomationRule {
  for (const r of DEFAULT_RULES) {
    if (r.id === id) return cloneRule(r);
  }
  return cloneRule(DEFAULT_RULES[0]);
}

function findDevice(devices: DeviceState[], id: string): DeviceState {
  for (const d of devices) {
    if (d.id === id) return d;
  }
  return devices[0];
}

/** 与 tests/node/rule-engine.test.mjs 对应，在 DevEco Studio / 设备上可直接运行 */
export default function ruleEngineTest() {
  describe('DormLink_RuleEngine', () => {
    it('normal_single_condition_changes_device_and_logs', 0, () => {
      const result = evaluate(makeEnv(30, 320, 52, 20, true),
        cloneDevices(DEFAULT_DEVICES), [findRule('R002')]);
      expect(findDevice(result.devices, 'ac').power).assertTrue();
      expect(findDevice(result.devices, 'ac').value).assertEqual(26);
      expect(result.executedCount).assertEqual(1);
      expect(result.records[0].order).assertEqual(1);
      expect(result.records[0].change.beforePower).assertFalse();
    });

    it('normal_double_condition_is_AND', 0, () => {
      const rule = findRule('R001');
      expect(isRuleTriggered(makeEnv(26, 300, 50, 23, true), rule)).assertTrue();
      expect(isRuleTriggered(makeEnv(26, 300, 50, 21, true), rule)).assertFalse();
      expect(isRuleTriggered(makeEnv(26, 300, 50, 23, false), rule)).assertFalse();
    });

    it('normal_execution_order_follows_priority', 0, () => {
      const result = evaluate(SCENE_PRESETS[0].env, cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES);
      expect(result.triggeredRuleIds[0]).assertEqual('R001');
      expect(result.triggeredRuleIds[1]).assertEqual('R002');
      expect(result.records[0].order).assertEqual(1);
      expect(result.records[1].order).assertEqual(2);
    });

    it('normal_conflict_higher_priority_wins', 0, () => {
      const result = evaluate(SCENE_PRESETS[1].env, cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES);
      expect(findDevice(result.devices, 'ac').power).assertTrue();
      expect(result.conflicts.length).assertEqual(1);
      expect(result.conflicts[0].winnerRuleId).assertEqual('R002');
      expect(result.conflicts[0].loserRuleId).assertEqual('R005');
      expect(result.blockedCount).assertEqual(1);
    });

    it('normal_conflict_blocks_only_contended_device', 0, () => {
      const result = evaluate(SCENE_PRESETS[1].env, cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES);
      expect(findDevice(result.devices, 'main_light').power).assertFalse();
      expect(findDevice(result.devices, 'fan').power).assertFalse();
      let blocked = 0;
      for (const r of result.records) {
        if (r.ruleId === 'R005' && r.blocked) blocked++;
      }
      expect(blocked).assertEqual(1);
    });

    it('normal_disabled_rule_does_not_trigger', 0, () => {
      const rule = findRule('R002');
      rule.enabled = false;
      const result = evaluate(makeEnv(30, 320, 52, 20, true), cloneDevices(DEFAULT_DEVICES), [rule]);
      expect(result.executedCount).assertEqual(0);
      expect(result.triggeredRuleIds.length).assertEqual(0);
    });

    it('boundary_threshold_equality', 0, () => {
      expect(isRuleTriggered(makeEnv(28, 300, 50, 20, true), findRule('R002'))).assertTrue();
      expect(isRuleTriggered(makeEnv(27, 300, 50, 20, true), findRule('R002'))).assertFalse();
      expect(isRuleTriggered(makeEnv(26, 300, 35, 20, true), findRule('R004'))).assertTrue();
      expect(isRuleTriggered(makeEnv(26, 300, 36, 20, true), findRule('R004'))).assertFalse();
    });

    it('boundary_hour_0_and_23', 0, () => {
      expect(normalizeEnvironment(makeEnv(26, 300, 50, 0, true)).hour).assertEqual(0);
      expect(normalizeEnvironment(makeEnv(26, 300, 50, 23, true)).hour).assertEqual(23);
      expect(isRuleTriggered(makeEnv(26, 300, 50, 23, true), findRule('R001'))).assertTrue();
      expect(isRuleTriggered(makeEnv(26, 300, 50, 0, true), findRule('R001'))).assertFalse();
    });

    it('boundary_empty_rules_keep_devices', 0, () => {
      const devices = cloneDevices(DEFAULT_DEVICES);
      const empty: AutomationRule[] = [];
      const result = evaluate(makeEnv(26, 300, 50, 20, true), devices, empty);
      expect(result.records.length).assertEqual(0);
      expect(result.executedCount).assertEqual(0);
      expect(result.devices.length).assertEqual(5);
    });

    it('boundary_all_scenes_reproducible', 0, () => {
      for (const scene of SCENE_PRESETS) {
        const a = evaluate(scene.env, cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES);
        const b = evaluate(scene.env, cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES);
        expect(a.triggeredRuleIds.length).assertEqual(b.triggeredRuleIds.length);
        expect(a.devices.length).assertEqual(b.devices.length);
      }
      expect(SCENE_PRESETS.length).assertEqual(4);
    });

    it('exception_out_of_range_env_is_clamped', 0, () => {
      const result = evaluate(makeEnv(999, -50, -1, 20, true),
        cloneDevices(DEFAULT_DEVICES), DEFAULT_RULES);
      expect(normalizeEnvironment(makeEnv(999, -50, -1, 20, true)).temperature).assertEqual(50);
      expect(normalizeEnvironment(makeEnv(999, -50, -1, 20, true)).illuminance).assertEqual(0);
      expect(result.warnings.length > 0).assertTrue();
      expect(result.devices.length).assertEqual(5);
    });

    it('exception_invalid_condition_returns_false', 0, () => {
      // NaN 阈值、NaN 环境值、未知环境量/运算符都走引擎的异常降级分支
      const nanThreshold: Condition = { metric: 'temperature', op: 'GE', value: Number.NaN };
      expect(matchCondition(makeEnv(26, 300, 50, 20, true), nanThreshold)).assertFalse();
      const unknownMetric = 'UNKNOWN_METRIC' as MetricKey;
      const unknownOp = 'BAD_OP' as CompareOp;
      const badMetric: Condition = { metric: unknownMetric, op: 'GE', value: 10 };
      const badOp: Condition = { metric: 'temperature', op: unknownOp, value: 10 };
      expect(matchCondition(makeEnv(26, 300, 50, 20, true), badMetric)).assertFalse();
      expect(matchCondition(makeEnv(26, 300, 50, 20, true), badOp)).assertFalse();
      const nanEnv: Environment = makeEnv(Number.NaN, 300, 50, 20, true);
      expect(matchCondition(nanEnv, { metric: 'temperature', op: 'GE', value: 10 })).assertFalse();
    });

    it('exception_invalid_rules_rejected', 0, () => {
      const bad = findRule('R002');
      const empty: Condition[] = [];
      bad.conditions = empty;
      expect(validateRule(bad).length > 0).assertTrue();
      const result = evaluate(makeEnv(30, 300, 50, 20, true), cloneDevices(DEFAULT_DEVICES), [bad]);
      expect(result.executedCount).assertEqual(0);
      expect(result.warnings.length > 0).assertTrue();
    });

    it('exception_corrupted_snapshot_returns_null', 0, () => {
      expect(deserializeState('{ broken json') === null).assertTrue();
      expect(deserializeState('') === null).assertTrue();
      const state: PersistedState = {
        version: 1,
        environment: makeEnv(26, 300, 50, 20, true),
        devices: cloneDevices(DEFAULT_DEVICES),
        rules: DEFAULT_RULES,
        records: [],
        conflicts: [],
        savedAt: 1760000000000
      };
      const text = serializeState(state);
      const restored = deserializeState(text);
      expect(restored === null).assertFalse();
      expect(text.length > 0).assertTrue();
    });
  });
}
