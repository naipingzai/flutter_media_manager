part of 'note_bloc.dart';

/// 笔记加载状态
enum NoteStatus { initial, loading, loaded, error }

class NoteState extends Equatable {
  /// 当前加载的笔记列表（按 updatedAt DESC）
  final List<Note> notes;

  /// 加载状态
  final NoteStatus status;

  /// 错误信息
  final String? errorMessage;

  const NoteState({
    this.notes = const [],
    this.status = NoteStatus.initial,
    this.errorMessage,
  });

  NoteState copyWith({
    List<Note>? notes,
    NoteStatus? status,
    String? errorMessage,
  }) {
    return NoteState(
      notes: notes ?? this.notes,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [notes, status, errorMessage];
}
