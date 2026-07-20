import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_media_manager/core/i18n/app_localizations.dart';
import 'package:flutter_media_manager/core/design_system/app_theme.dart';

/// 文件浏览器 - 返回选择的文件路径列表
Future<List<String>> openFileBrowser(BuildContext context) async {
  if (Platform.isAndroid) {
    final granted = await _ensureStoragePermission(context);
    if (!granted) return [];
  }
  if (!context.mounted) return [];
  final result = await Navigator.push<List<String>>(
    context,
    MaterialPageRoute(
      builder: (_) => const FileBrowserPage(),
      fullscreenDialog: true,
    ),
  );
  return result ?? [];
}

/// 目录选择器 - 返回单个目录路径
Future<String?> openDirectoryBrowser(BuildContext context) async {
  if (Platform.isAndroid) {
    final granted = await _ensureStoragePermission(context);
    if (!granted) return null;
  }
  if (!context.mounted) return null;
  final result = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => const DirectoryPickerPage(),
      fullscreenDialog: true,
    ),
  );
  return result;
}

/// Android 存储权限
Future<bool> _ensureStoragePermission(BuildContext context) async {
  var status = await Permission.manageExternalStorage.status;
  if (status.isGranted) return true;
  status = await Permission.manageExternalStorage.request();
  if (status.isGranted) return true;
  status = await Permission.storage.request();
  if (status.isGranted) return true;
  if (context.mounted) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.folder_off_outlined, size: 40, color: cs.error),
        title: Text(loc.needStoragePermission),
        content: Text(loc.manageAllFilesPermissionDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.gotoSettings),
          ),
        ],
      ),
    );
    if (shouldOpen == true) {
      await openAppSettings();
      status = await Permission.manageExternalStorage.status;
      return status.isGranted;
    }
  }
  return false;
}

// ═══════════════════════════════════════════════════════════════════════
// 文件浏览器页面
// ═══════════════════════════════════════════════════════════════════════

class FileBrowserPage extends StatefulWidget {
  const FileBrowserPage({super.key});
  @override
  State<FileBrowserPage> createState() => _FileBrowserPageState();
}

