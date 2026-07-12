// ignore_for_file: invalid_use_of_internal_member
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// album_bloc imported via bloc.dart
// bloc imports via specific files
import 'package:flutter_media_knowledge_base/functionality/home/app_bloc.dart';
import '../../functionality/album/album_bloc.dart';
import 'package:flutter_media_knowledge_base/bridge/native/api/album.dart';
import 'package:logger/logger.dart';
import 'package:flutter_media_knowledge_base/core/i18n/app_localizations.dart';
import 'package:flutter_media_knowledge_base/core/design_system/app_theme.dart';
import 'package:flutter_media_knowledge_base/bridge/native/api/media.dart';
import 'package:flutter_media_knowledge_base/bridge/native/api/media.dart'
    as media_api;
import '../viewer/viewer_page.dart';

final _logger = Logger();

/// 相册浏览页 - 支持无限层级嵌套
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

enum AlbumSortMode {
  nameAsc,
  nameDesc,
  dateNewest,
  dateOldest,
  countMost,
  countLeast
}

class _AlbumScreenState extends State<AlbumScreen> {
  AlbumSortMode _sortMode = AlbumSortMode.dateNewest;

  int get _albumColumns {
    final settings = context.watch<AppBloc>().state.settings;
    return settings?.gridColumns ?? 3;
  }

