import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../bloc/bloc.dart';
import '../src/rust/api/media.dart';
import '../src/rust/api/note.dart' as note_api;
import '../src/rust/api/tag.dart' as tag_api;
import '../src/rust/api/scanner.dart' as scanner_api;
import '../core/i18n/app_localizations.dart';

/// 媒体详情查看页面 - 支持浏览模式 / 详情模式切换
class MediaDetailScreen extends StatefulWidget {
  final MediaItem media;
  final List<MediaItem> mediaList;

  const MediaDetailScreen({
    super.key,
    required this.media,
    required this.mediaList,
  });

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen>
    with WidgetsBindingObserver {
  late MediaItem _currentMedia;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _noteContent;
  List<tag_api.Tag> _mediaTags = [];

  // 浏览模式 / 详情模式
  bool _isDetailMode = false;
  bool _showOverlay = true; // 浏览模式下 overlay 显隐

  // 详情模式图片变换参数
  double _scale = 1.0;
  double _rotation = 0.0; // 角度
  double _offsetX = 0.0;
  double _offsetY = 0.0;

  // PageView 控制器
  late PageController _pageController;

  // 多页计数器
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentMedia = widget.media;
    _currentIndex = widget.mediaList.indexWhere((m) => m.id == _currentMedia.id);
    if (_currentIndex < 0) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
    _loadMediaData();
    _initVideoIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.dispose();
    _chewieController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // 应用进入后台时暂停视频
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _videoController?.pause();
    }
  }

  void _loadMediaData() async {
    final notes = await note_api.getNotesByMediaId(mediaId: _currentMedia.id);
    if (mounted) {
      setState(() {
        _noteContent = notes.isNotEmpty ? notes.first.content : null;
      });
    }
    final tags = await tag_api.getMediaTags(mediaId: _currentMedia.id);
    if (mounted) {
      setState(() {
        _mediaTags = tags;
      });
    }
  }

  void _initVideoIfNeeded() {
    if (_currentMedia.mediaType == MediaType.video) {
      _videoController = VideoPlayerController.file(File(_currentMedia.filePath));
      _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() {
            _chewieController = ChewieController(
              videoPlayerController: _videoController!,
              autoPlay: false,
              looping: false,
              aspectRatio: _videoController!.value.aspectRatio,
            );
          });
        }
      });
    }
  }

  void _disposeVideo() {
    _videoController?.pause();
    _videoController?.dispose();
    _chewieController?.dispose();
    _videoController = null;
    _chewieController = null;
  }

  void _switchMedia(MediaItem media) {
    _disposeVideo();
    setState(() {
      _currentMedia = media;
      _noteContent = null;
      _mediaTags = [];
      _resetTransform();
    });
    _loadMediaData();
    _initVideoIfNeeded();
  }

  /// 重置图片变换参数
  void _resetTransform() {
    _scale = 1.0;
    _rotation = 0.0;
    _offsetX = 0.0;
    _offsetY = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      // 浏览模式下显示 AppBar（点击切换 overlay）
      appBar: _isDetailMode
          ? null
          : (_showOverlay
              ? AppBar(
                  backgroundColor: Colors.black54,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                  title: Text(
                    _currentMedia.originalName,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    // 多页计数器
                    if (widget.mediaList.length > 1)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / ${widget.mediaList.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    // 切换到详情模式
                    IconButton(
                      icon: const Icon(Icons.tune),
                      tooltip: '详情模式',
                      onPressed: () {
                        setState(() {
                          _isDetailMode = true;
                          _resetTransform();
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showMediaOptions(context),
                    ),
                  ],
                )
              : null),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 媒体内容（支持左右滑动）
          if (widget.mediaList.length > 1 && !_isDetailMode)
            PageView.builder(
              controller: _pageController,
              itemCount: widget.mediaList.length,
              onPageChanged: (index) {
                _switchMedia(widget.mediaList[index]);
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return _buildMediaContentForItem(widget.mediaList[index]);
              },
            )
          else
            GestureDetector(
              onTap: _isDetailMode ? null : () => setState(() => _showOverlay = !_showOverlay),
              child: _buildMediaContent(),
            ),

          // 浏览模式底部操作栏
          if (!_isDetailMode && _showOverlay) _buildBrowseBottomBar(),

          // 详情模式底部控制面板
          if (_isDetailMode) _buildDetailControlPanel(),

          // 详情模式返回按钮
          if (_isDetailMode)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => setState(() => _isDetailMode = false),
              ),
            ),
        ],
      ),
    );
  }

  /// 为 PageView 构建单个媒体内容
  Widget _buildMediaContentForItem(MediaItem media) {
    switch (media.mediaType) {
      case MediaType.image:
        return GestureDetector(
          onTap: () => setState(() => _showOverlay = !_showOverlay),
          child: PhotoView(
            imageProvider: FileImage(File(media.filePath)),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
            initialScale: PhotoViewComputedScale.contained,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        );
      case MediaType.video:
        return GestureDetector(
          onTap: () => setState(() => _showOverlay = !_showOverlay),
          child: _buildVideoPlayer(),
        );
      case MediaType.audio:
        return GestureDetector(
          onTap: () => setState(() => _showOverlay = !_showOverlay),
          child: _buildAudioPlayer(),
        );
      case MediaType.document:
      case MediaType.other:
        return GestureDetector(
          onTap: () => setState(() => _showOverlay = !_showOverlay),
          child: _buildFilePreview(),
        );
    }
  }

  Widget _buildMediaContent() {
    switch (_currentMedia.mediaType) {
      case MediaType.image:
        if (_isDetailMode) {
          return _buildTransformableImage();
        }
        return _buildImageViewer();
      case MediaType.video:
        return _buildVideoPlayer();
      case MediaType.audio:
        return _buildAudioPlayer();
      case MediaType.document:
      case MediaType.other:
        return _buildFilePreview();
    }
  }

  /// 浏览模式图片查看器（photo_view 自带缩放/平移）
  Widget _buildImageViewer() {
    return PhotoView(
      imageProvider: FileImage(File(_currentMedia.filePath)),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3,
      initialScale: PhotoViewComputedScale.contained,
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              Text('无法加载图片', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            ],
          ),
        );
      },
    );
  }

  /// 详情模式可变换图片（用户控制缩放/旋转/平移）
  Widget _buildTransformableImage() {
    return Center(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..translate(_offsetX, _offsetY)
          ..rotateZ(_rotation * math.pi / 180)
          ..scale(_scale),
        child: Image.file(
          File(_currentMedia.filePath),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                Text('无法加载图片', style: TextStyle(color: Colors.white.withOpacity(0.7))),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_chewieController == null || !_videoController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Center(child: Chewie(controller: _chewieController!));
  }

  Widget _buildAudioPlayer() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.audiotrack, size: 96, color: Colors.white54),
          const SizedBox(height: 24),
          Text(_currentMedia.originalName, style: const TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_formatFileSize(_currentMedia.size), style: TextStyle(color: Colors.white.withOpacity(0.6))),
          const SizedBox(height: 32),
          if (_videoController != null && _videoController!.value.isInitialized)
            IconButton(
              iconSize: 64,
              icon: Icon(
                _videoController!.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilePreview() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getFileIcon(), size: 96, color: Colors.white54),
          const SizedBox(height: 24),
          Text(_currentMedia.originalName, style: const TextStyle(color: Colors.white, fontSize: 18), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_formatFileSize(_currentMedia.size), style: TextStyle(color: Colors.white.withOpacity(0.6))),
          const SizedBox(height: 16),
          Text(_currentMedia.mimeType, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        ],
      ),
    );
  }

  /// 浏览模式底部操作栏
  Widget _buildBrowseBottomBar() {
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
            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
          ),
        ),
        padding: EdgeInsets.fromLTRB(16, 32, 16, MediaQuery.of(context).padding.bottom + 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBottomAction(Icons.share, loc.share, () => _shareMedia(context)),
            _buildBottomAction(Icons.download, loc.exportToDownload, () => _exportMedia(context)),
            _buildBottomAction(Icons.label_outline, loc.tags, () => _showTagManager(context)),
            _buildBottomAction(Icons.info_outline, loc.infoPanel, () => _showFileInfoDialog(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  /// 详情模式底部控制面板（图片变换按钮 + 视频播放控件）
  Widget _buildDetailControlPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        child: _currentMedia.mediaType == MediaType.image
            ? _buildImageTransformControls()
            : _currentMedia.mediaType == MediaType.video
                ? _buildVideoPlaybackControls()
                : const SizedBox.shrink(),
      ),
    );
  }

  /// 图片变换控制按钮：上移 / 左旋 / 缩小 / 还原 / 放大 / 右旋 / 下移
  Widget _buildImageTransformControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 变换参数显示
        Text(
          '缩放: ${(_scale * 100).toStringAsFixed(0)}%  旋转: ${_rotation.toStringAsFixed(0)}°',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        ),
        const SizedBox(height: 12),
        // 变换按钮行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTransformButton(Icons.arrow_upward, '↑', () {
              setState(() => _offsetY -= 20);
            }),
            _buildTransformButton(Icons.rotate_left, '⟲', () {
              setState(() => _rotation = (_rotation - 90) % 360);
            }),
            _buildTransformButton(Icons.remove, '−', () {
              setState(() => _scale = (_scale - 0.25).clamp(0.25, 4.0));
            }),
            _buildTransformButton(Icons.refresh, '↺', () {
              setState(() => _resetTransform());
            }),
            _buildTransformButton(Icons.add, '+', () {
              setState(() => _scale = (_scale + 0.25).clamp(0.25, 4.0));
            }),
            _buildTransformButton(Icons.rotate_right, '⟳', () {
              setState(() => _rotation = (_rotation + 90) % 360);
            }),
            _buildTransformButton(Icons.arrow_downward, '↓', () {
              setState(() => _offsetY += 20);
            }),
          ],
        ),
        const SizedBox(height: 8),
        // 平移控制
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTransformButton(Icons.arrow_back, AppLocalizations.of(context).moveLeft, () {
              setState(() => _offsetX -= 20);
            }),
            const SizedBox(width: 16),
            _buildTransformButton(Icons.arrow_forward, AppLocalizations.of(context).moveRight, () {
              setState(() => _offsetX += 20);
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildTransformButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }

  /// 视频播放控件（详情模式）
  Widget _buildVideoPlaybackControls() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 进度条
        VideoProgressIndicator(
          _videoController!,
          allowScrubbing: true,
          colors: VideoProgressColors(
            playedColor: Theme.of(context).colorScheme.primary,
            bufferedColor: Colors.white24,
            backgroundColor: Colors.white12,
          ),
        ),
        const SizedBox(height: 8),
        // 控制按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              iconSize: 36,
              onPressed: () {
                setState(() {
                  if (_videoController!.value.isPlaying) {
                    _videoController!.pause();
                  } else {
                    _videoController!.play();
                  }
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  /// 文件信息对话框（完整 EXIF 显示）
  void _showFileInfoDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.fileInfo),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailInfoRow(loc.fileName, _currentMedia.originalName),
              _buildDetailInfoRow(loc.storageName, _currentMedia.storageName),
              _buildDetailInfoRow(loc.mimeType, _currentMedia.mimeType),
              _buildDetailInfoRow(loc.fileSize, _formatFileSize(_currentMedia.size)),
              if (_currentMedia.width != null && _currentMedia.height != null)
                _buildDetailInfoRow(loc.resolution, '${_currentMedia.width} × ${_currentMedia.height}'),
              if (_currentMedia.duration != null && _currentMedia.duration! > 0)
                _buildDetailInfoRow(loc.duration, _formatDuration(_currentMedia.duration!)),
              _buildDetailInfoRow('SHA-256', _currentMedia.sha256Hash),
              _buildDetailInfoRow(loc.createdAt, _formatDate(_currentMedia.createdAt)),
              _buildDetailInfoRow(loc.updatedAt, _formatDate(_currentMedia.updatedAt)),
              _buildDetailInfoRow(loc.fullPath, _currentMedia.filePath),
              if (_noteContent != null && _noteContent!.isNotEmpty) ...[
                const Divider(),
                Text('${loc.notePanel}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_noteContent!),
              ],
              if (_mediaTags.isNotEmpty) ...[
                const Divider(),
                Text('${loc.tagPanel}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _mediaTags.map((tag) => Chip(
                    label: Text(tag.name, style: const TextStyle(fontSize: 12)),
                    backgroundColor: _parseColor(tag.color),
                    labelStyle: const TextStyle(color: Colors.white),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.close)),
        ],
      ),
    );
  }

  Widget _buildDetailInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text('$label:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis, maxLines: 3),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes % 60}m ${seconds % 60}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds % 60}s';
    }
    return '${seconds}s';
  }

  /// 导出到 Download 目录
  Future<void> _exportMedia(BuildContext context) async {
    try {
      final result = await scanner_api.importSingleFile(filePath: _currentMedia.filePath);
      // 实际导出
      final exportPath = '/storage/emulated/0/Download/${_currentMedia.originalName}';
      // 复制文件到 Download
      final sourceFile = File(_currentMedia.filePath);
      if (await sourceFile.exists()) {
        await sourceFile.copy(exportPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppLocalizations.of(context).exportedTo}: $exportPath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).exportFailed}: $e')),
        );
      }
    }
  }

  void _showMediaOptions(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: Text(loc.rename, style: const TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _showRenameDialog(context); },
              ),
              ListTile(
                leading: const Icon(Icons.note_add, color: Colors.white),
                title: Text(loc.editNote, style: const TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _showNoteDialog(context); },
              ),
              ListTile(
                leading: const Icon(Icons.label, color: Colors.white),
                title: Text(loc.manageTags, style: const TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _showTagManager(context); },
              ),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.white),
                title: Text(loc.exportToDownload, style: const TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _exportMedia(context); },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: Text(loc.share, style: const TextStyle(color: Colors.white)),
                onTap: () { Navigator.pop(context); _shareMedia(context); },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(loc.delete, style: const TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(context); _showDeleteConfirm(context); },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController(text: _currentMedia.originalName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(loc.rename),
          content: TextField(controller: controller, decoration: InputDecoration(labelText: loc.newName), autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.cancel)),
            TextButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  final updated = MediaItem(
                    id: _currentMedia.id, originalName: newName, storageName: _currentMedia.storageName,
                    filePath: _currentMedia.filePath, thumbnailPath: _currentMedia.thumbnailPath,
                    mediaType: _currentMedia.mediaType, mimeType: _currentMedia.mimeType,
                    size: _currentMedia.size, width: _currentMedia.width, height: _currentMedia.height,
                    duration: _currentMedia.duration, sha256Hash: _currentMedia.sha256Hash,
                    createdAt: _currentMedia.createdAt, updatedAt: _currentMedia.updatedAt,
                  );
                  await updateMedia(media: updated);
                  if (context.mounted) {
                    setState(() => _currentMedia = updated);
                    context.read<MediaBloc>().add(const MediaLoadAllEvent());
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(loc.save),
            ),
          ],
        );
      },
    );
  }

  void _showNoteDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController(text: _noteContent ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(loc.editNote),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: loc.noteContent, hintText: loc.noteContentHint),
            maxLines: 5,
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.cancel)),
            TextButton(
              onPressed: () async {
                await note_api.saveNote(mediaId: _currentMedia.id, content: controller.text);
                if (context.mounted) {
                  setState(() => _noteContent = controller.text);
                  Navigator.pop(context);
                }
              },
              child: Text(loc.save),
            ),
          ],
        );
      },
    );
  }

  void _shareMedia(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _currentMedia.filePath));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${AppLocalizations.of(context).filePathCopied}: ${_currentMedia.originalName}')),
    );
  }

  void _showTagManager(BuildContext context) async {
    // 加载所有标签
    final allTags = await tag_api.getAllTags();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => _TagManagerDialog(
        allTags: allTags,
        currentTags: _mediaTags,
        mediaId: _currentMedia.id,
        onTagsChanged: () {
          _loadMediaData();
        },
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(loc.confirmDeleteMedia),
          content: Text('${loc.confirmDeleteMediaMsg} "${_currentMedia.originalName}"'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.cancel)),
            TextButton(
              onPressed: () async {
                await deleteMedia(id: _currentMedia.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  context.read<MediaBloc>().add(const MediaLoadAllEvent());
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(loc.delete),
            ),
          ],
        );
      },
    );
  }

  IconData _getFileIcon() {
    switch (_currentMedia.mediaType) {
      case MediaType.image: return Icons.image;
      case MediaType.video: return Icons.videocam;
      case MediaType.audio: return Icons.audiotrack;
      case MediaType.document: return Icons.description;
      case MediaType.other: return Icons.insert_drive_file;
    }
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
}

