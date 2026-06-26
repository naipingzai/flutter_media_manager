import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';
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
                  const Expanded(
                    child: Text(
                      '高级搜索',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text('重置'),
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
                          _buildSectionTitle('关键词'),
                          TextField(
                            controller: _keywordController,
                            decoration: const InputDecoration(
                              hintText: '搜索文件名...',
                              prefixIcon: Icon(Icons.search, size: 20),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),

                          // 媒体类型
                          _buildSectionTitle('媒体类型'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildTypeChip('全部', null),
                              _buildTypeChip('图片', 'image'),
                              _buildTypeChip('视频', 'video'),
                              _buildTypeChip('音频', 'audio'),
                              _buildTypeChip('文档', 'document'),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // 日期范围
                          _buildSectionTitle('日期范围'),
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
                                        ? '选择日期范围'
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
                          _buildSectionTitle('标签筛选'),
                          const SizedBox(height: 4),
                          if (_allTags.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('暂无标签', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            )
                          else ...[
                            Row(
                              children: [
                                const Text('匹配模式: ', style: TextStyle(fontSize: 13)),
                                  ChoiceChip(
                                    label: const Text('任一标签', style: TextStyle(fontSize: 12)),
                                    selected: !_matchAllTags,
                                    onSelected: (_) => setState(() => _matchAllTags = false),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('所有标签', style: TextStyle(fontSize: 12)),
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
                          _buildSectionTitle('相册筛选'),
                          const SizedBox(height: 8),
                          if (_allAlbums.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text('暂无相册', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            )
                          else
                            DropdownButtonFormField<album_api.AlbumWithInfo>(
                              value: _selectedAlbum,
                              decoration: const InputDecoration(
                                hintText: '选择相册',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<album_api.AlbumWithInfo>(
                                  value: null,
                                  child: Text('全部', style: TextStyle(fontSize: 14)),
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
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('搜索'),
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
