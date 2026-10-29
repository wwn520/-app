/// 色彩模式 → IPP print-color-mode。
enum ColorMode {
  grayscale, // 黑白（灰度）→ monochrome
  color, // 彩色 → color
}

/// 纸张尺寸（P2 可扩展 a5 / photo）。
enum PaperSize {
  a4, // 默认 A4
}

/// 打印质量档位 → IPP 分辨率/质量。
enum PrintQuality {
  draft, // 草稿
  normal, // 标准
  high, // 高质量
}

/// 双面打印（P2 可扩展 twoSidedLongEdge）。
enum PrintSides {
  oneSided, // 单面
}

/// 打印设置。默认 A4 / 黑白 / 标准 / 单面 / 1 份。
class PrintSettings {
  final PaperSize paper; // 默认 a4
  final ColorMode colorMode; // 默认 grayscale
  final PrintQuality quality; // 默认 normal
  final PrintSides sides; // 默认 oneSided
  final int copies; // 默认 1

  const PrintSettings({
    this.paper = PaperSize.a4,
    this.colorMode = ColorMode.grayscale,
    this.quality = PrintQuality.normal,
    this.sides = PrintSides.oneSided,
    this.copies = 1,
  });

  /// 不可变拷贝。
  PrintSettings copyWith({
    PaperSize? paper,
    ColorMode? colorMode,
    PrintQuality? quality,
    PrintSides? sides,
    int? copies,
  }) {
    return PrintSettings(
      paper: paper ?? this.paper,
      colorMode: colorMode ?? this.colorMode,
      quality: quality ?? this.quality,
      sides: sides ?? this.sides,
      copies: copies ?? this.copies,
    );
  }

  /// 序列化为 JSON（持久化）。
  Map<String, dynamic> toJson() => {
        'paper': paper.name,
        'colorMode': colorMode.name,
        'quality': quality.name,
        'sides': sides.name,
        'copies': copies,
      };

  /// 从 JSON 反序列化（带默认值兜底，防止旧数据缺字段）。
  factory PrintSettings.fromJson(Map<String, dynamic> json) {
    PaperSize paper = PaperSize.a4;
    ColorMode colorMode = ColorMode.grayscale;
    PrintQuality quality = PrintQuality.normal;
    PrintSides sides = PrintSides.oneSided;
    int copies = 1;
    try {
      paper = PaperSize.values.byName(json['paper'] as String? ?? 'a4');
    } catch (_) {}
    try {
      colorMode =
          ColorMode.values.byName(json['colorMode'] as String? ?? 'grayscale');
    } catch (_) {}
    try {
      quality =
          PrintQuality.values.byName(json['quality'] as String? ?? 'normal');
    } catch (_) {}
    try {
      sides = PrintSides.values.byName(json['sides'] as String? ?? 'oneSided');
    } catch (_) {}
    if (json['copies'] is int) copies = (json['copies'] as int?) ?? 1;
    return PrintSettings(
      paper: paper,
      colorMode: colorMode,
      quality: quality,
      sides: sides,
      copies: copies,
    );
  }
}
