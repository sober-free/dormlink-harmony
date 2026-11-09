/**
 * DormLink 协作测试（钱志刚 / qianzhigang-free）
 *
 * 与 rule-engine.test.mjs 一样，直接 import 应用真实业务源码，
 * 借助 Node 22 的 TypeScript type-stripping 执行，不另写模拟实现。
 *
 * 运行： cd tests/node && npm test
 * 覆盖：正常 1 条 / 边界 1 条 / 异常 1 条，对应需求说明书第 7 节「每人至少 3 条测试」。
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  clampMetric, normalizeEnvironment, serializeState, deserializeState
} from '../../entry/src/main/ets/engine/RuleEngine.ts';
import { DEFAULT_ENVIRONMENT } from '../../entry/src/main/ets/engine/DefaultData.ts';

test('[协作-正常] 合法区间内的环境量归一化后保持原值', () => {
  const e = normalizeEnvironment({ temperature: 26, illuminance: 320, humidity: 52, hour: 20, occupancy: true });
  assert.equal(e.temperature, 26);
  assert.equal(e.illuminance, 320);
  assert.equal(e.humidity, 52);
  assert.equal(e.hour, 20);
  assert.equal(e.occupancy, true);
});

test('[协作-边界] hour 向下取整，温度/湿度在端点值不被裁剪', () => {
  assert.equal(clampMetric('hour', 23.9), 23);   // 向下取整
  assert.equal(clampMetric('hour', -0.5), 0);    // 低于下界
  assert.equal(clampMetric('temperature', 50), 50);  // 上端点保留
  assert.equal(clampMetric('temperature', -10), -10); // 下端点保留
  assert.equal(clampMetric('humidity', 100), 100);
});

test('[协作-异常] 非有限数回退下界；含中文与引号的存档可无损往返', () => {
  assert.equal(clampMetric('temperature', Number.NaN), -10);
  assert.equal(clampMetric('humidity', Number.POSITIVE_INFINITY), 0);
  assert.equal(clampMetric('hour', Number.NaN), 0);

  const state = {
    version: 1,
    environment: DEFAULT_ENVIRONMENT,
    devices: [{ id: 'main_light', name: '主灯', power: true, value: 60, unit: '%' }],
    rules: [{
      id: 'R001', name: '夜间"归寝"\n照明', enabled: true, priority: 10,
      conditions: [{ metric: 'hour', op: 'GE', value: 22 }],
      actions: [{ deviceId: 'main_light', power: true, value: 60 }],
      description: '含引号与换行'
    }],
    records: [], conflicts: []
  };
  const back = deserializeState(serializeState(state));
  assert.notEqual(back, null);
  assert.equal(back.rules[0].name, '夜间"归寝"\n照明');
});
