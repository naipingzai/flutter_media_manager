import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';
import '../core/design_system/app_theme.dart';
import '../core/design_system/components.dart';
import '../core/i18n/app_localizations.dart';
import '../widgets/media_grid.dart';
import '../widgets/file_browser_dialog.dart';
import '../src/rust/api/media.dart';
import '../src/rust/api/enums.dart';
import '../src/rust/api/scanner.dart';
import '../src/rust/api/tag.dart';
import '../src/rust/api/album.dart';
import '../core/navigation/app_router.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});
  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MediaBloc>().add(const MediaLoadAllEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MediaBloc, MediaState>(
      builder: (context, state) {
        return PopScope(
          canPop: !state.isSelectionMode,
          onPopInvoked: (didPop) {
            if (!didPop && state.isSelectionMode) {
              context.read<MediaBloc>().add(const MediaClearSelectionEvent());
              context.read<MediaBloc>().add(const MediaToggleSelectionModeEvent());
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context).tabAllMedia),
              actions: [
                // 过滤菜单
                _buildFilterMenuButton(context, state),
                const SizedBox(width: AppSpacing.xs),
                // 排序按钮
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort),
                  tooltip: AppLocalizations.of(context).sort,
                  onSelected: (val) {
                    final parts = val.split(':');
                    final field = SortField.values.firstWhere((f) => f.name == parts[0]);
                    final order = SortOrder.values.firstWhere((o) => o.name == parts[1]);
                    context.read<MediaBloc>().add(MediaSortEvent(field, order));
                  },
                  itemBuilder: (_) {
                    final loc = AppLocalizations.of(context);
                    return [
                      PopupMenuItem(value: 'date:descending', child: Text(loc.sortNewestFirst)),
                      PopupMenuItem(value: 'date:ascending', child: Text(loc.sortOldestFirst)),
                      PopupMenuItem(value: 'name:ascending', child: Text(loc.sortNameAsc)),
                      PopupMenuItem(value: 'name:descending', child: Text(loc.sortNameDesc)),
                      PopupMenuItem(value: 'size:descending', child: Text(loc.sortSizeDesc)),
                      PopupMenuItem(value: 'size:ascending', child: Text(loc.sortSizeAsc)),
                    ];
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: AppLocalizations.of(context).search,
                  onPressed: () => _showSearch(context),
                ),
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: AppLocalizations.of(context).settings,
                  onPressed: () => _openSettings(context),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ),
            body: _buildBody(context, state),
            // 多选模式底栏
            bottomNavigationBar: state.isSelectionMode
                ? _buildSelectionBottomBar(context, state)
                : const SizedBox.shrink(),
            // FAB: 导入（多选模式下隐藏）
            floatingActionButton: state.isSelectionMode
                ? const SizedBox.shrink()
                : FloatingActionButton(
                    onPressed: () => _showImportMenu(context),
                    tooltip: AppLocalizations.of(context).importMedia,
                    child: const Icon(Icons.add_photo_alternate),
                  ),
          ),
        );
      },
    );
  }

  /// 右上角过滤菜单
  ///
  /// 将“全部/图片/视频/有标签/无标签/有相册/无相册”收敛到右上角按钮。
  Widget _buildFilterMenuButton(BuildContext context, MediaState state) {
    final loc = AppLocalizations.of(context);
    final isFiltered = state.currentFilter != null || state.currentFilterMode != null;

    return PopupMenuButton<String>(
      icon: Badge(
        isLabelVisible: isFiltered,
        smallSize: 8,
        child: const Icon(Icons.filter_list),
      ),
      tooltip: loc.filter,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      position: PopupMenuPosition.under,
      onSelected: (value) {
        final bloc = context.read<MediaBloc>();
        bloc.add(const MediaClearSelectionEvent());
        switch (value) {
          case 'all':
            bloc.add(const MediaLoadAllEvent());
            break;
          case 'image':
            bloc.add(const MediaFilterByTypeEvent(MediaType.image));
            break;
          case 'video':
            bloc.add(const MediaFilterByTypeEvent(MediaType.video));
            break;
          case 'withTags':
            bloc.add(const MediaFilterByFilterModeEvent(FilterMode.withTags));
            break;
          case 'withoutTags':
            bloc.add(const MediaFilterByFilterModeEvent(FilterMode.withoutTags));
            break;
          case 'withAlbums':
            bloc.add(const MediaFilterByFilterModeEvent(FilterMode.withAlbums));
            break;
          case 'withoutAlbums':
            bloc.add(const MediaFilterByFilterModeEvent(FilterMode.withoutAlbums));
            break;
        }
      },
      itemBuilder: (context) {
        return [
          CheckedPopupMenuItem(
            value: 'all',
            checked: state.currentFilter == null && state.currentFilterMode == null,
            child: Text(loc.filterAll),
          ),
          const PopupMenuDivider(),
          CheckedPopupMenuItem(
            value: 'image',
            checked: state.currentFilter == MediaType.image,
            child: Text(loc.filterImages),
          ),
          CheckedPopupMenuItem(
            value: 'video',
            checked: state.currentFilter == MediaType.video,
            child: Text(loc.filterVideos),
          ),
          const PopupMenuDivider(),
          CheckedPopupMenuItem(
            value: 'withTags',
            checked: state.currentFilterMode == FilterMode.withTags,
            child: Text(loc.filterWithTags),
          ),
          CheckedPopupMenuItem(
            value: 'withoutTags',
            checked: state.currentFilterMode == FilterMode.withoutTags,
            child: Text(loc.filterWithoutTags),
          ),
          CheckedPopupMenuItem(
            value: 'withAlbums',
            checked: state.currentFilterMode == FilterMode.withAlbums,
            child: Text(loc.filterWithAlbums),
          ),
          CheckedPopupMenuItem(
            value: 'withoutAlbums',
            checked: state.currentFilterMode == FilterMode.withoutAlbums,
            child: Text(loc.filterWithoutAlbums),
          ),
        ];
      },
    );
  }


  /// 判断当前过滤结果是否已全部选中
  bool _isAllSelected(MediaState state) {
    if (state.filteredList.isEmpty) return false;
    return state.selectedMediaIds.containsAll(
      state.filteredList.map((m) => m.id),
    );
  }

  Widget _buildBody(BuildContext context, MediaState state) {
    switch (state.status) {
      case MediaStatus.initial:
      case MediaStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case MediaStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: AppSize.iconXLarge, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: AppSpacing.md),
              Text('${AppLocalizations.of(context).error}: ${state.errorMessage ?? AppLocalizations.of(context).unknown}',
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: () =>
                    context.read<MediaBloc>().add(const MediaLoadAllEvent()),
                child: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        );
      case MediaStatus.loaded:
        if (state.filteredList.isEmpty) {
          return _buildEmptyState();
        }
        return MediaGrid(
          mediaList: state.filteredList,
          selectedIds: state.selectedMediaIds,
          isSelectionMode: state.isSelectionMode,
          crossAxisCount: context.read<AppBloc>().state.settings?.gridColumns ?? 3,
        );
    }
  }

  Widget _buildEmptyState() {
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: EmptyState(
          icon: Icons.photo_library_outlined,
          title: loc.noMedia,
          subtitle: loc.noMediaDesc,
        ),
      ),
    );
  }

  /// 多选模式底栏
  Widget _buildSelectionBottomBar(BuildContext context, MediaState state) {
    final loc = AppLocalizations.of(context);
    final selectedCount = state.selectedMediaIds.length;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(color: cs.scrim.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: loc.cancel,
                onPressed: () {
                  context.read<MediaBloc>().add(const MediaClearSelectionEvent());
                  context.read<MediaBloc>().add(const MediaToggleSelectionModeEvent());
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text('${loc.selected} $selectedCount',
                    style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(_isAllSelected(state)
                    ? Icons.deselect
                    : Icons.select_all),
                tooltip: _isAllSelected(state)
                    ? loc.deselectAll
                    : loc.selectAll,
                onPressed: state.filteredList.isEmpty
                    ? null
                    : () => context
                        .read<MediaBloc>()
                        .add(const MediaToggleSelectAllEvent()),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: cs.error),
                tooltip: loc.delete,
                onPressed: selectedCount > 0 ? () => _batchDelete(context, state.selectedMediaIds) : null,
              ),
              IconButton(
                icon: const Icon(Icons.label_outline),
                tooltip: loc.addTag,
                onPressed: selectedCount > 0 ? () => _batchAddTags(context, state.selectedMediaIds) : null,
              ),
              IconButton(
                icon: const Icon(Icons.photo_album_outlined),
                tooltip: loc.addToAlbum,
                onPressed: selectedCount > 0 ? () => _batchAddToAlbum(context, state.selectedMediaIds) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示导入方式选择底部菜单（Skill-10 §3.1）
  ///
  /// 提供两个选项：
  /// 1. 从设备选择文件 - 打开 [openFileBrowser] 多选文件
  /// 2. 从文件夹导入 - 打开 [openDirectoryBrowser] 选择整个目录批量导入
  void _showImportMenu(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.file_download, color: Theme.of(ctx).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(loc.importMedia, style: Theme.of(ctx).textTheme.titleMedium),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(loc.importFromDevice),
              subtitle: Text(loc.noFilesDesc),
              onTap: () {
                Navigator.pop(ctx);
                _openFileBrowser(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(loc.importFromDirectory),
              subtitle: const Text('批量导入整个文件夹中的媒体文件'),
              onTap: () {
                Navigator.pop(ctx);
                _openDirectoryBrowser(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 打开目录浏览器并递归导入所有媒体
  Future<void> _openDirectoryBrowser(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final dirPath = await openDirectoryBrowser(context);
    if (dirPath == null || dirPath.isEmpty) return;
    if (!context.mounted) return;

    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.error)),
      );
      return;
    }

    // 递归扫描目录中的媒体文件
    final mediaFiles = <File>[];
    final mediaExtensions = {
      'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif',
      'mp4', 'mkv', 'avi', 'mov', 'webm', 'flv',
      'mp3', 'wav', 'flac', 'aac', 'ogg',
      'pdf', 'doc', 'docx', 'txt', 'md', 'epub',
    };

    try {
      await for (final entity in dir.list(recursive: true).where((e) => e is File)) {
        final ext = entity.path.split('.').last.toLowerCase();
        if (mediaExtensions.contains(ext)) {
          mediaFiles.add(entity as File);
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.error}: $e')),
      );
      return;
    }

    if (mediaFiles.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.noFilesDesc)),
      );
      return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportProgressDialog(totalCount: mediaFiles.length),
    );

    int successCount = 0;
    int failCount = 0;
    for (final file in mediaFiles) {
      try {
        if (!await file.exists()) {
          failCount++;
          continue;
        }
        await importSingleFile(filePath: file.path);
        successCount++;
      } catch (_) {
        failCount++;
      }
    }

    if (!context.mounted) return;
    try { Navigator.pop(context); } catch (_) {}

    context.read<MediaBloc>().add(const MediaLoadAllEvent());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).importComplete),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ ${AppLocalizations.of(context).success}: $successCount'),
            if (failCount > 0) Text('❌ ${AppLocalizations.of(context).importFailed}: $failCount', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).confirm),
          ),
        ],
      ),
    );
  }

  /// 打开文件浏览器
  Future<void> _openFileBrowser(BuildContext context) async {
    final filePaths = await openFileBrowser(context);
    if (filePaths.isEmpty) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportProgressDialog(totalCount: filePaths.length),
    );

    int successCount = 0;
    int failCount = 0;
    for (final path in filePaths) {
      try {
        final file = File(path);
        if (!await file.exists()) {
          failCount++;
          continue;
        }
        await importSingleFile(filePath: path);
        successCount++;
      } catch (e) {
        failCount++;
      }
    }

    if (!context.mounted) return;
    try { Navigator.pop(context); } catch (_) {}

    context.read<MediaBloc>().add(const MediaLoadAllEvent());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).importComplete),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✅ ${AppLocalizations.of(context).success}: $successCount'),
            if (failCount > 0) Text('❌ ${AppLocalizations.of(context).importFailed}: $failCount', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).confirm),
          ),
        ],
      ),
    );
  }

  /// 搜索
  void _showSearch(BuildContext context) {
    AppRouter.pushOverlay(context, page: const SearchScreen());
  }

  /// 打开设置
  void _openSettings(BuildContext context) {
    AppRouter.pushOverlay(context, page: const SettingsScreen());
  }

  Future<void> _batchDelete(BuildContext context, Set<String> ids) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(loc.confirmBatchDelete),
              content: Text(loc.confirmBatchDelete),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(loc.cancel)),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(loc.delete),
                ),
              ],
            ));
    if (confirmed != true) return;
    for (final id in ids) {
      context.read<MediaBloc>().add(MediaDeleteEvent(id));
    }
    context.read<MediaBloc>().add(const MediaClearSelectionEvent());
    context.read<MediaBloc>().add(const MediaToggleSelectionModeEvent());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${loc.success} ${ids.length}')));
  }

  Future<void> _batchAddTags(BuildContext context, Set<String> mediaIds) async {
    final loc = AppLocalizations.of(context);
    try {
      final tags = await getAllTags();
      if (!context.mounted) return;
      final result = await showDialog<Set<String>>(
          context: context,
          builder: (ctx) => _TagSelectionDialog(tags: tags, preselectedIds: <String>{}));
      if (result == null || result.isEmpty) return;
      int successCount = 0;
      for (final mediaId in mediaIds) {
        bool ok = true;
        for (final tagId in result) {
          try {
            await addTagToMedia(mediaId: mediaId, tagId: tagId);
          } catch (_) {
            ok = false;
          }
        }
        if (ok) successCount++;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.addTag} $successCount')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${loc.error}: $e')));
    }
  }

  Future<void> _batchAddToAlbum(BuildContext context, Set<String> mediaIds) async {
    final loc = AppLocalizations.of(context);
    try {
      final albums = await getRootAlbums();
      if (!context.mounted) return;
      final selectedAlbum = await showDialog<String>(
          context: context,
          builder: (ctx) => _AddToAlbumDialog(albums: albums));
      if (selectedAlbum == null) return;
      await addMediaToAlbum(mediaIds: mediaIds.toList(), albumId: selectedAlbum);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.addToAlbum} ${mediaIds.length}')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${loc.error}: $e')));
    }
  }
}


