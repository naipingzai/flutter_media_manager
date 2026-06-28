import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/bloc.dart';
import '../../core/i18n/app_localizations.dart';
import '../../src/rust/api/media.dart' as media_api;
import '../../src/rust/api/note.dart' as note_api;
import '../../src/rust/api/tag.dart' as tag_api;
import 'image_viewer.dart';
import 'video_player_widget.dart';
import 'audio_player_widget.dart';

/// 全屏媒体查看器
///
/// 功能:
/// - HorizontalPager 翻页浏览
/// - 自动隐藏的 TopBar 和 BottomBar
/// - 图片双指/双击缩放
/// - 视频播放控制
/// - 音频播放控制
/// - 详情模式面板（信息/笔记/标签）
/// - 标签管理
/// - 笔记编辑
/// - 分享/导出
class ViewerPage extends StatefulWidget {
  final media_api.MediaItem initialMedia;
  final List<media_api.MediaItem> mediaList;

  const ViewerPage({
    super.key,
    required this.initialMedia,
    required this.mediaList,
  });

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _showBars = true;
  bool _detailMode = false;
  double _scale = 1.0;
  double _rotation = 0.0;
  double _offsetX = 0.0;
  double _offsetY = 0.0;
  Timer? _hideTimer;
  note_api.Note? _mediaNote;
  List<tag_api.Tag> _mediaTags = [];

  media_api.MediaItem get _currentMedia => widget.mediaList[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.mediaList.indexWhere((m) => m.id == widget.initialMedia.id);
    if (_currentIndex < 0) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
    _loadMediaData();
    _startHideTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_detailMode) {
        setState(() => _showBars = false);
      }
    });
  }

  void _toggleBars() {
    setState(() {
      _showBars = !_showBars;
      if (_showBars) _startHideTimer();
    });
  }

  void _toggleDetailMode() {
    setState(() {
      _detailMode = !_detailMode;
      _showBars = true;
      _resetTransform();
    });
    _hideTimer?.cancel();
  }

  void _resetTransform() {
    _scale = 1.0;
    _rotation = 0.0;
    _offsetX = 0.0;
    _offsetY = 0.0;
  }

  void _loadMediaData() {
    _mediaNote = null;
    _mediaTags = [];
    _loadNotes();
    _loadTags();
  }

  Future<void> _loadNotes() async {
    try {
      final note = await note_api.getNoteByMediaId(mediaId: _currentMedia.id);
      if (mounted) {
        setState(() => _mediaNote = note);
      }
    } catch (_) {}
  }

  Future<void> _loadTags() async {
    try {
      final tags = await tag_api.getMediaTags(mediaId: _currentMedia.id);
      if (mounted) {
        setState(() => _mediaTags = tags);
      }
    } catch (_) {}
  }

  void _onPageChanged(int index) {
    _currentIndex = index;
    _loadMediaData();
    setState(() {});
  }

  void _showRenameDialog() {
    final loc = AppLocalizations.of(context);
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
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                final updated = media_api.MediaItem(
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
                await media_api.updateMedia(media: updated);
                if (mounted) {
                  setState(() {});
                  context.read<MediaBloc>().add(const MediaRefreshEvent());
                  Navigator.pop(ctx);
                }
              }
            },
            child: Text(loc.save),
          ),
        ],
      ),
    );
  }

  void _showNoteDialog() {
    final loc = AppLocalizations.of(context);
    // 把已有笔记内容预填
    final initialContent = _mediaNote?.content ?? '';
    final controller = TextEditingController(text: initialContent);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.editNote),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: loc.noteContent,
            hintText: loc.noteContentHint,
          ),
          maxLines: 5,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () async {
              await note_api.saveNote(
                mediaId: _currentMedia.id,
                content: controller.text,
              );
              if (mounted) {
                _loadNotes();
                Navigator.pop(ctx);
              }
            },
            child: Text(loc.save),
          ),
        ],
      ),
    );
  }

  void _showTagManagerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _TagSelectorDialog(
        mediaId: _currentMedia.id,
        currentTags: _mediaTags,
        onTagsChanged: (tags) {
          setState(() => _mediaTags = tags);
        },
      ),
    );
  }

  void _showDeleteConfirm() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.confirmDeleteMedia),
        content: Text(loc.confirmDeleteMediaMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () async {
              await media_api.deleteMedia(id: _currentMedia.id);
              if (mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
                context.read<MediaBloc>().add(const MediaRefreshEvent());
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  void _shareMedia() {
    final loc = AppLocalizations.of(context);
    final media = _currentMedia;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${loc.share}: ${media.originalName}'),
        action: SnackBarAction(
          label: loc.copyPath,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: media.filePath));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(loc.filePathCopied)),
            );
          },
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color? _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse(colorStr.substring(1), radix: 16) + 0xFF000000);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaList.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final media = widget.mediaList[index];
              return GestureDetector(
                onTap: _toggleBars,
                child: _buildMediaContent(media),
              );
            },
          ),
          if (_showBars) _buildTopBar(),
          if (_showBars) _buildBottomBar(),
          if (_detailMode) _buildDetailPanel(),
        ],
      ),
    );
  }

  Widget _buildMediaContent(media_api.MediaItem media) {
    switch (media.mediaType) {
      case media_api.MediaType.image:
        if (_detailMode) {
          return GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _offsetX += details.delta.dx;
                _offsetY += details.delta.dy;
              });
            },
            onDoubleTap: () => setState(() => _resetTransform()),
            child: Center(
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..translate(_offsetX, _offsetY)
                  ..rotateZ(_rotation * 3.14159 / 180)
                  ..scale(_scale),
                child: Image.file(
                  File(media.filePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64, color: Colors.white54),
                ),
              ),
            ),
          );
        }
        return ImageViewer(filePath: media.filePath);
      case media_api.MediaType.video:
        return VideoPlayerWidget(filePath: media.filePath);
      case media_api.MediaType.audio:
        return AudioPlayerWidget(filePath: media.filePath, title: media.originalName);
      case media_api.MediaType.document:
      case media_api.MediaType.other:
        return _buildFilePreview(media);
    }
  }

  Widget _buildFilePreview(media_api.MediaItem media) {
    IconData icon;
    switch (media.mediaType) {
      case media_api.MediaType.document:
        icon = Icons.description;
        break;
      default:
        icon = Icons.insert_drive_file;
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 96, color: Colors.white54),
          const SizedBox(height: 24),
          Text(media.originalName, style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_formatFileSize(media.size),
              style: TextStyle(color: Colors.white.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final loc = AppLocalizations.of(context);
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_currentMedia.originalName,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${_currentIndex + 1}/${widget.mediaList.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: 8),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final loc = AppLocalizations.of(context);
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_currentMedia.mediaType == media_api.MediaType.image)
                  _buildBottomAction(Icons.tune, loc.detailMode, () {
                    _hideTimer?.cancel();
                    _toggleDetailMode();
                  }),
                _buildBottomAction(Icons.share_outlined, loc.share, () {
                  _hideTimer?.cancel();
                  _shareMedia();
                }),
                _buildBottomAction(Icons.delete_outline, loc.delete, () {
                  _hideTimer?.cancel();
                  _showDeleteConfirm();
                }, color: Colors.red),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color ?? Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  /// Skill-17：详情模式控制面板（退出 + 旋转）
  Widget _buildDetailPanel() {
    return Positioned(
      bottom: 24, right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'rotateLeft',
            onPressed: () => setState(() => _rotation = (_rotation - 90) % 360),
            backgroundColor: Colors.black54,
            child: const Icon(Icons.rotate_left, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'rotateRight',
            onPressed: () => setState(() => _rotation = (_rotation + 90) % 360),
            backgroundColor: Colors.black54,
            child: const Icon(Icons.rotate_right, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'reset',
            onPressed: () => setState(() => _resetTransform()),
            backgroundColor: Colors.black54,
            child: const Icon(Icons.refresh, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'exitDetail',
            onPressed: () => setState(() => _toggleDetailMode()),
            backgroundColor: Colors.black54,
            child: const Icon(Icons.close_fullscreen, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }



  Widget _buildSectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.5)),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis, maxLines: 2),
          ),
        ],
      ),
    );
  }
}

