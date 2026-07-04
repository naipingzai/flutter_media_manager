import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/i18n/app_localizations.dart';

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

/// 文件夹浏览器 - 返回单个选中的目录路径
///
/// 用于按目录批量导入。用户在文件管理器中浏览，点击目录后
/// 通过右下角"选择此文件夹"按钮确认。
Future<String?> openDirectoryBrowser(BuildContext context) async {
  if (Platform.isAndroid) {
    final granted = await _ensureStoragePermission(context);
    if (!granted) return null;
  }
  if (!context.mounted) return null;
  final result = await Navigator.push<String>(
    context,
    MaterialPageRoute(builder: (_) => const DirectoryPickerPage()),
  );
  return result;
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
        title: Text(AppLocalizations.of(context).needStoragePermission),
        content: Text(AppLocalizations.of(context).manageAllFilesPermissionDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context).gotoSettings),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _navigateTo(_homePath, AppLocalizations.of(context));
      }
    });
  }

  void _navigateTo(String path, AppLocalizations loc) {
    setState(() {
      _loading = true;
      _error = null;
      _currentPath = path;
      if (!_pathHistory.contains(path)) _pathHistory.add(path);
    });
    _loadDir(path, loc);
  }

  void _goBack() {
    if (_pathHistory.length >= 2) {
      _pathHistory.removeLast();
      _navigateTo(_pathHistory.last, AppLocalizations.of(context));
    }
  }

  void _loadDir(String path, AppLocalizations loc) {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        setState(() {
          _error = loc.directoryNotAccessible;
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
        _error = loc.cannotReadDirectory(e.toString());
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
        onPressed: () => _navigateTo(p, AppLocalizations.of(context)),
      ));
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).fileManager),
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
              _loadDir(_currentPath, AppLocalizations.of(context));
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'name', child: Row(children: [
                if (_sortBy == 'name') const Icon(Icons.check, size: 18),
                const SizedBox(width: 8), Text(AppLocalizations.of(context).sortByName),
              ])),
              PopupMenuItem(value: 'type', child: Row(children: [
                if (_sortBy == 'type') const Icon(Icons.check, size: 18),
                const SizedBox(width: 8), Text(AppLocalizations.of(context).sortByType),
              ])),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadDir(_currentPath, AppLocalizations.of(context)),
          ),
        ],
      ),
      body: Column(
        children: [
          // 导航栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.home, size: 16),
                    label: Text(AppLocalizations.of(context).internalStorage, style: const TextStyle(fontSize: 11)),
                    onPressed: () => _navigateTo(_homePath, AppLocalizations.of(context)),
                  ),
                  ..._breadcrumbs(),
                  if (_pathHistory.length > 1) ...[
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.arrow_back, size: 14),
                      label: Text(AppLocalizations.of(context).back, style: TextStyle(fontSize: 11)),
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
                  child: Text(AppLocalizations.of(context).cancel),
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
                  label: Text(AppLocalizations.of(context).importSelectedWithCount(_selected.length)),
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
                onPressed: () => _navigateTo(_homePath, AppLocalizations.of(context)),
                child: Text(AppLocalizations.of(context).backToHome),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).noFiles, style: const TextStyle(fontSize: 16, color: Colors.grey)),
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
              _navigateTo(path, AppLocalizations.of(context));
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

/// 目录选择页面 - 浏览目录树，点击"选择此文件夹"确认
///
/// 与 [FileBrowserPage] 不同：本页只允许点击文件夹进入，不支持文件选择。
/// 用户通过面包屑导航进入目标目录后，点击右下角"选择此文件夹"按钮确认。
class DirectoryPickerPage extends StatefulWidget {
  const DirectoryPickerPage({super.key});

  @override
  State<DirectoryPickerPage> createState() => _DirectoryPickerPageState();
}

class _DirectoryPickerPageState extends State<DirectoryPickerPage> {
  List<Directory> _items = [];
  String _currentPath = '';
  final List<String> _pathHistory = [];
  bool _loading = true;
  String? _error;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _navigateTo(_homePath, AppLocalizations.of(context));
      }
    });
  }

  void _navigateTo(String path, AppLocalizations loc) {
    setState(() {
      _loading = true;
      _error = null;
      _currentPath = path;
      if (!_pathHistory.contains(path)) _pathHistory.add(path);
    });
    _loadDir(path, loc);
  }

  void _goBack() {
    if (_pathHistory.length >= 2) {
      _pathHistory.removeLast();
      _navigateTo(_pathHistory.last, AppLocalizations.of(context));
    }
  }

  void _loadDir(String path, AppLocalizations loc) {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        setState(() {
          _error = loc.directoryNotAccessible;
          _loading = false;
        });
        return;
      }

      var entities = dir.listSync();
      final dirs = <Directory>[];
      for (final e in entities) {
        try {
          if (e is Directory) dirs.add(e);
        } catch (_) {}
      }
      dirs.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));

      setState(() {
        _items = dirs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = loc.cannotReadDirectory(e.toString());
        _loading = false;
      });
    }
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
        onPressed: () => _navigateTo(p, AppLocalizations.of(context)),
      ));
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).selectFolder),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 导航栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.home, size: 16),
                    label: Text(AppLocalizations.of(context).internalStorage, style: TextStyle(fontSize: 11)),
                    onPressed: () => _navigateTo(_homePath, AppLocalizations.of(context)),
                  ),
                  ..._breadcrumbs(),
                  if (_pathHistory.length > 1) ...[
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.arrow_back, size: 14),
                      label: Text(AppLocalizations.of(context).back, style: TextStyle(fontSize: 11)),
                      onPressed: _goBack,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // 目录列表
          Expanded(child: _buildList(theme)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: const Icon(Icons.folder_special, size: 18),
                  onPressed: _loading || _error != null
                      ? null
                      : () => Navigator.pop(context, _currentPath),
                  label: Text(AppLocalizations.of(context).selectThisFolder),
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
                onPressed: () => _navigateTo(_homePath, AppLocalizations.of(context)),
                child: Text(AppLocalizations.of(context).backToHome),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).noSubfolders, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final dir = _items[i];
        final name = dir.path.split('/').last;
        return ListTile(
          leading: Icon(Icons.folder, color: Colors.amber.shade700, size: 28),
          title: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _navigateTo(dir.path, AppLocalizations.of(context)),
        );
      },
    );
  }
}
