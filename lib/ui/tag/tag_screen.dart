import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_media_knowledge_base/core/i18n/app_localizations.dart';
import 'package:flutter_media_knowledge_base/core/design_system/app_theme.dart';
import 'package:flutter_media_knowledge_base/core/design_system/components.dart';
import 'package:flutter_media_knowledge_base/bridge/native/api/tag.dart'
    as tag_api;
import 'package:flutter_media_knowledge_base/bridge/native/api/media.dart';
import '../viewer/viewer_page.dart';
import '../../functionality/tag/tag_bloc.dart';
import 'package:flutter_media_knowledge_base/functionality/home/app_bloc.dart';

/// 标签浏览页面 - 支持无限层级、面包屑导航、网格列数控制
class TagScreen extends StatefulWidget {
  const TagScreen({super.key});

  @override
  State<TagScreen> createState() => _TagScreenState();
}

class _TagScreenState extends State<TagScreen> {
  final Set<String> _selectedTagIds = {};
  final Set<String> _selectedMediaIds = {};
  bool _isMediaSelectionMode = false;
  List<MediaItem>? _filteredMedia;
  int get _tagColumns =>
      context.watch<AppBloc>().state.settings?.gridColumns ?? 3;

  void _enterMediaSelection(String mediaId) {
    setState(() {
      _isMediaSelectionMode = true;
      _selectedMediaIds.add(mediaId);
    });
  }

  void _toggleMediaSelection(String mediaId) {
    setState(() {
      if (_selectedMediaIds.contains(mediaId)) {
        _selectedMediaIds.remove(mediaId);
      } else {
        _selectedMediaIds.add(mediaId);
      }
      if (_selectedMediaIds.isEmpty) {
        _isMediaSelectionMode = false;
      }
    });
  }

  void _clearMediaSelection() {
    setState(() {
      _selectedMediaIds.clear();
      _isMediaSelectionMode = false;
    });
  }

