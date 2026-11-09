/**
 * DormLink 默认业务数据：设备、规则、场景预设。
 * 仅使用 import type，编译后不产生模块依赖，Node 单元测试可直接加载本文件。
 */
import type { AutomationRule, DeviceState, Environment } from './RuleEngine';

export interface ScenePreset {
  id: string;
  name: string;
  env: Environment;
  note: string;
}

export const DEFAULT_ENVIRONMENT: Environment = {
  temperature: 26, illuminance: 320, humidity: 52, hour: 20, occupancy: true
};

/** 5 类可控设备：主灯、空调、窗帘、风扇、加湿器 */
export const DEFAULT_DEVICES: DeviceState[] = [
  { id: 'main_light', name: '主灯', power: false, value: 0, unit: '%' },
  { id: 'ac', name: '空调', power: false, value: 26, unit: '℃' },
  { id: 'curtain', name: '窗帘', power: false, value: 0, unit: '%' },
  { id: 'fan', name: '风扇', power: false, value: 0, unit: '档' },
  { id: 'humidifier', name: '加湿器', power: false, value: 0, unit: '档' }
];

/**
 * 6 条默认规则（题目要求 >=4 条，且至少 1 条由两个条件共同决定）。
 * R001 / R004 / R006 为双条件规则；R005 与 R002 在"高温且无人"场景下争夺空调，
 * 用于演示冲突裁决与优先级调整。
 */
export const DEFAULT_RULES: AutomationRule[] = [
  {
    id: 'R001',
    name: '夜间归寝照明',
    enabled: true,
    priority: 10,
    description: '22 点以后且有人在室时，自动打开主灯并调至柔和亮度',
    conditions: [
      { metric: 'hour', op: 'GE', value: 22 },
      { metric: 'occupancy', op: 'EQ', value: 1 }
    ],
    actions: [{ deviceId: 'main_light', power: true, value: 60 }]
  },
  {
    id: 'R002',
    name: '高温自动制冷',
    enabled: true,
    priority: 20,
    description: '室温达到 28℃ 时开启空调制冷至 26℃',
    conditions: [{ metric: 'temperature', op: 'GE', value: 28 }],
    actions: [{ deviceId: 'ac', power: true, value: 26 }]
  },
  {
    id: 'R003',
    name: '强光自动遮阳',
    enabled: true,
    priority: 30,
    description: '光照达到 800 lux 时放下窗帘避免暴晒',
    conditions: [{ metric: 'illuminance', op: 'GE', value: 800 }],
    actions: [{ deviceId: 'curtain', power: false, value: 0 }]
  },
  {
    id: 'R004',
    name: '干燥加湿',
    enabled: true,
    priority: 25,
    description: '湿度不高于 35% 且有人在室时，开启加湿器二档',
    conditions: [
      { metric: 'humidity', op: 'LE', value: 35 },
      { metric: 'occupancy', op: 'EQ', value: 1 }
    ],
    actions: [{ deviceId: 'humidifier', power: true, value: 2 }]
  },
  {
    id: 'R005',
    name: '无人节能',
    enabled: true,
    priority: 50,
    description: '宿舍无人时关闭主灯、空调与风扇；与 R002 同时命中会产生可控冲突',
    conditions: [{ metric: 'occupancy', op: 'EQ', value: 0 }],
    actions: [
      { deviceId: 'main_light', power: false, value: 0 },
      { deviceId: 'ac', power: false, value: 26 },
      { deviceId: 'fan', power: false, value: 0 }
    ]
  },
  {
    id: 'R006',
    name: '晨间唤醒',
    enabled: false,
    priority: 15,
    description: '7 点至 9 点之间拉开窗帘并打开主灯；默认停用，可在规则页启用',
    conditions: [
      { metric: 'hour', op: 'GE', value: 7 },
      { metric: 'hour', op: 'LT', value: 9 }
    ],
    actions: [
      { deviceId: 'curtain', power: true, value: 100 },
      { deviceId: 'main_light', power: true, value: 40 }
    ]
  }
];

/** 4 组模拟演练场景（题目要求 >=2 组） */
export const SCENE_PRESETS: ScenePreset[] = [
  {
    id: 'S1',
    name: '夏夜归寝',
    env: { temperature: 30, illuminance: 60, humidity: 58, hour: 23, occupancy: true },
    note: '双条件规则 R001 与单条件规则 R002 同时命中，检查执行顺序是否为 R001 → R002'
  },
  {
    id: 'S2',
    name: '午后无人·冲突',
    env: { temperature: 31, illuminance: 900, humidity: 42, hour: 14, occupancy: false },
    note: 'R002 与 R005 争夺空调：优先级 20 胜出，R005 的空调动作被拦截，其余动作照常执行'
  },
  {
    id: 'S3',
    name: '干燥清晨',
    env: { temperature: 18, illuminance: 280, humidity: 28, hour: 8, occupancy: true },
    note: '双条件规则 R004 触发；启用 R006 后可观察窗帘通道的冲突变化'
  },
  {
    id: 'S4',
    name: '深夜无人',
    env: { temperature: 22, illuminance: 5, humidity: 50, hour: 2, occupancy: false },
    note: '仅 R005 生效，全部耗能设备关闭，用于验证节能边界'
  }
];

/** 环境量的合法区间，供 UI 滑块与需求说明书共用 */
export const METRIC_RANGES = {
  temperature: { min: -10, max: 50, step: 1, label: '温度', unit: '℃' },
  illuminance: { min: 0, max: 2000, step: 20, label: '光照', unit: 'lux' },
  humidity: { min: 0, max: 100, step: 1, label: '湿度', unit: '%' },
  hour: { min: 0, max: 23, step: 1, label: '时段', unit: '点' }
};
