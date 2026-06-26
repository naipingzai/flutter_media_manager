import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/bloc.dart';
import '../core/i18n/app_localizations.dart';
import '../src/rust/api/tag.dart' as tag_api;
import '../src/rust/api/media.dart';
import 'media_detail_screen.dart';

/// 标签浏览页面 - 支持无限层级、面包屑导航、网格列数控制
class TagScreen extends StatefulWidget {
  const TagScreen({super.key});

  @override
  State<TagScreen> createState() => _TagScreenState();
}

enum TagFilterMode { and, or }

class _TagScreenState extends State<TagScreen> {
  // 标签筛选模式
  TagFilterMode _filterMode = TagFilterMode.or;
  final Set<String> _selectedTagIds = {};
  List<MediaItem>? _filteredMedia;
  int _tagColumns = 3;

  @override
  void initState() {
    super.initState();
    context.read<TagBloc>().add(const TagLoadRootsEvent());
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<TagBloc, TagState>(
          builder: (context, state) {
            if (_filteredMedia != null) {
              return Text(loc.tags);
            }
            if (state.currentTagId != null && state.breadcrumb.isNotEmpty) {
              return Text(state.breadcrumb.last.name);
            }
            return Text(loc.tags);
          },
        ),
        leading: BlocBuilder<TagBloc, TagState>(
          builder: (context, state) {
            if (_filteredMedia != null) {
              return IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _clearFilter,
              );
            }
            if (state.currentParentId != null) {
              return IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  context.read<TagBloc>().add(const TagNavigateUpEvent());
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
        actions: [
          // 列数控制
          PopupMenuButton<int>(
            icon: const Icon(Icons.grid_view),
            tooltip: loc.gridColumns,
            onSelected: (cols) {
              setState(() => _tagColumns = cols);
            },
            itemBuilder: (_) => [2, 3, 4, 5].map((cols) {
              return CheckedPopupMenuItem<int>(
                value: cols,
                checked: _tagColumns == cols,
                child: Text('$cols ${loc.columns}'),
              );
            }).toList(),
          ),
          if (_filteredMedia != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: loc.delete,
              onPressed: _clearFilter,
            )
          else
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: loc.tags,
              onPressed: _showTagFilterDialog,
            ),
        ],
      ),
      body: BlocBuilder<TagBloc, TagState>(
        builder: (context, state) {
          switch (state.status) {
            case TagStatus.initial:
            case TagStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case TagStatus.error:
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('${loc.error}: ${state.errorMessage ?? loc.unknown}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (state.currentParentId != null) {
                          context.read<TagBloc>().add(
                                TagLoadChildrenEvent(state.currentParentId!),
                              );
                        } else {
                          context.read<TagBloc>().add(const TagLoadRootsEvent());
                        }
                      },
                      child: Text(loc.retry),
                    ),
                  ],
                ),
              );
            case TagStatus.loaded:
              // 如果有筛选结果，显示媒体网格
              if (_filteredMedia != null) {
                return _buildFilteredMediaView(context, _tagColumns);
              }

              return Column(
                children: [
                  // 面包屑导航
                  if (state.breadcrumb.isNotEmpty) _buildBreadcrumb(context, state),
                  // 内容区域
                  Expanded(child: _buildContent(context, state, _tagColumns)),
                ],
              );
          }
        },
      ),
      floatingActionButton: BlocBuilder<TagBloc, TagState>(
        builder: (context, state) {
          if (_filteredMedia != null) return const SizedBox.shrink();
          return FloatingActionButton(
            onPressed: () => _showCreateTagDialog(context),
            tooltip: loc.createTag,
            child: const Icon(Icons.new_label),
          );
        },
      ),
    );
  }

  /// 面包屑导航
  Widget _buildBreadcrumb(BuildContext context, TagState state) {
    final loc = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Home 按钮
            InkWell(
              onTap: () {
                context.read<TagBloc>().add(const TagNavigateToRootEvent());
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home, size: 18, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(loc.tabTags, style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    )),
                  ],
                ),
              ),
            ),
            // 各级面包屑
            for (int i = 0; i < state.breadcrumb.length; i++) ...[
              Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              InkWell(
                    onTap: i < state.breadcrumb.length - 1
                    ? () {
                        // 回到指定层级
                        final targetId = state.breadcrumb[i].id;
                        context.read<TagBloc>().add(
                              TagNavigateToEvent(targetId),
                            );
                      }
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Text(
                    state.breadcrumb[i].name,
                    style: TextStyle(
                      fontSize: 13,
                      color: i < state.breadcrumb.length - 1
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: i == state.breadcrumb.length - 1
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 内容区域 - 子标签网格 + 筛选结果
  Widget _buildContent(BuildContext context, TagState state, int gridColumns) {
    final loc = AppLocalizations.of(context);
    final hasTags = state.tagsWithInfo.isNotEmpty;
    final hasParent = state.currentParentId != null;

    if (!hasTags && !hasParent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.label, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(loc.noTags, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(loc.noTagsDesc, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // 子标签网格
        if (hasTags) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                '${loc.tags} (${state.tagsWithInfo.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridColumns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tagInfo = state.tagsWithInfo[index];
                  return _TagCard(
                    tagInfo: tagInfo,
                    onTap: () {
                      if (tagInfo.hasChildren != 0) {
                        context.read<TagBloc>().add(
                              TagNavigateToEvent(tagInfo.tag.id),
                            );
                      } else {
                        // 没有子标签，显示该标签关联的媒体
                        _showTagMedia(context, tagInfo.tag.id);
                      }
                    },
                    onLongPress: () => _showTagActions(context, tagInfo),
                  );
                },
                childCount: state.tagsWithInfo.length,
              ),
            ),
          ),
        ],
        // 底部间距
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  /// 显示筛选后的媒体网格
  Widget _buildFilteredMediaView(BuildContext context, int gridColumns) {
    final loc = AppLocalizations.of(context);
    final filterInfoBar = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '${_filterMode == TagFilterMode.and ? "AND" : "OR"} · ${_selectedTagIds.length} ${loc.tags} · ${_filteredMedia!.length}',
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    if (_filteredMedia!.isEmpty) {
      return Column(
        children: [
          filterInfoBar,
          Expanded(
            child: Center(
              child: Text(loc.noResults, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        filterInfoBar,
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridColumns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: _filteredMedia!.length,
            itemBuilder: (context, index) {
              final media = _filteredMedia![index];
              return _MediaGridItem(
                media: media,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MediaDetailScreen(media: media, mediaList: _filteredMedia!),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// 显示标签关联的媒体
  Future<void> _showTagMedia(BuildContext context, String tagId) async {
    try {
      final media = await tag_api.getMediaByTag(tagId: tagId);
      if (!mounted) return;
      setState(() {
        _filteredMedia = media;
        _selectedTagIds
          ..clear()
          ..add(tagId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
      );
    }
  }

  void _showCreateTagDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final nameController = TextEditingController();
    String selectedColor = '#FF6750A4';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(loc.createTag),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: loc.tagName,
                      border: const OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(loc.selectTagColor, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colorOptions.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [BoxShadow(color: Colors.black26, blurRadius: 4)]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(loc.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isNotEmpty) {
                      final currentParentId = context.read<TagBloc>().state.currentParentId;
                      context.read<TagBloc>().add(
                            TagCreateEvent(
                              name,
                              color: selectedColor,
                              parentId: currentParentId,
                            ),
                          );
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(loc.confirm),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTagActions(BuildContext context, dynamic tagInfo) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: Text(loc.createTag),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateSubTagDialog(context, tagInfo.tag.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(loc.edit),
              onTap: () {
                Navigator.pop(ctx);
                _showEditTagDialog(context, tagInfo);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text(loc.delete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteTag(context, tagInfo);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSubTagDialog(BuildContext context, String parentId) {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
    String selectedColor = '#FF6750A4';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(loc.createTag),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: loc.tagName,
                      border: const OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(loc.selectTagColor, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _colorOptions.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = color),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [BoxShadow(color: Colors.black26, blurRadius: 4)]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(loc.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      context.read<TagBloc>().add(
                            TagCreateEvent(name, color: selectedColor, parentId: parentId),
                          );
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(loc.confirm),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditTagDialog(BuildContext context, dynamic tagInfo) {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController(text: tagInfo.tag.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.edit),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: loc.tagName,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                context.read<TagBloc>().add(
                      TagRenameEvent(tagInfo.tag.id, name),
                    );
                Navigator.pop(ctx);
              }
            },
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTag(BuildContext context, dynamic tagInfo) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.confirmBatchDelete),
        content: Text('${loc.confirmBatchDelete}\n${tagInfo.tag.name}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              context.read<TagBloc>().add(TagDeleteEvent(tagInfo.tag.id));
              Navigator.pop(ctx);
            },
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }

  /// 显示标签筛选对话框
  void _showTagFilterDialog() async {
    final allTags = await tag_api.getAllTags();
    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _TagFilterDialog(
        allTags: allTags,
        selectedTagIds: _selectedTagIds,
        filterMode: _filterMode,
      ),
    );

    if (result == null) return;
    final selectedIds = result['selectedIds'] as Set<String>;
    final mode = result['mode'] as TagFilterMode;

    if (selectedIds.isEmpty) {
      _clearFilter();
      return;
    }

    setState(() {
      _selectedTagIds
        ..clear()
        ..addAll(selectedIds);
      _filterMode = mode;
    });

    await _executeFilter();
  }

  /// 执行标签筛选
  Future<void> _executeFilter() async {
    try {
      List<MediaItem> results;
      if (_filterMode == TagFilterMode.and) {
        results = await tag_api.getMediaByTagsAnd(tagIds: _selectedTagIds.toList());
      } else {
        results = await tag_api.getMediaByTagsOr(tagIds: _selectedTagIds.toList());
      }
      if (mounted) {
        setState(() => _filteredMedia = results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
        );
      }
    }
  }

  /// 清除筛选
  void _clearFilter() {
    setState(() {
      _selectedTagIds.clear();
      _filteredMedia = null;
    });
  }

  static const _colorOptions = [
    '#FF6750A4', '#FFE53935', '#FF1E88E5', '#FF43A047',
    '#FFFB8C00', '#FF8E24AA', '#FF00ACC1', '#FFD81B60',
  ];
}

/// 标签卡片组件（网格展示）
class _TagCard extends StatelessWidget {
  final dynamic tagInfo;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _TagCard({
    required this.tagInfo,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final tag = tagInfo.tag;
    final mediaCount = tagInfo.mediaCount;
    final hasChildren = tagInfo.hasChildren;
    final color = _parseColor(tag.color);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: (color ?? Theme.of(context).colorScheme.primary).withOpacity(0.15),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.label,
                        size: 40,
                        color: color ?? Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 4),
                      if (hasChildren != 0)
                        Icon(
                          Icons.subdirectory_arrow_right,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: color ?? Theme.of(context).colorScheme.primary,
                    width: 4,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$mediaCount ${AppLocalizations.of(context).files}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color? _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return null;
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }
}

/// 媒体网格项（用于标签筛选结果展示）
class _MediaGridItem extends StatelessWidget {
  final MediaItem media;
  final VoidCallback onTap;

  const _MediaGridItem({required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (media.thumbnailPath.isNotEmpty)
              Image.file(
                File(media.thumbnailPath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(context),
              )
            else
              _buildPlaceholder(context),
            if (media.mediaType != MediaType.image)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    _getMediaIcon(media.mediaType),
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          _getMediaIcon(media.mediaType),
          size: 32,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
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
}

/// 标签筛选对话框（支持 AND/OR 模式）
class _TagFilterDialog extends StatefulWidget {
  final List<tag_api.Tag> allTags;
  final Set<String> selectedTagIds;
  final TagFilterMode filterMode;

  const _TagFilterDialog({
    required this.allTags,
    required this.selectedTagIds,
    required this.filterMode,
  });

  @override
  State<_TagFilterDialog> createState() => _TagFilterDialogState();
}

class _TagFilterDialogState extends State<_TagFilterDialog> {
  late Set<String> _selected;
  late TagFilterMode _mode;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedTagIds);
    _mode = widget.filterMode;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.tags),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // AND/OR 模式切换
            SegmentedButton<TagFilterMode>(
              segments: const [
                ButtonSegment(
                  value: TagFilterMode.or,
                  label: Text('OR'),
                ),
                ButtonSegment(
                  value: TagFilterMode.and,
                  label: Text('AND'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selected) {
                setState(() => _mode = selected.first);
              },
            ),
            const SizedBox(height: 12),
            // 标签列表
            Expanded(
              child: widget.allTags.isEmpty
                  ? Center(child: Text(loc.noTags))
                  : ListView.builder(
                      itemCount: widget.allTags.length,
                      itemBuilder: (ctx, i) {
                        final tag = widget.allTags[i];
                        final isSelected = _selected.contains(tag.id);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selected.add(tag.id);
                              } else {
                                _selected.remove(tag.id);
                              }
                            });
                          },
                          title: Text(tag.name),
                          secondary: tag.color != null
                              ? CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Color(int.parse(
                                      tag.color!.replaceFirst('#', '0xFF'))),
                                )
                              : null,
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
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'selectedIds': _selected,
              'mode': _mode,
            });
          },
          child: Text('${loc.tags} (${_selected.length})'),
        ),
      ],
    );
  }
}
