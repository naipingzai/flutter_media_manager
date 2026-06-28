import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';
import '../src/rust/api/media.dart';
import 'viewer/viewer_page.dart';

/// 媒体网格展示组件
///
/// 规范要求（Skill-10 §2.4）：每个网格项在缩略图下方显示文件名（BodySmall）
/// 和文件大小（LabelSmall）。为此将 childAspectRatio 调整为 0.78 以容纳文本。

String _formatSize(int bytes) {
  if (bytes < 1024) return '\$bytes B';
  if (bytes < 1024 * 1024) return '\${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '\${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '\${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
class MediaGrid extends StatelessWidget {
  final List<MediaItem> mediaList;
  final Set<String> selectedIds;
  final int crossAxisCount;

  const MediaGrid({
    super.key,
    required this.mediaList,
    required this.selectedIds,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    // 1列时使用列表视图（文件管理器风格：左侧缩略图+右侧文件信息）
    if (crossAxisCount == 1) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: mediaList.length,
        itemBuilder: (context, index) {
          final media = mediaList[index];
          final isSelected = selectedIds.contains(media.id);
          return _MediaListTile(
            media: media,
            isSelected: isSelected,
            onTap: () => _onMediaTap(context, media),
            onLongPress: () => _onMediaLongPress(context, media),
          );
        },
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 0.78,
      ),
      itemCount: mediaList.length,
      itemBuilder: (context, index) {
        final media = mediaList[index];
        final isSelected = selectedIds.contains(media.id);
        return _MediaGridItem(
          media: media,
          isSelected: isSelected,
          onTap: () => _onMediaTap(context, media),
          onLongPress: () => _onMediaLongPress(context, media),
        );
      },
    );
  }

  void _onMediaTap(BuildContext context, MediaItem media) {
    if (selectedIds.isNotEmpty) {
      // 选择模式下，点击切换选择
      context.read<MediaBloc>().add(MediaSelectEvent(media.id));
    } else {
      // 正常浏览模式，打开详情
      _openMediaDetail(context, media);
    }
  }

  void _onMediaLongPress(BuildContext context, MediaItem media) {
    final bloc = context.read<MediaBloc>();
    if (!bloc.state.isSelectionMode) {
      bloc.add(const MediaToggleSelectionModeEvent());
    }
    bloc.add(MediaSelectEvent(media.id));
  }

  void _openMediaDetail(BuildContext context, MediaItem media) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewerPage(
          initialMedia: media,
          mediaList: mediaList,
        ),
      ),
    );
  }
}

/// 单个媒体网格项
///
/// 布局：Column(缩略图 Expanded + 文件名 + 大小) + Stack（角标/时长/选择）
class _MediaGridItem extends StatelessWidget {
  final MediaItem media;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MediaGridItem({
    required this.media,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 缩略图区域（占用大部分空间）
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(),
                  // 选择遮罩
                  if (isSelected)
                    Container(
                      color: theme.colorScheme.primary.withOpacity(0.25),
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.check,
                            color: theme.colorScheme.onPrimary,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  // 媒体类型标识（左上角）
                  Positioned(
                    top: 4,
                    left: 4,
                    child: _buildTypeIcon(),
                  ),
                  // 视频时长标识（右下角）
                  if (media.mediaType == MediaType.video &&
                      media.duration != null)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: _buildDurationBadge(),
                    ),
                ],
              ),
            ),
            // 文件名 + 大小（缩略图下方）
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    media.originalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _formatSize(media.size),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    if (media.thumbnailPath.isNotEmpty) {
      return Image.file(
        File(media.thumbnailPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallbackIcon();
        },
      );
    }
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    IconData iconData;
    switch (media.mediaType) {
      case MediaType.image:
        iconData = Icons.image;
        break;
      case MediaType.video:
        iconData = Icons.videocam;
        break;
      case MediaType.audio:
        iconData = Icons.audiotrack;
        break;
      case MediaType.document:
        iconData = Icons.description;
        break;
      default:
        iconData = Icons.insert_drive_file;
    }
    return Center(
      child: Icon(iconData, size: 32, color: Colors.grey[400]),
    );
  }

  Widget _buildTypeIcon() {
    IconData iconData;
    Color iconColor;
    switch (media.mediaType) {
      case MediaType.image:
        iconData = Icons.image;
        iconColor = Colors.greenAccent;
        break;
      case MediaType.video:
        iconData = Icons.videocam;
        iconColor = Colors.redAccent;
        break;
      case MediaType.audio:
        iconData = Icons.audiotrack;
        iconColor = Colors.orangeAccent;
        break;
      case MediaType.document:
        iconData = Icons.description;
        iconColor = Colors.lightBlueAccent;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(iconData, size: 12, color: iconColor),
    );
  }

  Widget _buildDurationBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _formatDuration(media.duration!),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// 列表视图项（1列时使用，文件管理器风格：左侧缩略图 + 右侧信息）
class _MediaListTile extends StatelessWidget {
  final MediaItem media;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MediaListTile({
    required this.media,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: Stack(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: media.thumbnailPath.isNotEmpty
                ? Image.file(File(media.thumbnailPath), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(_getMediaIcon(media.mediaType), size: 24))
                : Icon(_getMediaIcon(media.mediaType), size: 24),
          ),
          if (isSelected)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(Icons.check, color: theme.colorScheme.onPrimary, size: 20),
              ),
            ),
        ],
      ),
      title: Text(media.originalName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_formatSize(media.size), style: theme.textTheme.bodySmall),
      trailing: Icon(_getMediaIcon(media.mediaType), size: 16, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  IconData _getMediaIcon(MediaType type) {
    switch (type) {
      case MediaType.image: return Icons.image;
      case MediaType.video: return Icons.videocam;
      case MediaType.audio: return Icons.audiotrack;
      case MediaType.document: return Icons.description;
      default: return Icons.insert_drive_file;
    }
  }
}
