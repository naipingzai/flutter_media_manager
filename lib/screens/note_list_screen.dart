// Skill-14: 笔记列表页（覆盖层）
// 显示全部笔记，按 updatedAt 降序
// 点击打开 NoteEditScreen；长按弹出删除菜单

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/note/note_bloc.dart';
import '../core/design_system/app_theme.dart';
import '../core/design_system/components.dart';
import '../core/i18n/app_localizations.dart';
import '../core/navigation/app_router.dart';
import '../src/rust/api/note.dart' as note_api;
import 'note_edit_screen.dart';

/// 笔记列表页（覆盖层）
class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotes();
    });
  }

  void _loadNotes() {
    context.read<NoteBloc>().add(const NoteLoadAllEvent());
  }

  Future<void> _openEditor({note_api.Note? note}) async {
    final result = await AppRouter.pushOverlay<bool>(
      context,
      page: NoteEditScreen(note: note, mediaId: note?.mediaId ?? ''),
    );
    if (!mounted) return;
    if (result == true) _loadNotes();
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
      ),
      body: BlocBuilder<NoteBloc, NoteState>(
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
                  onTap: () => _openEditor(note: note),
                  onDelete: () => _confirmDelete(note),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NoteListItem extends StatelessWidget {
  final note_api.Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteListItem({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

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
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.note_outlined,
                size: 20,
                color: colorScheme.onPrimaryContainer,
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
                          _stripMarkdown(note.content).isEmpty
                              ? loc.noteEmpty
                              : _stripMarkdown(note.content),
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
                      _stripMarkdown(note.content),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  /// 剥离常见 Markdown 标记，用于列表纯文本预览
  String _stripMarkdown(String src) {
    var s = src;
    s = s.replaceAll(RegExp(r'^#{1,6}\s*'), '');
    s = s.replaceAll(RegExp(r'^\s*>\s*'), '');
    s = s.replaceAll(RegExp(r'^\s*[-*+]\s+'), '');
    s = s.replaceAll(RegExp(r'^\s*\d+\.\s+'), '');
    s = s.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    s = s.replaceAll(RegExp(r'__([^_]+)__'), r'$1');
    s = s.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    s = s.replaceAll(RegExp(r'_([^_]+)_'), r'$1');
    s = s.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    s = s.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), r'$1');
    s = s.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    s = s.replaceAll(RegExp(r'\n{2,}'), '\n');
    return s.trim();
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
