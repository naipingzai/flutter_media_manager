import 'package:flutter/material.dart';
import 'package:flutter_media_knowledge_base/core/i18n/app_localizations.dart';
import 'package:flutter_media_knowledge_base/core/design_system/app_theme.dart';
import 'package:flutter_media_knowledge_base/bridge/native/api/album.dart';
import 'package:flutter_media_knowledge_base/bridge/native/api/media.dart';
import 'package:flutter_media_knowledge_base/functionality/home/app_bloc.dart';
import 'package:flutter_media_knowledge_base/ui/album/album_detail_screen.dart';
import 'package:flutter_media_knowledge_base/ui/media/widgets/file_browser_dialog.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// 相册管理页面 - 支持创建、重命名、删除、网格列数控制
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  List<AlbumWithInfo> _albums = [];
  bool _loading = true;
  String? _error;

  int get _columns => context.watch<AppBloc>().state.settings?.gridColumns ?? 3;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final albums = await getRootAlbums();
      if (mounted) {
        setState(() {
          _albums = albums;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.tabAlbums),
      ),
      body: _buildBody(context, loc, cs),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'album_import',
            onPressed: () => _showImportMediaDialog(context),
            icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
            label: Text(loc.importMedia),
          ),
          const SizedBox(width: AppSpacing.sm),
          FloatingActionButton.extended(
            heroTag: 'album_create',
            onPressed: () => _showCreateAlbumDialog(context),
            icon: const Icon(Icons.create_new_folder_rounded, size: 20),
            label: Text(loc.createAlbum),
          ),
        ],
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────
  Widget _buildBody(
      BuildContext context, AppLocalizations loc, ColorScheme cs) {
    if (_loading) {
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

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_off_rounded, size: 48, color: cs.error),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style:
                      AppTextStyles.body.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _loadAlbums,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(loc.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_albums.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt_outlined,
                    size: 56, color: cs.primary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(loc.noAlbums,
                  style: AppTextStyles.title.copyWith(color: cs.onSurface),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(loc.noAlbumsDesc,
                  style:
                      AppTextStyles.body.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlbums,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.sm),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columns,
          childAspectRatio: 1.0,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        itemCount: _albums.length,
        itemBuilder: (context, index) {
          final info = _albums[index];
          return _AlbumCard(
            name: info.album.name,
            mediaCount: info.mediaCount,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AlbumDetailScreen(
                    albumId: info.album.id,
                    albumName: info.album.name,
                  ),
                ),
              );
            },
            onLongPress: () => _showAlbumActions(context, info),
          );
        },
      ),
    );
  }

  // ── 长按菜单 ───────────────────────────────────────────────────
  void _showAlbumActions(BuildContext context, AlbumWithInfo info) {
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
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: cs.primary),
                title: Text(loc.editAlbum),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameAlbumDialog(context, info);
                },
              ),
              ListTile(
                leading:
                    Icon(Icons.create_new_folder_outlined, color: cs.tertiary),
                title: Text(loc.createAlbum),
                subtitle: Text(loc.subalbumNote),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreateAlbumDialog(context, parentId: info.album.id);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                title: Text(loc.deleteAlbum, style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteAlbum(context, info);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  // ── 创建相册 ───────────────────────────────────────────────────
  void _showCreateAlbumDialog(BuildContext context, {String? parentId}) {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.createAlbum),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: loc.albumName),
          autofocus: true,
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
                createAlbum(name: name, parentId: parentId);
                Navigator.pop(ctx);
                _loadAlbums();
              }
            },
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
  }

  // ── 重命名相册 ─────────────────────────────────────────────────
  void _showRenameAlbumDialog(BuildContext context, AlbumWithInfo info) {
    final loc = AppLocalizations.of(context);
    final controller = TextEditingController(text: info.album.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.editAlbum),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: loc.albumName),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty && name != info.album.name) {
                renameAlbum(id: info.album.id, name: name);
                Navigator.pop(ctx);
                _loadAlbums();
              }
            },
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
  }

  // ── 导入媒体到相册 ─────────────────────────────────────────────
  void _showImportMediaDialog(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final filePaths = await _pickFiles(context);
    if (filePaths.isEmpty) return;

    // 选择目标相册
    if (!mounted) return;
    final selectedAlbum = await showDialog<String>(
      context: context,
      builder: (ctx) => const _SelectAlbumDialog(),
    );
    if (selectedAlbum == null) return;

    int successCount = 0;
    int failCount = 0;
    for (final path in filePaths) {
      try {
        await importSingleFile(filePath: path);
        successCount++;
      } catch (_) {
        failCount++;
      }
    }
    // 添加到相册
    if (successCount > 0) {
      try {
        await addMediaToAlbum(mediaIds: [], albumId: selectedAlbum);
      } catch (_) {}
    }
    if (!mounted) return;
    _loadAlbums();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${loc.importComplete}: $successCount')),
    );
  }

  Future<List<String>> _pickFiles(BuildContext context) async {
    final result = await openFileBrowser(context);
    return result;
  }

  // ── 删除确认 ───────────────────────────────────────────────────
  void _confirmDeleteAlbum(BuildContext context, AlbumWithInfo info) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, size: 40, color: cs.error),
        title: Text(loc.deleteAlbum),
        content: Text('${loc.confirmDeleteAlbum}\n\n${info.album.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await deleteAlbum(id: info.album.id);
              if (mounted) _loadAlbums();
            },
            child: Text(loc.delete),
          ),
        ],
      ),
    );
  }
}

