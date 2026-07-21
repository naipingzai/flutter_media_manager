import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_media_manager/core/design_system/app_theme.dart';
import 'package:flutter_media_manager/core/i18n/app_localizations.dart';
import 'package:flutter_media_manager/bridge/native/api/media.dart';
import 'package:flutter_media_manager/bridge/native/api/tag.dart' as tag_api;
import 'package:flutter_media_manager/bridge/native/api/album.dart'
    as album_api;
import 'package:flutter_media_manager/bridge/native/api/search.dart';
import 'package:flutter_media_manager/functionality/media/media_bloc.dart';
import 'package:flutter_media_manager/ui/media/widgets/media_grid.dart';
import 'package:flutter_media_manager/functionality/home/app_bloc.dart';

/// 全屏搜索页面
///
/// 顶部：搜索输入框 + 返回按钮
/// 内容：搜索结果网格 / 空状态
/// 右上角：筛选按钮（弹出筛选底部弹窗）
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _keywordController = TextEditingController();
  final _focusNode = FocusNode();

  // 搜索条件
  String? _selectedMediaType;
  DateTimeRange? _dateRange;
  List<tag_api.Tag> _selectedTags = [];
  album_api.AlbumWithInfo? _selectedAlbum;
  bool _matchAllTags = false;

  // 数据
  List<MediaItem> _results = [];
  bool _hasSearched = false;
  bool _searching = false;

  // 筛选数据
  List<tag_api.Tag> _allTags = [];
  List<album_api.AlbumWithInfo> _allAlbums = [];
  bool _loadingFilters = true;

  @override
  void initState() {
    super.initState();
    _loadFilterData();
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFilterData() async {
    try {
      final tags = await tag_api.getAllTags();
      final albums = await album_api.getRootAlbums();
      if (mounted) {
        setState(() {
          _allTags = tags;
          _allAlbums = albums;
          _loadingFilters = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingFilters = false);
    }
  }

  Future<void> _search() async {
    if (_keywordController.text.isEmpty &&
        _selectedMediaType == null &&
        _dateRange == null &&
        _selectedTags.isEmpty &&
        _selectedAlbum == null) {
      return;
    }

    setState(() {
      _searching = true;
      _hasSearched = true;
    });
    _focusNode.unfocus();

    final filter = SearchFilter(
      query: _keywordController.text,
      mediaType: _selectedMediaType == null
          ? null
          : MediaType.values.firstWhere((e) => e.name == _selectedMediaType,
              orElse: () => MediaType.other),
      startDate: _dateRange?.start.millisecondsSinceEpoch != null
          ? _dateRange!.start.millisecondsSinceEpoch ~/ 1000
          : null,
      endDate: _dateRange?.end.millisecondsSinceEpoch != null
          ? _dateRange!.end.millisecondsSinceEpoch ~/ 1000
          : null,
      albumId: _selectedAlbum?.album.id,
      tagIds: _selectedTags.isNotEmpty
          ? _selectedTags.map((t) => t.id).toList()
          : null,
      tagCount:
          _matchAllTags && _selectedTags.isNotEmpty ? _selectedTags.length : 1,
    );

    try {
      final bloc = context.read<MediaBloc>();
      bloc.add(MediaAdvancedSearchEvent(filter));
      // 等待 bloc 处理
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() {
          _results = bloc.state.filteredList;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _searching = false;
        });
      }
    }
  }

  void _clearAll() {
    setState(() {
      _keywordController.clear();
      _selectedMediaType = null;
      _dateRange = null;
      _selectedTags = [];
      _selectedAlbum = null;
      _matchAllTags = false;
      _results = [];
      _hasSearched = false;
    });
  }

  bool get _hasActiveFilter {
    return _keywordController.text.isNotEmpty ||
        _selectedMediaType != null ||
        _dateRange != null ||
        _selectedTags.isNotEmpty ||
        _selectedAlbum != null;
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedMediaType != null) count++;
    if (_dateRange != null) count++;
    if (_selectedTags.isNotEmpty) count++;
    if (_selectedAlbum != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _keywordController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: loc.searchMediaHint,
            border: InputBorder.none,
            suffixIcon: _keywordController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _keywordController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _search(),
          textInputAction: TextInputAction.search,
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: loc.filter,
                onPressed: () => _showFilterSheet(context),
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_activeFilterCount',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          FilledButton(
            onPressed: _hasActiveFilter ? _search : null,
            child: Text(loc.search),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(context, cs, loc),
    );
  }

  Widget _buildBody(
      BuildContext context, ColorScheme cs, AppLocalizations loc) {
    if (_searching) {
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

    if (!_hasSearched) {
      return _buildInitialHint(cs, loc);
    }

    if (_results.isEmpty) {
      return _buildNoResults(cs, loc);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
          child: Text(
            '${_results.length} ${loc.files}',
            style: AppTextStyles.subtitle.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: MediaGrid(
            mediaList: _results,
            selectedIds: const {},
            isSelectionMode: false,
            crossAxisCount:
                context.watch<AppBloc>().state.settings?.gridColumns ?? 3,
          ),
        ),
      ],
    );
  }

  Widget _buildInitialHint(ColorScheme cs, AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_rounded, size: 56, color: cs.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(loc.search,
              style: AppTextStyles.title.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(loc.searchMediaHint,
              style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildNoResults(ColorScheme cs, AppLocalizations loc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded,
                size: 56, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(loc.noResults,
              style: AppTextStyles.title.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(loc.noResultsDesc,
              style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ── 筛选底部弹窗 ──────────────────────────────────────────────
  void _showFilterSheet(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(loc.filterSort,
                              style: AppTextStyles.title
                                  .copyWith(color: cs.onSurface)),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              _selectedMediaType = null;
                              _dateRange = null;
                              _selectedTags = [];
                              _selectedAlbum = null;
                              _matchAllTags = false;
                            });
                            setState(() {});
                          },
                          child: Text(loc.reset),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 媒体类型
                          _buildSectionLabel(loc.mediaType, cs),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              _typeChip(ctx, loc.filterAll, null,
                                  _selectedMediaType == null, setSheetState),
                              _typeChip(ctx, loc.filterImages, 'image',
                                  _selectedMediaType == 'image', setSheetState),
                              _typeChip(ctx, loc.filterVideos, 'video',
                                  _selectedMediaType == 'video', setSheetState),
                              _typeChip(ctx, loc.filterAudios, 'audio',
                                  _selectedMediaType == 'audio', setSheetState),
                              _typeChip(
                                  ctx,
                                  loc.filterDocuments,
                                  'document',
                                  _selectedMediaType == 'document',
                                  setSheetState),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          // 日期范围
                          _buildSectionLabel(loc.dateRange, cs),
                          const SizedBox(height: AppSpacing.sm),
                          _buildDateRangePicker(ctx, loc, cs, setSheetState),
                          const SizedBox(height: AppSpacing.lg),
                          // 标签
                          if (_allTags.isNotEmpty) ...[
                            _buildSectionLabel(loc.tagFilter, cs),
                            const SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: _allTags
                                  .map((tag) =>
                                      _tagChip(ctx, tag, cs, setSheetState))
                                  .toList(),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          // 相册
                          if (_allAlbums.isNotEmpty) ...[
                            _buildSectionLabel(loc.albumFilter, cs),
                            const SizedBox(height: AppSpacing.sm),
                            _buildAlbumDropdown(ctx, loc, cs, setSheetState),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(loc.cancel),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.search, size: 18),
                            label: Text(loc.search),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _search();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildSectionLabel(String text, ColorScheme cs) {
    return Text(text,
        style: AppTextStyles.subtitle.copyWith(color: cs.primary));
  }

  Widget _typeChip(BuildContext ctx, String label, String? value, bool selected,
      StateSetter setSheetState) {
    final cs = Theme.of(ctx).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setSheetState(() => _selectedMediaType = value);
        setState(() {});
      },
    );
  }

  Widget _tagChip(BuildContext ctx, tag_api.Tag tag, ColorScheme cs,
      StateSetter setSheetState) {
    final selected = _selectedTags.any((t) => t.id == tag.id);
    return FilterChip(
      label: Text(tag.name),
      selected: selected,
      onSelected: (_) {
        setSheetState(() {
          if (selected) {
            _selectedTags.removeWhere((t) => t.id == tag.id);
          } else {
            _selectedTags.add(tag);
          }
        });
        setState(() {});
      },
    );
  }

  Widget _buildDateRangePicker(BuildContext ctx, AppLocalizations loc,
      ColorScheme cs, StateSetter setSheetState) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: ctx,
          firstDate: DateTime(2000),
          lastDate: now.add(const Duration(days: 1)),
          initialDateRange: _dateRange ??
              DateTimeRange(
                start: now.subtract(const Duration(days: 30)),
                end: now,
              ),
        );
        if (picked != null) {
          setSheetState(() => _dateRange = picked);
          setState(() {});
        }
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _dateRange != null ? cs.primary : cs.outline,
            width: _dateRange != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range,
                size: 20,
                color: _dateRange != null ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                _dateRange == null
                    ? loc.selectDateRange
                    : '${_formatDate(_dateRange!.start)}  ~  ${_formatDate(_dateRange!.end)}',
                style: TextStyle(
                    color: _dateRange != null
                        ? cs.onSurface
                        : cs.onSurfaceVariant),
              ),
            ),
            if (_dateRange != null)
              IconButton(
                icon: Icon(Icons.clear, size: 18, color: cs.onSurfaceVariant),
                onPressed: () {
                  setSheetState(() => _dateRange = null);
                  setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumDropdown(BuildContext ctx, AppLocalizations loc,
      ColorScheme cs, StateSetter setSheetState) {
    return DropdownButtonFormField<album_api.AlbumWithInfo>(
      value: _selectedAlbum,
      decoration: InputDecoration(
        hintText: loc.selectAlbum,
        prefixIcon: const Icon(Icons.camera_alt, size: 20),
      ),
      items: [
        DropdownMenuItem<album_api.AlbumWithInfo>(
          value: null,
          child: Text(loc.filterAll),
        ),
        ..._allAlbums.map((a) => DropdownMenuItem<album_api.AlbumWithInfo>(
              value: a,
              child: Text(a.album.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: (val) {
        setSheetState(() => _selectedAlbum = val);
        setState(() {});
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
