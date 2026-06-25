import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../bloc/bloc.dart';
import '../widgets/media_grid.dart';
import '../widgets/search_bar.dart';
import '../widgets/file_browser_dialog.dart';
import '../src/rust/api/media.dart';
import '../src/rust/api/scanner.dart';
import '../src/rust/api/tag.dart';
import '../src/rust/api/album.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('媒体库'),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterOptions(context)),
          IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showMoreOptions(context)),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: MediaSearchBar(),
        ),
      ),
      body: BlocBuilder<MediaBloc, MediaState>(
        builder: (context, state) => Stack(
          children: [
            _buildBody(context, state),
            if (state.isSelectionMode)
              Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildSelectionBottomBar(context, state)),
          ],
        ),
      ),
      floatingActionButton: BlocBuilder<MediaBloc, MediaState>(
        builder: (context, state) {
          if (state.isSelectionMode) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () => _showImportOptions(context),
            child: const Icon(Icons.add),
          );
        },
      ),
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
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('加载失败: ${state.errorMessage ?? '未知错误'}',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    context.read<MediaBloc>().add(const MediaLoadAllEvent()),
                child: const Text('重试'),
              ),
            ],
          ),
        );
      case MediaStatus.loaded:
        if (state.filteredList.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('暂无媒体文件',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
                SizedBox(height: 8),
                Text('点击右下角按钮导入',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: state.isSelectionMode ? 80.0 : 0),
          child: MediaGrid(
            mediaList: state.filteredList,
            selectedIds: state.selectedMediaIds,
            crossAxisCount: state.gridColumns,
          ),
        );
    }
  }

  Widget _buildSelectionBottomBar(BuildContext context, MediaState state) {
    final selectedCount = state.selectedMediaIds.length;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('已选 $selectedCount',
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.label),
                  tooltip: '添加标签',
                  onPressed: selectedCount > 0
                      ? () => _batchAddTags(context, state.selectedMediaIds)
                      : null),
              IconButton(
                  icon: const Icon(Icons.photo_album),
                  tooltip: '添加到相册',
                  onPressed: selectedCount > 0
                      ? () => _batchAddToAlbum(
                          context, state.selectedMediaIds)
                      : null),
              IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: '批量删除',
                  onPressed: selectedCount > 0
                      ? () => _batchDelete(context, state.selectedMediaIds)
                      : null),
              IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: '取消选择',
                  onPressed: () {
                    context
                        .read<MediaBloc>()
                        .add(const MediaClearSelectionEvent());
                    context
                        .read<MediaBloc>()
                        .add(const MediaToggleSelectionModeEvent());
                  }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _batchDelete(BuildContext context, Set<String> ids) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('批量删除'),
              content:
                  Text('确定删除选中的 ${ids.length} 个文件？此操作不可恢复。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('删除'),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已删除 ${ids.length} 个文件')));
  }

  Future<void> _batchAddTags(
      BuildContext context, Set<String> mediaIds) async {
    try {
      final tags = await getAllTags();
      if (!context.mounted) return;
      final result = await showDialog<Set<String>>(
          context: context,
          builder: (ctx) => _TagSelectionDialog(
              tags: tags, preselectedIds: <String>{}));
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
          SnackBar(content: Text('已为 $successCount 个文件添加标签')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('加载标签失败: $e')));
    }
  }

  Future<void> _batchAddToAlbum(
      BuildContext context, Set<String> mediaIds) async {
    try {
      final albums = await getRootAlbums();
      if (!context.mounted) return;
      final selectedAlbum = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('选择相册'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: albums.isEmpty
                      ? const Text('暂无相册，请先在相册页面创建')
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: albums.length,
                          itemBuilder: (ctx, index) {
                            final info = albums[index];
                            return ListTile(
                              leading: const Icon(Icons.photo_album),
                              title: Text(info.album.name),
                              subtitle: Text('${info.mediaCount} 个文件'),
                              onTap: () =>
                                  Navigator.pop(ctx, info.album.id),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                ],
              ));
      if (selectedAlbum == null) return;
      await addMediaToAlbum(
          mediaIds: mediaIds.toList(), albumId: selectedAlbum);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加 ${mediaIds.length} 个文件到相册')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败: $e')));
    }
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.image),
                    title: const Text('仅图片'),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.read<MediaBloc>().add(
                          const MediaFilterByTypeEvent(MediaType.image));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.videocam),
                    title: const Text('仅视频'),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.read<MediaBloc>().add(
                          const MediaFilterByTypeEvent(MediaType.video));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.audio_file),
                    title: const Text('仅音频'),
                    onTap: () {
                      Navigator.pop(ctx);
                      context.read<MediaBloc>().add(
                          const MediaFilterByTypeEvent(MediaType.audio));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.clear_all),
                    title: const Text('显示全部'),
                    onTap: () {
                      Navigator.pop(ctx);
                      context
                          .read<MediaBloc>()
                          .add(const MediaLoadAllEvent());
                    },
                  ),
                ],
              ),
            ));
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.select_all),
                    title: const Text('选择模式'),
                    onTap: () {
                      Navigator.pop(ctx);
                      context
                          .read<MediaBloc>()
                          .add(const MediaToggleSelectionModeEvent());
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.sort),
                    title: const Text('排序'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showSortOptions(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.grid_on),
                    title: const Text('网格设置'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showGridOptions(context);
                    },
                  ),
                ],
              ),
            ));
  }

  void _showImportOptions(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: const Text('扫描文件夹'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _scanDirectory(context);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.file_upload),
                    title: const Text('浏览选择文件'),
                    subtitle: const Text('直接浏览文件系统，显示所有文件'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _requestPermissionAndImport(context);
                    },
                  ),
                ],
              ),
            ));
  }

  Future<void> _scanDirectory(BuildContext context) async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;
    if (!context.mounted) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在扫描文件夹...'),
                ],
              ),
            ));
    try {
      final scanResult = await scanDirectory(path: result);
      if (!context.mounted) return;
      Navigator.pop(context);
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: const Text('扫描完成'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('导入: ${scanResult.importedCount}'),
                    Text('重复: ${scanResult.duplicateCount}'),
                    Text('失败: ${scanResult.failedCount}'),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context
                          .read<MediaBloc>()
                          .add(const MediaLoadAllEvent());
                    },
                    child: const Text('确定'),
                  ),
                ],
              ));
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('扫描失败: $e')));
    }
  }

  Future<void> _requestPermissionAndImport(BuildContext context) async {
    // 请求存储权限
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
      }
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      if (!status.isGranted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('需要存储权限才能浏览文件'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }
    if (!context.mounted) return;
    // 权限已获取，打开文件管理器
    await _importFiles(context);
  }

  Future<void> _importFiles(BuildContext context) async {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => FileBrowserDialog(
                  onImport: (filePaths) async {
                    if (!context.mounted) return;
                    showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => _ImportProgressDialog(
                            totalCount: filePaths.length));
                    int successCount = 0;
                    int failCount = 0;
                    final errors = <String>[];
                    for (final path in filePaths) {
                      try {
                        final file = File(path);
                        if (!await file.exists()) {
                          failCount++;
                          errors.add('文件不存在: $path');
                          continue;
                        }
                        await importSingleFile(filePath: path);
                        successCount++;
                      } catch (e) {
                        failCount++;
                        errors.add('$path: $e');
                      }
                    }
                    if (!context.mounted) return;
                    try { Navigator.pop(context); } catch (_) {}
                    context
                        .read<MediaBloc>()
                        .add(const MediaLoadAllEvent());
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            '导入完成: $successCount 成功, $failCount 失败'),
                        duration: const Duration(seconds: 3)));
                    if (errors.isNotEmpty) {
                      showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                                title: const Text('导入错误详情'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: errors.length.clamp(0, 20),
                                    itemBuilder: (_, index) => Padding(
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(errors[index],
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.red)),
                                    ),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('关闭')),
                                ],
                              ));
                    }
                  },
                )));
  }

  void _showSortOptions(BuildContext context) {
    final bloc = context.read<MediaBloc>();
    final cf = bloc.state.sortField;
    final co = bloc.state.sortOrder;
    showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                      title: Text('排序方式',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  _buildSortTile(
                      context, '按日期', SortField.date, cf, co, bloc),
                  _buildSortTile(
                      context, '按名称', SortField.name, cf, co, bloc),
                  _buildSortTile(
                      context, '按大小', SortField.size, cf, co, bloc),
                  _buildSortTile(
                      context, '按类型', SortField.type, cf, co, bloc),
                ],
              ),
            ));
  }

  Widget _buildSortTile(BuildContext context, String title, SortField field,
      SortField cf, SortOrder co, MediaBloc bloc) {
    final sel = field == cf;
    return ListTile(
      leading: sel
          ? Icon(co == SortOrder.ascending
              ? Icons.arrow_upward
              : Icons.arrow_downward)
          : const SizedBox(width: 24),
      title: Text(title),
      trailing: sel ? const Icon(Icons.check) : null,
      onTap: () {
        Navigator.pop(context);
        bloc.add(MediaSortEvent(
            field, sel && co == SortOrder.descending
                ? SortOrder.ascending
                : SortOrder.descending));
      },
    );
  }

  void _showGridOptions(BuildContext context) {
    final bloc = context.read<MediaBloc>();
    final cc = bloc.state.gridColumns;
    showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ListTile(
                      title: Text('网格列数',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  for (int i = 2; i <= 6; i++)
                    ListTile(
                      leading: Icon(Icons.grid_view,
                          color: i == cc
                              ? Theme.of(context).primaryColor
                              : null),
                      title: Text('$i 列'),
                      trailing:
                          i == cc ? const Icon(Icons.check) : null,
                      onTap: () {
                        Navigator.pop(context);
                        bloc.add(MediaSetGridColumnsEvent(i));
                      },
                    ),
                ],
              ),
            ));
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
          Text('正在导入 $totalCount 个文件...'),
          const SizedBox(height: 8),
          Text('请稍候，正在复制和处理文件',
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _TagSelectionDialog extends StatefulWidget {
  final List<Tag> tags;
  final Set<String> preselectedIds;
  const _TagSelectionDialog(
      {required this.tags, required this.preselectedIds});
  @override
  State<_TagSelectionDialog> createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends State<_TagSelectionDialog> {
  late Set<String> _selectedIds;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.preselectedIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();
    final filtered = query.isEmpty
        ? widget.tags
        : widget.tags
            .where((t) => t.name.toLowerCase().contains(query))
            .toList();
    return AlertDialog(
      title: const Text('选择标签'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '搜索标签...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('无匹配标签'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final tag = filtered[i];
                        return CheckboxListTile(
                          title: Text(tag.name),
                          subtitle: tag.color != null
                              ? Row(children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Color(int.parse(
                                          tag.color!
                                              .replaceAll('#', '0xFF'))),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ])
                              : null,
                          value: _selectedIds.contains(tag.id),
                          onChanged: (sel) {
                            setState(() {
                              if (sel == true) {
                                _selectedIds.add(tag.id);
                              } else {
                                _selectedIds.remove(tag.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedIds),
          child: Text('确认 (${_selectedIds.length})'),
        ),
      ],
    );
  }
}