/// 标签选择器对话框
class _TagSelectorDialog extends StatefulWidget {
  final String mediaId;
  final List<tag_api.Tag> currentTags;
  final ValueChanged<List<tag_api.Tag>> onTagsChanged;

  const _TagSelectorDialog({
    required this.mediaId,
    required this.currentTags,
    required this.onTagsChanged,
  });

  @override
  State<_TagSelectorDialog> createState() => _TagSelectorDialogState();
}

class _TagSelectorDialogState extends State<_TagSelectorDialog> {
  List<tag_api.Tag> _allTags = [];
  late Set<String> _selectedTagIds;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = widget.currentTags.map((t) => t.id).toSet();
    _loadTags();
  }

  Future<void> _loadTags() async {
    try {
      final tags = await tag_api.getAllTags();
      if (mounted) {
        setState(() {
          _allTags = tags;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleTag(tag_api.Tag tag) async {
    final isSelected = _selectedTagIds.contains(tag.id);
    try {
      if (isSelected) {
        await tag_api.removeTagFromMedia(mediaId: widget.mediaId, tagId: tag.id);
        _selectedTagIds.remove(tag.id);
      } else {
        await tag_api.addTagToMedia(mediaId: widget.mediaId, tagId: tag.id);
        _selectedTagIds.add(tag.id);
      }
      if (mounted) {
        final updatedTags = _allTags.where((t) => _selectedTagIds.contains(t.id)).toList();
        widget.onTagsChanged(updatedTags);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).operationFailed}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.manageTags),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _allTags.isEmpty
                ? Center(child: Text(loc.noTagsCreateFirst))
                : ListView.builder(
                    itemCount: _allTags.length,
                    itemBuilder: (ctx, index) {
                      final tag = _allTags[index];
                      final isSelected = _selectedTagIds.contains(tag.id);
                      return CheckboxListTile(
                        title: Text(tag.name),
                        subtitle: tag.color != null
                            ? Row(children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Color(int.parse(tag.color!.replaceAll('#', '0xFF'))),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ])
                            : null,
                        value: isSelected,
                        onChanged: (_) => _toggleTag(tag),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.close),
        ),
      ],
    );
  }
}

