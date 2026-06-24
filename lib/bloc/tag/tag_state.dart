part of 'tag_bloc.dart';

/// 标签状态枚举
enum TagStatus {
  initial,
  loading,
  loaded,
  error,
}

/// TagBloc 状态
class TagState extends Equatable {
  final TagStatus status;
  final List<Tag> tags;
  final List<TagWithInfo> tagsWithInfo;
  final List<MediaItem> filteredMedia;
  final List<Tag> mediaTags;
  final String? currentTagId;
  final String? currentParentId;
  final String? errorMessage;

  const TagState({
    this.status = TagStatus.initial,
    this.tags = const [],
    this.tagsWithInfo = const [],
    this.filteredMedia = const [],
    this.mediaTags = const [],
    this.currentTagId,
    this.currentParentId,
    this.errorMessage,
  });

  TagState copyWith({
    TagStatus? status,
    List<Tag>? tags,
    List<TagWithInfo>? tagsWithInfo,
    List<MediaItem>? filteredMedia,
    List<Tag>? mediaTags,
    String? currentTagId,
    String? currentParentId,
    String? errorMessage,
  }) {
    return TagState(
      status: status ?? this.status,
      tags: tags ?? this.tags,
      tagsWithInfo: tagsWithInfo ?? this.tagsWithInfo,
      filteredMedia: filteredMedia ?? this.filteredMedia,
      mediaTags: mediaTags ?? this.mediaTags,
      currentTagId: currentTagId,
      currentParentId: currentParentId,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tags,
        tagsWithInfo,
        filteredMedia,
        mediaTags,
        currentTagId,
        currentParentId,
        errorMessage,
      ];
}
