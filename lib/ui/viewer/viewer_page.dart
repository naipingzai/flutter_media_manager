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

/// 媒体查看器 - 苹果相册风格
///
/// 设计参考：Apple Photos
/// - 全屏沉浸式黑色背景
/// - 单击切换工具栏显隐
/// - 图片：双指缩放，双击放大/还原，旋转
/// - 视频：播放/暂停，进度条在视频底部（播放时自动隐藏）
/// - 底部工具栏：相册、标签、删除（只在工具栏可见时显示）
/// - 视频进度条在底部工具栏上方，不重叠
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

class _ViewerPageState extends State<ViewerPage> {
  late final PageController _pageController;
  late MediaItem _currentMedia;
  int _currentIndex = 0;
  List<tag_api.Tag> _mediaTags = [];
  int _imageRotation = 0;
  bool _showChrome = true; // 控制顶部+底部工具栏显隐

  // 视频
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  double _videoSpeed = 1.0;
  Timer? _autoHideTimer;

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
    _autoHideTimer?.cancel();
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
      _showChrome = true;
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
  }

  void _onVideoTick() {
    final c = _videoController;
    if (c == null || !mounted) return;
    setState(() {
      _videoPosition = c.value.position;
      _videoDuration = c.value.duration;
    });
    // 播放完成自动重置
    if (c.value.isCompleted && _videoDuration > Duration.zero) {
      _videoController?.seekTo(Duration.zero);
      _videoController?.pause();
      _showChrome = true;
      _autoHideTimer?.cancel();
    }
  }

  void _disposeVideo() {
    _autoHideTimer?.cancel();
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;
    _videoPosition = Duration.zero;
    _videoDuration = Duration.zero;
  }

  void _toggleVideoPlay() {
    final c = _videoController;
    if (c == null || !_videoReady) return;
    if (c.value.isPlaying) {
      c.pause();
      _autoHideTimer?.cancel();
    } else {
      if (c.value.isCompleted) c.seekTo(Duration.zero);
      c.play();
      _startAutoHide();
    }
    setState(() {});
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

  void _startAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_videoController?.value.isPlaying ?? false)) {
        setState(() => _showChrome = false);
      }
    });
  }

  // ═══════════════════════════════════════════════════════
  // 交互
  // ═══════════════════════════════════════════════════════

  /// 单击切换工具栏
  void _onTap() {
    setState(() => _showChrome = !_showChrome);
    if (_showChrome && (_videoController?.value.isPlaying ?? false)) {
      _startAutoHide();
    }
    _autoHideTimer?.cancel();
  }

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
          // 媒体内容
          GestureDetector(
            onTap: _onTap,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.mediaList.length,
              onPageChanged: _switchMedia,
              itemBuilder: (_, i) => _buildContent(widget.mediaList[i]),
            ),
          ),
          // 顶部栏
          AnimatedOpacity(
            opacity: _showChrome ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_showChrome,
              child: _buildTopBar(),
            ),
          ),
          // 底部栏（视频进度条 + 工具栏）
          AnimatedOpacity(
            opacity: _showChrome ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_showChrome,
              child: _buildBottomSection(),
            ),
          ),
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
    return InteractiveViewer(
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
    );
  }

  Widget _buildVideo() {
    if (!_videoReady || _videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
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
  // 顶部栏（苹果风格：简洁半透明）
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
            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          left: 4,
          right: 4,
          bottom: 8,
        ),
        child: Row(
          children: [
            _chromeIcon(Icons.arrow_back_ios_new_rounded, _goBack),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  if (multiple)
                    Text(
                      '${_currentIndex + 1} / ${widget.mediaList.length}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 11),
                    ),
                ],
              ),
            ),
            if (_currentMedia.mediaType == MediaType.image)
              _chromeIcon(Icons.rotate_right_rounded, _rotateImage),
            // 视频：播放/暂停
            if (_currentMedia.mediaType == MediaType.video)
              _chromeIcon(
                _videoController?.value.isPlaying == true
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                _toggleVideoPlay,
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // 底部区域（视频进度条 + 工具栏）
  // ═══════════════════════════════════════════════════════

  Widget _buildBottomSection() {
    final loc = AppLocalizations.of(context);
    final isVideo = _currentMedia.mediaType == MediaType.video;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
            16, 20, 16, MediaQuery.of(context).padding.bottom + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 视频进度条（仅视频显示，放在工具栏上方）
            if (isVideo && _videoReady) ...[
              _buildVideoProgressBar(),
              const SizedBox(height: 12),
            ],
            // 底部工具栏：相册 / 标签 / 删除
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _bottomAction(Icons.camera_alt_outlined, loc.addToAlbum,
                    _showAlbumPicker),
                _bottomAction(Icons.label_outline, loc.tags, _showTagManager),
                _bottomAction(Icons.info_outline, loc.details, _showFileInfo),
                _bottomAction(
                    Icons.delete_outline, loc.delete, _showDeleteConfirm,
                    color: Colors.redAccent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoProgressBar() {
    final isPlaying = _videoController?.value.isPlaying ?? false;
    final maxMs =
        _videoDuration.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final posMs = _videoPosition.inMilliseconds.toDouble().clamp(0.0, maxMs);
    return Row(
      children: [
        // 播放/暂停按钮
        GestureDetector(
          onTap: _toggleVideoPlay,
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 8),
        // 时间
        Text(_fmtDur(_videoPosition),
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(width: 8),
        // 进度条
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: posMs,
              max: maxMs,
              onChanged: _seekVideo,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 总时长
        Text(_fmtDur(_videoDuration),
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(width: 8),
        // 倍速
        GestureDetector(
          onTap: _cycleSpeed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _videoSpeed != 1.0
                  ? Colors.white.withOpacity(0.2)
                  : Colors.transparent,
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
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // 辅助组件
  // ═══════════════════════════════════════════════════════

  Widget _chromeIcon(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: color ?? Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  String _fmtDur(Duration d) {
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
    return _fmtDur(Duration(milliseconds: ms));
  }

  // ═══════════════════════════════════════════════════════
  // 功能方法
  // ═══════════════════════════════════════════════════════

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
  const _TagDialog({
    required this.allTags,
    required this.currentTags,
    required this.mediaId,
    required this.onChanged,
  });

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
