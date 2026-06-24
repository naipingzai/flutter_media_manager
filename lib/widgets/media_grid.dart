import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';
import '../src/rust/api/media.dart';

/// 媒体网格展示组件
class MediaGrid extends StatelessWidget {
  final List<MediaItem> mediaList;
  final Set<String> selectedIds;

  const MediaGrid({
    super.key,
    required this.mediaList,
    required this.selectedIds,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.0,
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
    context.read<MediaBloc>().add(MediaSelectEvent(media.id));
  }

  void _openMediaDetail(BuildContext context, MediaItem media) {
    // TODO: 导航到媒体详情页
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(media.originalName),
              const SizedBox(height: 8),
              Text('类型: ${media.mediaType.name}'),
              Text('大小: ${media.size} bytes'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}

/// 单个媒体网格项
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
    return Stack(
      fit: StackFit.expand,
      children: [
        InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            color: Colors.grey[200],
            child: _buildThumbnail(),
          ),
        ),
        if (isSelected)
          Container(
            color: Colors.black.withOpacity(0.4),
            child: const Center(
              child: Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        // 媒体类型标识
        Positioned(
          top: 4,
          right: 4,
          child: _buildTypeIcon(),
        ),
        // 视频时长标识
        if (media.mediaType == MediaType.video && media.duration != null)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
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
                ),
              ),
            ),
          ),
      ],
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
        iconColor = Colors.green;
        break;
      case MediaType.video:
        iconData = Icons.videocam;
        iconColor = Colors.red;
        break;
      case MediaType.audio:
        iconData = Icons.audiotrack;
        iconColor = Colors.orange;
        break;
      case MediaType.document:
        iconData = Icons.description;
        iconColor = Colors.blue;
        break;
      default:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(iconData, size: 14, color: iconColor),
    );
  }

  String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