  @override
  void initState() {
    super.initState();
    context.read<TagBloc>().add(const TagLoadRootsEvent());
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return PopScope(
        canPop: !_isMediaSelectionMode,
        onPopInvoked: (didPop) {
          if (!didPop && _isMediaSelectionMode) {
            _clearMediaSelection();
          }
        },
        child: Scaffold(
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
                        Icon(Icons.error_outline,
                            size: AppSize.iconXLarge,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(height: 16),
                        Text(
                            '${loc.error}: ${state.errorMessage ?? loc.unknown}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (state.currentParentId != null) {
                              context.read<TagBloc>().add(
                                    TagLoadChildrenEvent(
                                        state.currentParentId!),
                                  );
                            } else {
                              context
                                  .read<TagBloc>()
                                  .add(const TagLoadRootsEvent());
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
                      if (state.breadcrumb.isNotEmpty)
                        _buildBreadcrumb(context, state),
                      // 内容区域
                      Expanded(
                          child: _buildContent(context, state, _tagColumns)),
                    ],
                  );
              }
            },
          ),
          floatingActionButton: _isMediaSelectionMode
              ? const SizedBox.shrink()
              : BlocBuilder<TagBloc, TagState>(
                  builder: (context, state) {
                    if (_filteredMedia != null) return const SizedBox.shrink();
                    return FloatingActionButton(
                      onPressed: () => _showCreateTagDialog(context),
                      tooltip: loc.createTag,
                      child: const Icon(Icons.new_label),
                    );
                  },
                ),
          bottomNavigationBar:
              _isMediaSelectionMode ? _buildMediaSelectionBar(context) : null,
        ));
  }

  Widget _buildMediaSelectionBar(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.1),
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
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: loc.cancel,
                onPressed: _clearMediaSelection,
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${loc.selected} ${_selectedMediaIds.length}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                tooltip: loc.delete,
                onPressed: _selectedMediaIds.isNotEmpty
                    ? () => _batchDeleteSelectedMedia(context)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _batchDeleteSelectedMedia(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.confirmBatchDelete),
        content:
            Text('${loc.confirmBatchDelete} (${_selectedMediaIds.length})'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.cancel)),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final id in _selectedMediaIds) {
      await deleteMedia(id: id);
    }
    _clearMediaSelection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${loc.success} ${_selectedMediaIds.length}')));
      _executeFilter();
    }
  }

  /// 面包屑导航
  Widget _buildBreadcrumb(BuildContext context, TagState state) {
    final loc = AppLocalizations.of(context);
    final nodes = <BreadcrumbNode>[
      BreadcrumbNode(label: loc.tabTags, id: '', icon: Icons.home_rounded),
      ...state.breadcrumb.asMap().entries.map((e) => BreadcrumbNode(
            label: e.value.name,
            id: e.value.id,
            icon: e.key == state.breadcrumb.length - 1
                ? Icons.label_important
                : Icons.label,
          )),
    ];
    return BreadcrumbBar(
      nodes: nodes,
      onTap: (index) {
        if (index == 0) {
          context.read<TagBloc>().add(const TagNavigateToRootEvent());
        } else {
          context.read<TagBloc>().add(TagNavigateToEvent(nodes[index].id));
        }
      },
    );
  }

  /// 内容区域 - 子标签网格 + 筛选结果
  Widget _buildContent(BuildContext context, TagState state, int gridColumns) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final hasTags = state.tagsWithInfo.isNotEmpty;
    final hasParent = state.currentParentId != null;

    if (!hasTags && !hasParent) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.label,
                size: AppSize.iconXxl, color: cs.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(loc.noTags,
                style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.sm),
            Text(loc.noTagsDesc,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // 子标签网格
        if (hasTags) ...[
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
          Icon(Icons.filter_list,
              size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '${_selectedTagIds.length} ${loc.tags} · ${_filteredMedia!.length}',
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
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
              child: Text(loc.noResults,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
              final isSelected = _selectedMediaIds.contains(media.id);
              return _MediaGridItem(
                media: media,
                isSelectionMode: _isMediaSelectionMode,
                isSelected: isSelected,
                onTap: () {
                  if (_isMediaSelectionMode) {
                    _toggleMediaSelection(media.id);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ViewerPage(
                            initialMedia: media, mediaList: _filteredMedia!),
                      ),
                    );
                  }
                },
                onLongPress: () => _enterMediaSelection(media.id),
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
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(loc.createTag),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: loc.tagName,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
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
                  final currentParentId =
                      context.read<TagBloc>().state.currentParentId;
                  context.read<TagBloc>().add(
                        TagCreateEvent(
                          name,
                          color: '#FF6750A4',
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
              leading: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.error),
              title: Text(loc.delete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
                    child: Text(loc.selectTagColor,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
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
                            color: Color(
                                int.parse(color.replaceFirst('#', '0xFF'))),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                        color: Colors.black26, blurRadius: 4)
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
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
                            TagCreateEvent(name,
                                color: selectedColor, parentId: parentId),
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

  /// 递归收集一个标签及其所有后代的 ID（用于防止循环父子检测）
  static Set<String> _collectDescendantIds(
      List<tag_api.Tag> allTags, String rootId) {
    final result = <String>{rootId};
    final children =
        allTags.where((t) => t.parentId == rootId).map((t) => t.id).toList();
    for (final childId in children) {
      result.addAll(_collectDescendantIds(allTags, childId));
    }
    return result;
  }

  /// 编辑标签对话框（支持修改名字、颜色、父标签）
  void _showEditTagDialog(BuildContext context, dynamic tagInfo) async {
    final loc = AppLocalizations.of(context);
    final tag = tagInfo.tag;
    final nameController = TextEditingController(text: tag.name);

    // 获取所有可用父标签（排除自身及自身的后代以防循环）
    List<tag_api.Tag> allTags = [];
    try {
      allTags = await tag_api.getAllTags();
    } catch (_) {
      // 忽略错误，保持空列表
    }

    // 计算禁止的父标签 ID：自身 + 所有后代
    final forbiddenIds = _collectDescendantIds(allTags, tag.id);

    String selectedColor = tag.color ?? _colorOptions.first;
    String? selectedParentId = tag.parentId;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(loc.edit),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 名字
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: loc.tagName,
                          border: const OutlineInputBorder(),
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 16),
                      // 颜色选择
                      Text(
                        loc.selectTagColor,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                                color: Color(
                                    int.parse(color.replaceFirst('#', '0xFF'))),
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4)
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 18)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // 父标签选择
                      Text(
                        loc.tagParent,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        value: selectedParentId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('(${loc.none})'),
                          ),
                          ...allTags
                              .where((t) => !forbiddenIds.contains(t.id))
                              .map((t) => DropdownMenuItem<String?>(
                                    value: t.id,
                                    child: Text(t.name),
                                  )),
                        ],
                        onChanged: (val) =>
                            setState(() => selectedParentId = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(loc.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final bloc = context.read<TagBloc>();
                    if (name != tag.name) {
                      bloc.add(TagRenameEvent(tag.id, name));
                    }
                    if (selectedColor != tag.color) {
                      bloc.add(TagUpdateColorEvent(tag.id, selectedColor));
                    }
                    if (selectedParentId != tag.parentId) {
                      bloc.add(TagUpdateParentEvent(tag.id, selectedParentId));
                    }
                    Navigator.pop(ctx);
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

  void _confirmDeleteTag(BuildContext context, dynamic tagInfo) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.confirmBatchDelete),
        content: Text('${loc.confirmBatchDelete}\n${tagInfo.tag.name}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
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

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _TagFilterDialog(
        allTags: allTags,
        selectedTagIds: _selectedTagIds,
      ),
    );

    if (result == null) return;
    final selectedIds = result;

    if (selectedIds.isEmpty) {
      _clearFilter();
      return;
    }

    setState(() {
      _selectedTagIds
        ..clear()
        ..addAll(selectedIds);
    });

    await _executeFilter();
  }

  /// 执行标签筛选
  Future<void> _executeFilter() async {
    try {
      List<MediaItem> results;
      results =
          await tag_api.getMediaByTagsOr(tagIds: _selectedTagIds.toList());
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

  /// 12 种预设颜色（Material 调色板 + 互补色）
  static const List<String> _colorOptions = [
    '#FF6750A4', // Deep Purple
    '#FFE53935', // Red
    '#FF1E88E5', // Blue
    '#FF43A047', // Green
    '#FFFB8C00', // Orange
    '#FF8E24AA', // Purple
    '#FF00ACC1', // Cyan
    '#FFD81B60', // Pink
    '#FF3949AB', // Indigo
    '#FF00897B', // Teal
    '#FF7CB342', // Light Green
    '#FFC0CA33', // Lime
  ];
}

class _TagBreadcrumbItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _TagBreadcrumbItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? cs.primaryContainer : cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: AppSize.iconSmall,
                  color:
                      isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? cs.onPrimaryContainer : cs.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          color: cs.surface,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.md),
              child: Text(
                tag.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 媒体网格项（用于标签筛选结果展示）
class _MediaGridItem extends StatelessWidget {
  final MediaItem media;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MediaGridItem({
    required this.media,
    required this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
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
            if (isSelectionMode)
              Positioned.fill(
                child: Container(
                  color: isSelected
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
            if (isSelectionMode)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.check_circle_outline,
                  size: 24,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                ),
              ),
            if (media.mediaType != MediaType.image && !isSelectionMode)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

/// 标签筛选对话框
class _TagFilterDialog extends StatefulWidget {
  final List<tag_api.Tag> allTags;
  final Set<String> selectedTagIds;

  const _TagFilterDialog({
    required this.allTags,
    required this.selectedTagIds,
  });

  @override
  State<_TagFilterDialog> createState() => _TagFilterDialogState();
}

class _TagFilterDialogState extends State<_TagFilterDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.selectedTagIds);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc.tags),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, _selected);
          },
          child: Text('${loc.tags} (${_selected.length})'),
        ),
      ],
    );
  }
}
