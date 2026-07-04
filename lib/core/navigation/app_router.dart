import 'package:flutter/material.dart';
import 'package:advance_media_kb/core/design_system/app_theme.dart';
import 'package:advance_media_kb/screens/home_screen.dart';
import 'package:advance_media_kb/screens/settings_screen.dart';
import 'package:advance_media_kb/widgets/viewer/viewer_page.dart';
import 'package:advance_media_kb/src/rust/api/media.dart' as media_api;

/// 搜索覆盖层（暂用 media_screen 内的 _SearchOverlay；预留接口）
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const _SearchOverlayPlaceholder();
  }
}

class _SearchOverlayPlaceholder extends StatelessWidget {
  const _SearchOverlayPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: const Center(child: Text('请使用媒体页搜索入口')),
    );
  }
}

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

/// 路由生成器 - 支持覆盖层动画（Skill-09 §3）
///
/// 路由表：
/// - '/'              → HomeScreen
/// - '/search'        → SearchOverlay
/// - '/settings'      → SettingsScreen
/// - '/media_viewer'  → ViewerPage（需 arguments: media + mediaList）
Route<dynamic>? generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return _buildOverlayRoute(const HomeScreen());
    case AppRoutes.search:
      return _buildOverlayRoute(const SearchScreen());
    case AppRoutes.settings:
      return _buildOverlayRoute(const SettingsScreen());
    case AppRoutes.mediaViewer:
      final args = settings.arguments as Map<String, dynamic>?;
      return _buildOverlayRoute(
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

/// 内部辅助：构建带覆盖层动画的路由
Route<T> _buildOverlayRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
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