/// 添加到相册对话框
class _AddToAlbumDialog extends StatelessWidget {
  final List<dynamic> albums;
  const _AddToAlbumDialog({required this.albums});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).addToAlbum),
      content: SizedBox(
        width: double.maxFinite,
        child: albums.isEmpty
            ? Text(AppLocalizations.of(context).noAlbums)
            : ListView.builder(
                shrinkWrap: true,
                itemCount: albums.length,
                itemBuilder: (ctx, index) {
                  final info = albums[index];
                  return ListTile(
                    leading: const Icon(Icons.photo_album),
                    title: Text(info.album.name),
                    subtitle: Text('${info.mediaCount} ${AppLocalizations.of(context).files}'),
                    onTap: () => Navigator.pop(ctx, info.album.id),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel)),
      ],
    );
  }
}

class _ImportProgressDialog extends StatelessWidget {
  final int totalCount;
  const _ImportProgressDialog({required this.totalCount});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('${AppLocalizations.of(context).importing} ($totalCount)'),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context).loading,
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _TagSelectionDialog extends StatefulWidget {
  final List<Tag> tags;
  final Set<String> preselectedIds;
  const _TagSelectionDialog({required this.tags, required this.preselectedIds});
  @override
  State<_TagSelectionDialog> createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends State<_TagSelectionDialog> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.preselectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).addTag),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.tags.isEmpty
            ? Text(AppLocalizations.of(context).noTags)
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.tags.length,
                itemBuilder: (_, i) {
                  final tag = widget.tags[i];
                  final isSelected = _selectedIds.contains(tag.id);
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: Text(tag.name),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(tag.id);
                        } else {
                          _selectedIds.add(tag.id);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedIds),
          child: Text(AppLocalizations.of(context).confirm),
        ),
      ],
    );

  }
}
