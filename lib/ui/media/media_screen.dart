import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_media_manager/core/design_system/app_theme.dart';
import 'package:flutter_media_manager/core/i18n/app_localizations.dart';
import 'widgets/media_grid.dart';
import 'widgets/file_browser_dialog.dart';
import 'package:flutter_media_manager/bridge/native/api/media.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_media_manager/bridge/native/api/tag.dart';
import 'package:flutter_media_manager/bridge/native/api/album.dart';
import 'package:flutter_media_manager/core/navigation/app_router.dart';
import 'package:flutter_media_manager/ui/search/search_screen.dart';
import 'package:flutter_media_manager/ui/settings/settings_screen.dart';
import '../../functionality/media/media_bloc.dart';
import 'package:flutter_media_manager/functionality/home/app_bloc.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});
  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  @override
  void initState() {
    super.initState();
    context.read<MediaBloc>().add(const MediaLoadAllEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MediaBloc, MediaState>(
      builder: (context, state) {
        final cs = Theme.of(context).colorScheme;
        return PopScope(
          canPop: !state.isSelectionMode,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && state.isSelectionMode) {
              context.read<MediaBloc>().add(const MediaClearSelectionEvent());
              context
                  .read<MediaBloc>()
                  .add(const MediaToggleSelectionModeEvent());
            }
          },
          child: Scaffold(
            appBar: state.isSelectionMode
                ? _buildSelectionAppBar(context, state, cs)
                : _buildNormalAppBar(context, state, cs),
            body: _buildBody(context, state, cs),
            bottomNavigationBar: state.isSelectionMode
                ? _buildSelectionBottomBar(context, state, cs)
                : null,
            floatingActionButton:
                state.isSelectionMode ? null : _buildImportFAB(context, cs),
          ),
        );
      },
    );
  }

  // ── Normal AppBar ───────────────────────────────────────────────
  PreferredSizeWidget _buildNormalAppBar(
      BuildContext context, MediaState state, ColorScheme cs) {
    final loc = AppLocalizations.of(context);
    final isFiltered =
        state.currentFilter != null || state.currentFilterMode != null;

    return AppBar(
      title: Text(loc.tabAllMedia),
      actions: [
        // Filter chip
        _buildFilterChip(context, state, cs, loc, isFiltered),
        const SizedBox(width: AppSpacing.xs),
        // Sort
        PopupMenuButton<String>(
          icon: Icon(Icons.sort_rounded, color: cs.onSurfaceVariant),
          tooltip: loc.sort,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          onSelected: (val) {
            final parts = val.split(':');
            final field =
                SortField.values.firstWhere((f) => f.name == parts[0]);
            final order =
                SortOrder.values.firstWhere((o) => o.name == parts[1]);
            context.read<MediaBloc>().add(MediaSortEvent(field, order));
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'date:descending',
              child: _SortMenuItem(
                  icon: Icons.arrow_downward, label: loc.sortNewestFirst),
            ),
            PopupMenuItem(
              value: 'date:ascending',
              child: _SortMenuItem(
                  icon: Icons.arrow_upward, label: loc.sortOldestFirst),
            ),
            PopupMenuItem(
              value: 'name:ascending',
              child: _SortMenuItem(
                  icon: Icons.sort_by_alpha, label: loc.sortNameAsc),
            ),
            PopupMenuItem(
              value: 'name:descending',
              child: _SortMenuItem(
                  icon: Icons.sort_by_alpha, label: loc.sortNameDesc),
            ),
            PopupMenuItem(
              value: 'size:descending',
              child: _SortMenuItem(
                  icon: Icons.arrow_downward, label: loc.sortSizeDesc),
            ),
            PopupMenuItem(
              value: 'size:ascending',
              child: _SortMenuItem(
                  icon: Icons.arrow_upward, label: loc.sortSizeAsc),
            ),
          ],
        ),
        IconButton(
          icon: Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
          tooltip: loc.search,
          onPressed: () =>
              AppRouter.pushOverlay(context, page: const SearchScreen()),
        ),
        IconButton(
          icon: Icon(Icons.settings_outlined, color: cs.onSurfaceVariant),
          tooltip: loc.settings,
          onPressed: () =>
              AppRouter.pushOverlay(context, page: const SettingsScreen()),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  // ── Selection AppBar ────────────────────────────────────────────
  PreferredSizeWidget _buildSelectionAppBar(
      BuildContext context, MediaState state, ColorScheme cs) {
    final loc = AppLocalizations.of(context);
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () {
          context.read<MediaBloc>().add(const MediaClearSelectionEvent());
          context.read<MediaBloc>().add(const MediaToggleSelectionModeEvent());
        },
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          '${loc.selected} ${state.selectedMediaIds.length}',
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isAllSelected(state)
                ? Icons.deselect_rounded
                : Icons.select_all_rounded,
          ),
          tooltip: _isAllSelected(state) ? loc.deselectAll : loc.selectAll,
          onPressed: state.filteredList.isEmpty
              ? null
              : () => context
                  .read<MediaBloc>()
                  .add(const MediaToggleSelectAllEvent()),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  // ── Filter chip in appbar ───────────────────────────────────────
  Widget _buildFilterChip(BuildContext context, MediaState state,
      ColorScheme cs, AppLocalizations loc, bool isFiltered) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      onSelected: (value) {
        final bloc = context.read<MediaBloc>();
        bloc.add(const MediaClearSelectionEvent());
        switch (value) {
          case 'all':
            bloc.add(const MediaLoadAllEvent());
            break;
          case 'image':
            bloc.add(const MediaFilterByTypeEvent(MediaType.image));
            break;
          case 'video':
            bloc.add(const MediaFilterByTypeEvent(MediaType.video));
            break;
          case 'withTags':
            bloc.add(const MediaFilterByFilterModeEvent(FilterMode.withTags));
            break;
          case 'withoutTags':
            bloc.add(
                const MediaFilterByFilterModeEvent(FilterMode.withoutTags));
            break;
          case 'withAlbums':
            bloc.add(const MediaFilterByFilterModeEvent(FilterMode.withAlbums));
            break;
          case 'withoutAlbums':
            bloc.add(
                const MediaFilterByFilterModeEvent(FilterMode.withoutAlbums));
            break;
        }
      },
      itemBuilder: (context) {
        return [
          _filterMenuItem('all', loc.filterAll,
              state.currentFilter == null && state.currentFilterMode == null,
              icon: Icons.all_inclusive_rounded),
          const PopupMenuDivider(),
          _filterMenuItem(
              'image', loc.filterImages, state.currentFilter == MediaType.image,
              icon: Icons.image_rounded),
          _filterMenuItem(
              'video', loc.filterVideos, state.currentFilter == MediaType.video,
              icon: Icons.videocam_rounded),
          const PopupMenuDivider(),
          _filterMenuItem('withTags', loc.filterWithTags,
              state.currentFilterMode == FilterMode.withTags,
              icon: Icons.label_rounded),
          _filterMenuItem('withoutTags', loc.filterWithoutTags,
              state.currentFilterMode == FilterMode.withoutTags,
              icon: Icons.label_off_rounded),
          _filterMenuItem('withAlbums', loc.filterWithAlbums,
              state.currentFilterMode == FilterMode.withAlbums,
              icon: Icons.photo_album_rounded),
          _filterMenuItem('withoutAlbums', loc.filterWithoutAlbums,
              state.currentFilterMode == FilterMode.withoutAlbums,
              icon: Icons.hide_image_rounded),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isFiltered
              ? cs.primaryContainer
              : cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 18,
              color: isFiltered ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
            if (isFiltered) ...[
              const SizedBox(width: 4),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _filterMenuItem(
      String value, String label, bool checked,
      {required IconData icon}) {
    final cs = Theme.of(context).colorScheme;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: checked ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (checked) Icon(Icons.check_rounded, size: 18, color: cs.primary),
        ],
      ),
    );
  }

  bool _isAllSelected(MediaState state) {
    if (state.filteredList.isEmpty) return false;
    return state.selectedMediaIds.containsAll(
      state.filteredList.map((m) => m.id),
    );
  }

  // ── Body ────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context, MediaState state, ColorScheme cs) {
    switch (state.status) {
      case MediaStatus.initial:
      case MediaStatus.loading:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppLocalizations.of(context).loading,
                style: AppTextStyles.body.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      case MediaStatus.error:
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
                  child:
                      Icon(Icons.cloud_off_rounded, size: 48, color: cs.error),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '${AppLocalizations.of(context).error}: ${state.errorMessage ?? AppLocalizations.of(context).unknown}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () =>
                      context.read<MediaBloc>().add(const MediaLoadAllEvent()),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(AppLocalizations.of(context).retry),
                ),
              ],
            ),
          ),
        );
      case MediaStatus.loaded:
        if (state.filteredList.isEmpty) {
          return _buildEmptyState(context, cs);
        }
        return MediaGrid(
          mediaList: state.filteredList,
          selectedIds: state.selectedMediaIds,
          isSelectionMode: state.isSelectionMode,
          crossAxisCount:
              context.watch<AppBloc>().state.settings?.gridColumns ?? 3,
        );
    }
  }

  Widget _buildEmptyState(BuildContext context, ColorScheme cs) {
    final loc = AppLocalizations.of(context);
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
              child: Icon(Icons.photo_library_outlined,
                  size: 56, color: cs.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              loc.noMedia,
              style: AppTextStyles.title.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              loc.noMediaDesc,
              style: AppTextStyles.body.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Selection bottom bar ────────────────────────────────────────
  Widget _buildSelectionBottomBar(
      BuildContext context, MediaState state, ColorScheme cs) {
    final loc = AppLocalizations.of(context);
    final selectedCount = state.selectedMediaIds.length;
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
              _selectionActionButton(
                icon: Icons.delete_outline_rounded,
                label: loc.delete,
                color: cs.error,
                enabled: selectedCount > 0,
                onTap: () => _batchDelete(context, state.selectedMediaIds),
              ),
              const SizedBox(width: AppSpacing.xs),
              _selectionActionButton(
                icon: Icons.label_outline_rounded,
                label: loc.addTag,
                color: cs.primary,
                enabled: selectedCount > 0,
                onTap: () => _batchAddTags(context, state.selectedMediaIds),
              ),
              const SizedBox(width: AppSpacing.xs),
              _selectionActionButton(
                icon: Icons.camera_alt_outlined,
                label: loc.addToAlbum,
                color: cs.tertiary,
                enabled: selectedCount > 0,
                onTap: () => _batchAddToAlbum(context, state.selectedMediaIds),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectionActionButton({
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

  // ── Import FAB ──────────────────────────────────────────────────
  Widget _buildImportFAB(BuildContext context, ColorScheme cs) {
    final loc = AppLocalizations.of(context);
    return FloatingActionButton.extended(
      onPressed: () => _showImportSheet(context, cs, loc),
      icon: const Icon(Icons.add_photo_alternate_rounded, size: 20),
      label: Text(loc.importMedia),
    );
  }

  // ── Import bottom sheet ─────────────────────────────────────────
  void _showImportSheet(
      BuildContext context, ColorScheme cs, AppLocalizations loc) {
    _openFileBrowser(context);
  }

  // ── Directory import ────────────────────────────────────────────
  Future<void> _openDirectoryBrowser(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final dirPath = await openDirectoryBrowser(context);
    if (dirPath == null || dirPath.isEmpty) return;
    if (!context.mounted) return;

    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.error)),
        );
      }
      return;
    }

    final mediaFiles = <File>[];
    final mediaExtensions = {
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'bmp',
      'heic',
      'heif',
      'mp4',
      'mkv',
      'avi',
      'mov',
      'webm',
      'flv',
      'mp3',
      'wav',
      'flac',
      'aac',
      'ogg',
      'pdf',
      'doc',
      'docx',
      'txt',
      'md',
      'epub',
    };

    try {
      await for (final entity
          in dir.list(recursive: true).where((e) => e is File)) {
        final ext = entity.path.split('.').last.toLowerCase();
        if (mediaExtensions.contains(ext)) {
          mediaFiles.add(entity as File);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.error}: $e')),
        );
      }
      return;
    }

    if (mediaFiles.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.noFilesDesc)),
        );
      }
      return;
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportProgressDialog(totalCount: mediaFiles.length),
    );

    int successCount = 0;
    int failCount = 0;
    for (final file in mediaFiles) {
      try {
        if (!await file.exists()) {
          failCount++;
          continue;
        }
        await importSingleFile(filePath: file.path);
        successCount++;
      } catch (_) {
        failCount++;
      }
    }

    if (!context.mounted) return;
    try {
      Navigator.pop(context);
    } catch (_) {}

    context.read<MediaBloc>().add(const MediaLoadAllEvent());
    _showImportResult(context, successCount, failCount);
  }

  // ── File import ─────────────────────────────────────────────────
  Future<void> _openFileBrowser(BuildContext context) async {
    List<String> filePaths;
    if (Platform.isIOS) {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isEmpty) return;
      filePaths = pickedFiles.map((f) => f.path).toList();
    } else {
      filePaths = await openFileBrowser(context);
      if (filePaths.isEmpty) return;
    }
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ImportProgressDialog(totalCount: filePaths.length),
    );

    int successCount = 0;
    int failCount = 0;
    for (final path in filePaths) {
      try {
        final file = File(path);
        if (!await file.exists()) {
          failCount++;
          continue;
        }
        await importSingleFile(filePath: path);
        successCount++;
      } catch (_) {
        failCount++;
      }
    }

    if (!context.mounted) return;
    try {
      Navigator.pop(context);
    } catch (_) {}

    context.read<MediaBloc>().add(const MediaLoadAllEvent());
    _showImportResult(context, successCount, failCount);
  }

  void _showImportResult(BuildContext context, int success, int fail) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(Icons.check_circle_rounded, size: 40, color: cs.primary),
        title: Text(loc.importComplete),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _resultRow(
                Icons.check_rounded, cs.primary, '${loc.success}: $success'),
            if (fail > 0) ...[
              const SizedBox(height: 8),
              _resultRow(Icons.error_outline_rounded, cs.error,
                  '${loc.importFailed}: $fail'),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }

  // ── Batch operations ────────────────────────────────────────────
  Future<void> _batchDelete(BuildContext context, Set<String> ids) async {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, size: 40, color: cs.error),
        title: Text(loc.confirmBatchDelete),
        content: Text(loc.confirmBatchDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final id in ids) {
      context.read<MediaBloc>().add(MediaDeleteEvent(id));
    }
    context.read<MediaBloc>().add(const MediaClearSelectionEvent());
    context.read<MediaBloc>().add(const MediaToggleSelectionModeEvent());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${loc.success} ${ids.length}')));
  }

  Future<void> _batchAddTags(BuildContext context, Set<String> mediaIds) async {
    final loc = AppLocalizations.of(context);
    try {
      final tags = await getAllTags();
      if (!context.mounted) return;
      final result = await showDialog<Set<String>>(
        context: context,
        builder: (ctx) =>
            _TagSelectionDialog(tags: tags, preselectedIds: const <String>{}),
      );
      if (result == null || result.isEmpty) return;
      int successCount = 0;
      for (final mediaId in mediaIds) {
        bool ok = true;
        for (final tagId in result) {
          try {
            await addTagToMedia(mediaId: mediaId, tagId: tagId);
          } catch (_) {
            ok = false;
          }
        }
        if (ok) successCount++;
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${loc.addTag} $successCount')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${loc.error}: $e')));
    }
  }

  Future<void> _batchAddToAlbum(
      BuildContext context, Set<String> mediaIds) async {
    final loc = AppLocalizations.of(context);
    try {
      if (!context.mounted) return;
      final selectedAlbum = await showDialog<String>(
        context: context,
        builder: (ctx) => const _AddToAlbumDialog(),
      );
      if (selectedAlbum == null) return;
      await addMediaToAlbum(
          mediaIds: mediaIds.toList(), albumId: selectedAlbum);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.addToAlbum} ${mediaIds.length}')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${loc.error}: $e')));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Helper widgets