class _FileBrowserPageState extends State<FileBrowserPage> {
  List<_FileItem> _items = [];
  final Set<String> _selected = {};
  String _currentPath = '';
  final List<String> _pathHistory = [];
  bool _loading = true;
  String? _error;
  bool _sortByName = true;
  final bool _showHidden = false;
  final ScrollController _breadcrumbScroll = ScrollController();

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
      if (mounted) _navigateTo(_homePath);
    });
  }

  @override
  void dispose() {
    _breadcrumbScroll.dispose();
    super.dispose();
  }

  void _navigateTo(String path) {
    setState(() {
      _loading = true;
      _error = null;
      _currentPath = path;
      if (!_pathHistory.contains(path)) _pathHistory.add(path);
    });
    _loadDir(path);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_breadcrumbScroll.hasClients) {
        _breadcrumbScroll.jumpTo(_breadcrumbScroll.position.maxScrollExtent);
      }
    });
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
          _error = AppLocalizations.of(context).directoryNotAccessible;
          _loading = false;
        });
        return;
      }

      final entities = dir.listSync();
      final dirs = <Directory>[];
      final files = <File>[];

      for (final e in entities) {
        try {
          final name = e.path.split('/').last;
          if (!_showHidden && name.startsWith('.')) continue;
          if (e is Directory) {
            dirs.add(e);
          } else if (e is File) {
            files.add(e);
          }
        } catch (_) {}
      }

      // 排序
      if (_sortByName) {
        dirs.sort(
            (a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()));
        files.sort(
            (a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()));
      } else {
        dirs.sort(
            (a, b) => _name(a).toLowerCase().compareTo(_name(b).toLowerCase()));
        files.sort((a, b) {
          final ea = a.path.split('.').last.toLowerCase();
          final eb = b.path.split('.').last.toLowerCase();
          return ea != eb ? ea.compareTo(eb) : _name(a).compareTo(_name(b));
        });
      }

      setState(() {
        _items = [
          ...dirs.map((d) => _FileItem.directory(d)),
          ...files.map((f) => _FileItem.file(f)),
        ];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context).cannotReadDirectory(e.toString());
        _loading = false;
      });
    }
  }

  String _name(FileSystemEntity e) => e.path.split('/').last;

  String _ext(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(loc.fileManager),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context, <String>[]),
        ),
        actions: [
          // 选中计数
          if (_selected.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                '${_selected.length}',
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          // 排序切换
          IconButton(
            icon: Icon(
              _sortByName ? Icons.sort_by_alpha_rounded : Icons.sort_rounded,
              color: cs.onSurfaceVariant,
            ),
            tooltip: _sortByName ? loc.sortByName : loc.sortByType,
            onPressed: () {
              setState(() => _sortByName = !_sortByName);
              _loadDir(_currentPath);
            },
          ),
          // 刷新
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: cs.onSurfaceVariant),
            onPressed: () => _loadDir(_currentPath),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 面包屑 ──
          _buildBreadcrumbBar(cs),
          const Divider(height: 1),
          // ── 列表 ──
          Expanded(child: _buildContent(cs)),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(cs, loc),
    );
  }

  // ── 面包屑 ─────────────────────────────────────────────────────
  Widget _buildBreadcrumbBar(ColorScheme cs) {
    final loc = AppLocalizations.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      child: ListView(
        controller: _breadcrumbScroll,
        scrollDirection: Axis.horizontal,
        children: [
          // 返回按钮
          if (_pathHistory.length > 1)
            _BreadcrumbPill(
              icon: Icons.arrow_back_rounded,
              label: loc.back,
              onTap: _goBack,
              cs: cs,
            ),
          // 首页
          _BreadcrumbPill(
            icon: Icons.home_rounded,
            label: loc.internalStorage,
            isActive: _pathHistory.length <= 1,
            onTap: () => _navigateTo(_homePath),
            cs: cs,
          ),
          // 路径段
          ..._buildPathSegments(cs),
        ],
      ),
    );
  }

  List<Widget> _buildPathSegments(ColorScheme cs) {
    if (_currentPath.isEmpty) return [];
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    final widgets = <Widget>[];
    String acc = '';
    for (int i = 0; i < parts.length; i++) {
      acc += '/${parts[i]}';
      final p = acc;
      final isLast = i == parts.length - 1;
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(Icons.chevron_right_rounded,
            size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
      ));
      widgets.add(_BreadcrumbPill(
        label: parts[i],
        isActive: isLast,
        onTap: isLast ? null : () => _navigateTo(p),
        cs: cs,
      ));
    }
    return widgets;
  }

  // ── 内容区 ──────────────────────────────────────────────────────
  Widget _buildContent(ColorScheme cs) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child:
                  CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppLocalizations.of(context).loading,
              style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return _buildErrorState(cs);
    }
    if (_items.isEmpty) {
      return _buildEmptyState(cs);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final item = _items[i];
        return item.when(
          directory: (dir) => _buildDirTile(dir, cs),
          file: (file) => _buildFileTile(file, cs),
        );
      },
    );
  }

  Widget _buildDirTile(Directory dir, ColorScheme cs) {
    final name = _name(dir);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: () => _navigateTo(dir.path),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child:
                      Icon(Icons.folder_rounded, size: 20, color: cs.tertiary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    name,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileTile(File file, ColorScheme cs) {
    final name = _name(file);
    final ext = _ext(file.path);
    final sel = _selected.contains(file.path);
    final iconData = _fileIcon(ext);
    final iconColor = _fileIconColor(ext, cs);
    final fileSize = file.existsSync() ? file.lengthSync() : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Material(
        color: sel
            ? cs.primaryContainer.withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: () {
            setState(() {
              sel ? _selected.remove(file.path) : _selected.add(file.path);
            });
          },
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 文件图标
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: sel
                        ? cs.primary.withValues(alpha: 0.12)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(iconData,
                      size: 18, color: sel ? cs.primary : iconColor),
                ),
                const SizedBox(width: AppSpacing.md),
                // 文件信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: sel ? cs.primary : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            ext.toUpperCase(),
                            style: AppTextStyles.caption.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '  ·  ${_formatSize(fileSize)}',
                            style: AppTextStyles.caption.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 选中状态
                AnimatedSwitcher(
                  duration: AppAnimation.fast,
                  child: sel
                      ? Container(
                          key: const ValueKey(true),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_rounded,
                              size: 14, color: cs.onPrimary),
                        )
                      : Icon(Icons.circle_outlined,
                          key: const ValueKey(false),
                          size: 20,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 空/错误状态 ─────────────────────────────────────────────────
  Widget _buildEmptyState(ColorScheme cs) {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.folder_off_outlined,
                size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(loc.noFiles,
              style:
                  AppTextStyles.subtitle.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme cs) {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.folder_off_rounded, size: 48, color: cs.error),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(_error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () => _navigateTo(_homePath),
              icon: const Icon(Icons.home_rounded, size: 18),
              label: Text(loc.backToHome),
            ),
          ],
        ),
      ),
    );
  }

  // ── 底栏 ────────────────────────────────────────────────────────
  Widget _buildBottomBar(ColorScheme cs, AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, <String>[]),
                  child: Text(loc.cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: const Icon(Icons.file_upload_rounded, size: 18),
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected.toList()),
                  label: Text(loc.importSelectedWithCount(_selected.length)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 工具方法 ────────────────────────────────────────────────────
  IconData _fileIcon(String ext) {
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif']
        .contains(ext)) {
      return Icons.image_outlined;
    }
    if (['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv'].contains(ext)) {
      return Icons.videocam_outlined;
    }
    if (['mp3', 'wav', 'flac', 'aac', 'ogg'].contains(ext)) {
      return Icons.audiotrack_outlined;
    }
    if (['pdf', 'doc', 'docx', 'txt', 'md', 'epub'].contains(ext)) {
      return Icons.description_outlined;
    }
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return Icons.archive_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  Color _fileIconColor(String ext, ColorScheme cs) {
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif']
        .contains(ext)) {
      return cs.secondary;
    }
    if (['mp4', 'mkv', 'avi', 'mov', 'webm', 'flv'].contains(ext)) {
      return cs.error;
    }
    if (['mp3', 'wav', 'flac', 'aac', 'ogg'].contains(ext)) {
      return cs.primary;
    }
    if (['pdf', 'doc', 'docx', 'txt', 'md', 'epub'].contains(ext)) {
      return cs.tertiary;
    }
    return cs.onSurfaceVariant;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 目录选择页面
// ═══════════════════════════════════════════════════════════════════════

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
  final ScrollController _breadcrumbScroll = ScrollController();

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
      if (mounted) _navigateTo(_homePath);
    });
  }

  @override
  void dispose() {
    _breadcrumbScroll.dispose();
    super.dispose();
  }

  void _navigateTo(String path) {
    setState(() {
      _loading = true;
      _error = null;
      _currentPath = path;
      if (!_pathHistory.contains(path)) _pathHistory.add(path);
    });
    _loadDir(path);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_breadcrumbScroll.hasClients) {
        _breadcrumbScroll.jumpTo(_breadcrumbScroll.position.maxScrollExtent);
      }
    });
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
          _error = AppLocalizations.of(context).directoryNotAccessible;
          _loading = false;
        });
        return;
      }
      final dirs = <Directory>[];
      for (final e in dir.listSync()) {
        try {
          if (e is Directory && !e.path.split('/').last.startsWith('.')) {
            dirs.add(e);
          }
        } catch (_) {}
      }
      dirs.sort((a, b) => a.path
          .split('/')
          .last
          .toLowerCase()
          .compareTo(b.path.split('/').last.toLowerCase()));
      setState(() {
        _items = dirs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context).cannotReadDirectory(e.toString());
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(loc.selectFolder),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 面包屑
          _buildBreadcrumbBar(cs),
          const Divider(height: 1),
          // 当前路径提示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
            child: Row(
              children: [
                Icon(Icons.folder_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentPath,
                    style: AppTextStyles.caption
                        .copyWith(color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          // 列表
          Expanded(child: _buildContent(cs, loc)),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(cs, loc),
    );
  }

  Widget _buildBreadcrumbBar(ColorScheme cs) {
    final loc = AppLocalizations.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      child: ListView(
        controller: _breadcrumbScroll,
        scrollDirection: Axis.horizontal,
        children: [
          if (_pathHistory.length > 1)
            _BreadcrumbPill(
              icon: Icons.arrow_back_rounded,
              label: loc.back,
              onTap: _goBack,
              cs: cs,
            ),
          _BreadcrumbPill(
            icon: Icons.home_rounded,
            label: loc.internalStorage,
            isActive: _pathHistory.length <= 1,
            onTap: () => _navigateTo(_homePath),
            cs: cs,
          ),
          ..._buildPathSegments(cs),
        ],
      ),
    );
  }

  List<Widget> _buildPathSegments(ColorScheme cs) {
    if (_currentPath.isEmpty) return [];
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    final widgets = <Widget>[];
    String acc = '';
    for (int i = 0; i < parts.length; i++) {
      acc += '/${parts[i]}';
      final p = acc;
      final isLast = i == parts.length - 1;
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(Icons.chevron_right_rounded,
            size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
      ));
      widgets.add(_BreadcrumbPill(
        label: parts[i],
        isActive: isLast,
        onTap: isLast ? null : () => _navigateTo(p),
        cs: cs,
      ));
    }
    return widgets;
  }

  Widget _buildContent(ColorScheme cs, AppLocalizations loc) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child:
                  CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(loc.loading,
                style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.folder_off_rounded, size: 48, color: cs.error),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style:
                      AppTextStyles.body.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => _navigateTo(_homePath),
                icon: const Icon(Icons.home_rounded, size: 18),
                label: Text(loc.backToHome),
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
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.folder_off_outlined,
                  size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(loc.noSubfolders,
                style: AppTextStyles.subtitle
                    .copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final dir = _items[i];
        final name = dir.path.split('/').last;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: InkWell(
              onTap: () => _navigateTo(dir.path),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(Icons.folder_rounded,
                          size: 20, color: cs.tertiary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(name,
                          style: AppTextStyles.body
                              .copyWith(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(ColorScheme cs, AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.icon(
            icon: const Icon(Icons.folder_special_rounded, size: 18),
            onPressed: (_loading || _error != null)
                ? null
                : () => Navigator.pop(context, _currentPath),
            label: Text(loc.selectThisFolder),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 通用组件
// ═══════════════════════════════════════════════════════════════════════

/// 文件项（union type：目录或文件）
class _FileItem {
  final Directory? directory;
  final File? file;

  _FileItem.directory(this.directory) : file = null;
  _FileItem.file(this.file) : directory = null;

  T when<T>({
    required T Function(Directory) directory,
    required T Function(File) file,
  }) {
    if (this.directory != null) return directory(this.directory!);
    return file(this.file!);
  }
}

/// 面包屑药丸组件
class _BreadcrumbPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;
  final ColorScheme cs;

  const _BreadcrumbPill({
    this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? cs.primaryContainer
                : cs.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 14,
                    color:
                        isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? cs.onPrimaryContainer : cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
