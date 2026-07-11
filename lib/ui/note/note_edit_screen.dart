// Skill-14: 笔记编辑器（覆盖层）
// 内容（Markdown）+ 编辑/预览切换 + 未保存离开确认 + 删除入口

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../functionality/note/note_bloc.dart';
import 'package:flutter_media_knowledge_base/core/design_system/app_theme.dart';
import 'package:flutter_media_knowledge_base/core/design_system/components.dart';
import 'package:flutter_media_knowledge_base/core/i18n/app_localizations.dart';
import 'package:flutter_media_knowledge_base/bridge/native/api/note.dart' as note_api;

/// 笔记编辑器（覆盖层）
///
/// - 必传 [mediaId]（一对一绑定）
/// - 接受 [note] 时为编辑模式，否则为新建模式
class NoteEditScreen extends StatefulWidget {
  final String mediaId;
  final note_api.Note? note;

  const NoteEditScreen({
    super.key,
    required this.mediaId,
    this.note,
  });

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late final TextEditingController _contentController;
  bool _saving = false;
  bool _previewMode = false;

  bool get _isNew => widget.note == null;

  @override
  void initState() {
    super.initState();
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _contentController.addListener(_onChanged);
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _isDirty {
    if (_isNew) {
      return _contentController.text.isNotEmpty;
    }
    return _contentController.text != widget.note!.content;
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
    if (_saving) return;
    setState(() => _saving = true);
    final bloc = context.read<NoteBloc>();
    final loc = AppLocalizations.of(context);
    try {
      bloc.add(NoteSaveEvent(widget.mediaId, _contentController.text));
      // 等待 bloc 处理完成
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

  Future<void> _handleBack() async {
    if (await _confirmLeave() && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _contentController.removeListener(_onChanged);
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
                onPressed: _saving ? null : _onSave,
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
                // 编辑 / 预览 切换条
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc.noteContent,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    Text(
                      loc.markdownSupported,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _buildPreviewToggle(loc),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Expanded(
                  child: _previewMode
                      ? _buildContentPreview()
                      : TextField(
                          controller: _contentController,
                          decoration: InputDecoration(
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

  /// 编辑 / 预览 切换按钮
  Widget _buildPreviewToggle(AppLocalizations loc) {
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(
          value: false,
          icon: const Icon(Icons.edit, size: 16),
          label: Text(loc.edit, style: const TextStyle(fontSize: 12)),
        ),
        ButtonSegment(
          value: true,
          icon: const Icon(Icons.visibility, size: 16),
          label: Text(loc.preview, style: const TextStyle(fontSize: 12)),
        ),
      ],
      selected: {_previewMode},
      onSelectionChanged: (val) {
        setState(() => _previewMode = val.first);
      },
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity(horizontal: -3, vertical: -2),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  /// 内容预览（Markdown 渲染）
  Widget _buildContentPreview() {
    final text = _contentController.text;
    if (text.trim().isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).noteEmpty,
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: SingleChildScrollView(
        child: MarkdownBody(
          data: text,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[800]),
            h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            h2: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            code: TextStyle(
              backgroundColor: Colors.grey.shade200,
              fontFamily: 'monospace',
              fontSize: 13,
            ),
            codeblockDecoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}
