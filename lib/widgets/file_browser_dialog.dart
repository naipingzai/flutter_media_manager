import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// 文件浏览器对话框 - 返回选择的文件路径列表
///
/// 使用方式: final files = await Navigator.push<List<String>>(context, MaterialPageRoute(builder: (_) => FileBrowserDialog()));
Future<List<String>> openFileBrowser(BuildContext context) async {
  // 先检查并请求权限
  if (Platform.isAndroid) {
    final granted = await _ensureStoragePermission(context);
    if (!granted) return [];
  }
  if (!context.mounted) return [];
  // 打开文件浏览器
  final result = await Navigator.push<List<String>>(
    context,
    MaterialPageRoute(builder: (_) => const FileBrowserPage()),
  );
  return result ?? [];
}

/// 确保 Android 存储权限（MANAGE_EXTERNAL_STORAGE）
Future<bool> _ensureStoragePermission(BuildContext context) async {
  // 检查 MANAGE_EXTERNAL_STORAGE
  var status = await Permission.manageExternalStorage.status;
  if (status.isGranted) return true;

  // 请求权限（Android 11+ 会显示系统对话框）
  status = await Permission.manageExternalStorage.request();
  if (status.isGranted) return true;

  // 尝试普通存储权限（Android 10 及以下）
  status = await Permission.storage.request();
  if (status.isGranted) return true;

  // 权限被拒绝 - 引导用户去系统设置手动开启
  if (context.mounted) {
    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('需要存储权限'),
        content: const Text(
            '浏览文件需要"管理所有文件"权限。\n\n'
            '请点击"去设置"，然后在应用详情中开启"允许管理所有文件"。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );
    if (shouldOpenSettings == true) {
      await openAppSettings();
      // 再次检查
      status = await Permission.manageExternalStorage.status;
      return status.isGranted;
    }
  }
  return false;
}

/// 文件浏览器页面（全屏，完整文件管理器）
class FileBrowserPage extends StatefulWidget {
  const FileBrowserPage({super.key});

  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage> {
  List<FileSystemEntity> _items = [];
  final Set<String> _selected = {};
  String _currentPath = '';
  final List<String> _pathHistory = [];
  bool _loading = true;
  String? _error;
  String _sortBy = 'name'; // name / type

  static const _quickPaths = [
    '/storage/emulated/0',
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Documents',
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Movies',
  ];

  String get _homePath {
    for (final p in _quickPaths) {
      try {
        if (Directory(p).existsSync()) return p;
      } catch (_) {}
    }
    return '/';
  }

  @override
  void initState() {
    super.initState();
    _navigateTo(_homePath);
  }

  void _navigateTo(String path) {
    setState(() {
      _loading = true;
      _error = null;
      _currentPath = path;
      if (!_pathHistory.contains(path)) _pathHistory.add(path);
    });
    _loadDir(path);
  }

  void _goBack() {
    if (_pathHistory.length >= 2) {
      _pathHistory.removeLast();
      _navigateTo(_pathHistory.last);
    }
  }

  void _loadDir(String path) {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        setState(() {
          _error = '目录不可访问';
          _loading = false;
        });
        return;
      }

      var entities = dir.listSync();
      final dirs = <Directory>[];
      final fils = <File>[];

      for (final e in entities) {
        try {
          if (e is Directory) dirs.add(e);
          else if (e is File) fils.add(e);
        } catch (_) {}
      }

      if (_sortBy == 'name') {
        dirs.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
        fils.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
      } else {
        dirs.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
        fils.sort((a, b) {
          final ea = a.path.split('.').last.toLowerCase();
          final eb = b.path.split('.').last.toLowerCase();
          return ea != eb ? ea.compareTo(eb) : a.path.compareTo(b.path);
        });
      }

      setState(() {
        _items = [...dirs, ...fils];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '无法读取目录: $e';
        _loading = false;
      });
    }
  }

  String _ext(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  IconData _icon(FileSystemEntity e) {
    if (e is Directory) return Icons.folder;
    final ext = _ext(e.path);
    if (['jpg','jpeg','png','gif','webp','bmp','heic','heif'].contains(ext)) return Icons.image;
    if (['mp4','mkv','avi','mov','webm','flv'].contains(ext)) return Icons.videocam;
    if (['mp3','wav','flac','aac','ogg'].contains(ext)) return Icons.audiotrack;
    if (['pdf','doc','docx','txt','md','epub'].contains(ext)) return Icons.description;
    if (['zip','rar','7z','tar','gz'].contains(ext)) return Icons.archive;
    return Icons.insert_drive_file;
  }

  List<Widget> _breadcrumbs() {
    if (_currentPath.isEmpty) return [];
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    final chips = <Widget>[];
    String acc = '';
    for (int i = 0; i < parts.length; i++) {
      acc += '/${parts[i]}';
      final p = acc;
      chips.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2),
        child: Icon(Icons.chevron_right, size: 14, color: Colors.grey),
      ));
      chips.add(ActionChip(
        label: Text(parts[i], style: const TextStyle(fontSize: 11)),
        onPressed: () => _navigateTo(p),
      ));
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件管理器'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, <String>[]),
        ),
        actions: [
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                avatar: Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimaryContainer),
                label: Text('${_selected.length}'),
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (v) {
              setState(() => _sortBy = v);
              _loadDir(_currentPath);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'name', child: Row(children: [
                if (_sortBy == 'name') const Icon(Icons.check, size: 18),
                const SizedBox(width: 8), const Text('按名称'),
              ])),
              PopupMenuItem(value: 'type', child: Row(children: [
                if (_sortBy == 'type') const Icon(Icons.check, size: 18),
                const SizedBox(width: 8), const Text('按类型'),
              ])),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDir(_currentPath),
          ),
        ],
      ),
      body: Column(
        children: [
          // 导航栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.home, size: 16),
                    label: Text('内部存储', style: const TextStyle(fontSize: 11)),
                    onPressed: () => _navigateTo(_homePath),
                  ),
                  ..._breadcrumbs(),
                  if (_pathHistory.length > 1) ...[
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.arrow_back, size: 14),
                      label: const Text('返回', style: TextStyle(fontSize: 11)),
                      onPressed: _goBack,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // 文件列表
          Expanded(child: _buildList(theme)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, <String>[]),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: const Icon(Icons.file_upload, size: 18),
                  onPressed: _selected.isEmpty ? null : () {
                    final paths = _selected.toList();
                    Navigator.pop(context, paths);
                  },
                  label: Text('导入${_selected.isEmpty ? "" : " (${_selected.length})"}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _navigateTo(_homePath),
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('此目录为空', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final e = _items[i];
        final isDir = e is Directory;
        final path = e.path;
        final name = path.split('/').last;
        final sel = _selected.contains(path);

        return ListTile(
          leading: Icon(_icon(e), color: isDir ? Colors.amber.shade700 : (sel ? theme.colorScheme.primary : Colors.grey), size: 28),
          title: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
          subtitle: isDir ? null : Text(_ext(path).toUpperCase(), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          trailing: isDir ? const Icon(Icons.chevron_right) : Icon(sel ? Icons.check_circle : Icons.circle_outlined, color: sel ? theme.colorScheme.primary : Colors.grey.shade400),
          selected: sel,
          onTap: () {
            if (isDir) {
              _navigateTo(path);
            } else {
              setState(() {
                if (sel) _selected.remove(path); else _selected.add(path);
              });
            }
          },
        );
      },
    );
  }
}
