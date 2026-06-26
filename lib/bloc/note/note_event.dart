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

/// 加载指定媒体的笔记
class NoteLoadByMediaEvent extends NoteEvent {
  final String mediaId;

  const NoteLoadByMediaEvent(this.mediaId);

  @override
  List<Object?> get props => [mediaId];
}

/// 获取单条笔记
class NoteLoadByIdEvent extends NoteEvent {
  final String noteId;

  const NoteLoadByIdEvent(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

/// 创建笔记（支持独立笔记和关联笔记）
class NoteCreateEvent extends NoteEvent {
  final String? mediaId;
  final String title;
  final String content;

  const NoteCreateEvent({
    this.mediaId,
    required this.title,
    required this.content,
  });

  @override
  List<Object?> get props => [mediaId, title, content];
}

/// 更新笔记
class NoteUpdateEvent extends NoteEvent {
  final String id;
  final String? title;
  final String? content;

  const NoteUpdateEvent({
    required this.id,
    this.title,
    this.content,
  });

  @override
  List<Object?> get props => [id, title, content];
}

/// 保存笔记（兼容旧接口）
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

/// 搜索笔记
class NoteSearchEvent extends NoteEvent {
  final String query;

  const NoteSearchEvent(this.query);

  @override
  List<Object?> get props => [query];
}
