import 'package:flutter/material.dart';
import 'package:flutter_media_manager/ui/home/home_screen.dart';
import 'package:flutter_media_manager/ui/settings/settings_screen.dart';
import 'package:flutter_media_manager/ui/viewer/viewer_page.dart';
import 'package:flutter_media_manager/bridge/native/api/media.dart'
    as media_api;

/// 应用路由管理器
/// 统一所有页面过渡动画：底部向上滑入 + 淡入

class AppRouter {
  AppRouter._();

  /// 标准子页面导航 - 底部向上滑入
  static Future<T?> push<T>(
    BuildContext context, {
    required Widget page,
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).push<T>(
      _buildRoute(page, fullscreenDialog: fullscreenDialog),
    );
  }

  /// 关闭当前页面
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop<T>(result);
  }
}

/// 路由路径表
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String settings = '/settings';
  static const String mediaViewer = '/media_viewer';
}

/// 路由生成器
Route<dynamic>? generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.home:
      return _buildRoute(const HomeScreen());
    case AppRoutes.settings:
      return _buildRoute(const SettingsScreen());
    case AppRoutes.mediaViewer:
      final args = settings.arguments as Map<String, dynamic>?;
      return _buildRoute(
        AppMediaViewer(
          media: args?['media'] as dynamic,
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

/// 统一页面过渡动画 - 底部向上滑入 + 淡入
Route<T> _buildRoute<T>(Widget page, {bool fullscreenDialog = false}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.3),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
            ),
          ),
          child: child,
        ),
      );
    },
  );
}
