part of 'note_bloc.dart';

enum NoteStatus { initial, loading, loaded, error }

class NoteState extends Equatable {
  final NoteStatus status;
  final List<Note> notes;
  final Note? currentNote;
  final List<Note> searchResults;
  final String? errorMessage;

  const NoteState({
    this.status = NoteStatus.initial,
    this.notes = const [],
    this.currentNote,
    this.searchResults = const [],
    this.errorMessage,
  });

  NoteState copyWith({
    NoteStatus? status,
    List<Note>? notes,
    Note? currentNote,
    List<Note>? searchResults,
    String? errorMessage,
  }) {
    return NoteState(
      status: status ?? this.status,
      notes: notes ?? this.notes,
      currentNote: currentNote ?? this.currentNote,
      searchResults: searchResults ?? this.searchResults,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        notes,
        currentNote,
        searchResults,
        errorMessage,
      ];
}
