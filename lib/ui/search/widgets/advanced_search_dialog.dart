import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_media_manager/core/design_system/app_theme.dart';
import 'package:flutter_media_manager/core/i18n/app_localizations.dart';
import 'package:flutter_media_manager/bridge/native/api/search.dart';
import 'package:flutter_media_manager/bridge/native/api/tag.dart' as tag_api;
import 'package:flutter_media_manager/bridge/native/api/album.dart'
    as album_api;
import 'package:flutter_media_manager/functionality/media/media_bloc.dart';

/// 高级搜索对话框 - Material 3 组合筛选：关键词、类型、日期范围、标签、相册
class AdvancedSearchDialog extends StatefulWidget {
  const AdvancedSearchDialog({super.key});

  @override
  State<AdvancedSearchDialog> createState() => _AdvancedSearchDialogState();
}

class _AdvancedSearchDialogState extends State<AdvancedSearchDialog> {
  final _keywordController = TextEditingController();

  // 搜索条件
  String? _selectedMediaType;
  DateTimeRange? _dateRange;
  List<tag_api.Tag> _selectedTags = [];
  album_api.AlbumWithInfo? _selectedAlbum;
  bool _matchAllTags = false;

  // 加载状态
  List<tag_api.Tag> _allTags = [];
  List<album_api.AlbumWithInfo> _allAlbums = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final tags = await tag_api.getAllTags();
      final albums = await album_api.getRootAlbums();
      if (mounted) {
        setState(() {
          _allTags = tags;
          _allAlbums = albums;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _search() {
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

    context.read<MediaBloc>().add(MediaAdvancedSearchEvent(filter));
    Navigator.pop(context);
  }

  void _clearAll() {
    setState(() {
      _keywordController.clear();
      _selectedMediaType = null;
      _dateRange = null;
      _selectedTags = [];
      _selectedAlbum = null;
      _matchAllTags = false;
    });
  }

  bool get _hasActiveFilter {
    return _keywordController.text.isNotEmpty ||
        _selectedMediaType != null ||
        _dateRange != null ||
        _selectedTags.isNotEmpty ||
        _selectedAlbum != null;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏 - Material 3 大标题风格
            _buildHeader(loc, cs, tt),
            const Divider(height: 1),

            // 搜索内容
            Flexible(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            loc.loading,
                            style: tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildKeywordField(loc, cs, tt),
                          const SizedBox(height: AppSpacing.xl),
                          _buildMediaTypeSection(loc, cs, tt),
                          const SizedBox(height: AppSpacing.xl),
                          _buildDateRangeSection(loc, cs, tt),
                          const SizedBox(height: AppSpacing.xl),
                          _buildTagSection(loc, cs, tt),
                          const SizedBox(height: AppSpacing.xl),
                          _buildAlbumSection(loc, cs, tt),
                        ],
                      ),
                    ),
            ),

            // 底部操作栏
            const Divider(height: 1),
            _buildFooter(loc, cs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations loc, ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(Icons.tune, size: 20, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.advSearch,
                  style: tt.headlineSmall?.copyWith(color: cs.onSurface),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _clearAll,
            child: Text(loc.reset),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: loc.close,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordField(
      AppLocalizations loc, ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(loc.keyword, cs, tt),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _keywordController,
          decoration: InputDecoration(
            hintText: loc.searchFileName,
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildMediaTypeSection(
      AppLocalizations loc, ColorScheme cs, TextTheme tt) {
    final types = [
      _TypeOption(loc.filterAll, null, Icons.filter_list),
      _TypeOption(loc.image, 'image', Icons.image),
      _TypeOption(loc.video, 'video', Icons.videocam),
      _TypeOption(loc.audio, 'audio', Icons.audiotrack),
      _TypeOption(loc.document, 'document', Icons.description),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(loc.mediaType, cs, tt),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: types.map((t) => _buildTypeChip(t, cs, tt)).toList(),
        ),
      ],
    );
  }

  Widget _buildTypeChip(_TypeOption option, ColorScheme cs, TextTheme tt) {
    final isSelected = _selectedMediaType == option.value;
    return FilterChip(
      label: Text(option.label),
      avatar: Icon(
        option.icon,
        size: 18,
        color: isSelected ? cs.onSecondaryContainer : cs.onSurfaceVariant,
      ),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (selected) {
        setState(() {
          _selectedMediaType = selected ? option.value : null;
        });
      },
    );
  }

  Widget _buildDateRangeSection(
      AppLocalizations loc, ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(loc.dateRange, cs, tt),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: _pickDateRange,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: _dateRange != null ? cs.primary : cs.outline,
                width: _dateRange != null
                    ? AppSize.borderWidthStrong
                    : AppSize.borderWidthDefault,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.date_range,
                  size: 20,
                  color: _dateRange != null ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _dateRange == null
                        ? loc.selectDateRange
                        : '${_formatDate(_dateRange!.start)}  ~  ${_formatDate(_dateRange!.end)}',
                    style: tt.bodyLarge?.copyWith(
                      color: _dateRange != null
                          ? cs.onSurface
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_dateRange != null)
                  IconButton(
                    icon:
                        Icon(Icons.clear, size: 18, color: cs.onSurfaceVariant),
                    onPressed: () => setState(() => _dateRange = null),
                    tooltip: loc.cancel,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagSection(AppLocalizations loc, ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(loc.tagFilter, cs, tt),
        const SizedBox(height: AppSpacing.sm),
        if (_allTags.isEmpty)
          _buildEmptyHint(loc.noTags, cs, tt)
        else ...[
          // 匹配模式 - 使用 SegmentedButton (M3)
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.tune, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  loc.matchMode,
                  style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(loc.matchAnyTag),
                        icon: const Icon(Icons.join_full, size: 16),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(loc.matchAllTags),
                        icon: const Icon(Icons.join_inner, size: 16),
                      ),
                    ],
                    selected: {_matchAllTags},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        setState(() => _matchAllTags = s.first),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // 标签选择
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children:
                _allTags.map((tag) => _buildTagChip(tag, cs, tt)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTagChip(tag_api.Tag tag, ColorScheme cs, TextTheme tt) {
    final selected = _selectedTags.any((t) => t.id == tag.id);
    return FilterChip(
      label: Text(tag.name),
      selected: selected,
      onSelected: (_) {
        setState(() {
          if (selected) {
            _selectedTags.removeWhere((t) => t.id == tag.id);
          } else {
            _selectedTags.add(tag);
          }
        });
      },
    );
  }

  Widget _buildAlbumSection(
      AppLocalizations loc, ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(loc.albumFilter, cs, tt),
        const SizedBox(height: AppSpacing.sm),
        if (_allAlbums.isEmpty)
          _buildEmptyHint(loc.noAlbums, cs, tt)
        else
          DropdownButtonFormField<album_api.AlbumWithInfo>(
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
              ..._allAlbums
                  .map((a) => DropdownMenuItem<album_api.AlbumWithInfo>(
                        value: a,
                        child: Text(
                          a.album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
            ],
            onChanged: (val) => setState(() => _selectedAlbum = val),
          ),
      ],
    );
  }

  Widget _buildEmptyHint(String text, ColorScheme cs, TextTheme tt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _buildFooter(AppLocalizations loc, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.search, size: 18),
            label: Text(loc.search),
            onPressed: _hasActiveFilter ? _search : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text, ColorScheme cs, TextTheme tt) {
    return Text(
      text,
      style: tt.titleSmall?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class _TypeOption {
  final String label;
  final String? value;
  final IconData icon;

  const _TypeOption(this.label, this.value, this.icon);
}
