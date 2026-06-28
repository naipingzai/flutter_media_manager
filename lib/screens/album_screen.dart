import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// album_bloc imported via bloc.dart
// bloc imports via specific files
import '../bloc/app/app_bloc.dart';
import '../bloc/album/album_bloc.dart';
import 'package:advance_media_kb/src/rust/api/album.dart';
import 'package:advance_media_kb/src/rust/api/media.dart';
import 'package:advance_media_kb/src/rust/frb_generated.dart';
import 'package:logger/logger.dart';
import '../core/i18n/app_localizations.dart';

final _logger = Logger();

/// 相册浏览页 - 支持无限层级嵌套
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  int get _albumColumns {
    final settings = context.read<AppBloc>().state.settings;
    return settings?.albumGridColumns ?? 3;
  }

  @override
  void initState() {
    super.initState();
    // 加载根相册
    context.read<AlbumBloc>().add(const AlbumLoadRootsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlbumBloc, AlbumState>(
      builder: (context, state) {
        final isSelectionMode = state.selectedMediaIds.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context).tabAlbums),
            actions: [

            ],
          ),
          body: Column(
            children: [
              // 面包屑导航
              _BreadcrumbBar(
                breadcrumb: state.breadcrumb,
                isRoot: state.isRoot,
                onHomeClick: () {
                  context.read<AlbumBloc>().add(const AlbumNavigateToRootEvent());
                },
                onAlbumClick: (item) {
                  context.read<AlbumBloc>().add(AlbumNavigateToEvent(item.id));
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
                    context.read<AlbumBloc>().add(const AlbumClearSelectionEvent());
                  },
                  onRemove: () {
                    context.read<AlbumBloc>().add(const AlbumRemoveSelectedMediaEvent());
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
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'createAlbum',
                      onPressed: () => _showCreateAlbumDialog(context),
                      child: const Icon(Icons.add),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, AlbumState state) {
    if (state.status == AlbumStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == AlbumStatus.error) {
      return Center(child: Text('${AppLocalizations.of(context).error}: ${state.errorMessage}'));
    }

    final hasChildren = state.albums.isNotEmpty;
    final hasMedia = state.albumMedia.isNotEmpty;

    if (!hasChildren && !hasMedia) {
      return _EmptyState(
        message: state.isRoot ? AppLocalizations.of(context).noAlbums : AppLocalizations.of(context).noAlbums,
        subMessage: AppLocalizations.of(context).noAlbumsDesc,
      );
    }

    // 根目录只显示相册网格
    if (state.isRoot) {
      return _AlbumGrid(
        albums: state.albums,
        columns: _albumColumns,
        onAlbumClick: (album) {
          context.read<AlbumBloc>().add(AlbumNavigateToEvent(album.album.id));
        },
        onAlbumLongPress: (album) => _showDeleteDialog(context, album),
      );
    }

    // 子目录：子相册 + 媒体混合展示
    if (hasChildren && hasMedia) {
      return Column(
        children: [
          // 子相册区域
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(AppLocalizations.of(context).albums, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ),
          SizedBox(
            height: 120,
            child: _AlbumGrid(
              albums: state.albums,
              columns: _albumColumns,
              onAlbumClick: (album) {
                context.read<AlbumBloc>().add(AlbumNavigateToEvent(album.album.id));
              },
              onAlbumLongPress: (album) => _showDeleteDialog(context, album),
              scrollDirection: Axis.horizontal,
            ),
          ),
          // 媒体区域
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(AppLocalizations.of(context).tabMedia, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ),
          Expanded(
            child: _AlbumMediaGrid(
              mediaList: state.albumMedia,
              selectedIds: state.selectedMediaIds,
              columns: _albumColumns,
              onTap: (media) {
                context.read<AlbumBloc>().add(AlbumToggleMediaSelectionEvent(media.id));
              },
              onLongPress: (media) {
                context.read<AlbumBloc>().add(AlbumToggleMediaSelectionEvent(media.id));
              },
            ),
          ),
        ],
      );
    }

    // 只有子相册
    if (hasChildren) {
      return _AlbumGrid(
        albums: state.albums,
        columns: _albumColumns,
        onAlbumClick: (album) {
          context.read<AlbumBloc>().add(AlbumNavigateToEvent(album.album.id));
        },
        onAlbumLongPress: (album) => _showDeleteDialog(context, album),
      );
    }

    // 只有媒体
    return _AlbumMediaGrid(
      mediaList: state.albumMedia,
      selectedIds: state.selectedMediaIds,
      columns: _albumColumns,
      onTap: (media) {
        context.read<AlbumBloc>().add(AlbumToggleMediaSelectionEvent(media.id));
      },
      onLongPress: (media) {
        context.read<AlbumBloc>().add(AlbumToggleMediaSelectionEvent(media.id));
      },
    );
  }

  void _showCreateAlbumDialog(BuildContext context) {
    final state = context.read<AlbumBloc>().state;
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).createAlbum),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).albumName,
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            if (state.currentParentId != null) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).createAlbum,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
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
            child: Text(AppLocalizations.of(context).confirm),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, AlbumWithInfo album) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteAlbum),
        content: Text('${AppLocalizations.of(context).confirmDeleteAlbum}\n${album.album.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<AlbumBloc>().add(AlbumDeleteEvent(album.album.id));
              Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.of(context).delete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
    return Container(
      height: 40,
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          // Home 图标
          IconButton(
            icon: Icon(
              Icons.home,
              size: 18,
              color: isRoot
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: onHomeClick,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          // 面包屑项
          ...breadcrumb.asMap().entries.expand((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == breadcrumb.length - 1;

            return [
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ActionChip(
                  label: Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: isLast
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  backgroundColor: isLast
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surface,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  onPressed: () => onAlbumClick(item),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ];
          }),
        ],
      ),
    );
  }
}

