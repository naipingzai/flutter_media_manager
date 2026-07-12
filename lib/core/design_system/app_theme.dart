/// 文件坐标: lib/core/design_system/app_theme.dart
/// 作用:     Material 3 设计系统常量与主题工厂
/// 说明:     定义间距、尺寸、圆角、动画、色板、文本样式和完整 ThemeData。

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

/// 第 4 行: 间距常量 - Material 3 4dp 网格
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // M3 标准间距别名
  static const double m3GapXs = xs;
  static const double m3GapSm = sm;
  static const double m3GapMd = md;
  static const double m3GapLg = lg;
  static const double m3GapXl = xl;
  static const double m3GapXxl = xxl;
  static const double m3TouchTarget = 48;
}

/// 尺寸常量
class AppSize {
  AppSize._();

  static const double iconSmall = 14;
  static const double iconMedium = 20;
  static const double iconLarge = 24;
  static const double iconXLarge = 36;
  static const double iconXxl = 64;
  static const double touchTargetMin = 48;
  static const double thumbnailSize = 256;
  static const double bottomBarHeight = 56;
  static const double topBarHeight = 64;
  static const double bottomNavHeight = 80;
  static const double fabSize = 56;
  static const double fabExtendedHeight = 56;
  static const double fabSmallSize = 40;
  static const double checkCircleSize = 24;
  static const double borderWidthSelected = 3;
  static const double borderWidthDefault = 1;
  static const double borderWidthStrong = 2;
  static const double overlayOpacity = 0.24;
  static const double elevation1 = 1;
  static const double elevation2 = 3;
  static const double elevation3 = 6;
  static const double elevation4 = 8;
  static const double elevation5 = 12;
  static const double appBarElevation = 0;
  static const double appBarScrolledElevation = 3;
  static const double searchBarHeight = 56;
  static const double chipHeight = 32;
  static const double iconButtonSize = 40;
  static const double iconButtonSmallSize = 32;
}

/// 圆角常量 - Material 3 形状系统
class AppRadius {
  AppRadius._();

  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 32;
  static const double full = 100;

  // M3 标准形状别名
  static const double m3CornerNone = none;
  static const double m3CornerExtraSmall = 4;
  static const double m3CornerSmall = 8;
  static const double m3CornerMedium = 12;
  static const double m3CornerLarge = 16;
  static const double m3CornerExtraLarge = 28;
  static const double m3CornerFull = full;
}

/// 文本样式常量
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle body = TextStyle(fontSize: 14);
  static const TextStyle caption = TextStyle(fontSize: 12);
}

/// 动画常量 - Material 3 emphasized motion
class AppAnimation {
  AppAnimation._();

  // M3 标准时长
  static const Duration m3Short1 = Duration(milliseconds: 50);
  static const Duration m3Short2 = Duration(milliseconds: 100);
  static const Duration m3Short3 = Duration(milliseconds: 150);
  static const Duration m3Short4 = Duration(milliseconds: 200);
  static const Duration m3Medium1 = Duration(milliseconds: 250);
  static const Duration m3Medium2 = Duration(milliseconds: 300);
  static const Duration m3Medium3 = Duration(milliseconds: 350);
  static const Duration m3Medium4 = Duration(milliseconds: 400);
  static const Duration m3Long1 = Duration(milliseconds: 450);
  static const Duration m3Long2 = Duration(milliseconds: 500);
  static const Duration m3Long3 = Duration(milliseconds: 550);
  static const Duration m3Long4 = Duration(milliseconds: 600);

  // 应用业务时长
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
  static const Duration cardMorphIn = Duration(milliseconds: 350);
  static const Duration sheetShow = Duration(milliseconds: 250);
  static const Duration sheetHide = Duration(milliseconds: 200);

  // 缓动曲线
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve slideInCurve = Curves.easeOutCubic;
  static const Curve slideOutCurve = Curves.easeInCubic;
  static const Curve emphasizedDecelerate = Curves.easeOutExpo;
  static const Curve emphasizedAccelerate = Curves.easeInExpo;
  static const Curve standardCurve = Curves.easeInOutCubic;
}

