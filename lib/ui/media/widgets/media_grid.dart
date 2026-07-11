import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:advance_media_kb/core/design_system/app_theme.dart';
import 'package:advance_media_kb/bridge/native/api/media.dart';
import 'package:advance_media_kb/ui/viewer/viewer_page.dart';
import '../../../functionality/media/media_bloc.dart';


class MediaGrid extends StatelessWidget {
  final List<MediaItem> mediaList;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final int crossAxisCount;

  const MediaGrid({
    super.key,
    required this.mediaList,
    required this.selectedIds,
    this.isSelectionMode = false,
    this.crossAxisCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    if (crossAxisCount == 1) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
      padding: const EdgeInsets.all(AppSpacing.sm),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.xs,
        mainAxisSpacing: AppSpacing.xs,
        childAspectRatio: 0.78,
      ),
      itemCount: mediaList.length,
      itemBuilder: (context, index) {
        final media = mediaList[index];
        final isSelected = selectedIds.contains(media.id);
        return _MediaGridItem(
          media: media,
          isSelected: isSelected,
          selectionMode: isSelectionMode,
          onTap: () => _onMediaTap(context, media),
          onLongPress: () => _onMediaLongPress(context, media),
        );
      },
    );
  }

  void _onMediaTap(BuildContext context, MediaItem media) {
    if (isSelectionMode) {
      context.read<MediaBloc>().add(MediaSelectEvent(media.id));
    } else {
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

class _MediaGridItem extends StatelessWidget {
  final MediaItem media;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MediaGridItem({
    required this.media,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(context),
                  if (selectionMode) _buildSelectionOverlay(cs),
                  Positioned(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                    child: _buildTypeIcon(cs),
                  ),
                  if (media.mediaType == MediaType.video && media.duration != null)
                    Positioned(
                      bottom: AppSpacing.xs,
                      right: AppSpacing.xs,
                      child: _buildDurationBadge(cs),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
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
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    formatFileSize(media.size),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
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

  Widget _buildThumbnail(BuildContext context) {
    if (media.thumbnailPath.isEmpty) return _buildFallbackIcon(context);
    return Image.file(
      File(media.thumbnailPath),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildFallbackIcon(context),
    );
  }

  Widget _buildFallbackIcon(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Icon(
        _mediaIcon(media.mediaType),
        size: AppSize.iconLarge,
        color: cs.onSurfaceVariant,
      ),
    );
  }

  Widget _buildTypeIcon(ColorScheme cs) {
    final (icon, color) = _typeIconData(media.mediaType, cs);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: cs.scrim.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, size: AppSize.iconSmall, color: color),
    );
  }

  Widget _buildDurationBadge(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: cs.scrim.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        formatDuration(media.duration!),
        style: TextStyle(
          color: cs.onError,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSelectionOverlay(ColorScheme cs) {
    return Container(
      color: isSelected
          ? cs.primary.withValues(alpha: 0.25)
          : cs.scrim.withValues(alpha: 0.05),
      child: Center(
        child: AnimatedSwitcher(
          duration: AppAnimation.thumbnailScaleIn,
          child: isSelected
              ? Container(
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    Icons.check,
                    color: cs.onPrimary,
                    size: AppSize.iconMedium,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  static IconData _mediaIcon(MediaType type) {
    switch (type) {
      case MediaType.image:
        return Icons.image_outlined;
      case MediaType.video:
        return Icons.videocam_outlined;
      case MediaType.audio:
        return Icons.audiotrack_outlined;
      case MediaType.document:
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  static (IconData, Color) _typeIconData(MediaType type, ColorScheme cs) {
    switch (type) {
      case MediaType.image:
        return (Icons.image_outlined, cs.secondary);
      case MediaType.video:
        return (Icons.videocam_outlined, cs.error);
      case MediaType.audio:
        return (Icons.audiotrack_outlined, cs.primary);
      case MediaType.document:
        return (Icons.description_outlined, cs.primary);
      default:
        return (Icons.insert_drive_file_outlined, cs.onSurfaceVariant);
    }
  }
}

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
    final cs = theme.colorScheme;
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: SizedBox(
        width: AppSize.touchTargetMin,
        height: AppSize.touchTargetMin,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                width: AppSize.touchTargetMin,
                height: AppSize.touchTargetMin,
                color: cs.surfaceContainerHighest,
                child: media.thumbnailPath.isNotEmpty
                    ? Image.file(
                        File(media.thumbnailPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackIcon(cs),
                      )
                    : _buildFallbackIcon(cs),
              ),
            ),
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.check,
                    color: cs.onPrimary,
                    size: AppSize.iconMedium,
                  ),
                ),
              ),
          ],
        ),
      ),
      title: Text(
        media.originalName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        formatFileSize(media.size),
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Icon(
        _MediaGridItem._mediaIcon(media.mediaType),
        size: AppSize.iconMedium,
        color: cs.onSurfaceVariant,
      ),
    );
  }

  Widget _buildFallbackIcon(ColorScheme cs) {
    return Center(
      child: Icon(
        _MediaGridItem._mediaIcon(media.mediaType),
        size: AppSize.iconMedium,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}
