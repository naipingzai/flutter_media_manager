import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_media_manager/core/i18n/app_localizations.dart';
import 'package:flutter_media_manager/bridge/native/api/album.dart'
    as album_api;
import 'package:flutter_media_manager/bridge/native/api/media.dart';
import 'package:flutter_media_manager/bridge/native/api/tag.dart' as tag_api;
import 'package:flutter_media_manager/functionality/media/media_bloc.dart';

/// 媒体查看器 - Google Photos 风格
///
/// 设计原则（参考 Google Photos）：
/// 1. 图片：全屏显示，单指左右滑动切换，双指缩放，双击放大
/// 2. 视频：点击画面播放/暂停，底部进度条自动隐藏
/// 3. 顶部：简洁（文件名+页码+更多），点击隐藏
/// 4. 底部：3个核心操作（相册/标签/删除）
/// 5. 所有控件点击时显示，再次点击隐藏，播放视频时自动隐藏
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

class _ViewerPageState extends State<ViewerPage>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late MediaItem _currentMedia;
  int _currentIndex = 0;
  List<tag_api.Tag> _mediaTags = [];
  int _imageRotation = 0;
  bool _showControls = true;

  // 视频
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  double _videoSpeed = 1.0;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex =
        widget.mediaList.indexWhere((m) => m.id == widget.initialMedia.id);
    if (_currentIndex < 0) _currentIndex = 0;
    _currentMedia = widget.mediaList[_currentIndex];
    _pageController = PageController(initialPage: _currentIndex);
    _loadTags();
    if (_currentMedia.mediaType == MediaType.video) _initVideo();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeVideo();
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // 数据
  // ═══════════════════════════════════════════════════════

  Future<void> _loadTags() async {
    final tags = await tag_api.getMediaTags(mediaId: _currentMedia.id);
    if (mounted) setState(() => _mediaTags = tags);
  }

  void _switchMedia(int index) {
    if (index < 0 || index >= widget.mediaList.length) return;
    final newMedia = widget.mediaList[index];
    setState(() {
      _currentIndex = index;
      _currentMedia = newMedia;
      _imageRotation = 0;
      _mediaTags = [];
      _showControls = true;
    });
    _loadTags();
    if (newMedia.mediaType == MediaType.video) {
      _initVideo();
    } else {
      _disposeVideo();
    }
  }

  // ═══════════════════════════════════════════════════════
  // 视频播放器
  // ═══════════════════════════════════════════════════════

  Future<void> _initVideo() async {
    _disposeVideo();
    final c = VideoPlayerController.file(File(_currentMedia.filePath));
    _videoController = c;
    c.addListener(_onVideoTick);
    await c.initialize();
    if (!mounted) return;
    setState(() => _videoReady = true);
    _scheduleHide();
  }

  void _onVideoTick() {
    final c = _videoController;
    if (c == null || !mounted) return;
    setState(() {
      _videoPosition = c.value.position;
      _videoDuration = c.value.duration;
      if (c.value.isCompleted && !_videoReady) {
        _videoController?.seekTo(Duration.zero);
        _showControls = true;
        _hideTimer?.cancel();
      }
    });
  }

  void _disposeVideo() {
    _hideTimer?.cancel();
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;
    _videoPosition = Duration.zero;
    _videoDuration = Duration.zero;
  }

  void _toggleVideo() {
    final c = _videoController;
    if (c == null || !_videoReady) return;
    if (c.value.isPlaying) {
      c.pause();
      setState(() => _showControls = true);
      _hideTimer?.cancel();
    } else {
      if (c.value.isCompleted) c.seekTo(Duration.zero);
      c.play();
      setState(() => _showControls = true);
      _scheduleHide();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls && (_videoController?.value.isPlaying ?? false)) {
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_videoController?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _seekVideo(double ms) {
    _videoController?.seekTo(Duration(milliseconds: ms.toInt()));
  }

  void _cycleSpeed() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final idx = speeds.indexOf(_videoSpeed);
    _videoSpeed = speeds[(idx + 1) % speeds.length];
    _videoController?.setPlaybackSpeed(_videoSpeed);
    setState(() {});
  }

  // ═══════════════════════════════════════════════════════
  // 通用操作
  // ═══════════════════════════════════════════════════════

  void _rotateImage() =>
      setState(() => _imageRotation = (_imageRotation + 1) % 4);

  void _goBack() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pop(context);
  }

  // ═══════════════════════════════════════════════════════
  // 构建
  // ═══════════════════════════════════════════════════════

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
            onPageChanged: _switchMedia,
            itemBuilder: (_, i) => _buildContent(widget.mediaList[i]),
          ),
          if (_showControls) _buildTopBar(),
          if (_showControls) _buildBottomBar(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 内容
  // ═══════════════════════════════════════════════════════

  Widget _buildContent(MediaItem media) {
    switch (media.mediaType) {
      case MediaType.image:
        return _buildImage();
      case MediaType.video:
        return _buildVideo();
      default:
        return _buildFallback(media);
    }
  }

  Widget _buildImage() {
    return GestureDetector(
      onTap: _toggleControls,
      onDoubleTap: () => setState(() => _showControls = !_showControls),
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: RotatedBox(
            quarterTurns: _imageRotation,
            child: Image.file(
              File(_currentMedia.filePath),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_rounded,
                    size: 64, color: Colors.white54),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    if (!_videoReady || _videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return GestureDetector(
      onTap: _toggleVideo,
      onDoubleTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          // 播放大图标（暂停时）
          if (!_videoController!.value.isPlaying)
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 40),
              ),
            ),
          // 底部进度条
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showControls ? 0 : -80,
            left: 0,
            right: 0,
            child: _buildVideoControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoControls() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(_fmt(_videoPosition),
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _videoPosition.inMilliseconds.toDouble().clamp(
                    0.0,
                    _videoDuration.inMilliseconds
                        .toDouble()
                        .clamp(1.0, double.infinity)),
                max: _videoDuration.inMilliseconds
                    .toDouble()
                    .clamp(1.0, double.infinity),
                onChanged: _seekVideo,
              ),
            ),
          ),
          Text(_fmt(_videoDuration),
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(width: 8),
          // 倍速按钮
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _cycleSpeed,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _videoSpeed != 1.0
                      ? cs.primary
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${_videoSpeed}x',
                  style: TextStyle(
                    color: _videoSpeed != 1.0 ? Colors.white : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallback(MediaItem media) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_rounded,
              size: 72, color: Colors.white38),
          const SizedBox(height: 16),
          Text(media.originalName,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(media.mimeType,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 13)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 顶部栏
  // ═══════════════════════════════════════════════════════

  Widget _buildTopBar() {
    final loc = AppLocalizations.of(context);
    final multiple = widget.mediaList.length > 1;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.7), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 8,
          bottom: 16,
        ),
        child: Row(
          children: [
            _iconBtn(Icons.arrow_back_rounded, _goBack),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_currentMedia.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  if (multiple)
                    Text(
                      '${_currentIndex + 1} / ${widget.mediaList.length}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                ],
              ),
            ),
            if (_currentMedia.mediaType == MediaType.image)
              _iconBtn(Icons.rotate_right_rounded, _rotateImage),
            PopupMenuButton<String>(
              icon: _iconBtn(Icons.more_vert_rounded, () {}),
              onSelected: (value) {
                switch (value) {
                  case 'rename':
                    _showRenameDialog();
                    break;
                  case 'album':
                    _showAlbumPicker();
                    break;
                  case 'tags':
                    _showTagManager();
                    break;
                  case 'info':
                    _showFileInfo();
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(loc.rename)),
                PopupMenuItem(value: 'album', child: Text(loc.addToAlbum)),
                PopupMenuItem(value: 'tags', child: Text(loc.tags)),
                PopupMenuItem(value: 'info', child: Text(loc.details)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 底部栏
  // ═══════════════════════════════════════════════════════

  Widget _buildBottomBar() {
    final loc = AppLocalizations.of(context);
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.85), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
            16, 24, 16, MediaQuery.of(context).padding.bottom + 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _actionBtn(
                Icons.camera_alt_outlined, loc.addToAlbum, _showAlbumPicker),
            _actionBtn(Icons.label_outlined, loc.tags, _showTagManager),
            _actionBtn(
                Icons.delete_outline_rounded, loc.delete, _showDeleteConfirm,
                color: Colors.red),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 辅助
  // ═══════════════════════════════════════════════════════

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, color: Colors.white, size: 20)),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: color ?? Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours,
        m = d.inMinutes.remainder(60),
        s = d.inSeconds.remainder(60);
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024)
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _fmtMs(int? ms) {
    if (ms == null || ms <= 0) return '0:00';
    final d = Duration(milliseconds: ms);
    final h = d.inHours,
        m = d.inMinutes.remainder(60),
        s = d.inSeconds.remainder(60);
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '$m:${s.toString().padLeft(2, '0')}';
  }

  // ═══════════════════════════════════════════════════════
  // 功能方法
  // ═══════════════════════════════════════════════════════

  void _showRenameDialog() {
    final loc = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: _currentMedia.originalName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.rename),
        content: TextField(
            controller: ctrl,
            decoration: InputDecoration(labelText: loc.newName),
            autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          FilledButton(
            onPressed: () async {
              final n = ctrl.text.trim();
              if (n.isNotEmpty) {
                await updateMedia(
                    media: MediaItem(
                  id: _currentMedia.id,
                  originalName: n,
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
                ));
                if (mounted) {
                  setState(() =>
                      _currentMedia = _currentMedia.copyWith(originalName: n));
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

  Future<void> _showTagManager() async {
    final allTags = await tag_api.getAllTags();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => _TagDialog(
        allTags: allTags,
        currentTags: _mediaTags,
        mediaId: _currentMedia.id,
        onChanged: _loadTags,
      ),
    );
  }

  Future<void> _showAlbumPicker() async {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final albums = await album_api.getRootAlbums();
    if (!mounted) return;
    if (albums.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.noAlbums)));
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
            itemBuilder: (_, i) {
              final a = albums[i];
              return ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: cs.primary),
                title: Text(a.album.name),
                subtitle: Text('${a.mediaCount} ${loc.files}'),
                onTap: () async {
                  await album_api.addMediaToAlbum(
                      mediaIds: [_currentMedia.id], albumId: a.album.id);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('${loc.addToAlbum}: ${a.album.name}')));
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
        title: Text(loc.delete),
        content:
            Text('${loc.confirmDeleteMedia} "${_currentMedia.originalName}"?'),
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
              if (widget.mediaList.length <= 1) {
                Navigator.pop(context);
                return;
              }
              final rest = widget.mediaList
                  .where((m) => m.id != _currentMedia.id)
                  .toList();
              if (rest.isEmpty) {
                Navigator.pop(context);
                return;
              }
              final next = math.min(_currentIndex, rest.length - 1);
              setState(() {
                _currentMedia = rest[next];
                _currentIndex = next;
                _imageRotation = 0;
                _mediaTags = [];
              });
              _pageController.jumpToPage(next);
              _loadTags();
              if (_currentMedia.mediaType == MediaType.video)
                _initVideo();
              else
                _disposeVideo();
            },
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  void _showFileInfo() {
    final loc = AppLocalizations.of(context);
    final rows = [
      _infoRow(loc.fileName, _currentMedia.originalName),
      _infoRow(loc.mimeType, _currentMedia.mimeType),
      _infoRow(loc.fileSize, _fmtSize(_currentMedia.size)),
      if (_currentMedia.width != null && _currentMedia.height != null)
        _infoRow(
            loc.resolution, '${_currentMedia.width} x ${_currentMedia.height}'),
      if (_currentMedia.duration != null)
        _infoRow(loc.duration, _fmtMs(_currentMedia.duration!)),
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
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => rows[i],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(loc.close))
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
        Expanded(
            child: SelectableText(value,
                style: TextStyle(color: cs.onSurface, fontSize: 13))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 标签对话框
// ═══════════════════════════════════════════════════════════════════════

class _TagDialog extends StatefulWidget {
  final List<tag_api.Tag> allTags;
  final List<tag_api.Tag> currentTags;
  final String mediaId;
  final VoidCallback onChanged;
  const _TagDialog(
      {required this.allTags,
      required this.currentTags,
      required this.mediaId,
      required this.onChanged});

  @override
  State<_TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  late final Set<String> _ids;
  @override
  void initState() {
    super.initState();
    _ids = widget.currentTags.map((t) => t.id).toSet();
  }

  Future<void> _toggle(tag_api.Tag tag) async {
    if (_ids.contains(tag.id)) {
      await tag_api.removeTagFromMedia(mediaId: widget.mediaId, tagId: tag.id);
      _ids.remove(tag.id);
    } else {
      await tag_api.addTagToMedia(mediaId: widget.mediaId, tagId: tag.id);
      _ids.add(tag.id);
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.label_off_outlined,
                    size: 48, color: cs.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(loc.noTags),
              ]))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.allTags.length,
                itemBuilder: (_, i) {
                  final tag = widget.allTags[i];
                  final sel = _ids.contains(tag.id);
                  final tc = tag.color != null
                      ? Color(int.parse(tag.color!.replaceFirst('#', '0xFF')))
                      : cs.primary;
                  return ListTile(
                    leading: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                          color: sel ? tc : cs.surfaceContainerHighest,
                          shape: BoxShape.circle),
                      padding: const EdgeInsets.all(4),
                      child: Icon(sel ? Icons.check_rounded : null,
                          size: 16,
                          color: sel ? Colors.white : cs.onSurfaceVariant),
                    ),
                    title: Text(tag.name),
                    onTap: () => _toggle(tag),
                  );
                }),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(loc.close))
      ],
    );
  }
}
