// Skill-14: 笔记编辑器（覆盖层）
// 标题（单行）+ 内容（多行）+ 关联媒体显示 + 未保存离开确认 + 删除入口

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/note/note_bloc.dart';
import '../core/design_system/app_theme.dart';
import '../core/design_system/components.dart';
import '../core/i18n/app_localizations.dart';
import '../src/rust/api/note.dart' as note_api;
import '../src/rust/api/media.dart' as media_api;

/// 笔记编辑器（覆盖层）
///
/// 接受 [note] 时为编辑模式，否则为新建模式。
/// 可选 [mediaId] 用于新建时直接关联到媒体。
class NoteEditScreen extends StatefulWidget {
  final note_api.Note? note;
  final String? mediaId;

  const NoteEditScreen({super.key, this.note, this.mediaId});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late String? _mediaId;
  String? _mediaFileName;
  bool _saving = false;
  bool _loadingMediaName = false;

  bool get _isNew => widget.note == null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _mediaId = widget.note?.mediaId ?? widget.mediaId;
    _loadMediaNameIfNeeded();
    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
  }

  Future<void> _loadMediaNameIfNeeded() async {
    if (_mediaId == null) return;
    setState(() => _loadingMediaName = true);
    try {
      final m = await media_api.getMediaById(id: _mediaId!);
      if (m != null && mounted) {
        setState(() => _mediaFileName = m.originalName);
      }
    } catch (_) {
      // 媒体可能已删除
    } finally {
      if (mounted) setState(() => _loadingMediaName = false);
    }
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _isDirty {
    if (_isNew) {
      return _titleController.text.trim().isNotEmpty ||
          _contentController.text.trim().isNotEmpty;
    }
    return _titleController.text != widget.note!.title ||
        _contentController.text != widget.note!.content;
  }

  bool get _canSave {
    return _titleController.text.trim().isNotEmpty ||
        _contentController.text.trim().isNotEmpty;
  }

  Future<bool> _confirmLeave() async {
    if (!_isDirty) return true;
    final loc = AppLocalizations.of(context);
    final result = await UIHelper.showConfirmDialog(
      context,
      title: loc.unsavedChanges,
      message: loc.unsavedChangesDesc,
      confirmLabel: loc.leaveEditor,
      cancelLabel: loc.continueEditing,
    );
    return result == true;
  }

  Future<void> _onSave() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final bloc = context.read<NoteBloc>();
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final loc = AppLocalizations.of(context);
    try {
      if (_isNew) {
        bloc.add(NoteCreateEvent(
          mediaId: _mediaId,
          title: title,
          content: content,
        ));
      } else {
        bloc.add(NoteUpdateEvent(
          id: widget.note!.id,
          title: title,
          content: content,
        ));
      }
      // 等待 bloc 处理完成（短延迟让 stream 进入 sink）
      await Future.delayed(const Duration(milliseconds: 250));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        UIHelper.showSnackBar(context, '${loc.saveFailed}: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onDelete() async {
    final loc = AppLocalizations.of(context);
    final ok = await UIHelper.showConfirmDialog(
      context,
      title: loc.deleteNote,
      message: loc.confirmDeleteNote,
      confirmLabel: loc.delete,
      cancelLabel: loc.cancel,
    );
    if (ok == true && mounted) {
      context.read<NoteBloc>().add(NoteDeleteEvent(widget.note!.id));
      Navigator.of(context).pop(true);
    }
  }

  void _onUnlinkMedia() {
    setState(() {
      _mediaId = null;
      _mediaFileName = null;
    });
  }

  Future<void> _handleBack() async {
    if (await _confirmLeave() && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onChanged);
    _contentController.removeListener(_onChanged);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: Text(_isNew ? loc.createNote : loc.editNote),
          actions: [
            if (!_isNew)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: loc.deleteNote,
                onPressed: _saving ? null : _onDelete,
              ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: TextButton.icon(
                onPressed: (_saving || !_canSave) ? null : _onSave,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(loc.save),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_mediaId != null) ...[
                  _buildLinkedMediaRow(loc, colorScheme),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: loc.noteTitle,
                    hintText: loc.noteTitleHint,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.title),
                  ),
                  textInputAction: TextInputAction.next,
                  maxLines: 1,
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    decoration: InputDecoration(
                      labelText: loc.noteContent,
                      hintText: loc.noteContentHint,
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                  ),
                ),
                if (_isDirty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Icon(Icons.edit_note,
                          size: 16, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        loc.unsavedChanges,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colorScheme.primary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedMediaRow(AppLocalizations loc, ColorScheme colorScheme) {
    final displayName = _loadingMediaName
        ? '...'
        : (_mediaFileName ?? '${loc.fileName}: $_mediaId');
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colorScheme.primary.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.link, size: 18, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${loc.linkedMedia}: $displayName',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: loc.noteUnlinkFromMedia,
            visualDensity: VisualDensity.compact,
            onPressed: _onUnlinkMedia,
          ),
        ],
      ),
    );
  }
}
