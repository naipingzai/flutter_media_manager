part of 'app_bloc.dart';

/// 应用状态枚举
enum AppStatus {
  initial,
  initializing,
  ready,
  error,
}

/// AppBloc 状态
class AppState extends Equatable {
  final AppStatus status;
  final AppSettings? settings;
  final String currentLanguage;
  final int currentTabIndex;
  final String? errorMessage;

  const AppState({
    this.status = AppStatus.initial,
    this.settings,
    this.currentLanguage = 'zh_CN',
    this.currentTabIndex = 0,
    this.errorMessage,
  });

  AppState copyWith({
    AppStatus? status,
    AppSettings? settings,
    String? currentLanguage,
    int? currentTabIndex,
    String? errorMessage,
  }) {
    return AppState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      currentLanguage: currentLanguage ?? this.currentLanguage,
      currentTabIndex: currentTabIndex ?? this.currentTabIndex,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        settings,
        currentLanguage,
        currentTabIndex,
        errorMessage,
      ];
}
