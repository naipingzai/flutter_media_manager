import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Skill-03 §5.1 - 可复用 MediaItemCard
/// 显示缩略图、选中态、文件名、文件大小
class MediaItemCard extends StatelessWidget {
  final String? thumbnailPath;
  final String fileName;
  final String fileSize;
  final MediaTypeDisplay mediaType;
  final bool isSelected;
  final bool isMultiSelectMode;
  final bool showPreview;
  final int? durationMs;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MediaItemCard({
    super.key,
    this.thumbnailPath,
    required this.fileName,
    required this.fileSize,
    required this.mediaType,
    this.isSelected = false,
    this.isMultiSelectMode = false,
    this.showPreview = true,
    this.durationMs,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 缩略图区域
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 缩略图或占位
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: showPreview && thumbnailPath != null
                      ? _buildThumbnail()
                      : _buildPlaceholder(colorScheme),
                ),
                // 视频时长徽章
                if (mediaType == MediaTypeDisplay.video && durationMs != null)
                  Positioned(
                    right: AppSpacing.xs,
                    bottom: AppSpacing.xs,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        formatDuration(durationMs!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                // 选中态覆盖
                if (isMultiSelectMode)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outline,
                          width: isSelected
                              ? AppSize.borderWidthSelected
                              : 1,
                        ),
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: AppSize.overlayOpacity)
                            : null,
                      ),
                    ),
                  ),
                // 选中勾选图标
                if (isMultiSelectMode)
                  Positioned(
                    left: AppSpacing.xs,
                    top: AppSpacing.xs,
                    child: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      size: AppSize.checkCircleSize,
                    ),
                  ),
              ],
            ),
          ),
          // 文件名和大小
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  fileSize,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    // 占位：后续接入图片加载（如使用 Rust 端读取文件字节）
    return Container(
      color: Colors.grey[300],
      child: const Center(child: Icon(Icons.image, size: 32, color: Colors.grey)),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    IconData icon;
    switch (mediaType) {
      case MediaTypeDisplay.image:
        icon = Icons.broken_image;
        break;
      case MediaTypeDisplay.video:
        icon = Icons.videocam;
        break;
      case MediaTypeDisplay.audio:
        icon = Icons.audiotrack;
        break;
      default:
        icon = Icons.insert_drive_file;
    }
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(icon, size: AppSize.iconLarge, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

enum MediaTypeDisplay { image, video, audio, document, other }

/// Skill-03 §5.3 - 面包屑导航组件
class BreadcrumbNav extends StatelessWidget {
  final List<BreadcrumbItem> items;
  final Function(int index) onTap;

  const BreadcrumbNav({
    super.key,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isLast = index == items.length - 1;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              GestureDetector(
                onTap: () => onTap(index),
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                    color: isLast
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BreadcrumbItem {
  final String label;
  final String path;

  const BreadcrumbItem({required this.label, required this.path});
}

/// Skill-03 §5.5 - 可折叠面板组件
class CollapsiblePanel extends StatefulWidget {
  final String title;
  final bool defaultExpanded;
  final Widget? action;
  final Widget child;

  const CollapsiblePanel({
    super.key,
    required this.title,
    this.defaultExpanded = true,
    this.action,
    required this.child,
  });

  @override
  State<CollapsiblePanel> createState() => _CollapsiblePanelState();
}

class _CollapsiblePanelState extends State<CollapsiblePanel>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _expanded = widget.defaultExpanded;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));
    if (_expanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 20,
                  color: colorScheme.onSurface,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.action != null) widget.action!,
              ],
            ),
          ),
        ),
        ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Align(
                alignment: Alignment.centerLeft,
                heightFactor: _heightFactor.value,
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}

/// 空状态组件
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSize.iconXxl, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
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

/// 相册卡片组件 - Skill-10 §3.2
class AlbumCard extends StatelessWidget {
  final String albumName;
  final int mediaCount;
  final String? coverThumbnailPath;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AlbumCard({
    super.key,
    required this.albumName,
    required this.mediaCount,
    this.coverThumbnailPath,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 封面区域
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: coverThumbnailPath != null
                  ? Container(
                      color: Colors.grey[300],
                      child: const Center(child: Icon(Icons.photo_album, size: 32, color: Colors.grey)),
                    )
                  : Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.photo_album,
                          size: AppSize.iconLarge,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ),
          // 信息区域
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  albumName,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$mediaCount 个媒体',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skill-19 §5 - Toast / Snackbar / 对话框辅助工具
class UIHelper {
  UIHelper._();

  static void showSnackBar(BuildContext context, String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), action: action),
    );
  }

  static Future<bool> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = '确定',
    String cancelLabel = '取消',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