/// 相册网格
class _AlbumGrid extends StatelessWidget {
  final List<AlbumWithInfo> albums;
  final Function(AlbumWithInfo) onAlbumClick;
  final Function(AlbumWithInfo) onAlbumLongPress;
  final Axis scrollDirection;
  final int columns;

  const _AlbumGrid({
    required this.albums,
    required this.onAlbumClick,
    required this.onAlbumLongPress,
    this.scrollDirection = Axis.vertical,
    this.columns = 3,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      scrollDirection: scrollDirection,
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: scrollDirection == Axis.vertical ? columns : 1,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return _AlbumCard(
          album: album,
          onTap: () => onAlbumClick(album),
          onLongPress: () => onAlbumLongPress(album),
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

  const _AlbumCard({
    required this.album,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasCover = album.coverThumbnailPath != null;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 封面图或默认图标
            if (hasCover)
              Positioned.fill(
                child: Image.file(
                  File(album.coverThumbnailPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildDefaultIcon(context),
                ),
              )
            else
              _buildDefaultIcon(context),

            // 渐变蒙层
            if (hasCover)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
              ),

            // 相册名 + 媒体数量
            Positioned(
              left: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.album.name,
                    style: TextStyle(
                      color: hasCover ? Colors.white : Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${album.mediaCount} ${AppLocalizations.of(context).files}',
                    style: TextStyle(
                      color: hasCover ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // 子相册指示
            if (album.hasChildren > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: hasCover ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          Icons.folder,
          size: 48,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (subMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              subMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
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
    return BottomAppBar(
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onCancel,
          ),
          Text('${AppLocalizations.of(context).selected} $count'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onRemove,
            tooltip: AppLocalizations.of(context).removeFromAlbum,
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

  const _AlbumMediaGrid({
    required this.mediaList,
    required this.selectedIds,
    required this.onTap,
    required this.onLongPress,
    this.columns = 3,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1.0,
      ),
      itemCount: mediaList.length,
      itemBuilder: (context, index) {
        final media = mediaList[index];
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
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.image),
                        ),
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image),
                      ),
              ),
              if (isSelectionMode)
                Positioned.fill(
                  child: Container(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
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
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    try {
      final media = await RustLib.instance.api.crateApiMediaGetAllMedia();
      setState(() {
        _allMedia = media;
        _loading = false;
      });
    } catch (e) {
      _logger.e('加载媒体失败: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).addToAlbum),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _allMedia.isEmpty
                ? Center(child: Text(AppLocalizations.of(context).noMedia))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: _allMedia.length,
                    itemBuilder: (ctx, index) {
                      final media = _allMedia[index];
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
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Theme.of(context).colorScheme.surfaceVariant,
                                        child: const Icon(Icons.image),
                                      ),
                                    )
                                  : Container(
                                      color: Theme.of(context).colorScheme.surfaceVariant,
                                      child: const Icon(Icons.image),
                                    ),
                            ),
                            if (isSelected)
                              Positioned.fill(
                                child: Container(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                ),
                              ),
                            if (isSelected)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(
                                  Icons.check_circle,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        TextButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () {
                  context.read<AlbumBloc>().add(
                    AlbumAddMediaEvent(_selectedIds.toList(), widget.albumId),
                  );
                  // 刷新子相册列表
                  context.read<AlbumBloc>().add(AlbumLoadChildrenEvent(widget.albumId));
                  Navigator.pop(context);
                },
          child: Text('${AppLocalizations.of(context).addToAlbum} (${_selectedIds.length})'),
        ),
      ],
    );
  }
}