  List<AlbumWithInfo> _sortAlbums(List<AlbumWithInfo> albums) {
    final sorted = List<AlbumWithInfo>.from(albums);
    switch (_sortMode) {
      case AlbumSortMode.nameAsc:
        sorted.sort((a, b) => a.album.name.compareTo(b.album.name));
      case AlbumSortMode.nameDesc:
        sorted.sort((a, b) => b.album.name.compareTo(a.album.name));
      case AlbumSortMode.dateNewest:
        sorted.sort((a, b) => b.album.createdAt.compareTo(a.album.createdAt));
      case AlbumSortMode.dateOldest:
        sorted.sort((a, b) => a.album.createdAt.compareTo(b.album.createdAt));
      case AlbumSortMode.countMost:
        sorted.sort((a, b) => b.mediaCount.compareTo(a.mediaCount));
      case AlbumSortMode.countLeast:
        sorted.sort((a, b) => a.mediaCount.compareTo(b.mediaCount));
    }
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    // 加载根相册
    context.read<AlbumBloc>().add(const AlbumLoadRootsEvent());
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return BlocBuilder<AlbumBloc, AlbumState>(
      builder: (context, state) {
        final isSelectionMode = state.selectedMediaIds.isNotEmpty;

        return WillPopScope(
          onWillPop: () async {
            if (isSelectionMode) {
              context.read<AlbumBloc>().add(const AlbumClearSelectionEvent());
              return false;
            }
            if (!state.isRoot) {
              context.read<AlbumBloc>().add(const AlbumNavigateUpEvent());
              return false;
            }
            return true;
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(loc.tabAlbums),
              actions: [
                // 排序按钮
                PopupMenuButton<AlbumSortMode>(
                  icon: const Icon(Icons.sort),
                  tooltip: loc.sortTooltip,
                  onSelected: (mode) {
                    setState(() => _sortMode = mode);
                  },
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem(
                      value: AlbumSortMode.nameAsc,
                      checked: _sortMode == AlbumSortMode.nameAsc,
                      child: Text(loc.sortNameAsc),
                    ),
                    CheckedPopupMenuItem(
                      value: AlbumSortMode.nameDesc,
                      checked: _sortMode == AlbumSortMode.nameDesc,
                      child: Text(loc.sortNameDesc),
                    ),
                    CheckedPopupMenuItem(
                      value: AlbumSortMode.dateNewest,
                      checked: _sortMode == AlbumSortMode.dateNewest,
                      child: Text(loc.sortNewestFirst),
                    ),
                    CheckedPopupMenuItem(
                      value: AlbumSortMode.dateOldest,
                      checked: _sortMode == AlbumSortMode.dateOldest,
                      child: Text(loc.sortOldestFirst),
                    ),
                    CheckedPopupMenuItem(
                      value: AlbumSortMode.countMost,
                      checked: _sortMode == AlbumSortMode.countMost,
                      child: Text(loc.sortCountMost),
                    ),
                    CheckedPopupMenuItem(
                      value: AlbumSortMode.countLeast,
                      checked: _sortMode == AlbumSortMode.countLeast,
                      child: Text(loc.sortCountLeast),
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                // 面包屑导航
                _BreadcrumbBar(
                  breadcrumb: state.breadcrumb,
                  isRoot: state.isRoot,
                  onHomeClick: () {
                    context
                        .read<AlbumBloc>()
                        .add(const AlbumNavigateToRootEvent());
                  },
                  onAlbumClick: (item) {
                    context
                        .read<AlbumBloc>()
                        .add(AlbumNavigateToEvent(item.id));
                  },
                ),
                // 内容区
                Expanded(
                  child: _buildContent(context, state),
                ),
              ],
            ),
            // 选择模式下的底部操作栏
            bottomNavigationBar: isSelectionMode
                ? _SelectionBottomBar(
                    count: state.selectedMediaIds.length,
                    onCancel: () {
                      context
                          .read<AlbumBloc>()
                          .add(const AlbumClearSelectionEvent());
                    },
                    onRemove: () {
                      context
                          .read<AlbumBloc>()
                          .add(const AlbumRemoveSelectedMediaEvent());
                    },
                  )
                : null,
            // FAB
            floatingActionButton: isSelectionMode
                ? null
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.currentParentId != null)
                        FloatingActionButton.small(
                          heroTag: 'addMedia',
                          onPressed: () => _showAddMediaDialog(context),
                          child: const Icon(Icons.add_photo_alternate),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      FloatingActionButton(
                        heroTag: 'createAlbum',
                        onPressed: () => _showCreateAlbumDialog(context),
                        child: const Icon(Icons.add),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, AlbumState state) {
    final loc = AppLocalizations.of(context);
    if (state.status == AlbumStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == AlbumStatus.error) {
      return Center(child: Text('${loc.error}: ${state.errorMessage}'));
    }

    final hasChildren = state.albums.isNotEmpty;
    final hasMedia = state.albumMedia.isNotEmpty;

    if (!hasChildren && !hasMedia) {
      return _EmptyState(
        message: loc.noAlbums,
        subMessage: loc.noAlbumsDesc,
      );
    }

    // 根目录只显示相册网格
    if (state.isRoot) {
      return _AlbumGrid(
        albums: _sortAlbums(state.albums),
        columns: _albumColumns,
        onAlbumClick: (album) {
          context.read<AlbumBloc>().add(AlbumNavigateToEvent(album.album.id));
        },
        onAlbumLongPress: (album) => _showDeleteDialog(context, album),
      );
    }

    // 子目录：子相册和媒体统一网格显示
    return _AlbumMediaGrid(
      mediaList: state.albumMedia,
      selectedIds: state.selectedMediaIds,
      columns: _albumColumns,
      albums: hasChildren ? _sortAlbums(state.albums) : null,
      onTap: (media) {
        if (state.selectedMediaIds.isNotEmpty) {
          context
              .read<AlbumBloc>()
              .add(AlbumToggleMediaSelectionEvent(media.id));
        } else {
          // 正常模式：单击打开查看器
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ViewerPage(initialMedia: media, mediaList: state.albumMedia),
            ),
          );
        }
      },
      onLongPress: (media) {
        // 长按进入多选模式
        context.read<AlbumBloc>().add(AlbumToggleMediaSelectionEvent(media.id));
      },
      onAlbumClick: (album) {
        context.read<AlbumBloc>().add(AlbumNavigateToEvent(album.album.id));
      },
      onAlbumLongPress: (album) => _showDeleteDialog(context, album),
    );
  }

  void _showCreateAlbumDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final state = context.read<AlbumBloc>().state;
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.createAlbum),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: loc.albumName,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            if (state.currentParentId != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                loc.subalbumNote,
                style:
                    AppTextStyles.caption.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                context.read<AlbumBloc>().add(
                      AlbumCreateEvent(name, parentId: state.currentParentId),
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

  void _showDeleteDialog(BuildContext context, AlbumWithInfo album) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.deleteAlbum),
        content: Text('${loc.confirmDeleteAlbum}\n${album.album.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<AlbumBloc>().add(AlbumDeleteEvent(album.album.id));
              Navigator.pop(ctx);
            },
            child: Text(loc.delete, style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
  }

  void _showAddMediaDialog(BuildContext context) {
    final albumBloc = context.read<AlbumBloc>();
    final albumId = albumBloc.state.currentParentId;
    if (albumId == null) return;

    // 获取所有媒体（不在当前相册中的）
    showDialog(
      context: context,
      builder: (ctx) => _AddMediaDialogContent(albumId: albumId),
    );
  }
}

/// 面包屑导航栏
class _BreadcrumbBar extends StatelessWidget {
  final List<BreadcrumbItem> breadcrumb;
  final bool isRoot;
  final VoidCallback onHomeClick;
  final Function(BreadcrumbItem) onAlbumClick;

  const _BreadcrumbBar({
    required this.breadcrumb,
    required this.isRoot,
    required this.onHomeClick,
    required this.onAlbumClick,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      color: cs.surfaceContainerHighest,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // Home 图标
          _BreadcrumbItem(
            icon: Icons.home_rounded,
            label: isRoot ? loc.tabAlbums : loc.backToHome,
            isActive: isRoot,
            onTap: onHomeClick,
          ),
          // 面包屑项
          ...breadcrumb.asMap().entries.expand((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == breadcrumb.length - 1;

            return [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Icon(Icons.chevron_right,
                    size: AppSpacing.lg, color: cs.onSurfaceVariant),
              ),
              _BreadcrumbItem(
                icon: isLast ? Icons.folder_open : Icons.folder,
                label: item.name,
                isActive: isLast,
                onTap: () => onAlbumClick(item),
              ),
            ];
          }),
        ],
      ),
    );
  }
}

class _BreadcrumbItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BreadcrumbItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? cs.primaryContainer : cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14,
                  color:
                      isActive ? cs.onPrimaryContainer : cs.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
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

/// 相册网格
class _AlbumGrid extends StatelessWidget {
  final List<AlbumWithInfo> albums;
  final Function(AlbumWithInfo) onAlbumClick;
  final Function(AlbumWithInfo) onAlbumLongPress;
  final int columns;

