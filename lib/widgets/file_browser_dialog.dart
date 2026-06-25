import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

/// 全屏文件浏览器对话框
/// 
/// 直接从文件管理器浏览所有文件并导入，不再经过媒体渠道扫描。
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

  @override
  void initState() {
    super.initState();
    _resetSession();
  }

  void _resetSession() {
    _selectedFiles = [];
    _loadPath('');
  }

  Future<void> _loadPath(String path) async {
    setState(() => _isLoading = true);
    try {
      final dir = Directory(path.isEmpty ? '/' : path);
      final entities = dir.listSync();
      final items = <FileSystemEntity>[];
      // 先列目录，再列文件
      final folders = entities.where((e) => e is Directory).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      final files = entities.where((e) => e is File).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      items.addAll(folders);
      items.addAll(files);

      setState(() {
        _currentItems = items;
        _currentPath = path;
        _pathSegments = _buildPathSegments(path);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
    if (index < 0) return '';
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
        ],
      ),
      body: Column(
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
                    label: const Text('根目录'),
                    onPressed: () => _loadPath(''),
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
                        itemCount: _currentItems.length,
                        itemBuilder: (context, index) {
                          final entity = _currentItems[index];
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
      ),
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
                          widget.onImport(_selectedFiles);
                          Navigator.pop(context);
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
}
