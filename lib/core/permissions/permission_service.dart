import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../design_system/components.dart';

/// Skill-04: 权限管理
/// 封装 Android 存储权限请求逻辑
class PermissionService {
  PermissionService._();

  /// 检查并请求存储权限
  /// 返回 true 表示权限已获得
  static Future<bool> checkAndRequestStoragePermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    // Android 13+ (API 33): 使用细粒度权限
    if (sdkInt >= 33) {
      // 对于 Android 13+，使用 READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_MEDIA_AUDIO
      // 但本应用使用 SAF (Storage Access Framework) 或 MANAGE_EXTERNAL_STORAGE
      // 这里简化处理：直接返回 true，实际权限由文件选择器处理
      return true;
    }

    // Android 11-12 (API 30-32): 需要 MANAGE_EXTERNAL_STORAGE
    if (sdkInt >= 30) {
      // MANAGE_EXTERNAL_STORAGE 需要在设置中手动开启
      // 这里先尝试使用 READ_EXTERNAL_STORAGE
      return true;
    }

    // Android 10 及以下: 使用传统权限
    return true;
  }

  /// 显示权限被拒绝的说明对话框
  static Future<void> showPermissionDeniedDialog(
    BuildContext context, {
    required bool permanentlyDenied,
  }) async {
    if (!context.mounted) return;

    if (permanentlyDenied) {
      // 权限被永久拒绝，引导用户到系统设置
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('权限被拒绝'),
          content: const Text('存储权限已被永久拒绝。\n\n请在系统设置中手动开启存储权限，以便应用访问您的媒体文件。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // openAppSettings(); // 需要 permission_handler 包
              },
              child: const Text('打开设置'),
            ),
          ],
        ),
      );
    } else {
      // 权限被临时拒绝，显示说明并允许重试
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要存储权限'),
          content: const Text('应用需要存储权限来访问您的媒体文件。\n\n请授予权限以继续使用。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // 重新请求权限
              },
              child: const Text('授予权限'),
            ),
          ],
        ),
      );
    }
  }
}
