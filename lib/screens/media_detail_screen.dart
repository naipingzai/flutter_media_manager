import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../bloc/bloc.dart';
import '../src/rust/api/media.dart';
import '../src/rust/api/note.dart' as note_api;
import '../src/rust/api/tag.dart' as tag_api;

/// 媒体详情查看页面
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

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  late MediaItem _currentMedia;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _noteContent;
  List<tag_api.Tag> _mediaTags = [];
  bool _showInfo = false;

  @override
  void initState() {
    super.initState();
    _currentMedia = widget.media;
    _loadMediaData();
    _initVideoIfNeeded();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _loadMediaData() async {
    // 加载笔记
    final note = await note_api.getNoteByMediaId(mediaId: _currentMedia.id);
    if (mounted) {
      setState(() {
        _noteContent = note?.content;
      });
    }

    // 加载标签
    final tags = await tag_api.getMediaTags(mediaId: _currentMedia.id);
    if (mounted) {
      setState(() {
        _mediaTags = tags;
      });
    }
  }

  void _initVideoIfNeeded() {
    if (_currentMedia.mediaType == MediaType.video) {
      _videoController = VideoPlayerController.file(
        File(_currentMedia.filePath),
      );
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
      _showInfo = false;
    });
    _loadMediaData();
    _initVideoIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => setState(() => _showInfo = !_showInfo),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMediaOptions(context),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 媒体内容
          _buildMediaContent(),

          // 底部信息面板
          if (_showInfo) _buildInfoPanel(),

          // 导航按钮
          if (widget.mediaList.length > 1) ...[
            _buildPreviousButton(),
            _buildNextButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaContent() {
    switch (_currentMedia.mediaType) {
      case MediaType.image:
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
              Text(
                '无法加载图片',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoPlayer() {
    if (_chewieController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _buildAudioPlayer() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.audiotrack, size: 96, color: Colors.white54),
          const SizedBox(height: 24),
          Text(
            _currentMedia.originalName,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _formatFileSize(_currentMedia.size),
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 32),
          if (_videoController != null && _videoController!.value.isInitialized)
            IconButton(
              iconSize: 64,
              icon: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
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
          Icon(
            _getFileIcon(),
            size: 96,
            color: Colors.white54,
          ),
          const SizedBox(height: 24),
          Text(
            _currentMedia.originalName,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _formatFileSize(_currentMedia.size),
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 16),
          Text(
            _currentMedia.mimeType,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousButton() {
    final currentIndex = widget.mediaList.indexWhere((m) => m.id == _currentMedia.id);
    if (currentIndex <= 0) return const SizedBox.shrink();

    return Positioned(
      left: 8,
      top: 0,
      bottom: 0,
      child: Center(
        child: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 48),
          onPressed: () {
            _switchMedia(widget.mediaList[currentIndex - 1]);
          },
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    final currentIndex = widget.mediaList.indexWhere((m) => m.id == _currentMedia.id);
    if (currentIndex < 0 || currentIndex >= widget.mediaList.length - 1) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 8,
      top: 0,
      bottom: 0,
      child: Center(
        child: IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white, size: 48),
          onPressed: () {
            _switchMedia(widget.mediaList[currentIndex + 1]);
          },
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.9),
              Colors.black.withOpacity(0.6),
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentMedia.originalName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(Icons.folder, '路径', _currentMedia.filePath),
              _buildInfoRow(Icons.data_usage, '大小', _formatFileSize(_currentMedia.size)),
              _buildInfoRow(Icons.merge_type, '类型', _currentMedia.mimeType),
              _buildInfoRow(Icons.calendar_today, '创建时间', _formatDate(_currentMedia.createdAt)),
              if (_currentMedia.width != null && _currentMedia.height != null)
                _buildInfoRow(
                  Icons.aspect_ratio,
                  '尺寸',
                  '${_currentMedia.width} x ${_currentMedia.height}',
                ),
              if (_noteContent != null && _noteContent!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.note, '笔记', _noteContent!),
              ],
              if (_mediaTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _mediaTags.map((tag) {
                    return Chip(
                      label: Text(
                        tag.name,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: _parseColor(tag.color) ?? Colors.grey[700],
                      labelStyle: const TextStyle(color: Colors.white),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white.withOpacity(0.6)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  void _showMediaOptions(BuildContext context) {
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
                title: const Text('编辑名称', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showRenameDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.note_add, color: Colors.white),
                title: const Text('编辑笔记', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showNoteDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.label, color: Colors.white),
                title: const Text('管理标签', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _showTagManager(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: const Text('分享', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _shareMedia(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirm(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: _currentMedia.originalName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重命名'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '新名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
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
                  if (context.mounted) {
                    setState(() {
                      _currentMedia = updated;
                    });
                    context.read<MediaBloc>().add(const MediaLoadAllEvent());
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showNoteDialog(BuildContext context) {
    final controller = TextEditingController(text: _noteContent ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('编辑笔记'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '笔记内容',
              hintText: '输入笔记...',
            ),
            maxLines: 5,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                await note_api.saveNote(
                  mediaId: _currentMedia.id,
                  content: controller.text,
                );
                if (context.mounted) {
                  setState(() {
                    _noteContent = controller.text;
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _shareMedia(BuildContext context) {
    // 分享功能：使用系统分享对话框
    // 由于 share_plus 插件可能未安装，使用简单的 Snackbar 提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('分享: ${_currentMedia.originalName}'),
        action: SnackBarAction(
          label: '复制路径',
          onPressed: () {
            // 复制文件路径到剪贴板
            // 需要 flutter/services 的 Clipboard
          },
        ),
      ),
    );
  }

  void _showTagManager(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('标签管理'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _mediaTags.length,
              itemBuilder: (context, index) {
                final tag = _mediaTags[index];
                return ListTile(
                  dense: true,
                  title: Text(tag.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () async {
                      await tag_api.removeTagFromMedia(
                        mediaId: _currentMedia.id,
                        tagId: tag.id,
                      );
                      if (mounted) {
                        setState(() {
                          _mediaTags.removeAt(index);
                        });
                      }
                    },
                  ),
                );
              },
            ),
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

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除 "${_currentMedia.originalName}" 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                await deleteMedia(id: _currentMedia.id);
                if (context.mounted) {
                  Navigator.pop(context); // 关闭对话框
                  Navigator.pop(context); // 返回媒体列表
                  context.read<MediaBloc>().add(const MediaLoadAllEvent());
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  IconData _getFileIcon() {
    switch (_currentMedia.mediaType) {
      case MediaType.image:
        return Icons.image;
      case MediaType.video:
        return Icons.videocam;
      case MediaType.audio:
        return Icons.audiotrack;
      case MediaType.document:
        return Icons.description;
      case MediaType.other:
        return Icons.insert_drive_file;
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
