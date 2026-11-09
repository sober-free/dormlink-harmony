/**
 * DormLink 设计规范 —— Design Tokens（唯一来源）
 *
 * 约定：页面与组件禁止硬编码颜色 / 字号 / 间距 / 圆角，一律引用本文件。
 * 视觉主题：浅色（Light），参考米家 App：中性浅灰底 + 白色大圆角卡片 + 柔和橙主色 + 设备网格。
 *
 * v2 调整（2026-11-09）：主色由高饱和 #FF6900 降为柔和橙 #F2793C，底色与文字改为中性灰（去蓝调），
 * 避免大面积橙色块造成刺眼；橙色只用于按钮、选中态与关键强调，数字改用主文字色。
 */

/** 语义化颜色：按用途命名，不按色相命名，便于换肤 */
export class ColorToken {
  // 背景层级
  static readonly canvas: string = '#F7F7F8';
  static readonly surfaceHigh: string = '#FFFFFF';
  static readonly surface: string = '#FFFFFF';
  static readonly surfaceAlt: string = '#F2F3F5';
  static readonly overlay: string = '#F7F7F8';

  // 边框 / 分隔
  static readonly border: string = '#F0F1F2';
  static readonly borderStrong: string = '#E4E5E7';

  // 文字（中性灰）
  static readonly textPrimary: string = '#1A1A1A';
  static readonly textSecondary: string = '#8C8C8C';
  static readonly textTertiary: string = '#BDBDBD';
  static readonly textInverse: string = '#FFFFFF';

  // 品牌与强调（柔和橙，替代高饱和 #FF6900）
  static readonly brand: string = '#F2793C';
  static readonly brandPressed: string = '#D96A2E';
  static readonly accent: string = '#E5713A';
  static readonly accentSubtle: string = '#FDF2EA';

  // 状态
  static readonly success: string = '#22A06B';
  static readonly successBg: string = '#E9F7F1';
  static readonly warning: string = '#E6A23C';
  static readonly warningBg: string = '#FDF6EC';
  static readonly danger: string = '#E15A54';
  static readonly dangerBg: string = '#FCECEA';
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

/** 阴影：米家式「卡片浮起」用极轻投影，替代生硬的描边 */
export class ShadowToken {
  static readonly cardRadius: number = 12;
  static readonly cardColor: string = '#0F000000';
  static readonly cardOffsetY: number = 2;
}
