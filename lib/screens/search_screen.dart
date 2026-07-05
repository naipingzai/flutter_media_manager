import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/design_system/app_theme.dart';
import '../core/i18n/app_localizations.dart';
import '../src/rust/api/media.dart';
import '../src/rust/api/note.dart' as note_api;
import '../src/rust/api/search.dart';
import '../widgets/advanced_search_dialog.dart';
import '../widgets/viewer/viewer_page.dart';

/// 搜索页面 - 卡片覆盖层形式呈现
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
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: loc.searchHint,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
              const SizedBox(width: AppSpacing.sm),
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
            ],
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_showHistory && _controller.text.isEmpty && _searchHistory.isNotEmpty) {
      return _buildHistoryList();
    }

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

    return _buildEmptyState();
  }

  Widget _buildEmptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context).searchHint,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
          child: Row(
            children: [
              Text(
                loc.searchHistory,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _searchHistory.clear()),
                child: Text(loc.clearAll, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            itemCount: _searchHistory.length,
            itemBuilder: (ctx, i) {
              final query = _searchHistory[i];
              return ListTile(
                leading: Icon(Icons.history, size: 20, color: cs.onSurfaceVariant),
                title: Text(query, style: const TextStyle(fontSize: 14)),
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                onTap: () {
                  _controller.text = query;
                  _executeSearch(query);
                },
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _searchHistory.removeAt(i)),
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
    final total = _results.length + _noteResults.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
          child: Text(
            '${loc.searchResults} ($total)',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            itemCount: _results.length + _noteResults.length,
            itemBuilder: (ctx, i) {
              if (i < _results.length) {
                final media = _results[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: ListTile(
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
                          builder: (_) => ViewerPage(initialMedia: media, mediaList: _results),
                        ),
                      );
                    },
                  ),
                );
              } else {
                final note = _noteResults[i - _results.length];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.note, color: Colors.amber),
                    title: Text(
                      '${loc.notes}: ${note.content}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      '${loc.tabMedia} ID: ${note.mediaId}',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
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
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Image.file(
          File(media.thumbnailPath),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 48),
        ),
      );
    }
    return Icon(_getMediaIcon(media.mediaType), size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant);
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
