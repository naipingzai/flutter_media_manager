import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';
import '../core/design_system/app_theme.dart';
import '../core/i18n/app_localizations.dart';
import '../src/rust/api/search.dart';
import '../src/rust/api/tag.dart' as tag_api;
import '../src/rust/api/album.dart' as album_api;

/// 高级搜索对话框 - 组合筛选：关键词、类型、日期范围、标签、相册
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
      query: _keywordController.text.isNotEmpty ? _keywordController.text : null,
      mediaType: _selectedMediaType,
      startDate: _dateRange?.start.millisecondsSinceEpoch != null
          ? _dateRange!.start.millisecondsSinceEpoch ~/ 1000
          : null,
      endDate: _dateRange?.end.millisecondsSinceEpoch != null
          ? _dateRange!.end.millisecondsSinceEpoch ~/ 1000
          : null,
      albumId: _selectedAlbum?.album.id,
      tagIds: _selectedTags.isNotEmpty ? _selectedTags.map((t) => t.id).toList() : null,
      tagCount: _matchAllTags && _selectedTags.isNotEmpty ? _selectedTags.length : 1,
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

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(loc, cs),

            const Divider(height: 1),

            // 搜索内容
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
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
                          _buildKeywordField(loc, cs),
                          const SizedBox(height: AppSpacing.xl),
                          _buildMediaTypeSection(loc, cs),
                          const SizedBox(height: AppSpacing.xl),
                          _buildDateRangeSection(loc, cs),
                          const SizedBox(height: AppSpacing.xl),
                          _buildTagSection(loc, cs),
                          const SizedBox(height: AppSpacing.xl),
                          _buildAlbumSection(loc, cs),
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

  Widget _buildHeader(AppLocalizations loc, ColorScheme cs) {
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
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(Icons.tune, size: 20, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              loc.advSearch,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
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

  Widget _buildKeywordField(AppLocalizations loc, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(loc.keyword, cs),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _keywordController,
          decoration: InputDecoration(
            hintText: loc.searchFileName,
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildMediaTypeSection(AppLocalizations loc, ColorScheme cs) {
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
        _buildSectionTitle(loc.mediaType, cs),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: types.map((t) => _buildTypeChip(t, cs)).toList(),
        ),
      ],
    );
  }

  Widget _buildTypeChip(_TypeOption option, ColorScheme cs) {
    final isSelected = _selectedMediaType == option.value;
    return FilterChip(
      label: Text(option.label),
      avatar: Icon(
        option.icon,
        size: 18,
        color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedMediaType = selected ? option.value : null;
        });
      },
      selectedColor: cs.primary,
      checkmarkColor: cs.onPrimary,
      labelStyle: TextStyle(
        color: isSelected ? cs.onPrimary : cs.onSurface,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.5),
        ),
      ),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildDateRangeSection(AppLocalizations loc, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(loc.dateRange, cs),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: _pickDateRange,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _dateRange != null ? cs.primary : cs.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.date_range,
                  size: 20,
                  color: _dateRange != null ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _dateRange == null
                        ? loc.selectDateRange
                        : '${_formatDate(_dateRange!.start)}  ~  ${_formatDate(_dateRange!.end)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: _dateRange != null ? cs.onSurface : cs.onSurfaceVariant,
                    ),
                  ),
                ),
                if (_dateRange != null)
                  IconButton(
                    icon: Icon(Icons.clear, size: 18, color: cs.onSurfaceVariant),
                    onPressed: () => setState(() => _dateRange = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagSection(AppLocalizations loc, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(loc.tagFilter, cs),
        const SizedBox(height: AppSpacing.sm),
        if (_allTags.isEmpty)
          _buildEmptyHint(loc.noTags, cs)
        else ...[
          // 匹配模式
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.matchMode,
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.sm),
                _buildMatchModeChip(loc.matchAnyTag, false, cs),
                const SizedBox(width: AppSpacing.sm),
                _buildMatchModeChip(loc.matchAllTags, true, cs),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 标签选择
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _allTags.map((tag) => _buildTagChip(tag, cs)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildMatchModeChip(String label, bool matchAll, ColorScheme cs) {
    final selected = _matchAllTags == matchAll;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => setState(() => _matchAllTags = matchAll),
      selectedColor: cs.primaryContainer,
      labelStyle: TextStyle(
        color: selected ? cs.onPrimaryContainer : cs.onSurface,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildTagChip(tag_api.Tag tag, ColorScheme cs) {
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
      selectedColor: cs.primaryContainer,
      checkmarkColor: cs.onPrimaryContainer,
      labelStyle: TextStyle(
        color: selected ? cs.onPrimaryContainer : cs.onSurface,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: selected ? cs.primaryContainer : cs.outline.withValues(alpha: 0.5),
        ),
      ),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAlbumSection(AppLocalizations loc, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(loc.albumFilter, cs),
        const SizedBox(height: AppSpacing.sm),
        if (_allAlbums.isEmpty)
          _buildEmptyHint(loc.noAlbums, cs)
        else
          DropdownButtonFormField<album_api.AlbumWithInfo>(
            initialValue: _selectedAlbum,
            decoration: InputDecoration(
              hintText: loc.selectAlbum,
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
            ),
            items: [
              DropdownMenuItem<album_api.AlbumWithInfo>(
                value: null,
                child: Text(loc.filterAll, style: const TextStyle(fontSize: 14)),
              ),
              ..._allAlbums.map((a) => DropdownMenuItem<album_api.AlbumWithInfo>(
                value: a,
                child: Text(
                  a.album.name,
                  style: const TextStyle(fontSize: 14),
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

  Widget _buildEmptyHint(String text, ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
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

  Widget _buildSectionTitle(String text, ColorScheme cs) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: cs.onSurface,
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xxl),
            ),
          ),
        ),
        child: child!,
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
