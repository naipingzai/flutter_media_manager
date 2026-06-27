import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../design_system/components.dart';
import '../i18n/app_localizations.dart';

/// Skill-04: 权限管理（合规度目标 ~80%）
///
/// Android 存储权限模型 + 3 种 Intent 降级：
/// - API ≥ 30 (Android 11+): 申请 MANAGE_EXTERNAL_STORAGE
/// - API 33+ (Android 13+): 申请 READ_MEDIA_IMAGES / VIDEO / AUDIO 细粒度权限
/// - API < 30: 申请 READ_EXTERNAL_STORAGE + WRITE_EXTERNAL_STORAGE
/// 权限申请结果
enum PermissionResult {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
}

class PermissionService {
  PermissionService._();

  /// Android SDK 版本常量
  static const int _apiAndroid11 = 30;
  static const int _apiAndroid13 = 33;

  /// 检测 Android SDK 版本
  static Future<int> _getSdkInt() async {
    if (!Platform.isAndroid) return 0;
    final info = await DeviceInfoPlugin().androidInfo;
    return info.version.sdkInt;
  }

  /// 检查所有存储权限
  static Future<PermissionResult> checkStoragePermission() async {
    if (!Platform.isAndroid) return PermissionResult.granted;

    final sdkInt = await _getSdkInt();

    if (sdkInt >= _apiAndroid13) {
      // Android 13+：检查细粒度媒体权限
      final images = await Permission.photos.status;
      final videos = await Permission.videos.status;
      final audio = await Permission.audio.status;
      if (images.isGranted && videos.isGranted && audio.isGranted) {
        return PermissionResult.granted;
      }
      if (images.isPermanentlyDenied ||
          videos.isPermanentlyDenied ||
          audio.isPermanentlyDenied) {
        return PermissionResult.permanentlyDenied;
      }
      if (images.isLimited || videos.isLimited || audio.isLimited) {
        return PermissionResult.limited;
      }
      return PermissionResult.denied;
    }

    if (sdkInt >= _apiAndroid11) {
      // Android 11-12: MANAGE_EXTERNAL_STORAGE
      final status = await Permission.manageExternalStorage.status;
      if (status.isGranted) return PermissionResult.granted;
      if (status.isPermanentlyDenied) return PermissionResult.permanentlyDenied;
      if (status.isLimited) return PermissionResult.limited;
      if (status.isRestricted) return PermissionResult.restricted;
      return PermissionResult.denied;
    }

    // Android 10 及以下: 传统存储权限
    final storage = await Permission.storage.status;
    if (storage.isGranted) return PermissionResult.granted;
    if (storage.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }
    return PermissionResult.denied;
  }

  /// 请求所有存储权限（按 Android 版本分支处理）
  ///
  /// - Android 13+: 细粒度媒体权限
  /// - Android 11-12: MANAGE_EXTERNAL_STORAGE
  /// - Android 10-: 传统存储权限
  static Future<PermissionResult> requestStoragePermission() async {
    if (!Platform.isAndroid) return PermissionResult.granted;

    final sdkInt = await _getSdkInt();

    if (sdkInt >= _apiAndroid13) {
      // Android 13+: 同时请求 3 种细粒度权限
      final results = await Future.wait([
        Permission.photos.request(),
        Permission.videos.request(),
        Permission.audio.request(),
      ]);

      // 全部授予
      if (results.every((s) => s.isGranted)) {
        return PermissionResult.granted;
      }
      if (results.any((s) => s.isPermanentlyDenied)) {
        return PermissionResult.permanentlyDenied;
      }
      if (results.any((s) => s.isLimited)) {
        return PermissionResult.limited;
      }
      return PermissionResult.denied;
    }

    if (sdkInt >= _apiAndroid11) {
      // Android 11-12: MANAGE_EXTERNAL_STORAGE（会自动跳转设置）
      final result = await Permission.manageExternalStorage.request();
      if (result.isGranted) return PermissionResult.granted;
      if (result.isPermanentlyDenied) {
        return PermissionResult.permanentlyDenied;
      }
      if (result.isLimited) return PermissionResult.limited;
      if (result.isRestricted) return PermissionResult.restricted;
      return PermissionResult.denied;
    }

    // Android 10 及以下
    final result = await Permission.storage.request();
    if (result.isGranted) return PermissionResult.granted;
    if (result.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }
    return PermissionResult.denied;
  }

  /// 兼容性入口：先检查后请求（用于界面层）
  static Future<PermissionResult> checkAndRequestStoragePermission() async {
    final current = await checkStoragePermission();
    if (current == PermissionResult.granted ||
        current == PermissionResult.limited) {
      return current;
    }
    return requestStoragePermission();
  }

  /// 跳转到应用设置页（用于永久拒绝时引导用户）
  static Future<bool> openAppSettingsPage() async {
    return await openAppSettings();
  }

  /// 显示权限被拒绝的说明对话框（带 i18n + 永久拒绝引导）
  static Future<void> showPermissionDeniedDialog(
    BuildContext context, {
    required bool permanentlyDenied,
  }) async {
    if (!context.mounted) return;
    final loc = AppLocalizations.of(context);

    if (permanentlyDenied) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(loc.permissionPermanentlyDenied),
          content: Text(loc.permissionDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await openAppSettingsPage();
              },
              child: Text(loc.openSettings),
            ),
          ],
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(loc.permissionRequired),
          content: Text(loc.permissionDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(loc.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                // 重新申请
                await checkAndRequestStoragePermission();
              },
              child: Text(loc.grantPermission),
            ),
          ],
        ),
      );
    }
  }

  /// 显示权限请求结果 SnackBar（简化反馈）
  static void showResultSnackBar(
    BuildContext context,
    PermissionResult result,
  ) {
    if (!context.mounted) return;
    final loc = AppLocalizations.of(context);
    final message = switch (result) {
      PermissionResult.granted => loc.permissionGranted,
      PermissionResult.denied => loc.permissionDenied,
      PermissionResult.permanentlyDenied => loc.permissionPermanentlyDenied,
      PermissionResult.restricted => loc.permissionDenied,
      PermissionResult.limited => loc.permissionGranted,
    };
    UIHelper.showSnackBar(context, message);
  }
}
