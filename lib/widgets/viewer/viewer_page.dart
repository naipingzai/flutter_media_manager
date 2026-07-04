import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/bloc.dart';
import '../../core/i18n/app_localizations.dart';
import '../../src/rust/api/media.dart' as media_api;
import 'image_viewer.dart';
import 'video_player_widget.dart';
import 'audio_player_widget.dart';
import '../../screens/media_edit_screen.dart';

/// 全屏媒体查看器
///
/// 功能:
/// - HorizontalPager 翻页浏览
/// - 自动隐藏的 TopBar 和 BottomBar
/// - 图片双指/双击缩放
/// - 视频播放控制
/// - 音频播放控制
/// - 分享/导出
/// - 跳转到编辑页
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
  Timer? _hideTimer;

  media_api.MediaItem get _currentMedia => widget.mediaList[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.mediaList.indexWhere((m) => m.id == widget.initialMedia.id);
    if (_currentIndex < 0) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
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
      if (mounted) {
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

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _showDeleteConfirm() {
    final loc = AppLocalizations.of(context);
    final mediaBloc = context.read<MediaBloc>();
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
            onPressed: () => _deleteMedia(
              dialogNavigator: Navigator.of(ctx),
              mediaBloc: mediaBloc,
            ),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMedia({
    required NavigatorState dialogNavigator,
    required MediaBloc mediaBloc,
  }) async {
    await media_api.deleteMedia(id: _currentMedia.id);
    if (mounted) {
      dialogNavigator.pop(); // 关闭删除确认对话框
      dialogNavigator.pop(); // 关闭 ViewerPage
      mediaBloc.add(const MediaRefreshEvent());
    }
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
        ],
      ),
    );
  }

  Widget _buildMediaContent(media_api.MediaItem media) {
    switch (media.mediaType) {
      case media_api.MediaType.image:
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
          Text(
            media.originalName,
            style: const TextStyle(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _formatFileSize(media.size),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentMedia.originalName,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${widget.mediaList.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
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
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBottomAction(Icons.edit, loc.edit, () {
                  _hideTimer?.cancel();
                  _openEditScreen();
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

  Widget _buildBottomAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(color: color ?? Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaEditScreen(
          media: _currentMedia,
          mediaList: widget.mediaList,
        ),
      ),
    );
  }
}
