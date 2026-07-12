import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_media_knowledge_base/core/design_system/app_theme.dart';
import 'package:flutter_media_knowledge_base/core/i18n/app_localizations.dart';
import 'package:flutter_media_knowledge_base/bridge/native/api/note.dart'
    as note_api;
import 'package:flutter_media_knowledge_base/bridge/native/api/search.dart';
import 'widgets/advanced_search_dialog.dart';
import '../viewer/viewer_page.dart';

/// 搜索页面 - Material 3 卡片覆盖层形式呈现
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<MediaItem> _results = [];
  List<note_api.Note> _noteResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  // 搜索历史（内存中存储）
  static final List<String> _searchHistory = [];
  bool _showHistory = true;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.surfaceTint,
        elevation: 0,
        scrolledUnderElevation: 3,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: loc.back,
          onPressed: () => Navigator.pop(context),
        ),
        title: SearchBar(
          controller: _controller,
          focusNode: _focusNode,
          hintText: loc.searchHint,
          leading: Icon(Icons.search, color: cs.onSurfaceVariant),
          trailing: [
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: loc.cancel,
                onPressed: () {
                  _controller.clear();
                  setState(() {
                    _results = [];
                    _noteResults = [];
                    _showHistory = true;
                  });
                },
              ),
          ],
          onChanged: (q) {
            setState(() {}); // 更新 trailing 图标
            _onSearch(q);
          },
          onSubmitted: (q) => _executeSearch(q),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: loc.advSearch,
            onPressed: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => const AdvancedSearchDialog(),
              );
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppLocalizations.of(context).loading,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    if (_showHistory && _controller.text.isEmpty && _searchHistory.isNotEmpty) {
      return _buildHistoryList();
    }

    if (_controller.text.isNotEmpty) {
      if (_results.isEmpty && _noteResults.isEmpty) {
        return _buildNoResults();
      }
      return _buildResultsList();
    }

    return _buildEmptyState();
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search,
                size: 48,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              loc.searchMedia,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              loc.searchHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => const AdvancedSearchDialog(),
                );
              },
              icon: const Icon(Icons.tune),
              label: Text(loc.advSearch),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                size: 48,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              loc.noResults,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              loc.noResultsDesc,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Icon(Icons.history, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  loc.searchHistory,
                  style: tt.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _searchHistory.clear()),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: Text(loc.clearAll),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          sliver: SliverList.separated(
            itemCount: _searchHistory.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (ctx, i) {
              final query = _searchHistory[i];
              return Material(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  leading:
                      Icon(Icons.history, size: 20, color: cs.onSurfaceVariant),
                  title: Text(
                    query,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: cs.onSurfaceVariant,
                    onPressed: () => setState(() => _searchHistory.removeAt(i)),
                  ),
                  onTap: () {
                    _controller.text = query;
                    _controller.selection =
                        TextSelection.collapsed(offset: query.length);
                    _executeSearch(query);
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
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final total = _results.length + _noteResults.length;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text(
                  '${loc.searchResults} ($total)',
                  style: tt.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          sliver: SliverList.separated(
            itemCount: _results.length + _noteResults.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (ctx, i) {
              if (i < _results.length) {
                final media = _results[i];
                return _buildMediaResultCard(media);
              } else {
                final note = _noteResults[i - _results.length];
                return _buildNoteResultCard(note, loc);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMediaResultCard(MediaItem media) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      surfaceTintColor: cs.surfaceTint,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ViewerPage(initialMedia: media, mediaList: _results),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              _buildMediaThumbnail(media),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      media.originalName,
                      style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${_formatSize(media.size)} · ${_formatDate(media.createdAt)}',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteResultCard(note_api.Note note, AppLocalizations loc) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      surfaceTintColor: cs.surfaceTint,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(Icons.note, color: cs.onTertiaryContainer, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${loc.notes}: ${note.content}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${loc.tabMedia} ID: ${note.mediaId}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaThumbnail(MediaItem media) {
    if (media.thumbnailPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.file(
          File(media.thumbnailPath),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 56,
            height: 56,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(_getMediaIcon(media.mediaType),
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(_getMediaIcon(media.mediaType),
          color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }

  IconData _getMediaIcon(MediaType type) {
    switch (type) {
      case MediaType.image:
        return Icons.image;
      case MediaType.video:
        return Icons.videocam;
      case MediaType.audio:
        return Icons.audiotrack;
      case MediaType.document:
        return Icons.description;
      case MediaType.other:
        return Icons.insert_drive_file;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _onSearch(String query) {
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _noteResults = [];
        _showHistory = true;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _showHistory = false;
    });

    if (!_searchHistory.contains(query)) {
      _searchHistory.insert(0, query);
      if (_searchHistory.length > 20) _searchHistory.removeLast();
    }

    try {
      final filter = SearchFilter(query: query);
      final mediaResults = await searchMediaAdvanced(filter: filter);

      if (mounted) {
        setState(() {
          _results = mediaResults;
          _noteResults = [];
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
