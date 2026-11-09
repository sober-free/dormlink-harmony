/**
 * DormLink 设计规范 —— Design Tokens（唯一来源）
 *
 * 约定：页面与组件禁止硬编码颜色 / 字号 / 间距 / 圆角，一律引用本文件。
 * 视觉主题：浅色（Light），参考米家 App：浅灰底 + 白色大圆角卡片 + 橙色主色 + 设备网格。
 */

/** 语义化颜色：按用途命名，不按色相命名，便于换肤 */
export class ColorToken {
  // 背景层级
  static readonly canvas: string = '#F5F6F8';
  static readonly surfaceHigh: string = '#FFFFFF';
  static readonly surface: string = '#FFFFFF';
  static readonly surfaceAlt: string = '#F0F2F5';
  static readonly overlay: string = '#F5F6F8';

  // 边框 / 分隔
  static readonly border: string = '#EDEFF2';
  static readonly borderStrong: string = '#DDE1E7';

  // 文字
  static readonly textPrimary: string = '#1A1D21';
  static readonly textSecondary: string = '#8A9099';
  static readonly textTertiary: string = '#B0B6BF';
  static readonly textInverse: string = '#FFFFFF';

  // 品牌与强调（米家橙）
  static readonly brand: string = '#FF6900';
  static readonly brandPressed: string = '#E55F00';
  static readonly accent: string = '#FF6900';
  static readonly accentSubtle: string = '#FFF1E8';

  // 状态
  static readonly success: string = '#00C48C';
  static readonly successBg: string = '#E6FAF4';
  static readonly warning: string = '#FF9500';
  static readonly warningBg: string = '#FFF4E5';
  static readonly danger: string = '#FF3B30';
  static readonly dangerBg: string = '#FFECEB';
}

/** 字号阶梯 */
export class FontToken {
  static readonly display: number = 21;
  static readonly title: number = 16;
  static readonly heading: number = 15;
  static readonly body: number = 13;
  static readonly label: number = 12;
  static readonly caption: number = 11;
}

/** 间距：4 基准 */
export class SpaceToken {
  static readonly xs: number = 4;
  static readonly sm: number = 8;
  static readonly md: number = 12;
  static readonly lg: number = 16;
  static readonly xl: number = 20;
  static readonly xxl: number = 28;
}

/** 圆角：米家风格偏大圆角 */
export class RadiusToken {
  static readonly sm: number = 8;
  static readonly md: number = 12;
  static readonly lg: number = 18;
  static readonly pill: number = 999;
}

/** 组件尺寸 */
export class SizeToken {
  static readonly buttonHeight: number = 46;
  static readonly buttonHeightSm: number = 34;
  static readonly inputHeight: number = 40;
  static readonly tabBarHeight: number = 58;
  static readonly iconBox: number = 44;
  static readonly borderWidth: number = 1;
}
