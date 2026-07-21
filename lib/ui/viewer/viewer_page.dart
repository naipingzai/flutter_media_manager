import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_media_manager/core/design_system/app_theme.dart';
import 'package:flutter_media_manager/core/i18n/app_localizations.dart';
import 'package:flutter_media_manager/bridge/native/api/album.dart'
    as album_api;
import 'package:flutter_media_manager/bridge/native/api/media.dart';
import 'package:flutter_media_manager/bridge/native/api/note.dart' as note_api;
import 'package:flutter_media_manager/bridge/native/api/tag.dart' as tag_api;
import 'package:flutter_media_manager/ui/viewer/widgets/audio_player_widget.dart';
import 'package:flutter_media_manager/ui/viewer/widgets/video_player_widget.dart';
import 'package:flutter_media_manager/functionality/media/media_bloc.dart';
import 'package:path_provider/path_provider.dart';

/// 统一媒体查看器页面
class ViewerPage extends StatefulWidget {
  final MediaItem initialMedia;
  final List<MediaItem> mediaList;

  const ViewerPage({
    super.key,
    required this.initialMedia,
    required this.mediaList,
  });

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> with WidgetsBindingObserver {
  late final PageController _pageController;
  late MediaItem _currentMedia;
  int _currentIndex = 0;

  String? _noteContent;
  List<tag_api.Tag> _mediaTags = [];
  int _imageRotation = 0;
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex =
        widget.mediaList.indexWhere((m) => m.id == widget.initialMedia.id);
    if (_currentIndex < 0) _currentIndex = 0;
    _currentMedia = widget.mediaList[_currentIndex];
    _pageController = PageController(initialPage: _currentIndex);
    _loadMediaData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 页面暂停时不控制视频/音频，组件自身处理
  }

  Future<void> _loadMediaData() async {
    final note = await note_api.getNoteByMediaId(mediaId: _currentMedia.id);
    final tags = await tag_api.getMediaTags(mediaId: _currentMedia.id);
    if (mounted) {
      setState(() {
        _noteContent = note?.content;
        _mediaTags = tags;
      });
    }
  }

  void _switchMedia(int index) {
    if (index < 0 || index >= widget.mediaList.length) return;
    setState(() {
      _currentIndex = index;
      _currentMedia = widget.mediaList[index];
      _imageRotation = 0;
      _noteContent = null;
      _mediaTags = [];
    });
    _loadMediaData();
  }

  void _toggleOverlay() => setState(() => _showOverlay = !_showOverlay);

