// Skill-14: 笔记独立列表页（覆盖层）
// 显示全部笔记（独立 + 关联），按 updatedAt 降序
// 点击打开 NoteEditScreen；长按弹出删除菜单；右上角 FAB 新建笔记

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/note/note_bloc.dart';
import '../core/design_system/app_theme.dart';
import '../core/design_system/components.dart';
import '../core/i18n/app_localizations.dart';
import '../core/navigation/app_router.dart';
import '../src/rust/api/note.dart' as note_api;
import '../src/rust/api/media.dart' as media_api;
import 'note_edit_screen.dart';

/// 笔记独立列表页（覆盖层）
class NoteListScreen extends StatefulWidget {
  /// 可选：进入时只显示指定 mediaId 关联的笔记
  final String? mediaId;

  const NoteListScreen({super.key, this.mediaId});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  /// 笔记-媒体文件名映射（仅用于显示关联笔记的媒体名）
  final Map<String, String> _mediaFileNames = {};
  bool _loadingMediaNames = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotes();
    });
  }

  void _loadNotes() {
    final bloc = context.read<NoteBloc>();
    if (widget.mediaId != null) {
      bloc.add(NoteLoadByMediaEvent(widget.mediaId!));
    } else {
      bloc.add(const NoteLoadAllEvent());
    }
  }

  /// 加载所有引用过的媒体的文件名（仅一次）
  Future<void> _loadMediaNamesIfNeeded(List<note_api.Note> notes) async {
    if (_loadingMediaNames) return;
    final mediaIds = notes
        .map((n) => n.mediaId)
        .whereType<String>()
        .where((id) => !_mediaFileNames.containsKey(id))
        .toSet();
    if (mediaIds.isEmpty) return;

    setState(() => _loadingMediaNames = true);
    try {
      for (final id in mediaIds) {
        try {
          final m = await media_api.getMediaById(id: id);
          if (m != null && mounted) {
            setState(() {
              _mediaFileNames[id] = m.originalName;
            });
          }
        } catch (_) {
          // 媒体可能已被删除，忽略
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMediaNames = false);
      }
    }
  }

  Future<void> _openEditor({note_api.Note? note}) async {
    final result = await AppRouter.pushOverlay<bool>(
      context,
      page: NoteEditScreen(note: note, mediaId: note?.mediaId),
    );
    if (result == true && mounted) {
      _loadNotes();
    }
  }

  Future<void> _confirmDelete(note_api.Note note) async {
    final loc = AppLocalizations.of(context);
    final ok = await UIHelper.showConfirmDialog(
      context,
      title: loc.deleteNote,
      message: loc.confirmDeleteNote,
      confirmLabel: loc.delete,
      cancelLabel: loc.cancel,
    );
    if (ok == true && mounted) {
      context.read<NoteBloc>().add(NoteDeleteEvent(note.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(loc.notes),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: loc.search,
            onPressed: () {
              // 进入搜索状态（简单实现：聚焦时键盘弹出，使用 AlertDialog 临时方案）
              showSearch(
                context: context,
                delegate: _NoteSearchDelegate(onResultTap: (n) {
                  Navigator.of(context).pop();
                  _openEditor(note: n);
                }),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<NoteBloc, NoteState>(
        listener: (context, state) {
          if (state.notes.isNotEmpty) {
            _loadMediaNamesIfNeeded(state.notes);
          }
        },
        builder: (context, state) {
          if (state.status == NoteStatus.loading && state.notes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.notes.isEmpty) {
            return EmptyState(
              icon: Icons.note_alt_outlined,
              title: loc.noNotes,
              subtitle: loc.noNotesDesc,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _loadNotes(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.notes.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final note = state.notes[i];
                return _NoteListItem(
                  note: note,
                  mediaFileName: note.mediaId == null
                      ? null
                      : _mediaFileNames[note.mediaId!],
                  onTap: () => _openEditor(note: note),
                  onDelete: () => _confirmDelete(note),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: loc.createNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NoteListItem extends StatelessWidget {
  final note_api.Note note;
  final String? mediaFileName;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteListItem({
    required this.note,
    required this.mediaFileName,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isLinked = note.mediaId != null;

    return InkWell(
      onTap: onTap,
      onLongPress: () async {
        final action = await showModalBottomSheet<String>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(loc.deleteNote),
                  onTap: () => Navigator.of(ctx).pop('delete'),
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: Text(loc.cancel),
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        );
        if (action == 'delete') onDelete();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: isLinked
                  ? colorScheme.primaryContainer
                  : colorScheme.secondaryContainer,
              child: Icon(
                isLinked ? Icons.link : Icons.note_outlined,
                size: 20,
                color: isLinked
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title.isEmpty
                              ? loc.notes
                              : note.title,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatRelative(note.updatedAt),
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      note.content,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (isLinked) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            mediaFileName ?? '${loc.fileName}: ${note.mediaId}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: colorScheme.primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 将 i64 时间戳格式化为 "YYYY-MM-DD HH:MM"（避免引入 intl）
  String _formatRelative(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

/// 笔记搜索代理
class _NoteSearchDelegate extends SearchDelegate<note_api.Note?> {
  final void Function(note_api.Note) onResultTap;

  _NoteSearchDelegate({required this.onResultTap});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchList(context);

  Widget _buildSearchList(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (query.trim().isEmpty) {
      return Center(child: Text(loc.searchHint));
    }
    return FutureBuilder<List<note_api.Note>>(
      future: note_api.searchNotes(query: query),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.isEmpty) {
          return EmptyState(
            icon: Icons.search_off,
            title: loc.noResults,
            subtitle: loc.noResultsDesc,
          );
        }
        final results = snap.data!;
        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final n = results[i];
            return ListTile(
              leading: const Icon(Icons.note),
              title: Text(n.title.isEmpty ? loc.notes : n.title),
              subtitle: Text(
                n.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onResultTap(n),
            );
          },
        );
      },
    );
  }
}
