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
import 'package:flutter_media_manager/bridge/native/api/note.dart' as note_api;
import 'package:flutter_media_manager/bridge/native/api/tag.dart' as tag_api;
import 'package:flutter_media_manager/functionality/media/media_bloc.dart';

/// 媒体查看器页面 - 全屏沉浸式
///
/// 功能设计（产品经理视角）：
/// - 图片：双指缩放 + 拖拽平移 + 双击缩放 + 旋转
/// - 视频：播放/暂停 + 进度条 + 全屏 + 倍速
/// - 底部操作栏：相册管理、标签管理、删除（3个核心按钮）
/// - 顶部信息栏：返回、文件名、页码指示、更多菜单
/// - 更多菜单：重命名、文件详情
/// - 点击屏幕：切换 overlay 显示/隐藏
/// - 滑动翻页切换媒体
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

  String? _noteContent;
  List<tag_api.Tag> _mediaTags = [];
  int _imageRotation = 0;
  bool _showOverlay = true;

  // 视频播放器状态
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoPlaying = false;
  bool _videoShowControls = true;
  Duration _videoPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  double _videoPlaybackSpeed = 1.0;
  Timer? _hideControlsTimer;
  List<StreamSubscription> _videoSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _currentIndex =
        widget.mediaList.indexWhere((m) => m.id == widget.initialMedia.id);
    if (_currentIndex < 0) _currentIndex = 0;
    _currentMedia = widget.mediaList[_currentIndex];
    _pageController = PageController(initialPage: _currentIndex);
    _loadMediaData();
    if (_currentMedia.mediaType == MediaType.video) {
      _initVideo(_currentMedia.filePath);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeVideo();
    _hideControlsTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // 数据加载
  // ═══════════════════════════════════════════════════════════════

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
    final newMedia = widget.mediaList[index];
    setState(() {
      _currentIndex = index;
      _currentMedia = newMedia;
      _imageRotation = 0;
      _noteContent = null;
      _mediaTags = [];
      _showOverlay = true;
    });
    _loadMediaData();
    // 切换视频播放器
    if (newMedia.mediaType == MediaType.video) {
      _initVideo(newMedia.filePath);
    } else {
      _disposeVideo();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 视频播放器管理
  // ═══════════════════════════════════════════════════════════════

  Future<void> _initVideo(String filePath) async {
    _disposeVideo();
    final controller = VideoPlayerController.file(File(filePath));
    _videoController = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => _videoInitialized = true);
      controller.addListener(_onVideoUpdate);
    } catch (e) {
      debugPrint('Video init failed: $e');
    }
  }

  void _onVideoUpdate() {
    final c = _videoController;
    if (c == null || !mounted) return;
    setState(() {
      _videoPlaying = c.value.isPlaying;
      _videoPosition = c.value.position;
      _videoDuration = c.value.duration;
      if (c.value.isCompleted) {
        _videoPlaying = false;
      }
    });
  }

  void _disposeVideo() {
    for (final sub in _videoSubscriptions) {
      sub.cancel();
    }
    _videoSubscriptions.clear();
    _videoController?.removeListener(_onVideoUpdate);
    _videoController?.dispose();
    _videoController = null;
    _videoInitialized = false;
    _videoPlaying = false;
    _videoPosition = Duration.zero;
    _videoDuration = Duration.zero;
  }

  void _togglePlayPause() {
    final c = _videoController;
    if (c == null || !_videoInitialized) return;
    if (_videoPlaying) {
      c.pause();
    } else {
      if (c.value.isCompleted) {
        c.seekTo(Duration.zero);
      }
      c.play();
    }
    setState(() => _videoPlaying = !_videoPlaying);
    _resetHideTimer();
  }

  void _seekVideo(double ms) {
    _videoController?.seekTo(Duration(milliseconds: ms.toInt()));
  }

  void _changeSpeed() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentIdx = speeds.indexOf(_videoPlaybackSpeed);
    final nextIdx = (currentIdx + 1) % speeds.length;
    _videoPlaybackSpeed = speeds[nextIdx];
    _videoController?.setPlaybackSpeed(_videoPlaybackSpeed);
    setState(() {});
  }

  String _formatVideoDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    setState(() => _videoShowControls = true);
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _videoPlaying) {
        setState(() => _videoShowControls = false);
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // 通用操作
  // ═══════════════════════════════════════════════════════════════

  void _toggleOverlay() {
    if (_currentMedia.mediaType == MediaType.video) {
      _togglePlayPause();
    } else {
      setState(() => _showOverlay = !_showOverlay);
    }
  }

  void _rotateImage() =>
      setState(() => _imageRotation = (_imageRotation + 1) % 4);

  void _goBack() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 媒体内容
          GestureDetector(
            onTap: _toggleOverlay,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.mediaList.length,
              onPageChanged: _switchMedia,
              itemBuilder: (context, index) {
                return _buildMediaContent(widget.mediaList[index]);
              },
            ),
          ),
          // 顶部信息栏
          if (_showOverlay) _buildTopBar(),
          // 底部操作栏
          if (_showOverlay) _buildBottomBar(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 媒体内容构建
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMediaContent(MediaItem media) {
    switch (media.mediaType) {
      case MediaType.image:
        return _buildImageViewer();
      case MediaType.video:
        return _buildVideoViewer();
      default:
        return _buildUnsupportedContent(media);
    }
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: RotatedBox(
          quarterTurns: _imageRotation,
          child: Image.file(
            File(_currentMedia.filePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_rounded,
                      size: 64, color: Colors.white54),
                  const SizedBox(height: 12),
                  Text(_currentMedia.originalName,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoViewer() {
    if (!_videoInitialized || _videoController == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 视频画面
        GestureDetector(
          onDoubleTap: _togglePlayPause,
          child: Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
        // 播放/暂停大图标（播放中隐藏）
        if (!_videoPlaying && _showOverlay)
          Center(
            child: GestureDetector(
              onTap: _togglePlayPause,
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
          ),
        // 底部进度条和控制栏
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildVideoControls(),
        ),
      ],
    );
  }

  Widget _buildVideoControls() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 32, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: cs.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: cs.primary,
              overlayColor: cs.primary.withOpacity(0.2),
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
          // 控制按钮行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                // 时间显示
                Text(
                  '${_formatVideoDuration(_videoPosition)} / ${_formatVideoDuration(_videoDuration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Spacer(),
                // 倍速按钮
                GestureDetector(
                  onTap: _changeSpeed,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _videoPlaybackSpeed != 1.0
                          ? cs.primary.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_videoPlaybackSpeed}x',
                      style: TextStyle(
                        color: _videoPlaybackSpeed != 1.0
                            ? cs.primary
                            : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupportedContent(MediaItem media) {
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

  // ═══════════════════════════════════════════════════════════════
  // 顶部栏
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTopBar() {
    final loc = AppLocalizations.of(context);
    final hasMultiple = widget.mediaList.length > 1;
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
            _iconButton(
              icon: Icons.arrow_back_rounded,
              onTap: _goBack,
              tooltip: loc.back,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentMedia.originalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w500),
                  ),
                  if (hasMultiple)
                    Text(
                      '${_currentIndex + 1} / ${widget.mediaList.length}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 12),
                    ),
                ],
              ),
            ),
            // 图片旋转按钮
            if (_currentMedia.mediaType == MediaType.image)
              _iconButton(
                icon: Icons.rotate_right_rounded,
                onTap: _rotateImage,
                tooltip: loc.rotate,
              ),
            // 更多菜单
            _iconButton(
              icon: Icons.more_vert_rounded,
              onTap: _showMoreMenu,
              tooltip: loc.more,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 底部栏
  // ═══════════════════════════════════════════════════════════════

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
            // 添加到相册
            _actionButton(
              icon: Icons.camera_alt_outlined,
              label: loc.addToAlbum,
              onTap: _showAlbumPicker,
            ),
            // 标签管理
            _actionButton(
              icon: Icons.label_outlined,
              label: loc.tags,
              onTap: _showTagManager,
            ),
            // 删除
            _actionButton(
              icon: Icons.delete_outline_rounded,
              label: loc.delete,
              color: Colors.red,
              onTap: _showDeleteConfirm,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // UI 辅助组件
  // ═══════════════════════════════════════════════════════════════

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final btn = Material(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
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

  // ═══════════════════════════════════════════════════════════════
  // 更多菜单
  // ═══════════════════════════════════════════════════════════════

  void _showMoreMenu() {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            _moreTile(Icons.edit_outlined, loc.rename, () {
              Navigator.pop(ctx);
              _showRenameDialog();
            }),
            _moreTile(Icons.info_outline, loc.details, () {
              Navigator.pop(ctx);
              _showFileInfoDialog();
            }),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _moreTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(leading: Icon(icon), title: Text(title), onTap: onTap);
  }

  // ═══════════════════════════════════════════════════════════════
  // 功能方法
  // ═══════════════════════════════════════════════════════════════

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
            itemBuilder: (context, index) {
              final album = albums[index];
              return ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: cs.primary),
                title: Text(album.album.name),
                subtitle: Text('${album.mediaCount} ${loc.files}'),
                onTap: () async {
                  await album_api.addMediaToAlbum(
                      mediaIds: [_currentMedia.id], albumId: album.album.id);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text('${loc.addToAlbum}: ${album.album.name}')));
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
            Text('${loc.confirmDeleteMedia} "${_currentMedia.originalName}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await deleteMedia(id: _currentMedia.id);
              if (!mounted) return;
              context.read<MediaBloc>().add(const MediaLoadAllEvent());
              if (widget.mediaList.length == 1) {
                Navigator.pop(context);
                return;
              }
              final newList = widget.mediaList
                  .where((m) => m.id != _currentMedia.id)
                  .toList();
              if (newList.isEmpty) {
                Navigator.pop(context);
                return;
              }
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
            },
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  void _showFileInfoDialog() {
    final loc = AppLocalizations.of(context);
    final info = [
      _infoRow(loc.fileName, _currentMedia.originalName),
      _infoRow(loc.mimeType, _currentMedia.mimeType),
      _infoRow(loc.fileSize, _formatBytes(_currentMedia.size)),
      if (_currentMedia.width != null && _currentMedia.height != null)
        _infoRow(
            loc.resolution, '${_currentMedia.width} x ${_currentMedia.height}'),
      if (_currentMedia.duration != null)
        _infoRow(loc.duration, _formatDuration(_currentMedia.duration!)),
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
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.close),
          )
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(
            child: SelectableText(value,
                style: TextStyle(color: cs.onSurface, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int? ms) {
    if (ms == null || ms <= 0) return '0:00';
    final d = Duration(milliseconds: ms);
    final h = d.inHours,
        m = d.inMinutes.remainder(60),
        s = d.inSeconds.remainder(60);
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ═══════════════════════════════════════════════════════════════
// 标签管理对话框
// ═══════════════════════════════════════════════════════════════

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
                    const SizedBox(height: 12),
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
                      duration: const Duration(milliseconds: 200),
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
                }),
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
