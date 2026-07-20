import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_media_manager/core/design_system/app_theme.dart';
import 'package:flutter_media_manager/core/i18n/app_localizations.dart';
import 'package:flutter_media_manager/bridge/native/api/album.dart';
import 'package:flutter_media_manager/bridge/native/api/media.dart';
import 'package:flutter_media_manager/ui/viewer/viewer_page.dart';
import 'package:flutter_media_manager/functionality/home/app_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 相册详情页 - 显示相册内的媒体网格
class AlbumDetailScreen extends StatefulWidget {
  final String albumId;
  final String albumName;

  const AlbumDetailScreen({
    super.key,
    required this.albumId,
    required this.albumName,
  });

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<MediaItem> _mediaList = [];
  List<AlbumWithInfo> _childAlbums = [];
  bool _loading = true;
  String? _error;

  int get _columns => context.watch<AppBloc>().state.settings?.gridColumns ?? 3;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final media = await getMediaByAlbum(albumId: widget.albumId);
      final children = await getChildAlbums(parentId: widget.albumId);
      if (mounted) {
        setState(() {
          _mediaList = media;
          _childAlbums = children;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.albumName),
      ),
      body: _buildBody(context, loc, cs),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAlbumDialog(context),
        icon: const Icon(Icons.create_new_folder_rounded, size: 20),
        label: Text(loc.createAlbum),
      ),
    );
  }

  void _showCreateAlbumDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.createAlbum),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: loc.albumName),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                createAlbum(name: name, parentId: widget.albumId);
                Navigator.pop(ctx);
                _loadData();
              }
            },
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, AppLocalizations loc, ColorScheme cs) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child:
                  CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(loc.loading,
                style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_off_rounded, size: 48, color: cs.error),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style:
                      AppTextStyles.body.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(loc.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_mediaList.isEmpty && _childAlbums.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt_outlined,
                    size: 56, color: cs.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(loc.noMedia,
                  style: AppTextStyles.title.copyWith(color: cs.onSurface),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(loc.noMediaDesc,
                  style:
                      AppTextStyles.body.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          // 子相册
          if (_childAlbums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                child: Text(loc.albums,
                    style:
                        AppTextStyles.subtitle.copyWith(color: cs.onSurface)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns,
                  childAspectRatio: 1.0,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final info = _childAlbums[index];
                    return _AlbumCard(
                      name: info.album.name,
                      mediaCount: info.mediaCount,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AlbumDetailScreen(
                              albumId: info.album.id,
                              albumName: info.album.name,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  childCount: _childAlbums.length,
                ),
              ),
            ),
          ],
          // 媒体标题
          if (_mediaList.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
                child: Text('${_mediaList.length} ${loc.files}',
                    style: AppTextStyles.subtitle
                        .copyWith(color: cs.onSurfaceVariant)),
              ),
            ),
          // 媒体网格
          if (_mediaList.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns,
                  crossAxisSpacing: AppSpacing.xs,
                  mainAxisSpacing: AppSpacing.xs,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final media = _mediaList[index];
                    return _MediaGridItem(
                      media: media,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ViewerPage(
                              initialMedia: media,
                              mediaList: _mediaList,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  childCount: _mediaList.length,
                ),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }
}

// ── Album card ─────────────────────────────────────────────────────

class _AlbumCard extends StatelessWidget {
  final String name;
  final int mediaCount;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.name,
    required this.mediaCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child:
                    Icon(Icons.camera_alt_rounded, size: 32, color: cs.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(name,
                  style: AppTextStyles.subtitle.copyWith(color: cs.onSurface),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text('$mediaCount ${loc.files}',
                    style: AppTextStyles.caption
                        .copyWith(color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Media grid item ───────────────────────────────────────────────

class _MediaGridItem extends StatelessWidget {
  final MediaItem media;
  final VoidCallback onTap;

  const _MediaGridItem({
    required this.media,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (media.thumbnailPath.isNotEmpty)
              Image.file(
                File(media.thumbnailPath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(cs),
              )
            else
              _buildPlaceholder(cs),
            // Type badge
            if (media.mediaType != MediaType.image)
              Positioned(
                bottom: AppSpacing.xs,
                right: AppSpacing.xs,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.scrim.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Icon(
                    _mediaIcon(media.mediaType),
                    size: 12,
                    color: cs.secondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme cs) {
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
}
