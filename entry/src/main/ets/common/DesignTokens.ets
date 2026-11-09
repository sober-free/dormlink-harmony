/**
 * DormLink 设计规范 —— Design Tokens（唯一来源）
 *
 * 约定：页面与组件禁止硬编码颜色 / 字号 / 间距 / 圆角，一律引用本文件。
 * 视觉主题：深色（Dark），用于宿舍夜间场景，降低屏幕亮度干扰。
 */

/** 语义化颜色：按用途命名，不按色相命名，便于后续换肤 */
export class ColorToken {
  // 背景层级（由深到浅）
  static readonly canvas: string = '#0B1220';        // 页面底色
  static readonly surfaceHigh: string = '#132238';   // 顶部栏 / 固定区域
  static readonly surface: string = '#16273D';       // 卡片
  static readonly surfaceAlt: string = '#1E3350';    // 输入框 / 次级块 / 嵌套块
  static readonly overlay: string = '#0B1220';       // 全屏弹层底

  // 边框
  static readonly border: string = '#263C55';        // 常规分隔
  static readonly borderStrong: string = '#35506E';  // 次按钮 / 强调边框

  // 文字
  static readonly textPrimary: string = '#EAF2FA';
  static readonly textSecondary: string = '#9DB1C6';
  static readonly textTertiary: string = '#7A8DA3';
  static readonly textInverse: string = '#0B1220';   // 亮底上的文字

  // 品牌与强调
  static readonly brand: string = '#2E86C8';         // 主按钮
  static readonly brandPressed: string = '#256FA6';  // 主按钮按下
  static readonly accent: string = '#4FC3E8';        // 选中态 / 关键数值 / 条件文案
  static readonly accentSubtle: string = '#1B3A52';  // 选中背景

  // 状态
  static readonly success: string = '#5FD3A0';
  static readonly successBg: string = '#16382C';
  static readonly warning: string = '#F0B45F';
  static readonly warningBg: string = '#3A2C18';
  static readonly danger: string = '#E8776F';
  static readonly dangerBg: string = '#4A2428';
}

/** 字号阶梯：拉开层级，避免相邻级别只差 1px */
export class FontToken {
  static readonly display: number = 19;   // 页面主标题
  static readonly title: number = 17;     // 卡片标题 / 区块标题
  static readonly heading: number = 15;   // 次级标题 / 按钮文字
  static readonly body: number = 13;      // 正文
  static readonly label: number = 12;     // 标签 / 辅助信息
  static readonly caption: number = 11;   // 说明 / 注释
}

/** 间距：以 4 为基准，常用 8 的倍数 */
export class SpaceToken {
  static readonly xs: number = 4;
  static readonly sm: number = 8;
  static readonly md: number = 12;
  static readonly lg: number = 16;
  static readonly xl: number = 20;
  static readonly xxl: number = 28;
}

/** 圆角 */
export class RadiusToken {
  static readonly sm: number = 6;
  static readonly md: number = 10;
  static readonly lg: number = 14;
  static readonly pill: number = 999;
}

/** 组件尺寸 */
export class SizeToken {
  static readonly buttonHeight: number = 44;      // 主 / 次按钮
  static readonly buttonHeightSm: number = 34;    // 卡片内小按钮
  static readonly inputHeight: number = 40;
  static readonly tabBarHeight: number = 58;
  static readonly iconBox: number = 32;
  static readonly borderWidth: number = 1;
}