/// 标签管理对话框（支持添加和删除标签）
class _TagManagerDialog extends StatefulWidget {
  final List<tag_api.Tag> allTags;
  final List<tag_api.Tag> currentTags;
  final String mediaId;
  final VoidCallback onTagsChanged;

  const _TagManagerDialog({
    required this.allTags,
    required this.currentTags,
    required this.mediaId,
    required this.onTagsChanged,
  });

  @override
  State<_TagManagerDialog> createState() => _TagManagerDialogState();
}

class _TagManagerDialogState extends State<_TagManagerDialog> {
  late Set<String> _selectedTagIds;

  @override
  void initState() {
    super.initState();
    _selectedTagIds = widget.currentTags.map((t) => t.id).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).manageTags),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.allTags.isEmpty
            ? Text(AppLocalizations.of(context).noTagsCreateFirst)
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.allTags.length,
                itemBuilder: (_, i) {
                  final tag = widget.allTags[i];
                  final isSelected = _selectedTagIds.contains(tag.id);
                  return CheckboxListTile(
                    title: Text(tag.name),
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedTagIds.add(tag.id);
                        } else {
                          _selectedTagIds.remove(tag.id);
                        }
                      });
                    },
                    secondary: tag.color != null
                        ? CircleAvatar(
                            backgroundColor: _parseColor(tag.color) ?? Colors.grey,
                            radius: 10,
                          )
                        : null,
                  );
                },
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context).cancel)),
        FilledButton(
          onPressed: () async {
            // 差集计算
            final currentIds = widget.currentTags.map((t) => t.id).toSet();
            final toAdd = _selectedTagIds.difference(currentIds);
            final toRemove = currentIds.difference(_selectedTagIds);

            for (final tagId in toAdd) {
              await tag_api.addTagToMedia(mediaId: widget.mediaId, tagId: tagId);
            }
            for (final tagId in toRemove) {
              await tag_api.removeTagFromMedia(mediaId: widget.mediaId, tagId: tagId);
            }

            widget.onTagsChanged();
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(AppLocalizations.of(context).save),
        ),
      ],
    );
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
}
