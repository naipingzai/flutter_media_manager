import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';
import '../core/design_system/components.dart';
import '../core/i18n/app_localizations.dart';
import '../widgets/media_grid.dart';
import '../widgets/file_browser_dialog.dart';
import '../widgets/advanced_search_dialog.dart';
import '../src/rust/api/media.dart';
import '../src/rust/api/enums.dart';
import '../src/rust/api/scanner.dart';
import '../src/rust/api/search.dart';
import '../src/rust/api/tag.dart';
import '../src/rust/api/album.dart';
import '../src/rust/api/note.dart' as note_api;
import 'media_detail_screen.dart';
import 'settings_screen.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});
  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  FilterMode? _filterMode;

  @override
  void initState() {
    super.initState();
    context.read<MediaBloc>().add(const MediaLoadAllEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).tabAllMedia),
        actions: [
          // 列数控制按钮
          BlocBuilder<MediaBloc, MediaState>(
            buildWhen: (prev, curr) => prev.gridColumns != curr.gridColumns,
            builder: (context, state) {
              return PopupMenuButton<int>(
                icon: const Icon(Icons.grid_view),
                tooltip: AppLocalizations.of(context).gridColumns,
                onSelected: (cols) {
                  context.read<MediaBloc>().add(MediaSetGridColumnsEvent(cols));
                },
                itemBuilder: (_) => [2, 3, 4, 5].map((cols) {
                  return CheckedPopupMenuItem<int>(
                    value: cols,
                    checked: state.gridColumns == cols,
                    child: Text('$cols ${AppLocalizations.of(context).columns}'),
                  );
                }).toList(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: AppLocalizations.of(context).search,
            onPressed: () => _showSearch(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppLocalizations.of(context).settings,
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
      body: BlocBuilder<MediaBloc, MediaState>(
        builder: (context, state) => Column(
          children: [
            // 过滤器 Chip 行（多选模式下隐藏）
            if (!state.isSelectionMode) _buildFilterChips(context, state),
            // 内容区域
            Expanded(child: _buildBody(context, state)),
          ],
        ),
      ),
      // 多选模式底栏
      bottomNavigationBar: BlocBuilder<MediaBloc, MediaState>(
        builder: (context, state) {
          if (!state.isSelectionMode) return const SizedBox.shrink();
          return _buildSelectionBottomBar(context, state);
        },
      ),
      // FAB: 导入（多选模式下隐藏）
      floatingActionButton: BlocBuilder<MediaBloc, MediaState>(
        builder: (context, state) {
          if (state.isSelectionMode) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () => _openFileBrowser(context),
            tooltip: AppLocalizations.of(context).importMedia,
            child: const Icon(Icons.add_photo_alternate),
          );
        },
      ),
    );
  }

  /// 过滤器 Chip 行
  Widget _buildFilterChips(BuildContext context, MediaState state) {
    final loc = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(loc.filterAll, null),
          const SizedBox(width: 8),
          _buildFilterChip(loc.filterWithTags, FilterMode.withTags),
          const SizedBox(width: 8),
          _buildFilterChip(loc.filterWithoutTags, FilterMode.withoutTags),
          const SizedBox(width: 8),
          _buildFilterChip(loc.filterWithAlbums, FilterMode.withAlbums),
          const SizedBox(width: 8),
          _buildFilterChip(loc.filterWithoutAlbums, FilterMode.withoutAlbums),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, FilterMode? mode) {
    final selected = _filterMode == mode;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _toggleFilter(mode),
    );
  }

  void _toggleFilter(FilterMode? mode) {
    setState(() {
      if (_filterMode == mode) {
        _filterMode = null;
      } else {
        _filterMode = mode;
      }
    });
    if (mode != null) {
      context.read<MediaBloc>().add(MediaFilterByFilterModeEvent(mode));
    } else {
      context.read<MediaBloc>().add(const MediaLoadAllEvent());
    }
    context.read<MediaBloc>().add(const MediaClearSelectionEvent());
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
              Text('${AppLocalizations.of(context).error}: ${state.errorMessage ?? AppLocalizations.of(context).unknown}',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
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
          crossAxisCount: state.gridColumns,
        );
    }
  }

  Widget _buildEmptyState() {
    final loc = AppLocalizations.of(context);
    String text = loc.noMedia;
    String? subtitle = _filterMode == null ? loc.noMediaDesc : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: EmptyState(
          icon: Icons.photo_library_outlined,
          title: text,
          subtitle: subtitle,
        ),
      ),
    );
  }

  /// 多选模式底栏
  Widget _buildSelectionBottomBar(BuildContext context, MediaState state) {
    final selectedCount = state.selectedMediaIds.length;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: AppLocalizations.of(context).cancel,
              onPressed: () {
                context.read<MediaBloc>().add(const MediaClearSelectionEvent());
                context.read<MediaBloc>().add(const MediaToggleSelectionModeEvent());
              },
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${AppLocalizations.of(context).selected} $selectedCount',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: AppLocalizations.of(context).delete,
              onPressed: selectedCount > 0 ? () => _batchDelete(context, state.selectedMediaIds) : null,
            ),
            IconButton(
              icon: const Icon(Icons.label_outline),
              tooltip: AppLocalizations.of(context).addTag,
              onPressed: selectedCount > 0 ? () => _batchAddTags(context, state.selectedMediaIds) : null,
            ),
            IconButton(
              icon: const Icon(Icons.photo_album_outlined),
              tooltip: AppLocalizations.of(context).addToAlbum,
              onPressed: selectedCount > 0 ? () => _batchAddToAlbum(context, state.selectedMediaIds) : null,
            ),
          ],
        ),
      ),
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
            if (failCount > 0) Text('❌ ${AppLocalizations.of(context).importFailed}: $failCount', style: const TextStyle(color: Colors.red)),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => _SearchOverlay(scrollController: scrollController),
      ),
    );
  }

  /// 打开设置
  void _openSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => const SettingsScreen(),
      ),
    );
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

