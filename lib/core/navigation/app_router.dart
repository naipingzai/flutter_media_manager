import 'package:flutter/material.dart';
import 'package:flutter_media_knowledge_base/core/design_system/app_theme.dart';
import 'package:flutter_media_knowledge_base/ui/home/home_screen.dart';
import 'package:flutter_media_knowledge_base/ui/search/search_screen.dart';
import 'package:flutter_media_knowledge_base/ui/settings/settings_screen.dart';
import 'package:flutter_media_knowledge_base/ui/viewer/viewer_page.dart';
import 'package:flutter_media_knowledge_base/bridge/native/api/media.dart'
    as media_api;

/// Skill-09: 应用壳与导航规范
/// 覆盖层路由管理器 - 非主页面以卡片覆盖层/全屏覆盖层形式呈现

class AppRouter {
  AppRouter._();

  /// 全屏覆盖层导航 - 从右侧滑入（媒体查看器等需要全屏的页面）
  static Future<T?> pushOverlay<T>(
    BuildContext context, {
    required Widget page,
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).push<T>(
      _buildFullScreenOverlayRoute(page, fullscreenDialog: fullscreenDialog),
    );
  }

  /// 非全屏卡片覆盖层导航 - 从右侧滑入，圆角矩形
  static Future<T?> pushCardOverlay<T>(
    BuildContext context, {
    required Widget page,
  }) {
    return Navigator.of(context).push<T>(
      _buildCardOverlayRoute(page),
    );
  }

  /// 带路由名称的覆盖层导航
  static Future<T?> pushNamedOverlay<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  /// 关闭当前覆盖层
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop<T>(result);
  }
}

/// Skill-09 §3 - 路由定义
/// 路由路径表
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String albumDetail = '/album_detail';
  static const String tagMedia = '/tag_media';
  static const String mediaDetail = '/media_detail';
  static const String noteList = '/note_list';
  static const String noteEdit = '/note_edit';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String mediaViewer = '/media_viewer';
  static const String fileBrowser = '/file_browser';
}

/// 路由生成器 - 支持覆盖层动画（Skill-09 §3）
///
/// 路由表：
/// - '/'              → HomeScreen（全屏）
/// - '/search'        → SearchScreen（卡片覆盖层）
/// - '/settings'      → SettingsScreen（卡片覆盖层）
/// - '/media_viewer'  → ViewerPage（全屏覆盖层，需 arguments: media + mediaList）
Route<dynamic>? generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return _buildFullScreenOverlayRoute(const HomeScreen());
    case AppRoutes.search:
      return _buildCardOverlayRoute(const SearchScreen());
    case AppRoutes.settings:
      return _buildCardOverlayRoute(const SettingsScreen());
    case AppRoutes.mediaViewer:
      final args = settings.arguments as Map<String, dynamic>?;
      return _buildFullScreenOverlayRoute(
        ViewerPage(
          initialMedia: args?['media'] as dynamic,
          mediaList: (args?['mediaList'] as List<dynamic>?)
                  ?.cast<media_api.MediaItem>()
                  .toList() ??
              const <media_api.MediaItem>[],
        ),
      );
    default:
      return null;
  }
}

/// 内部辅助：全屏覆盖层
Route<T> _buildFullScreenOverlayRoute<T>(Widget page,
    {bool fullscreenDialog = false}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: AppAnimation.overlaySlideIn,
    reverseTransitionDuration: AppAnimation.overlaySlideOut,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppAnimation.slideInCurve,
        reverseCurve: AppAnimation.slideOutCurve,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          ).drive(Tween<double>(begin: 0.0, end: 1.0)),
          child: child,
        ),
      );
    },
  );
}

/// 内部辅助：非全屏圆角卡片覆盖层
Route<T> _buildCardOverlayRoute<T>(Widget page) {
  const double radius = AppRadius.xxl;
  const double margin = 12.0;

  return PageRouteBuilder<T>(
    opaque: false,
    barrierDismissible: true,
    transitionDuration: AppAnimation.overlaySlideIn,
    reverseTransitionDuration: AppAnimation.overlaySlideOut,
    pageBuilder: (context, animation, secondaryAnimation) {
      final cs = Theme.of(context).colorScheme;
      final mq = MediaQuery.of(context);
      return GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Material(
          color: cs.scrim.withValues(alpha: 0.35),
          child: SafeArea(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(margin),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(radius),
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: mq.size.width - margin * 2,
                      height: mq.size.height - margin * 2 - mq.padding.vertical,
                      color: cs.surface,
                      child: page,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppAnimation.slideInCurve,
        reverseCurve: AppAnimation.slideOutCurve,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          ).drive(Tween<double>(begin: 0.0, end: 1.0)),
          child: child,
        ),
      );
    },
  );
}

/// Skill-09 §6 - TopAppBar 组件
enum TopAppBarMode { normal, multiSelect, overlay }

/// 普通模式 TopAppBar
PreferredSizeWidget buildNormalAppBar(
  BuildContext context, {
  required String title,
  VoidCallback? onSearchTap,
  VoidCallback? onSettingsTap,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return AppBar(
    leading: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Icon(Icons.photo_camera, color: colorScheme.primary),
    ),
    title: Text(title),
    actions: [
      if (onSearchTap != null)
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: onSearchTap,
        ),
      if (onSettingsTap != null)
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: onSettingsTap,
        ),
    ],
  );
}

/// 多选模式 TopAppBar
PreferredSizeWidget buildMultiSelectAppBar(
  BuildContext context, {
  required int selectedCount,
  VoidCallback? onSelectAll,
  VoidCallback? onCancel,
}) {
  return AppBar(
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: onCancel ?? () => Navigator.of(context).pop(),
    ),
    title: Text('已选中 $selectedCount 项'),
    actions: [
      if (onSelectAll != null)
        TextButton(
          onPressed: onSelectAll,
          child: const Text('全选'),
        ),
      if (onCancel != null)
        TextButton(
          onPressed: onCancel,
          child: const Text('取消'),
        ),
    ],
  );
}

/// 覆盖层模式 TopAppBar
PreferredSizeWidget buildOverlayAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
}) {
  return AppBar(
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => Navigator.of(context).pop(),
    ),
    title: Text(title),
    actions: actions,
  );
}
