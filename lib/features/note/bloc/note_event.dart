part of 'note_bloc.dart';

abstract class NoteEvent extends Equatable {
  const NoteEvent();

  @override
  List<Object?> get props => [];
}

/// 加载所有笔记
class NoteLoadAllEvent extends NoteEvent {
  const NoteLoadAllEvent();
}

/// 加载指定媒体的笔记（一对一）
class NoteLoadByMediaEvent extends NoteEvent {
  final String mediaId;

  const NoteLoadByMediaEvent(this.mediaId);

  @override
  List<Object?> get props => [mediaId];
}

/// 保存笔记（upsert：一对一语义，存在则更新 content，不存在则新建）
class NoteSaveEvent extends NoteEvent {
  final String mediaId;
  final String content;

  const NoteSaveEvent(this.mediaId, this.content);

  @override
  List<Object?> get props => [mediaId, content];
}

/// 删除笔记
class NoteDeleteEvent extends NoteEvent {
  final String noteId;

  const NoteDeleteEvent(this.noteId);

  @override
  List<Object?> get props => [noteId];
}