  const _AlbumGrid({
    required this.albums,
    required this.onAlbumClick,
    required this.onAlbumLongPress,
    this.columns = 3,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: 1.0,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return _AlbumCard(
          album: album,
          onTap: () => onAlbumClick(album),
          onLongPress: () => onAlbumLongPress(album),
          loc: AppLocalizations.of(context),
        );
      },
    );
  }
}

/// 相册卡片
class _AlbumCard extends StatelessWidget {
  final AlbumWithInfo album;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final AppLocalizations loc;

  const _AlbumCard({
    required this.album,
    required this.onTap,
    required this.onLongPress,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          color: cs.surface,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.md),
              child: Text(
                album.album.name,
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

/// 空状态
class _EmptyState extends StatelessWidget {
  final String message;
  final String? subMessage;

  const _EmptyState({required this.message, this.subMessage});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          if (subMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              subMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 选择模式底部栏
class _SelectionBottomBar extends StatelessWidget {
  final int count;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  const _SelectionBottomBar({
    required this.count,
    required this.onCancel,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return BottomAppBar(
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onCancel,
          ),
          Text('${loc.selected} $count'),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.remove_circle_outline, color: cs.error),
            onPressed: onRemove,
            tooltip: loc.removeFromAlbum,
          ),
        ],
      ),
    );
  }
}

/// 相册媒体网格
class _AlbumMediaGrid extends StatelessWidget {
  final List<MediaItem> mediaList;
  final Set<String> selectedIds;
  final Function(MediaItem) onTap;
  final Function(MediaItem) onLongPress;
  final int columns;
  final List<AlbumWithInfo>? albums;
  final void Function(AlbumWithInfo)? onAlbumClick;
  final void Function(AlbumWithInfo)? onAlbumLongPress;
  const _AlbumMediaGrid({
    required this.mediaList,
    required this.selectedIds,
    required this.onTap,
    required this.onLongPress,
    this.columns = 3,
    this.albums,
    this.onAlbumClick,
    this.onAlbumLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.0,
      ),
      itemCount: (albums?.length ?? 0) + mediaList.length,
      itemBuilder: (context, index) {
        final albumCount = albums?.length ?? 0;
        if (index < albumCount) {
          final album = albums![index];
          return _AlbumCard(
            album: album,
            onTap: () => onAlbumClick?.call(album),
            onLongPress: () => onAlbumLongPress?.call(album),
            loc: AppLocalizations.of(context),
          );
        }
        final media = mediaList[index - albumCount];
        final isSelected = selectedIds.contains(media.id);
        final isSelectionMode = selectedIds.isNotEmpty;

        return GestureDetector(
          onTap: () => onTap(media),
          onLongPress: () => onLongPress(media),
          child: Stack(
            children: [
              Positioned.fill(
                child: media.thumbnailPath.isNotEmpty
                    ? Image.file(
                        File(media.thumbnailPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: cs.surfaceContainerHighest,
                          child: const Icon(Icons.image),
                        ),
                      )
                    : Container(
                        color: cs.surfaceContainerHighest,
                        child: const Icon(Icons.image),
                      ),
              ),
              if (isSelectionMode)
                Positioned.fill(
                  child: Container(
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
              if (isSelectionMode)
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    size: 24,
                    color: isSelected
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 添加媒体对话框
class _AddMediaDialogContent extends StatefulWidget {
  final String albumId;

  const _AddMediaDialogContent({required this.albumId});

  @override
  State<_AddMediaDialogContent> createState() => _AddMediaDialogContentState();
}

class _AddMediaDialogContentState extends State<_AddMediaDialogContent> {
  List<MediaItem> _allMedia = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _applyFilter();
  }

  Future<void> _applyFilter() async {
    setState(() => _loading = true);
    try {
      List<MediaItem> results;
      switch (_filter) {
        case 'image':
          results =
              await media_api.filterMediaByType(mediaType: MediaType.image);
          break;
        case 'video':
          results =
              await media_api.filterMediaByType(mediaType: MediaType.video);
          break;
        case 'withTags':
          results =
              await media_api.getMediaByFilter(filter: FilterMode.withTags);
          break;
        case 'withoutTags':
          results =
              await media_api.getMediaByFilter(filter: FilterMode.withoutTags);
          break;
        case 'withAlbums':
          results =
              await media_api.getMediaByFilter(filter: FilterMode.withAlbums);
          break;
        case 'withoutAlbums':
          results = await media_api.getMediaByFilter(
              filter: FilterMode.withoutAlbums);
          break;
        default:
          results = await media_api.getAllMedia();
      }
      setState(() {
        _allMedia = results;
        _loading = false;
      });
    } catch (e) {
      _logger.e('筛选媒体失败: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final items = _allMedia;
    return AlertDialog(
      title: Text(loc.addToAlbum),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // 筛选菜单
            _buildFilterBar(loc),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? Center(child: Text(loc.noMedia))
                      : GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: context
                                    .read<AppBloc>()
                                    .state
                                    .settings
                                    ?.gridColumns ??
                                3,
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                          ),
                          itemCount: items.length,
                          itemBuilder: (ctx, index) {
                            final media = items[index];
                            final isSelected = _selectedIds.contains(media.id);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(media.id);
                                  } else {
                                    _selectedIds.add(media.id);
                                  }
                                });
                              },
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: media.thumbnailPath.isNotEmpty
                                        ? Image.file(
                                            File(media.thumbnailPath),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: cs.surfaceContainerHighest,
                                              child: const Icon(Icons.image),
                                            ),
                                          )
                                        : Container(
                                            color: cs.surfaceContainerHighest,
                                            child: const Icon(Icons.image),
                                          ),
                                  ),
                                  if (isSelected)
                                    Positioned.fill(
                                      child: Container(
                                        color:
                                            cs.primary.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  if (isSelected)
                                    Positioned(
                                      top: AppSpacing.sm,
                                      right: AppSpacing.sm,
                                      child: Icon(
                                        Icons.check_circle,
                                        size: AppSpacing.lg,
                                        color: cs.primary,
                                      ),
                                    ),
                                ],
                              ),
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
        TextButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () {
                  context.read<AlbumBloc>().add(
                        AlbumAddMediaEvent(
                            _selectedIds.toList(), widget.albumId),
                      );
                  context
                      .read<AlbumBloc>()
                      .add(AlbumLoadChildrenEvent(widget.albumId));
                  Navigator.pop(context);
                },
          child: Text('${loc.addToAlbum} (${_selectedIds.length})'),
        ),
      ],
    );
  }

  Widget _buildFilterBar(AppLocalizations loc) {
    String label;
    switch (_filter) {
      case 'image':
        label = loc.filterImages;
        break;
      case 'video':
        label = loc.filterVideos;
        break;
      case 'withTags':
        label = loc.filterWithTags;
        break;
      case 'withoutTags':
        label = loc.filterWithoutTags;
        break;
      case 'withAlbums':
        label = loc.filterWithAlbums;
        break;
      case 'withoutAlbums':
        label = loc.filterWithoutAlbums;
        break;
      default:
        label = loc.filterAll;
    }
    return PopupMenuButton<String>(
      child: Chip(
        avatar: const Icon(Icons.filter_list, size: 18),
        label: Text(label),
      ),
      onSelected: (value) {
        _filter = value;
        _applyFilter();
      },
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
            value: 'all',
            checked: _filter == 'all',
            child: Text(loc.filterAll)),
        CheckedPopupMenuItem(
            value: 'image',
            checked: _filter == 'image',
            child: Text(loc.filterImages)),
        CheckedPopupMenuItem(
            value: 'video',
            checked: _filter == 'video',
            child: Text(loc.filterVideos)),
        CheckedPopupMenuItem(
            value: 'withTags',
            checked: _filter == 'withTags',
            child: Text(loc.filterWithTags)),
        CheckedPopupMenuItem(
            value: 'withoutTags',
            checked: _filter == 'withoutTags',
            child: Text(loc.filterWithoutTags)),
        CheckedPopupMenuItem(
            value: 'withAlbums',
            checked: _filter == 'withAlbums',
            child: Text(loc.filterWithAlbums)),
        CheckedPopupMenuItem(
            value: 'withoutAlbums',
            checked: _filter == 'withoutAlbums',
            child: Text(loc.filterWithoutAlbums)),
      ],
    );
  }
}
