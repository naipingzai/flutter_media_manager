import 'package:flutter/material.dart';

/// AdvanceMediaKB 设计系统 - 主题定义
/// 遵循 Skill-03: 浅色/深色主题色板、字体排版、间距、尺寸、动画常量
class AppTheme {
  AppTheme._();

  // ─── 浅色主题色板 ───
  static const Color lightPrimary = Color(0xFF2196F3);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFBBDEFB);
  static const Color lightOnPrimaryContainer = Color(0xFF0D47A1);
  static const Color lightSecondary = Color(0xFF03DAC5);
  static const Color lightOnSecondary = Color(0xFF000000);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFE3F2FD);
  static const Color lightOnSurface = Color(0xFF212121);
  static const Color lightOnSurfaceVariant = Color(0xFF757575);
  static const Color lightError = Color(0xFFB00020);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightOutline = Color(0xFFBDBDBD);
  static const Color lightScrim = Color(0x52000000);

  // ─── 深色主题色板 ───
  static const Color darkPrimary = Color(0xFF90CAF9);
  static const Color darkOnPrimary = Color(0xFF003258);
  static const Color darkPrimaryContainer = Color(0xFF1565C0);
  static const Color darkOnPrimaryContainer = Color(0xFFE3F2FD);
  static const Color darkSecondary = Color(0xFF03DAC5);
  static const Color darkOnSecondary = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurfaceVariant = Color(0xFF1E1E1E);
  static const Color darkOnSurface = Color(0xFFE0E0E0);
  static const Color darkOnSurfaceVariant = Color(0xFF9E9E9E);
  static const Color darkError = Color(0xFFCF6679);
  static const Color darkOnError = Color(0xFF000000);
  static const Color darkOutline = Color(0xFF424242);
  static const Color darkScrim = Color(0x52000000);

  // ─── 浅色主题 ───
  static ThemeData lightTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: lightPrimary,
      onPrimary: lightOnPrimary,
      primaryContainer: lightPrimaryContainer,
      onPrimaryContainer: lightOnPrimaryContainer,
      secondary: lightSecondary,
      onSecondary: lightOnSecondary,
      surface: lightSurface,
      onSurface: lightOnSurface,
      error: lightError,
      onError: lightOnError,
      outline: lightOutline,
      surfaceContainerHighest: lightSurfaceVariant,
      onSurfaceVariant: lightOnSurfaceVariant,
    );

    return _buildTheme(colorScheme);
  }

  // ─── 深色主题 ───
  static ThemeData darkTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: darkOnPrimary,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: darkOnPrimaryContainer,
      secondary: darkSecondary,
      onSecondary: darkOnSecondary,
      surface: darkSurface,
      onSurface: darkOnSurface,
      error: darkError,
      onError: darkOnError,
      outline: darkOutline,
      surfaceContainerHighest: darkSurfaceVariant,
      onSurfaceVariant: darkOnSurfaceVariant,
    );

    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: null, // 使用系统字体
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        color: colorScheme.surface,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: colorScheme.surface,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: const CircleBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primary,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w500);
          }
          return TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12);
        }),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    );
  }
}

/// 间距常量 - Skill-03 §3.1
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2; // 网格项间距
  static const double xs = 4;  // 图标与文字间距
  static const double sm = 8;  // 组件内部间距
  static const double md = 12; // 列表项间距
  static const double lg = 16; // 页面水平边距
  static const double xl = 24; // 大块内容间距
  static const double xxl = 32; // 章节间距
}

/// 尺寸常量 - Skill-03 §3.2
class AppSize {
  AppSize._();

  static const double iconSmall = 14;
  static const double iconMedium = 24;
  static const double iconLarge = 36;
  static const double iconXLarge = 48;
  static const double iconXxl = 64;
  static const double touchTargetMin = 48;
  static const double thumbnailSize = 256;
  static const double bottomBarHeight = 56;
  static const double topBarHeight = 64;
  static const double bottomNavHeight = 80;
  static const double fabSize = 56;
  static const double checkCircleSize = 24;
  static const double borderWidthSelected = 3;
  static const double overlayOpacity = 0.3;
}

/// 圆角常量 - Skill-03 §3.2
class AppRadius {
  AppRadius._();

  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 28;
  static const double xxl = 16; // 统一卡片圆角
  static const double full = 100; // 胶囊形
}

/// 动画常量 - Skill-03 §4.1
class AppAnimation {
  AppAnimation._();

  static const Duration tabSwitchFadeIn = Duration(milliseconds: 250);
  static const Duration tabSwitchFadeOut = Duration(milliseconds: 200);
  static const Duration filterSwitchFadeIn = Duration(milliseconds: 220);
  static const Duration filterSwitchFadeOut = Duration(milliseconds: 180);
  static const Duration overlaySlideIn = Duration(milliseconds: 280);
  static const Duration overlaySlideOut = Duration(milliseconds: 220);
  static const Duration overlayFadeIn = Duration(milliseconds: 220);
  static const Duration overlayFadeOut = Duration(milliseconds: 180);
  static const Duration fabShow = Duration(milliseconds: 220);
  static const Duration fabHide = Duration(milliseconds: 180);
  static const Duration bottomBarShow = Duration(milliseconds: 200);
  static const Duration bottomBarHide = Duration(milliseconds: 150);
  static const Duration thumbnailCrossfade = Duration(milliseconds: 200);
  static const Duration thumbnailScaleIn = Duration(milliseconds: 150);

  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve slideInCurve = Curves.easeOut;
  static const Curve slideOutCurve = Curves.easeIn;
}

/// 视频时长格式化
String formatDuration(int milliseconds) {
  final seconds = (milliseconds / 1000).round();
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

/// 文件大小格式化
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