// ═══════════════════════════════════════════════════════════════════════

class _SortMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SortMenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

class _ImportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ImportOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Material(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.subtitle),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.caption.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Album dialog ──────────────────────────────────────────────────

class _AddToAlbumDialog extends StatefulWidget {
  const _AddToAlbumDialog();

  @override
  State<_AddToAlbumDialog> createState() => _AddToAlbumDialogState();
}

class _AddToAlbumDialogState extends State<_AddToAlbumDialog> {
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
              _currentParentId == null ? loc.addToAlbum : _currentParentName,
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
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_album_outlined,
                            size: 48, color: cs.onSurfaceVariant),
                        const SizedBox(height: AppSpacing.md),
                        Text(loc.noAlbums,
                            style: AppTextStyles.body
                                .copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _albums.length,
                    itemBuilder: (ctx, index) {
                      final info = _albums[index];
                      return ListTile(
                        leading:
                            Icon(Icons.photo_album_rounded, color: cs.primary),
                        title: Text(info.album.name),
                        subtitle: Text('${info.mediaCount} ${loc.files}'),
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: cs.onSurfaceVariant),
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
            child: Text(loc.addToAlbum),
          ),
      ],
    );
  }
}

// ── Progress dialog ───────────────────────────────────────────────

class _ImportProgressDialog extends StatelessWidget {
  final int totalCount;
  const _ImportProgressDialog({required this.totalCount});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3, color: cs.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('${AppLocalizations.of(context).importing} ($totalCount)',
              style: AppTextStyles.subtitle),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppLocalizations.of(context).loading,
            style: AppTextStyles.caption.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tag selection dialog ──────────────────────────────────────────

class _TagSelectionDialog extends StatefulWidget {
  final List<Tag> tags;
  final Set<String> preselectedIds;
  const _TagSelectionDialog({required this.tags, required this.preselectedIds});
  @override
  State<_TagSelectionDialog> createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends State<_TagSelectionDialog> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.preselectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(AppLocalizations.of(context).addTag),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.tags.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.label_off_outlined,
                        size: 48, color: cs.onSurfaceVariant),
                    const SizedBox(height: AppSpacing.md),
                    Text(AppLocalizations.of(context).noTags),
                  ],
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.tags.length,
                itemBuilder: (_, i) {
                  final tag = widget.tags[i];
                  final isSelected = _selectedIds.contains(tag.id);
                  return ListTile(
                    leading: AnimatedContainer(
                      duration: AppAnimation.fast,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isSelected ? Icons.check_rounded : null,
                        size: 16,
                        color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                    ),
                    title: Text(tag.name),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIds.remove(tag.id);
                        } else {
                          _selectedIds.add(tag.id);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selectedIds),
          child: Text(AppLocalizations.of(context).confirm),
        ),
      ],
    );
  }
}
