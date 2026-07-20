import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_media_manager/core/design_system/app_theme.dart';
import 'package:flutter_media_manager/core/design_system/components.dart'
    hide formatDuration;
import 'package:flutter_media_manager/bridge/native/api/media.dart';
import 'package:flutter_media_manager/ui/viewer/viewer_page.dart';
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

// ── Grid item ─────────────────────────────────────────────────────

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
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Thumbnail area ──
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(context),
                  if (selectionMode) _buildSelectionOverlay(cs),
                  // Duration badge (bottom-right, video only)
                  if (media.mediaType == MediaType.video &&
                      media.duration != null)
                    Positioned(
                      bottom: AppSpacing.xs,
                      right: AppSpacing.xs,
                      child: _buildDurationBadge(cs),
                    ),
                ],
              ),
            ),
            // ── Info area ──
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
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    formatFileSize(media.size),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
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
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          _mediaIcon(media.mediaType),
          size: AppSize.iconXl,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildDurationBadge(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: cs.scrim.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        formatDuration(media.duration!),
        style: TextStyle(
          color: cs.onError,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSelectionOverlay(ColorScheme cs) {
    return AnimatedContainer(
      duration: AppAnimation.fast,
      color: isSelected
          ? cs.primary.withValues(alpha: 0.25)
          : cs.scrim.withValues(alpha: 0.05),
      child: Center(
        child: AnimatedSwitcher(
          duration: AppAnimation.thumbnailScale,
          child: isSelected
              ? Container(
                  key: const ValueKey(true),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.check_rounded,
                    color: cs.onPrimary,
                    size: 18,
                  ),
                )
              : const SizedBox.shrink(key: ValueKey(false)),
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
        return (Icons.description_outlined, cs.tertiary);
      default:
        return (Icons.insert_drive_file_outlined, cs.onSurfaceVariant);
    }
  }
}

// ── List tile (single-column mode) ────────────────────────────────

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
        width: AppSize.touchTarget,
        height: AppSize.touchTarget,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                width: AppSize.touchTarget,
                height: AppSize.touchTarget,
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
                    Icons.check_rounded,
                    color: cs.onPrimary,
                    size: AppSize.iconMd,
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
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        formatFileSize(media.size),
        style: AppTextStyles.caption.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Icon(
        _MediaGridItem._mediaIcon(media.mediaType),
        size: AppSize.iconMd,
        color: cs.onSurfaceVariant,
      ),
    );
  }

  Widget _buildFallbackIcon(ColorScheme cs) {
    return Center(
      child: Icon(
        _MediaGridItem._mediaIcon(media.mediaType),
        size: AppSize.iconMd,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}