// ── 选择相册对话框 ───────────────────────────────────────────────

class _SelectAlbumDialog extends StatefulWidget {
  const _SelectAlbumDialog();
  @override
  State<_SelectAlbumDialog> createState() => _SelectAlbumDialogState();
}

class _SelectAlbumDialogState extends State<_SelectAlbumDialog> {
  List<AlbumWithInfo> _albums = [];
  bool _loading = true;
  String? _currentParentId;
  String _currentParentName = '';
  final List<MapEntry<String?, String>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() => _loading = true);
    List<AlbumWithInfo> albums;
    if (_currentParentId == null) {
      albums = await getRootAlbums();
    } else {
      albums = await getChildAlbums(parentId: _currentParentId!);
    }
    setState(() {
      _albums = albums;
      _loading = false;
    });
  }

  void _navigateTo(String albumId, String albumName) {
    _history.add(MapEntry(_currentParentId, _currentParentName));
    _currentParentId = albumId;
    _currentParentName = albumName;
    _loadAlbums();
  }

  void _navigateBack() {
    if (_history.isNotEmpty) {
      final prev = _history.removeLast();
      _currentParentId = prev.key;
      _currentParentName = prev.value;
      _loadAlbums();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          if (_currentParentId != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _navigateBack,
            ),
          if (_currentParentId != null) const SizedBox(width: 4),
          Expanded(
            child: Text(
              _currentParentId == null ? loc.selectAlbum : _currentParentName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _albums.isEmpty
                ? Center(child: Text(loc.noAlbums))
                : ListView.builder(
                    itemCount: _albums.length,
                    itemBuilder: (ctx, index) {
                      final info = _albums[index];
                      return ListTile(
                        leading:
                            Icon(Icons.camera_alt_rounded, color: cs.primary),
                        title: Text(info.album.name),
                        subtitle: Text('${info.mediaCount} ${loc.files}'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () =>
                            _navigateTo(info.album.id, info.album.name),
                        onLongPress: () => Navigator.pop(ctx, info.album.id),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        if (_currentParentId != null)
          FilledButton(
            onPressed: () => Navigator.pop(context, _currentParentId),
            child: Text(loc.confirm),
          ),
      ],
    );
  }
}

// ── 相册卡片 ─────────────────────────────────────────────────────

class _AlbumCard extends StatelessWidget {
  final String name;
  final int mediaCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _AlbumCard({
    required this.name,
    required this.mediaCount,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child:
                    Icon(Icons.camera_alt_rounded, size: 32, color: cs.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(name,
                  style: AppTextStyles.subtitle.copyWith(color: cs.onSurface),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text('$mediaCount ${loc.files}',
                    style: AppTextStyles.caption
                        .copyWith(color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
