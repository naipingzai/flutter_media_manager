import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';
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
      startDate: _dateRange?.start.millisecondsSinceEpoch != null ? _dateRange!.start.millisecondsSinceEpoch ~/ 1000 : null,
      endDate: _dateRange?.end.millisecondsSinceEpoch != null ? _dateRange!.end.millisecondsSinceEpoch ~/ 1000 : null,
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                children: [
                  const Icon(Icons.tune, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.advSearch,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearAll,
                    child: Text(AppLocalizations.of(context).reset),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(),

            // 搜索内容
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 关键词
                          _buildSectionTitle(loc.keyword),
                          TextField(
                            controller: _keywordController,
                            decoration: InputDecoration(
                              hintText: loc.searchFileName,
                              prefixIcon: const Icon(Icons.search, size: 20),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),

                          // 媒体类型
                          _buildSectionTitle(loc.mediaType),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildTypeChip(AppLocalizations.of(context).filterAll, null),
                              _buildTypeChip(AppLocalizations.of(context).image, 'image'),
                              _buildTypeChip(AppLocalizations.of(context).video, 'video'),
                              _buildTypeChip(AppLocalizations.of(context).audio, 'audio'),
                              _buildTypeChip(AppLocalizations.of(context).document, 'document'),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 日期范围
                          _buildSectionTitle(loc.dateRange),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickDateRange,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.date_range, size: 20, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Text(
                                    _dateRange == null
                                        ? AppLocalizations.of(context).selectDateRange
                                        : '${_formatDate(_dateRange!.start)} ~ ${_formatDate(_dateRange!.end)}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const Spacer(),
                                  if (_dateRange != null)
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () => setState(() => _dateRange = null),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 标签
                          _buildSectionTitle(loc.tagFilter),
                          const SizedBox(height: 4),
                          if (_allTags.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(loc.noTags, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            )
                          else ...[
                            Row(
                              children: [
                                Text(AppLocalizations.of(context).matchMode, style: TextStyle(fontSize: 13)),
                                  ChoiceChip(
                                    label: Text(AppLocalizations.of(context).matchAnyTag, style: TextStyle(fontSize: 12)),
                                    selected: !_matchAllTags,
                                    onSelected: (_) => setState(() => _matchAllTags = false),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: Text(AppLocalizations.of(context).matchAllTags, style: TextStyle(fontSize: 12)),
                                    selected: _matchAllTags,
                                    onSelected: (_) => setState(() => _matchAllTags = true),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 120),
                              child: ListView(
                                shrinkWrap: true,
                                children: _allTags.map((tag) {
                                  final sel = _selectedTags.any((t) => t.id == tag.id);
                                  return CheckboxListTile(
                                    title: Text(tag.name, style: const TextStyle(fontSize: 13)),
                                    visualDensity: VisualDensity.compact,
                                    value: sel,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedTags.add(tag);
                                        } else {
                                          _selectedTags.removeWhere((t) => t.id == tag.id);
                                        }
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // 相册
                          _buildSectionTitle(loc.albumFilter),
                          const SizedBox(height: 8),
                          if (_allAlbums.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(loc.noAlbums, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            )
                          else
                            DropdownButtonFormField<album_api.AlbumWithInfo>(
                              value: _selectedAlbum,
                              decoration: InputDecoration(
                                hintText: loc.selectAlbum,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                DropdownMenuItem<album_api.AlbumWithInfo>(
                                  value: null,
                                  child: Text(loc.filterAll, style: const TextStyle(fontSize: 14)),
                                ),
                                ..._allAlbums.map((a) => DropdownMenuItem<album_api.AlbumWithInfo>(
                                      value: a,
                                      child: Text(a.album.name, style: const TextStyle(fontSize: 14)),
                                    )),
                              ],
                              onChanged: (val) => setState(() => _selectedAlbum = val),
                            ),
                        ],
                      ),
                    ),
            ),

            // 底部操作栏
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context).cancel),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.search, size: 18),
                    label: Text(AppLocalizations.of(context).search),
                    onPressed: _search,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTypeChip(String label, String? value) {
    final isSelected = _selectedMediaType == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (sel) {
        setState(() {
          _selectedMediaType = sel ? value : null;
        });
      },
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: _dateRange ?? DateTimeRange(
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
