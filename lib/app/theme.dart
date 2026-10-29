import 'package:flutter/material.dart';

/// 应用主题（Material 3 浅色；P2 暗黑模式预留）。
///
/// 设计基调：纯净、无广告位、清晰可读。
/// - ColorScheme.fromSeed 生成 M3 配色；
/// - 圆角统一 16、卡片阴影柔和；
/// - 主按钮加大加粗；文字层级分明。
class AppTheme {
  /// 主色（沉稳蓝绿，传达「可靠工具」质感）。
  static const Color primary = Color(0xFF1F6F6B);
  static const Color primaryLight = Color(0xFF4FA39C);
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Colors.white;
  static const Color onSurface = Color(0xFF1C1C1E);
  static const Color muted = Color(0xFF8A8A8E);
  static const Color success = Color(0xFF2E9E5B);
  static const Color danger = Color(0xFFD64545);

  /// 全局圆角。
  static const double radius = 16;

  /// 浅色主题数据。
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: primary);
    final baseText = Typography.material2021().black.apply(
          bodyColor: onSurface,
          displayColor: onSurface,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withOpacity(0.35),
          disabledForegroundColor: Colors.white70,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(48),
          side: BorderSide(color: primary.withOpacity(0.4)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 1.5,
        shadowColor: Colors.black.withOpacity(0.08),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withOpacity(0.06),
        thickness: 1,
      ),
      textTheme: baseText.copyWith(
        // 文字层级：标题加粗、正文常规、辅助信息弱化。
        titleLarge: baseText.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, color: onSurface),
        titleMedium: baseText.titleMedium
            ?.copyWith(fontWeight: FontWeight.w600, color: onSurface),
        bodyMedium: baseText.bodyMedium?.copyWith(color: onSurface),
        bodySmall: baseText.bodySmall?.copyWith(color: muted),
      ),
    );
  }
}
