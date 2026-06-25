import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// 全屏文件浏览器对话框
///
/// 直接从文件管理器浏览所有文件并导入，不再经过媒体渠道扫描。
/// 自动请求存储权限，Android 上从 /storage/emulated/0 开始浏览。
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
  List<String> _selectedFiles = [];
  String _currentPath = '';
  List<String> _pathSegments = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _permissionGranted = false;

  /// 获取默认起始路径（Android 上用外部存储，其他用 /）
  String get _defaultPath {
    if (Platform.isAndroid) {
      // Android 常见的外部存储路径
      const candidates = [
        '/storage/emulated/0',
        '/sdcard',
        '/storage',
      ];
      for (final p in candidates) {
        if (Directory(p).existsSync()) return p;
      }
    }
    return '/';
  }

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoad();
  }

  Future<void> _requestPermissionAndLoad() async {
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      if (!status.isGranted) {
        // 尝试旧的存储权限
        status = await Permission.storage.request();
      }
      if (mounted) {
        setState(() => _permissionGranted = status.isGranted);
        if (status.isGranted) {
          _loadPath(_defaultPath);
        } else {
          setState(() {
            _errorMessage = '需要存储权限才能浏览文件。请在系统设置中手动授予"管理所有文件"权限。';
            _isLoading = false;
          });
        }
        return;
      }
    }
    // 非 Android 直接加载
    _loadPath(_defaultPath);
  }

  void _resetSession() {
    _selectedFiles = [];
    _loadPath(_currentPath.isNotEmpty ? _currentPath : _defaultPath);
  }

  Future<void> _loadPath(String path) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        setState(() {
          _errorMessage = '目录不存在: $path';
          _isLoading = false;
        });
        return;
      }

      final entities = dir.listSync();
      final items = <FileSystemEntity>[];
      // 先列目录，再列文件
      final folders = <Directory>[];
      final files = <File>[];
      for (final e in entities) {
        if (e is Directory) {
          folders.add(e);
        } else if (e is File) {
          files.add(e);
        }
      }
      folders.sort((a, b) => a.path.compareTo(b.path));
      files.sort((a, b) => a.path.compareTo(b.path));
      items.addAll(folders);
      items.addAll(files);

      setState(() {
        _currentItems = items;
        _currentPath = path;
        _pathSegments = _buildPathSegments(path);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '无法访问目录: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法访问目录: $e')),
        );
      }
    }
  }

  List<String> _buildPathSegments(String path) {
    if (path.isEmpty) return [];
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    return parts;
  }

  String _buildPathFromSegments(int index) {
    if (index < 0) return _defaultPath;
    final segments = _pathSegments.sublist(0, index + 1);
    return '/' + segments.join('/');
  }

  bool get _canNavigateUp => _pathSegments.isNotEmpty;

  bool _isFileSelected(String path) => _selectedFiles.contains(path);

  void _toggleFileSelection(String path) {
    setState(() {
      if (_isFileSelected(path)) {
        _selectedFiles.remove(path);
      } else {
        _selectedFiles.add(path);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('文件浏览器'),
        actions: [
          if (_selectedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  '已选 ${_selectedFiles.length} 个文件',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _resetSession,
          ),
        ],
      ),
      body: _buildBody(theme),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                child: FilledButton(
                  onPressed: _selectedFiles.isEmpty
                      ? null
                      : () {
                          // 先关闭文件浏览器，再执行导入
                          // 确保 onImport 在原始页面的上下文中运行
                          final paths = List<String>.from(_selectedFiles);
                          Navigator.pop(context);
                          widget.onImport(paths);
                        },
                  child: Text(
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

  Widget _buildBody(ThemeData theme) {
    if (_errorMessage != null && !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                onPressed: _requestPermissionAndLoad,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 路径面包屑
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.home, size: 18),
                  label: Text(Platform.isAndroid ? '内部存储' : '根目录'),
                  onPressed: () => _loadPath(_defaultPath),
                ),
                ...List.generate(_pathSegments.length, (index) {
                  return Row(
                    children: [
                      const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                      ActionChip(
                        label: Text(_pathSegments[index]),
                        onPressed: () => _loadPath(_buildPathFromSegments(index)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // 内容区域
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentItems.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('此目录为空', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _currentItems.length + (_canNavigateUp ? 1 : 0),
                      itemBuilder: (context, index) {
                        // 第一个是"返回上级"按钮
                        if (_canNavigateUp && index == 0) {
                          return ListTile(
                            leading: const Icon(Icons.arrow_upward, color: Colors.blue),
                            title: const Text('.. (返回上级)'),
                            onTap: () {
                              if (_pathSegments.length <= 1) {
                                _loadPath(_defaultPath);
                              } else {
                                _loadPath(_buildPathFromSegments(_pathSegments.length - 2));
                              }
                            },
                          );
                        }

                        final itemIndex = _canNavigateUp ? index - 1 : index;
                        if (itemIndex >= _currentItems.length) {
                          return const SizedBox.shrink();
                        }

                        final entity = _currentItems[itemIndex];
                        final isDir = entity is Directory;
                        final entityPath = entity.path;
                        final name = entity.path.split('/').last;
                        final isSelected = _isFileSelected(entityPath);

                        return ListTile(
                          leading: Icon(
                            isDir ? Icons.folder : Icons.insert_drive_file,
                            color: isDir
                                ? Colors.amber
                                : (isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.grey),
                          ),
                          title: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: isDir
                              ? const Icon(Icons.chevron_right)
                              : (isSelected
                                  ? Icon(Icons.check_circle,
                                      color: theme.colorScheme.primary)
                                  : null),
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
                    ),
        ),
      ],
    );
  }
}
