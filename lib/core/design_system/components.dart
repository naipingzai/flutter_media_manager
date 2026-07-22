/// Design System 组件库 — Semantic UI 层
///
/// 业务代码通过语义组件描述 UI，不直接使用 Material/Cupertino 组件。
/// 参考：Flutter C++ Cross-Platform Application Engineering Skill §4
library;

import 'package:flutter/material.dart';
import 'app_theme.dart';

// ═══════════════════════════════════════════════════════════════════════
// AppButton — 语义按钮
// ═══════════════════════════════════════════════════════════════════════

enum AppButtonVariant {
  filled,
  tonal,
  outlined,
  text,
  destructive,
}

class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool expanded;
  final double? iconSize;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.expanded = false,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    Widget button;
    switch (variant) {
      case AppButtonVariant.filled:
        button = icon != null
            ? FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: iconSize ?? AppSize.iconMd),
                label: Text(label),
              )
            : FilledButton(onPressed: onPressed, child: Text(label));
        break;
      case AppButtonVariant.tonal:
        button = icon != null
            ? FilledButton.tonalIcon(
                onPressed: onPressed,
                icon: Icon(icon, size: iconSize ?? AppSize.iconMd),
                label: Text(label),
              )
            : FilledButton.tonal(onPressed: onPressed, child: Text(label));
        break;
      case AppButtonVariant.outlined:
        button = icon != null
            ? OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: iconSize ?? AppSize.iconMd),
                label: Text(label),
              )
            : OutlinedButton(onPressed: onPressed, child: Text(label));
        break;
      case AppButtonVariant.text:
        button = icon != null
            ? TextButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: iconSize ?? AppSize.iconMd),
                label: Text(label),
              )
            : TextButton(onPressed: onPressed, child: Text(label));
        break;
      case AppButtonVariant.destructive:
        button = icon != null
            ? FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: cs.error),
                onPressed: onPressed,
                icon: Icon(icon, size: iconSize ?? AppSize.iconMd),
                label: Text(label),
              )
            : FilledButton(
                style: FilledButton.styleFrom(backgroundColor: cs.error),
                onPressed: onPressed,
                child: Text(label),
              );
        break;
    }

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// AppIconButton — 语义图标按钮
// ═══════════════════════════════════════════════════════════════════════

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double? size;
  final bool filled;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.size,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (filled) {
      return Material(
        color: (color ?? cs.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Tooltip(
            message: tooltip ?? '',
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(icon,
                  size: size ?? AppSize.iconMd, color: color ?? cs.primary),
            ),
          ),
        ),
      );
    }
    return IconButton(
      icon: Icon(icon, size: size ?? AppSize.iconMd, color: color),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// AppSheet — 语义底部弹窗
// ═══════════════════════════════════════════════════════════════════════

class AppSheet extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final Widget? trailing;

  const AppSheet({
    super.key,
    this.title,
    this.trailing,
    required this.children,
  });

  /// 显示底部弹窗
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽指示器
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (title != null || trailing != null) ...[
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Text(title!,
                          style: AppTextStyles.title
                              .copyWith(color: cs.onSurface)),
                    ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            const Divider(),
          ],
          ...children,
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// AppDialog — 语义对话框
// ═══════════════════════════════════════════════════════════════════════

class AppDialog {
  AppDialog._();

  /// 显示确认对话框
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    String? content,
    IconData? icon,
    String? confirmLabel,
    String? cancelLabel,
    bool destructive = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: icon != null
            ? Icon(icon, size: 40, color: destructive ? cs.error : cs.primary)
            : null,
        title: Text(title),
        content: content != null ? Text(content) : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel ?? '取消'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: cs.error)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel ?? '确认'),
          ),
        ],
      ),
    );
  }

  /// 显示信息对话框
  static Future<void> info(
    BuildContext context, {
    required String title,
    required Widget content,
    String? closeLabel,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: content,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(closeLabel ?? '关闭'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// AppMenu — 语义菜单项
// ═══════════════════════════════════════════════════════════════════════

class AppMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const AppMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });
}

class AppMenu {
  AppMenu._();

  /// 显示底部菜单
  static Future<void> showSheet(
    BuildContext context,
    List<AppMenuItem> items,
  ) {
    return AppSheet.show(
      context: context,
      builder: (ctx) => AppSheet(
        children: items
            .map((item) => ListTile(
                  leading: Icon(item.icon, color: item.color),
                  title: Text(item.label,
                      style: item.color != null
                          ? TextStyle(color: item.color)
                          : null),
                  onTap: () {
                    Navigator.pop(ctx);
                    item.onTap();
                  },
                ))
            .toList(),
      ),
    );
  }

  /// 显示弹出菜单
  static Future<String?> showPopup(
    BuildContext context,
    List<AppMenuItem> items, {
    Offset offset = Offset.zero,
  }) {
    return showMenu<String>(
      context: context,
      position:
          RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx, offset.dy),
      items: items
          .map((item) => PopupMenuItem<String>(
                value: item.label,
                child: Row(
                  children: [
                    Icon(item.icon,
                        size: AppSize.iconMd,
                        color: item.color ??
                            Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.md),
                    Text(item.label),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// AppLoadingState — 统一加载状态
// ═══════════════════════════════════════════════════════════════════════

class AppLoadingState extends StatelessWidget {
  final String? message;

  const AppLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!,
                style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// AppErrorState — 统一错误状态
// ═══════════════════════════════════════════════════════════════════════

class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.errorContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, size: 48, color: cs.error),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant)),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// AppEmptyState — 统一空状态（替代旧 EmptyState）
// ═══════════════════════════════════════════════════════════════════════

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: AppSize.iconXxl, color: cs.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title,
                style: AppTextStyles.title.copyWith(color: cs.onSurface),
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle!,
                  style:
                      AppTextStyles.body.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 向后兼容别名 — 确保旧代码不断
// ═══════════════════════════════════════════════════════════════════════

/// [UIHelper] 提供 formatFileSize / showSnackBar / showConfirmDialog
class UIHelper {
  UIHelper._();
  static String formatFileSize(int bytes) => _formatFileSize(bytes);
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Theme.of(context).colorScheme.error : null),
    );
  }
  static Future<bool?> showConfirmDialog(BuildContext context, {required String title, String? content, String? message, String confirmText = '确认', String cancelText = '取消', String? confirmLabel, String? cancelLabel}) {
    return AppDialog.confirm(context, title: title, content: content ?? message, confirmLabel: confirmLabel ?? confirmText, cancelLabel: cancelLabel ?? cancelText);
  }
}

String formatFileSize(int bytes) => _formatFileSize(bytes);
String formatDuration(int? milliseconds) => _formatDuration(milliseconds);

String _formatFileSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  int i = 0;
  double size = bytes.toDouble();
  while (size >= 1024 && i < suffixes.length - 1) { size /= 1024; i++; }
  return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${suffixes[i]}';
}

String _formatDuration(int? milliseconds) {
  if (milliseconds == null || milliseconds <= 0) return '--';
  final seconds = milliseconds ~/ 1000;
  final minutes = seconds ~/ 60;
  final hours = minutes ~/ 60;
  if (hours > 0) {
    final rm = minutes % 60;
    final rs = seconds % 60;
    return '$hours:${rm.toString().padLeft(2, '0')}:${rs.toString().padLeft(2, '0')}';
  } else {
    final rs = seconds % 60;
    return '$minutes:${rs.toString().padLeft(2, '0')}';
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, this.icon = Icons.inbox_outlined, required this.title, this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => AppEmptyState(icon: icon, title: title, subtitle: subtitle, action: action);
}
