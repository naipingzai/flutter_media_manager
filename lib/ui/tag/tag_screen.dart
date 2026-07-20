import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_media_manager/core/i18n/app_localizations.dart';
import 'package:flutter_media_manager/core/design_system/app_theme.dart';
import 'package:flutter_media_manager/bridge/native/api/tag.dart' as tag_api;
import 'package:flutter_media_manager/bridge/native/api/media.dart';
import '../viewer/viewer_page.dart';
import '../../functionality/tag/tag_bloc.dart';
import 'package:flutter_media_manager/functionality/home/app_bloc.dart';

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
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_isMediaSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isMediaSelectionMode) {
          _clearMediaSelection();
        }
      },
      child: Scaffold(
        appBar: _isMediaSelectionMode
            ? _buildSelectionAppBar(context, loc, cs)
            : _buildNormalAppBar(context, loc, cs),
        body: BlocBuilder<TagBloc, TagState>(
          builder: (context, state) {
            switch (state.status) {
              case TagStatus.initial:
              case TagStatus.loading:
                return _buildLoading(loc, cs);
              case TagStatus.error:
                return _buildError(context, state, loc, cs);
              case TagStatus.loaded:
                if (_filteredMedia != null) {
                  return _buildFilteredMediaView(context, cs, loc);
                }
                return _buildLoaded(context, state, loc, cs);
            }
          },
        ),
        floatingActionButton: _isMediaSelectionMode
            ? null
            : BlocBuilder<TagBloc, TagState>(
                builder: (context, state) {
                  if (_filteredMedia != null) return const SizedBox.shrink();
                  return FloatingActionButton.extended(
                    onPressed: () => _showCreateTagDialog(context),
                    icon: const Icon(Icons.new_label_rounded, size: 20),
                    label: Text(loc.createTag),
                  );
                },
              ),
        bottomNavigationBar:
            _isMediaSelectionMode ? _buildMediaSelectionBar(context, cs) : null,
      ),
    );
  }

  // ── Normal AppBar ───────────────────────────────────────────────
  PreferredSizeWidget _buildNormalAppBar(
      BuildContext context, AppLocalizations loc, ColorScheme cs) {
    return AppBar(
      title: Text(loc.tabTags),
      actions: [
        if (_filteredMedia != null)
          IconButton(
            icon: Icon(Icons.clear_all_rounded, color: cs.onSurfaceVariant),
            tooltip: loc.clearAll,
            onPressed: _clearFilter,
          )
        else
          BlocBuilder<TagBloc, TagState>(
            buildWhen: (prev, curr) =>
                prev.currentParentId != curr.currentParentId,
            builder: (context, state) {
              if (state.currentParentId != null) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon:
                    Icon(Icons.filter_list_rounded, color: cs.onSurfaceVariant),
                tooltip: loc.tagFilter,
                onPressed: _showTagFilterDialog,
              );
            },
          ),
      ],
    );
  }

  // ── Selection AppBar ────────────────────────────────────────────
  PreferredSizeWidget _buildSelectionAppBar(
      BuildContext context, AppLocalizations loc, ColorScheme cs) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: _clearMediaSelection,
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          '${loc.selected} ${_selectedMediaIds.length}',
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ── Loading ─────────────────────────────────────────────────────
  Widget _buildLoading(AppLocalizations loc, ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(loc.loading,
              style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  // ── Error ───────────────────────────────────────────────────────
  Widget _buildError(BuildContext context, TagState state, AppLocalizations loc,
      ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.errorContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, size: 48, color: cs.error),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('${loc.error}: ${state.errorMessage ?? loc.unknown}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () {
                if (state.currentParentId != null) {
                  context
                      .read<TagBloc>()
                      .add(TagLoadChildrenEvent(state.currentParentId!));
                } else {
                  context.read<TagBloc>().add(const TagLoadRootsEvent());
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(loc.retry),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loaded content ──────────────────────────────────────────────
  Widget _buildLoaded(BuildContext context, TagState state,
      AppLocalizations loc, ColorScheme cs) {
    final hasTags = state.tagsWithInfo.isNotEmpty;
    final hasParent = state.currentParentId != null;

    if (!hasTags && !hasParent) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.label_outline_rounded,
                    size: 56, color: cs.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(loc.noTags,
                  style: AppTextStyles.title.copyWith(color: cs.onSurface),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(loc.noTagsDesc,
                  style:
                      AppTextStyles.body.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        if (state.breadcrumb.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildBreadcrumb(context, state),
          ),
        if (hasTags) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _tagColumns,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tagInfo = state.tagsWithInfo[index];
                  return _TagCard(
                    tagInfo: tagInfo,
                    onTap: () => context
                        .read<TagBloc>()
                        .add(TagNavigateToEvent(tagInfo.tag.id)),
                    onLongPress: () => _showTagActions(context, tagInfo),
                  );
                },
                childCount: state.tagsWithInfo.length,
              ),
            ),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  // ── Media selection bar ─────────────────────────────────────────
  Widget _buildMediaSelectionBar(BuildContext context, ColorScheme cs) {
    final loc = AppLocalizations.of(context);
    final selectedCount = _selectedMediaIds.length;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withOpacity(0.3)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
          child: Row(
            children: [
              _actionButton(
                icon: Icons.delete_outline_rounded,
                label: loc.delete,
                color: cs.error,
                enabled: selectedCount > 0,
                onTap: () => _batchDeleteSelectedMedia(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: enabled
            ? color.withOpacity(0.1)
            : cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 22, color: enabled ? color : cs.onSurfaceVariant),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: enabled ? color : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _batchDeleteSelectedMedia(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, size: 40, color: cs.error),
        title: Text(loc.confirmBatchDelete),
        content:
            Text('${loc.confirmBatchDelete} (${_selectedMediaIds.length})'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
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

  // ── Breadcrumb ──────────────────────────────────────────────────
  Widget _buildBreadcrumb(BuildContext context, TagState state) {
    final loc = AppLocalizations.of(context);
    final nodes = <BreadcrumbNode>[
      BreadcrumbNode(label: loc.tabTags, id: '', icon: Icons.home_rounded),
      ...state.breadcrumb.asMap().entries.map((e) => BreadcrumbNode(
            label: e.value.name,
            id: e.value.id,
            icon: e.key == state.breadcrumb.length - 1
                ? Icons.label_important_rounded
                : Icons.label_rounded,
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

  // ── Filtered media view ─────────────────────────────────────────
  Widget _buildFilteredMediaView(
      BuildContext context, ColorScheme cs, AppLocalizations loc) {
    final filterInfoBar = Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: cs.surfaceContainerHighest.withOpacity(0.4),
      child: Row(
        children: [
          Icon(Icons.filter_list_rounded, size: 16, color: cs.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '${_selectedTagIds.length} ${loc.tags} · ${_filteredMedia!.length}',
            style: AppTextStyles.caption.copyWith(color: cs.onSurfaceVariant),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 48, color: cs.onSurfaceVariant),
                  const SizedBox(height: AppSpacing.md),
                  Text(loc.noResults,
                      style: AppTextStyles.body
                          .copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
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
            padding: const EdgeInsets.all(AppSpacing.sm),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _tagColumns,
              crossAxisSpacing: AppSpacing.xs,
              mainAxisSpacing: AppSpacing.xs,
              childAspectRatio: 0.78,
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

  // ── Create tag dialog ───────────────────────────────────────────
  void _showCreateTagDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.createTag),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(hintText: loc.tagName),
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
                      TagCreateEvent(name,
                          color: '#FF6750A4', parentId: currentParentId),
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

  // ── Tag actions (long press) ────────────────────────────────────
  void _showTagActions(BuildContext context, dynamic tagInfo) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading:
                    Icon(Icons.create_new_folder_outlined, color: cs.primary),
                title: Text(loc.createTag),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateSubTagDialog(context, tagInfo.tag.id);
                },
              ),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: cs.primary),
                title: Text(loc.edit),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditTagDialog(context, tagInfo);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                title: Text(loc.delete, style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteTag(context, tagInfo);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  // ── Create sub-tag ──────────────────────────────────────────────
  void _showCreateSubTagDialog(BuildContext context, String parentId) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final controller = TextEditingController();
    String selectedColor = '#FF6750A4';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(loc.createTag),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(hintText: loc.tagName),
                    autofocus: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child:
                        Text(loc.selectTagColor, style: AppTextStyles.subtitle),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _colorOptions.map((color) {
                      final isSelected = selectedColor == color;
                      return GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedColor = color),
                        child: AnimatedContainer(
                          duration: AppAnimation.fast,
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(
                                int.parse(color.replaceFirst('#', '0xFF'))),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: cs.onPrimary, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                        color: cs.primary.withOpacity(0.3),
                                        blurRadius: 6)
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? Icon(Icons.check_rounded,
                                  color: cs.onPrimary, size: 18)
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

  // ── Recursive descendant IDs ────────────────────────────────────
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

  // ── Edit tag dialog ─────────────────────────────────────────────
  void _showEditTagDialog(BuildContext context, dynamic tagInfo) async {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tag = tagInfo.tag;
    final nameController = TextEditingController(text: tag.name);

    List<tag_api.Tag> allTags = [];
    try {
      allTags = await tag_api.getAllTags();
    } catch (_) {}

    final forbiddenIds = _collectDescendantIds(allTags, tag.id);
    String selectedColor = tag.color ?? _colorOptions.first;
    String? selectedParentId = tag.parentId;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(loc.edit),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(hintText: loc.tagName),
                        autofocus: true,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(loc.selectTagColor, style: AppTextStyles.subtitle),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: _colorOptions.map((color) {
                          final isSelected = selectedColor == color;
                          return GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedColor = color),
                            child: AnimatedContainer(
                              duration: AppAnimation.fast,
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Color(
                                    int.parse(color.replaceFirst('#', '0xFF'))),
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: cs.onPrimary, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                            color: cs.primary.withOpacity(0.3),
                                            blurRadius: 6)
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? Icon(Icons.check_rounded,
                                      color: cs.onPrimary, size: 18)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(loc.tagParent, style: AppTextStyles.subtitle),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<String?>(
                        value: selectedParentId,
                        isExpanded: true,
                        decoration: const InputDecoration(
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
                            setDialogState(() => selectedParentId = val),
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

  // ── Delete tag confirmation ─────────────────────────────────────
  void _confirmDeleteTag(BuildContext context, dynamic tagInfo) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, size: 40, color: cs.error),
        title: Text(loc.deleteTag),
        content: Text('${loc.confirmDeleteTag}\n\n${tagInfo.tag.name}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(loc.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
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

  // ── Tag filter dialog ───────────────────────────────────────────
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

  void _clearFilter() {
    setState(() {
      _selectedTagIds.clear();
      _filteredMedia = null;
    });
  }

  static const List<String> _colorOptions = [
    '#FF6750A4',
    '#FFE53935',
    '#FF1E88E5',
    '#FF43A047',
    '#FFFB8C00',
    '#FF8E24AA',
    '#FF00ACC1',
    '#FFD81B60',
    '#FF3949AB',
    '#FF00897B',
    '#FF7CB342',
    '#FFC0CA33',
  ];
}

// ── Tag card ──────────────────────────────────────────────────────

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

    final tagColor = tag.color != null
        ? Color(int.parse(tag.color!.replaceFirst('#', '0xFF')))
        : cs.primary;
    return Card(
      color: tagColor.withOpacity(0.15),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Icon(Icons.label_rounded, size: 20, color: tagColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  tag.name,
                  style: AppTextStyles.subtitle.copyWith(color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tagInfo.mediaCount != null)
                Text(
                  '${tagInfo.mediaCount}',
                  style: AppTextStyles.caption.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Media grid item (unified with media_grid.dart) ───────────────

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
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withOpacity(0.4),
      borderRadius: BorderRadius.circular(AppRadius.md),
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
                errorBuilder: (_, __, ___) => _buildPlaceholder(cs),
              )
            else
              _buildPlaceholder(cs),
            if (isSelectionMode)
              AnimatedContainer(
                duration: AppAnimation.fast,
                color: isSelected
                    ? cs.primary.withOpacity(0.25)
                    : cs.scrim.withOpacity(0.05),
              ),
            if (isSelectionMode)
              Positioned(
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                child: AnimatedSwitcher(
                  duration: AppAnimation.thumbnailScale,
                  child: isSelected
                      ? Container(
                          key: const ValueKey(true),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: cs.primary.withOpacity(0.3),
                                  blurRadius: 8),
                            ],
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.check_rounded,
                              color: cs.onPrimary, size: 18),
                        )
                      : const SizedBox.shrink(key: ValueKey(false)),
                ),
              ),
            if (media.mediaType != MediaType.image && !isSelectionMode)
              Positioned(
                bottom: AppSpacing.xs,
                right: AppSpacing.xs,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.scrim.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Icon(
                    _getMediaIcon(media.mediaType),
                    size: 12,
                    color: cs.secondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme cs) {
    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          _getMediaIcon(media.mediaType),
          size: AppSize.iconXl,
          color: cs.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }

  IconData _getMediaIcon(MediaType type) {
    switch (type) {
      case MediaType.image:
        return Icons.image_outlined;
      case MediaType.video:
        return Icons.videocam_outlined;
      case MediaType.audio:
        return Icons.audiotrack_outlined;
      case MediaType.document:
        return Icons.description_outlined;
      case MediaType.other:
        return Icons.insert_drive_file_outlined;
    }
  }
}

// ── Tag filter dialog ─────────────────────────────────────────────

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
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(loc.tagFilter),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: widget.allTags.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.label_off_outlined,
                        size: 48, color: cs.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.md),
                    Text(loc.noTags),
                  ],
                ),
              )
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