/// 搜索覆盖层 - 实时搜索 + 搜索历史 + 高级搜索入口
class _SearchOverlay extends StatefulWidget {
  final ScrollController scrollController;
  const _SearchOverlay({required this.scrollController});

  @override
  State<_SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<_SearchOverlay> {
  final _controller = TextEditingController();
  List<MediaItem> _results = [];
  List<note_api.Note> _noteResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  // 搜索历史（内存中存储，页面关闭后清除）
  static final List<String> _searchHistory = [];
  bool _showHistory = true;

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 搜索栏
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).searchHint,
                    border: InputBorder.none,
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _results = [];
                                _noteResults = [];
                                _showHistory = true;
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: _onSearch,
                  onSubmitted: (q) => _executeSearch(q),
                ),
              ),
              // 高级搜索按钮
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: AppLocalizations.of(context).search,
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (_) => const AdvancedSearchDialog(),
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 内容区域
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // 显示搜索历史
    if (_showHistory && _controller.text.isEmpty && _searchHistory.isNotEmpty) {
      return _buildHistoryList();
    }

    // 显示搜索结果
    if (_controller.text.isNotEmpty) {
      if (_results.isEmpty && _noteResults.isEmpty) {
        return Center(
          child: Text(
            AppLocalizations.of(context).noResults,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        );
      }
      return _buildResultsList();
    }

    // 初始状态
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context).searchHint, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(AppLocalizations.of(context).search, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() => _searchHistory.clear());
                },
                child: Text(AppLocalizations.of(context).delete, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: _searchHistory.length,
            itemBuilder: (ctx, i) {
              final query = _searchHistory[i];
              return ListTile(
                leading: const Icon(Icons.history, size: 20),
                title: Text(query, style: const TextStyle(fontSize: 14)),
                dense: true,
                onTap: () {
                  _controller.text = query;
                  _executeSearch(query);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    setState(() => _searchHistory.removeAt(i));
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList() {
    final total = _results.length + _noteResults.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            '${AppLocalizations.of(context).noResults} ($total)',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: widget.scrollController,
            itemCount: _results.length + _noteResults.length,
            itemBuilder: (ctx, i) {
              if (i < _results.length) {
                final media = _results[i];
                return ListTile(
                  leading: _buildMediaThumbnail(media),
                  title: Text(media.originalName, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    '${_formatSize(media.size)} · ${_formatDate(media.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaDetailScreen(media: media, mediaList: _results),
                      ),
                    );
                  },
                );
              } else {
                final note = _noteResults[i - _results.length];
                return ListTile(
                  leading: const Icon(Icons.note, color: Colors.amber),
                  title: Text('${AppLocalizations.of(context).notes}: ${note.content}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                  subtitle: Text('${AppLocalizations.of(context).tabMedia} ID: ${note.mediaId}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMediaThumbnail(MediaItem media) {
    if (media.thumbnailPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          File(media.thumbnailPath),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40),
        ),
      );
    }
    return Icon(_getMediaIcon(media.mediaType), size: 40);
  }

  IconData _getMediaIcon(MediaType type) {
    switch (type) {
      case MediaType.image: return Icons.image;
      case MediaType.video: return Icons.videocam;
      case MediaType.audio: return Icons.audiotrack;
      case MediaType.document: return Icons.description;
      case MediaType.other: return Icons.insert_drive_file;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _onSearch(String query) {
    _debounceTimer?.cancel();
    if (query.length < 2) {
      setState(() {
        _results = [];
        _noteResults = [];
        _showHistory = query.isEmpty;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    if (query.length < 2) return;

    setState(() {
      _isSearching = true;
      _showHistory = false;
    });

    // 添加到搜索历史
    if (!_searchHistory.contains(query)) {
      _searchHistory.insert(0, query);
      if (_searchHistory.length > 20) _searchHistory.removeLast();
    }

    try {
      // 同时搜索媒体和笔记
      final filter = SearchFilter(query: query);
      final mediaResults = await searchMediaAdvanced(filter: filter);
      final noteResults = await note_api.searchNotes(query: query);

      if (mounted) {
        setState(() {
          _results = mediaResults;
          _noteResults = noteResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _noteResults = [];
          _isSearching = false;
        });
      }
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
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