/// 视频时长格式化 (兼容 BigInt/int)
String formatDuration(Object milliseconds) {
  final ms =
      (milliseconds is BigInt) ? milliseconds.toInt() : milliseconds as int;
  final seconds = (ms / 1000).round();
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

/// 文件大小格式化 (兼容 BigInt/int)
String formatFileSize(Object bytes) {
  final b = (bytes is BigInt) ? bytes.toInt() : bytes as int;
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024)
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class AppTheme {
  AppTheme._();

  // ─── 品牌种子色 ───
  static const Color seedColor = Color(0xFF006C4C);

  // ─── 浅色主题色板 ───
  static const Color lightPrimary = Color(0xFF006C4C);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFF89F8C7);
  static const Color lightOnPrimaryContainer = Color(0xFF002113);
  static const Color lightSecondary = Color(0xFF4C6358);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFEDF2EB);
  static const Color lightOnSecondaryContainer = Color(0xFF082017);
  static const Color lightTertiary = Color(0xFF3E628B);
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightTertiaryContainer = Color(0xFFCDE5FF);
  static const Color lightOnTertiaryContainer = Color(0xFF001D33);
  static const Color lightError = Color(0xFFBA1A1A);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFFFDAD6);
  static const Color lightOnErrorContainer = Color(0xFF410002);
  static const Color lightSurfaceDim = Color(0xFFDBE5DD);
  static const Color lightSurface = Color(0xFFFBFDF8);
  static const Color lightSurfaceBright = Color(0xFFFBFDF8);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF1F4ED);
  static const Color lightSurfaceContainer = Color(0xFFEBEFE8);
  static const Color lightSurfaceContainerHigh = Color(0xFFE5E9E2);
  static const Color lightSurfaceContainerHighest = Color(0xFFDFE3DC);
  static const Color lightOnSurface = Color(0xFF191C1A);
  static const Color lightOnSurfaceVariant = Color(0xFF404942);
  static const Color lightOutline = Color(0xFF707973);
  static const Color lightOutlineVariant = Color(0xFFC0C9C0);
  static const Color lightInverseSurface = Color(0xFF2E312F);
  static const Color lightInverseOnSurface = Color(0xFFEFF1ED);
  static const Color lightInversePrimary = Color(0xFF6CDBAC);
  static const Color lightShadow = Color(0xFF000000);
  static const Color lightScrim = Color(0xFF000000);
  static const Color lightSurfaceTint = lightPrimary;

  // ─── 深色主题色板 ───
  static const Color darkPrimary = Color(0xFF6CDBAC);
  static const Color darkOnPrimary = Color(0xFF003824);
  static const Color darkPrimaryContainer = Color(0xFF005237);
  static const Color darkOnPrimaryContainer = Color(0xFF89F8C7);
  static const Color darkSecondary = Color(0xFFB3CCBE);
  static const Color darkOnSecondary = Color(0xFF1F352B);
  static const Color darkSecondaryContainer = Color(0xFF354B41);
  static const Color darkOnSecondaryContainer = Color(0xFFEDF2EB);
  static const Color darkTertiary = Color(0xFF9CCBFB);
  static const Color darkOnTertiary = Color(0xFF003355);
  static const Color darkTertiaryContainer = Color(0xFF004A78);
  static const Color darkOnTertiaryContainer = Color(0xFFCDE5FF);
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkOnError = Color(0xFF690005);
  static const Color darkErrorContainer = Color(0xFF93000A);
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);
  static const Color darkSurfaceDim = Color(0xFF101412);
  static const Color darkSurface = Color(0xFF101412);
  static const Color darkSurfaceBright = Color(0xFF353A37);
  static const Color darkSurfaceContainerLowest = Color(0xFF0B0F0D);
  static const Color darkSurfaceContainerLow = Color(0xFF181C1A);
  static const Color darkSurfaceContainer = Color(0xFF1C201E);
  static const Color darkSurfaceContainerHigh = Color(0xFF262B28);
  static const Color darkSurfaceContainerHighest = Color(0xFF313633);
  static const Color darkOnSurface = Color(0xFFE1E3DF);
  static const Color darkOnSurfaceVariant = Color(0xFFC0C9C0);
  static const Color darkOutline = Color(0xFF8A938B);
  static const Color darkOutlineVariant = Color(0xFF404942);
  static const Color darkInverseSurface = Color(0xFFE1E3DF);
  static const Color darkInverseOnSurface = Color(0xFF2E312F);
  static const Color darkInversePrimary = Color(0xFF006C4C);
  static const Color darkShadow = Color(0xFF000000);
  static const Color darkScrim = Color(0xFF000000);
  static const Color darkSurfaceTint = darkPrimary;

  // ─── 完整 ColorScheme 工厂 ───
  static ColorScheme lightColorScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: lightPrimary,
      onPrimary: lightOnPrimary,
      primaryContainer: lightPrimaryContainer,
      onPrimaryContainer: lightOnPrimaryContainer,
      secondary: lightSecondary,
      onSecondary: lightOnSecondary,
      secondaryContainer: lightSecondaryContainer,
      onSecondaryContainer: lightOnSecondaryContainer,
      tertiary: lightTertiary,
      onTertiary: lightOnTertiary,
      tertiaryContainer: lightTertiaryContainer,
      onTertiaryContainer: lightOnTertiaryContainer,
      error: lightError,
      onError: lightOnError,
      errorContainer: lightErrorContainer,
      onErrorContainer: lightOnErrorContainer,
      surface: lightSurface,
      onSurface: lightOnSurface,
      surfaceContainerLowest: lightSurfaceContainerLowest,
      surfaceContainerLow: lightSurfaceContainerLow,
      surfaceContainer: lightSurfaceContainer,
      surfaceContainerHigh: lightSurfaceContainerHigh,
      surfaceContainerHighest: lightSurfaceContainerHighest,
      surfaceTint: lightSurfaceTint,
      onSurfaceVariant: lightOnSurfaceVariant,
      outline: lightOutline,
      outlineVariant: lightOutlineVariant,
      inverseSurface: lightInverseSurface,
      onInverseSurface: lightInverseOnSurface,
      inversePrimary: lightInversePrimary,
      shadow: lightShadow,
      scrim: lightScrim,
    );
  }

  static ColorScheme darkColorScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: darkOnPrimary,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: darkOnPrimaryContainer,
      secondary: darkSecondary,
      onSecondary: darkOnSecondary,
      secondaryContainer: darkSecondaryContainer,
      onSecondaryContainer: darkOnSecondaryContainer,
      tertiary: darkTertiary,
      onTertiary: darkOnTertiary,
      tertiaryContainer: darkTertiaryContainer,
      onTertiaryContainer: darkOnTertiaryContainer,
      error: darkError,
      onError: darkOnError,
      errorContainer: darkErrorContainer,
      onErrorContainer: darkOnErrorContainer,
      surface: darkSurface,
      onSurface: darkOnSurface,
      surfaceContainerLowest: darkSurfaceContainerLowest,
      surfaceContainerLow: darkSurfaceContainerLow,
      surfaceContainer: darkSurfaceContainer,
      surfaceContainerHigh: darkSurfaceContainerHigh,
      surfaceContainerHighest: darkSurfaceContainerHighest,
      surfaceTint: darkSurfaceTint,
      onSurfaceVariant: darkOnSurfaceVariant,
      outline: darkOutline,
      outlineVariant: darkOutlineVariant,
      inverseSurface: darkInverseSurface,
      onInverseSurface: darkInverseOnSurface,
      inversePrimary: darkInversePrimary,
      shadow: darkShadow,
      scrim: darkScrim,
    );
  }

  // ─── 完整 Typography（Material 3 类型尺度） ───
  static TextTheme textTheme(ColorScheme cs) {
    final base = Typography.material2021(platform: TargetPlatform.android);
    return base.black.apply(
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
    );
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final tt = textTheme(colorScheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: tt,
      fontFamily: null,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 0,
        scrolledUnderElevation: 3,
        centerTitle: false,
        titleTextStyle: tt.titleLarge?.copyWith(color: colorScheme.onSurface),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurface),
        shape: const Border(),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        elevation: 3,
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        titleTextStyle:
            tt.headlineSmall?.copyWith(color: colorScheme.onSurface),
        contentTextStyle:
            tt.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: colorScheme.surfaceTint,
        modalBackgroundColor: colorScheme.surfaceContainerLow,
        modalElevation: 1,
        elevation: 1,
        showDragHandle: true,
        dragHandleColor: colorScheme.onSurfaceVariant,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 3,
        focusElevation: 3,
        hoverElevation: 4,
        highlightElevation: 4,
        extendedTextStyle:
            tt.labelLarge?.copyWith(color: colorScheme.onPrimaryContainer),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        selectedColor: colorScheme.secondaryContainer,
        secondarySelectedColor: colorScheme.secondaryContainer,
        disabledColor: colorScheme.surfaceContainerLow.withValues(alpha: 0.38),
        labelStyle: tt.labelLarge?.copyWith(color: colorScheme.onSurface),
        secondaryLabelStyle:
            tt.labelLarge?.copyWith(color: colorScheme.onSecondaryContainer),
        iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        deleteIconColor: colorScheme.onSurfaceVariant,
        checkmarkColor: colorScheme.onSecondaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(color: colorScheme.outline),
        ),
        side: BorderSide(color: colorScheme.outline),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        elevation: 0,
        pressElevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        titleTextStyle: tt.bodyLarge?.copyWith(color: colorScheme.onSurface),
        subtitleTextStyle:
            tt.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 8,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full)),
        tileColor: Colors.transparent,
        selectedTileColor: colorScheme.secondaryContainer,
        selectedColor: colorScheme.onSecondaryContainer,
        horizontalTitleGap: 16,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: colorScheme.surfaceTint,
        indicatorColor: colorScheme.secondaryContainer,
        elevation: 0,
        height: 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
                color: colorScheme.onSecondaryContainer, size: 24);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tt.labelMedium?.copyWith(
                color: colorScheme.onSurface, fontWeight: FontWeight.w600);
          }
          return tt.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant);
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: colorScheme.outlineVariant,
        labelStyle: tt.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        unselectedLabelStyle: tt.titleSmall,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle:
            tt.bodyMedium?.copyWith(color: colorScheme.onInverseSurface),
        actionTextColor: colorScheme.inversePrimary,
        disabledActionTextColor:
            colorScheme.onInverseSurface.withValues(alpha: 0.38),
        elevation: 3,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: tt.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: tt.bodyLarge?.copyWith(color: colorScheme.primary),
        hintStyle: tt.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        valueIndicatorColor: colorScheme.primary,
        valueIndicatorTextStyle:
            tt.labelMedium?.copyWith(color: colorScheme.onPrimary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected))
            return colorScheme.onPrimary;
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return colorScheme.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        side: BorderSide(color: colorScheme.outline, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
        circularTrackColor: colorScheme.surfaceContainerHighest,
        linearMinHeight: 4,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withValues(alpha: 0.38);
            }
            return colorScheme.onSurfaceVariant;
          }),
          shape: WidgetStateProperty.all(const CircleBorder()),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withValues(alpha: 0.38);
            }
            return colorScheme.primary;
          }),
          textStyle: WidgetStateProperty.all(tt.labelLarge),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full)),
          ),
          padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withValues(alpha: 0.12);
            }
            return colorScheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withValues(alpha: 0.38);
            }
            return colorScheme.onPrimary;
          }),
          textStyle: WidgetStateProperty.all(tt.labelLarge),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full)),
          ),
          padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return colorScheme.onSurface.withValues(alpha: 0.38);
            }
            return colorScheme.primary;
          }),
          textStyle: WidgetStateProperty.all(tt.labelLarge),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.12));
            }
            return BorderSide(color: colorScheme.outline);
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full)),
          ),
          padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
        ),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: colorScheme.surfaceTint,
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tt.labelLarge?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600);
          }
          return tt.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onSecondaryContainer);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: tt.bodySmall?.copyWith(color: colorScheme.onInverseSurface),
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(seconds: 2),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainer,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 3,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        textStyle: tt.bodyMedium?.copyWith(color: colorScheme.onSurface),
        labelTextStyle: WidgetStateProperty.all(
            tt.bodyMedium?.copyWith(color: colorScheme.onSurface)),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor:
            WidgetStateProperty.all(colorScheme.surfaceContainerHigh),
        surfaceTintColor: WidgetStateProperty.all(colorScheme.surfaceTint),
        elevation: WidgetStateProperty.all(0),
        textStyle: WidgetStateProperty.all(
            tt.bodyLarge?.copyWith(color: colorScheme.onSurface)),
        hintStyle: WidgetStateProperty.all(
            tt.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
        padding:
            WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
            side: BorderSide(color: colorScheme.outline),
          ),
        ),
        constraints: const BoxConstraints(minHeight: 56),
      ),
      searchViewTheme: SearchViewThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 3,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xxl)),
        headerTextStyle: tt.labelLarge?.copyWith(color: colorScheme.onSurface),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected))
              return colorScheme.secondaryContainer;
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected))
              return colorScheme.onSecondaryContainer;
            return colorScheme.onSurface;
          }),
          textStyle: WidgetStateProperty.all(tt.labelLarge),
          side: WidgetStateProperty.all(BorderSide(color: colorScheme.outline)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full)),
          ),
        ),
      ),
    );
  }

  // ─── 浅色主题 ───
  static ThemeData lightTheme({ColorScheme? dynamicScheme}) {
    final scheme = dynamicScheme?.harmonized() ?? lightColorScheme();
    return _buildTheme(scheme);
  }

  // ─── 深色主题 ───
  static ThemeData darkTheme({ColorScheme? dynamicScheme}) {
    final scheme = dynamicScheme?.harmonized() ?? darkColorScheme();
    return _buildTheme(scheme);
  }
}
