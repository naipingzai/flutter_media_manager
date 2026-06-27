// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:advance_media_kb/src/rust/api/settings.dart';
import 'package:advance_media_kb/src/rust/frb_generated.dart';
import 'package:logger/logger.dart';

part 'app_event.dart';
part 'app_state.dart';

final _logger = Logger();

/// 应用级 Bloc，管理全局状态（主题、设置、初始化等）
class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc() : super(const AppState()) {
    on<AppInitializeEvent>(_onInitialize);
    on<AppThemeChangedEvent>(_onThemeChanged);
    on<AppSettingsUpdatedEvent>(_onSettingsUpdated);
    on<AppLanguageChangedEvent>(_onLanguageChanged);
    on<AppNavigationChangedEvent>(_onNavigationChanged);
  }

  Future<void> _onInitialize(
    AppInitializeEvent event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(status: AppStatus.initializing));
    try {
      // 加载应用设置
      final settings = await RustLib.instance.api.crateApiSettingsGetSettings();
      emit(state.copyWith(
        status: AppStatus.ready,
        settings: settings,
        currentLanguage: settings.language,
      ));
    } catch (e) {
      _logger.e('应用初始化失败: $e');
      emit(state.copyWith(
        status: AppStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onThemeChanged(
    AppThemeChangedEvent event,
    Emitter<AppState> emit,
  ) async {
    if (state.settings == null) return;
    final newSettings = AppSettings(
      themeMode: event.themeMode,
      gridColumns: state.settings!.gridColumns,
      albumGridColumns: state.settings!.albumGridColumns,
      showContentPreviews: state.settings!.showContentPreviews,
      thumbnailQuality: state.settings!.thumbnailQuality,
      language: state.settings!.language,
      dynamicColor: state.settings!.dynamicColor,
      lastScanPath: state.settings!.lastScanPath,
    );
    try {
      await RustLib.instance.api.crateApiSettingsSaveSettings(settings: newSettings);
      emit(state.copyWith(settings: newSettings));
    } catch (e) {
      _logger.e('保存主题设置失败: $e');
    }
  }

  Future<void> _onSettingsUpdated(
    AppSettingsUpdatedEvent event,
    Emitter<AppState> emit,
  ) async {
    try {
      await RustLib.instance.api.crateApiSettingsSaveSettings(settings: event.settings);
      emit(state.copyWith(
        settings: event.settings,
        currentLanguage: event.settings.language,
      ));
    } catch (e) {
      _logger.e('保存设置失败: $e');
    }
  }

  Future<void> _onLanguageChanged(
    AppLanguageChangedEvent event,
    Emitter<AppState> emit,
  ) async {
    if (state.settings == null) return;
    final newSettings = AppSettings(
      themeMode: state.settings!.themeMode,
      gridColumns: state.settings!.gridColumns,
      albumGridColumns: state.settings!.albumGridColumns,
      showContentPreviews: state.settings!.showContentPreviews,
      thumbnailQuality: state.settings!.thumbnailQuality,
      language: event.language,
      dynamicColor: state.settings!.dynamicColor,
      lastScanPath: state.settings!.lastScanPath,
    );
    try {
      await RustLib.instance.api.crateApiSettingsSaveSettings(settings: newSettings);
      emit(state.copyWith(
        settings: newSettings,
        currentLanguage: event.language,
      ));
    } catch (e) {
      _logger.e('保存语言设置失败: $e');
    }
  }

  void _onNavigationChanged(
    AppNavigationChangedEvent event,
    Emitter<AppState> emit,
  ) {
    emit(state.copyWith(currentTabIndex: event.tabIndex));
  }
}
