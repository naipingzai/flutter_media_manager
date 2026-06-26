import 'package:flutter/material.dart';
import 'package:advance_media_kb/core/design_system/app_theme.dart';

/// Skill-09: 应用壳与导航规范
/// 覆盖层路由管理器 - 所有非主页面以覆盖层形式从右侧滑入

class AppRouter {
  AppRouter._();

  /// 通用覆盖层导航 - 从右侧滑入
  static Future<T?> pushOverlay<T>(
    BuildContext context, {
    required Widget page,
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        fullscreenDialog: fullscreenDialog,
        transitionDuration: AppAnimation.overlaySlideIn,
        reverseTransitionDuration: AppAnimation.overlaySlideOut,
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: AppAnimation.slideInCurve,
            reverseCurve: AppAnimation.slideOutCurve,
          );

          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: FadeTransition(
              opacity: Tween<double>(
                begin: 0.0,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
              )),
              child: child,
            ),
          );
        },
      ),
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

/// 路由生成器 - 支持覆盖层动画
Route<dynamic>? generateRoute(RouteSettings settings) {
  // 路由参数通过 arguments 传递
  // 具体页面路由在各自的 screen 文件中定义
  return null;
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
