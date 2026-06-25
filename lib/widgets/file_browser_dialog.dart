import 'dart:io';
import 'package:flutter/material.dart';

/// 全屏文件浏览器对话框（文件管理器风格）
///
/// 直接浏览文件系统的全部文件，不再经过媒体渠道扫描。
/// 显示目录树和文件列表，用户可以自由浏览和选择文件导入。
/// 
/// 注意：请在打开此页面之前确保已获取 MANAGE_EXTERNAL_STORAGE 权限。
class FileBrowserDialog extends StatefulWidget {
  final void Function(List<String> filePaths) onImport;

  const FileBrowserDialog({
    super.key,
    required this.onImport,
  });

  @override
  State<FileBrowserDialog> createState() => _FileBrowserDialogState();
}

class _FileBrowserDialogState extends State<FileBrowserDialog> {
  List<FileSystemEntity> _currentItems = [];
  final Set<String> _selectedFiles = {};
  String _currentPath = '';
  final List<String> _pathHistory = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _sortMode = 'name'; // 'name' or 'type'

  /// Android 常用可访问目录
  static const List<String> _favoritePaths = [
    '/storage/emulated/0',
    '/storage/emulated/0/DCIM',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Documents',
    '/storage/emulated/0/Pictures',
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Movies',
    '/storage',
  ];

  String get _defaultPath {
    if (Platform.isAndroid) {
      for (final p in _favoritePaths) {
        try {
          if (Directory(p).existsSync()) return p;
        } catch (_) {}
      }
    }
    return '/';
  }

  @override
  void initState() {
    super.initState();
    _loadPath(_defaultPath);
  }

  Future<void> _loadPath(String path) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dir = Directory(path);
      final exists = await dir.exists();
      if (!exists) {
        setState(() {
          _errorMessage = '目录不可访问: $path';
          _isLoading = false;
        });
        return;
      }

      final entities = await dir.list().toList();
      final folders = <Directory>[];
      final files = <File>[];

      for (final e in entities) {
        try {
          if (e is Directory) {
            folders.add(e);
          } else if (e is File) {
            files.add(e);
          }
        } catch (_) {
          // 忽略无法访问的条目
        }
      }

      if (_sortMode == 'name') {
        folders.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
        files.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
      } else {
        // type sort: 按扩展名分组
        folders.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
        files.sort((a, b) {
          final extA = a.path.split('.').last.toLowerCase();
          final extB = b.path.split('.').last.toLowerCase();
          final cmp = extA.compareTo(extB);
          if (cmp != 0) return cmp;
          return a.path.toLowerCase().compareTo(b.path.toLowerCase());
        });
      }

      setState(() {
        _currentItems = [...folders, ...files];
        _currentPath = path;
        if (!_pathHistory.contains(path)) {
          _pathHistory.add(path);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '无法访问目录: $e';
      });
    }
  }

  bool _isFileSelected(String path) => _selectedFiles.contains(path);

  void _toggleFileSelection(String path) {
    setState(() {
      if (_selectedFiles.contains(path)) {
        _selectedFiles.remove(path);
      } else {
        _selectedFiles.add(path);
      }
    });
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }

  String _getFileExtension(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  IconData _getFileIcon(FileSystemEntity entity) {
    if (entity is Directory) return Icons.folder;
    final ext = _getFileExtension(entity.path);
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'].contains(ext)) {
      return Icons.image;
    }
    if (['mp4', 'mkv', 'avi', 'mov', 'webm'].contains(ext)) {
      return Icons.videocam;
    }
    if (['mp3', 'wav', 'flac', 'aac', 'ogg'].contains(ext)) {
      return Icons.audiotrack;
    }
    if (['pdf', 'doc', 'docx', 'txt', 'md'].contains(ext)) {
      return Icons.description;
    }
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件管理器'),
        actions: [
          if (_selectedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_selectedFiles.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onSelected: (val) {
              setState(() => _sortMode = val);
              if (_currentPath.isNotEmpty) _loadPath(_currentPath);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    if (_sortMode == 'name') const Icon(Icons.check, size: 18),
                    const SizedBox(width: 8),
                    const Text('按名称排序'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'type',
                child: Row(
                  children: [
                    if (_sortMode == 'type') const Icon(Icons.check, size: 18),
                    const SizedBox(width: 8),
                    const Text('按类型排序'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => _currentPath.isNotEmpty ? _loadPath(_currentPath) : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // 当前位置与快速访问
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.home, size: 16),
                    label: Text(
                      Platform.isAndroid ? '内部存储' : '根目录',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _loadPath(_defaultPath),
                  ),
                  ..._buildBreadcrumbs(),
                  const SizedBox(width: 8),
                  if (_pathHistory.length > 1)
                    ActionChip(
                      avatar: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('返回', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        if (_pathHistory.length >= 2) {
                          final prev = _pathHistory[_pathHistory.length - 2];
                          _pathHistory.removeLast();
                          _loadPath(prev);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          // 文件列表
          Expanded(child: _buildFileList(theme)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: const Icon(Icons.file_upload, size: 18),
                  onPressed: _selectedFiles.isEmpty
                      ? null
                      : () {
                          final paths = List<String>.from(_selectedFiles);
                          // 先关闭文件管理器，回到 MediaScreen
                          Navigator.pop(context);
                          // 再触发导入回调
                          widget.onImport(paths);
                        },
                  label: Text(
                    '导入${_selectedFiles.isEmpty ? "" : " (${_selectedFiles.length})"}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBreadcrumbs() {
    if (_currentPath.isEmpty) return [];
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    final widgets = <Widget>[];
    String accumulated = '';

    for (int i = 0; i < parts.length; i++) {
      accumulated += '/${parts[i]}';
      final path = accumulated;
      widgets.add(const Icon(Icons.chevron_right, size: 16, color: Colors.grey));
      widgets.add(
        ActionChip(
          label: Text(parts[i], style: const TextStyle(fontSize: 11)),
          onPressed: () => _loadPath(path),
        ),
      );
    }
    return widgets;
  }

  Widget _buildFileList(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                onPressed: () => _loadPath(_defaultPath),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentItems.isEmpty) {
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
      itemCount: _currentItems.length,
      itemBuilder: (context, index) {
        final entity = _currentItems[index];
        final isDir = entity is Directory;
        final entityPath = entity.path;
        final name = _getFileName(entityPath);
        final isSelected = _isFileSelected(entityPath);

        return ListTile(
          leading: Icon(
            _getFileIcon(entity),
            color: isDir
                ? Colors.amber.shade700
                : (isSelected ? theme.colorScheme.primary : Colors.grey),
            size: 28,
          ),
          title: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: isDir
              ? null
              : Text(
                  _getFileExtension(entityPath).toUpperCase(),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
          trailing: isDir
              ? const Icon(Icons.chevron_right)
              : (isSelected
                  ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                  : const Icon(Icons.circle_outlined, color: Colors.grey, size: 20)),
          selected: isSelected,
          onTap: () {
            if (isDir) {
              _loadPath(entityPath);
            } else {
              _toggleFileSelection(entityPath);
            }
          },
        );
      },
    );
  }
}