  void _rotateImage() =>
      setState(() => _imageRotation = (_imageRotation + 1) % 4);

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.black,
              systemNavigationBarColor: Colors.black,
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: cs.surface,
              systemNavigationBarColor: cs.surface,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : cs.surface,
        extendBodyBehindAppBar: true,
        body: SafeArea(
          top: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: _toggleOverlay,
                behavior: HitTestBehavior.translucent,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.mediaList.length,
                  onPageChanged: _switchMedia,
                  itemBuilder: (context, index) {
                    return _buildMediaContent(
                        widget.mediaList[index], bottomPadding);
                  },
                ),
              ),
              if (_showOverlay) _buildTopOverlay(),
              if (_showOverlay) _buildBottomActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaContent(MediaItem media, double bottomPadding) {
    switch (media.mediaType) {
      case MediaType.image:
        return _ImageViewer(
          media: media,
          rotation: _imageRotation,
        );
      case MediaType.video:
        return VideoPlayerWidget(
          key: ValueKey(media.id),
          filePath: media.filePath,
          bottomPadding: bottomPadding,
        );
      case MediaType.audio:
        return AudioPlayerWidget(
          key: ValueKey(media.id),
          filePath: media.filePath,
          title: media.originalName,
        );
      case MediaType.document:
      case MediaType.other:
        return _DocumentContent(media: media);
    }
  }

  Widget _buildTopOverlay() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isImage = _currentMedia.mediaType == MediaType.image;
    final hasMultiple = widget.mediaList.length > 1;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withOpacity(0.7)
              : cs.surface.withOpacity(0.9),
          border: Border(
            bottom: BorderSide(
              color: cs.outlineVariant.withOpacity(0.2),
            ),
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + AppSpacing.sm,
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          bottom: AppSpacing.md,
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Row(
            children: [
              _buildTopButton(Icons.arrow_back_rounded,
                  () => Navigator.pop(context), isDark, cs),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentMedia.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (hasMultiple)
                      Text(
                        '${_currentIndex + 1} / ${widget.mediaList.length}',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (isImage) ...[
                _buildTopButton(
                    Icons.rotate_right_rounded, _rotateImage, isDark, cs),
                const SizedBox(width: AppSpacing.xs),
              ],
              _buildTopButton(Icons.close_rounded, () => Navigator.pop(context),
                  isDark, cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopButton(
      IconData icon, VoidCallback onTap, bool isDark, ColorScheme cs) {
    final btn = Material(
      color: isDark
          ? Colors.white.withOpacity(0.15)
          : cs.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child:
              Icon(icon, color: isDark ? Colors.white : cs.onSurface, size: 20),
        ),
      ),
    );
    return btn;
  }

  Widget _buildBottomActionBar() {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withOpacity(0.7)
              : cs.surface.withOpacity(0.9),
          border: Border(
            top: BorderSide(
              color: cs.outlineVariant.withOpacity(0.2),
            ),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          MediaQuery.of(context).padding.bottom + AppSpacing.sm,
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionItem(Icons.photo_album_outlined, loc.album,
                  _showAlbumPicker, isDark, cs),
              _buildActionItem(
                  Icons.label_outlined, loc.tags, _showTagManager, isDark, cs),
              _buildActionItem(Icons.delete_outline_rounded, loc.delete,
                  _showDeleteConfirm, isDark, cs,
                  color: cs.error),
              _buildActionItem(Icons.more_horiz_rounded, loc.more,
                  _showMorePanel, isDark, cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap,
      bool isDark, ColorScheme cs,
      {Color? color}) {
    final iconColor = color ?? (isDark ? Colors.white : cs.onSurface);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(color: iconColor, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showMorePanel() {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildMoreTile(Icons.edit_outlined, loc.rename, _showRenameDialog),
            _buildMoreTile(
                Icons.save_alt_rounded, loc.saveToGallery, _saveMedia),
            _buildMoreTile(Icons.link, loc.copyPath, _copyPath),
            _buildMoreTile(
                Icons.info_outline, loc.details, _showFileInfoDialog),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreTile(IconData icon, String title, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.onSurface),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _showRenameDialog() {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController(text: _currentMedia.originalName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.rename),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: loc.newName),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final updated = MediaItem(
                  id: _currentMedia.id,
                  originalName: newName,
                  storageName: _currentMedia.storageName,
                  filePath: _currentMedia.filePath,
                  thumbnailPath: _currentMedia.thumbnailPath,
                  mediaType: _currentMedia.mediaType,
                  mimeType: _currentMedia.mimeType,
                  size: _currentMedia.size,
                  width: _currentMedia.width,
                  height: _currentMedia.height,
                  duration: _currentMedia.duration,
                  sha256Hash: _currentMedia.sha256Hash,
                  createdAt: _currentMedia.createdAt,
                  updatedAt: _currentMedia.updatedAt,
                );
                await updateMedia(media: updated);
                if (mounted) {
                  setState(() => _currentMedia = updated);
                  context.read<MediaBloc>().add(const MediaLoadAllEvent());
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(loc.save),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int? milliseconds) {
    if (milliseconds == null || milliseconds <= 0) return '0:00';
    final d = Duration(milliseconds: milliseconds);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _saveMedia() async {
    final loc = AppLocalizations.of(context);
    try {
      final sourceFile = File(_currentMedia.filePath);
      if (!await sourceFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.saveFileFailed)),
          );
        }
        return;
      }

      // Get the app's documents directory as a safe save location
      final appDir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${appDir.path}/saved_media');
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final ext = _currentMedia.filePath.split('.').last;
      final baseName = _currentMedia.originalName.contains('.')
          ? _currentMedia.originalName.split('.').first
          : _currentMedia.originalName;
      var savePath = '${saveDir.path}/${baseName}.$ext';
      int counter = 1;
      while (File(savePath).existsSync()) {
        savePath = '${saveDir.path}/${baseName}_$counter.$ext';
        counter++;
      }

      await sourceFile.copy(savePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.saveSuccess}: $savePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.saveFileFailed}: $e')),
        );
      }
    }
  }

  void _copyPath() {
    Clipboard.setData(ClipboardData(text: _currentMedia.filePath));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).filePathCopied)),
    );
  }

  Future<void> _showTagManager() async {
    final allTags = await tag_api.getAllTags();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => _TagManagerDialog(
        allTags: allTags,
        currentTags: _mediaTags,
        mediaId: _currentMedia.id,
        onChanged: _loadMediaData,
      ),
    );
  }

  Future<void> _showAlbumPicker() async {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final albums = await album_api.getRootAlbums();
    if (!mounted) return;
    if (albums.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.noAlbums)),
      );
      return;
    }
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.addToAlbum),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return ListTile(
                leading: Icon(Icons.photo_album_rounded, color: cs.primary),
                title: Text(album.album.name),
                subtitle: Text('${album.mediaCount} ${loc.files}'),
                onTap: () async {
                  await album_api.addMediaToAlbum(
                    mediaIds: [_currentMedia.id],
                    albumId: album.album.id,
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('${loc.addToAlbum}: ${album.album.name}')),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm() {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, size: 40, color: cs.error),
        title: Text(loc.confirmDeleteMedia),
        content: Text(
            '${loc.confirmDeleteMediaMsg} "${_currentMedia.originalName}"'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await deleteMedia(id: _currentMedia.id);
              if (!mounted) return;
              context.read<MediaBloc>().add(const MediaLoadAllEvent());
              if (widget.mediaList.length == 1) {
                Navigator.pop(context);
              } else {
                final newList = widget.mediaList
                    .where((m) => m.id != _currentMedia.id)
                    .toList();
                if (newList.isEmpty) {
                  Navigator.pop(context);
                } else {
                  final newIndex = math.min(_currentIndex, newList.length - 1);
                  setState(() {
                    _currentMedia = newList[newIndex];
                    _currentIndex = newIndex;
                    _imageRotation = 0;
                    _noteContent = null;
                    _mediaTags = [];
                  });
                  _pageController.jumpToPage(newIndex);
                  _loadMediaData();
                }
              }
            },
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  void _showFileInfoDialog() {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final info = [
      _infoRow(loc.fileName, _currentMedia.originalName),
      _infoRow(loc.filePath, _currentMedia.filePath),
      _infoRow(loc.mimeType, _currentMedia.mimeType),
      _infoRow(loc.fileSize, _formatBytes(_currentMedia.size)),
      if (_currentMedia.width != null && _currentMedia.height != null)
        _infoRow(
            loc.resolution, '${_currentMedia.width} x ${_currentMedia.height}'),
      if (_currentMedia.duration != null)
        _infoRow(loc.duration, _formatDuration(_currentMedia.duration!)),
      _infoRow(loc.hash, _currentMedia.sha256Hash),
      _infoRow(
          loc.note, _noteContent?.isEmpty == false ? _noteContent! : loc.none),
      _infoRow(
          loc.tags,
          _mediaTags.isEmpty
              ? loc.none
              : _mediaTags.map((t) => t.name).join(', ')),
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.details),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: info.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) => info[index],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(loc.close)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ─── 图片查看器 ───
class _ImageViewer extends StatelessWidget {
  final MediaItem media;
  final int rotation;

  const _ImageViewer({required this.media, required this.rotation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4,
      child: RotatedBox(
        quarterTurns: rotation,
        child: Image.file(
          File(media.filePath),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_rounded,
                    size: 64, color: cs.onSurfaceVariant.withOpacity(0.5)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  media.originalName,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 文档占位 ───
class _DocumentContent extends StatelessWidget {
  final MediaItem media;

  const _DocumentContent({required this.media});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_rounded,
                size: 72, color: isDark ? Colors.white54 : cs.onSurfaceVariant),
            const SizedBox(height: AppSpacing.lg),
            Text(
              media.originalName,
              style: TextStyle(
                  color: isDark ? Colors.white : cs.onSurface, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              media.mimeType,
              style: TextStyle(
                  color: isDark
                      ? Colors.white.withOpacity(0.5)
                      : cs.onSurfaceVariant,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 标签管理对话框 ───
class _TagManagerDialog extends StatefulWidget {
  final List<tag_api.Tag> allTags;
  final List<tag_api.Tag> currentTags;
  final String mediaId;
  final VoidCallback onChanged;

  const _TagManagerDialog({
    required this.allTags,
    required this.currentTags,
    required this.mediaId,
    required this.onChanged,
  });

  @override
  State<_TagManagerDialog> createState() => _TagManagerDialogState();
}

class _TagManagerDialogState extends State<_TagManagerDialog> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.currentTags.map((t) => t.id).toSet();
  }

  Future<void> _toggleTag(tag_api.Tag tag) async {
    final isSelected = _selectedIds.contains(tag.id);
    if (isSelected) {
      await tag_api.removeTagFromMedia(mediaId: widget.mediaId, tagId: tag.id);
      _selectedIds.remove(tag.id);
    } else {
      await tag_api.addTagToMedia(mediaId: widget.mediaId, tagId: tag.id);
      _selectedIds.add(tag.id);
    }
    if (mounted) {
      setState(() {});
      widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(loc.tags),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.allTags.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.label_off_outlined,
                        size: 48, color: cs.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.md),
                    Text(loc.noTags),
                  ],
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.allTags.length,
                itemBuilder: (context, index) {
                  final tag = widget.allTags[index];
                  final selected = _selectedIds.contains(tag.id);
                  final tagColor = tag.color != null
                      ? Color(int.parse(tag.color!.replaceFirst('#', '0xFF')))
                      : cs.primary;
                  return ListTile(
                    leading: AnimatedContainer(
                      duration: AppAnimation.fast,
                      decoration: BoxDecoration(
                        color: selected ? tagColor : cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        selected ? Icons.check_rounded : null,
                        size: 16,
                        color: selected ? Colors.white : cs.onSurfaceVariant,
                      ),
                    ),
                    title: Text(tag.name),
                    onTap: () => _toggleTag(tag),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(loc.close)),
      ],
    );
  }
}
