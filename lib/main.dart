import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'src/rust/frb_generated.dart';
import 'src/rust/api/settings.dart' as rust_settings;
import 'core/design_system/app_theme.dart';
import 'core/i18n/app_localizations.dart';
import 'core/navigation/app_router.dart';
import 'bloc/bloc.dart';
import 'screens/home_screen.dart';

/// 全局 Rust API 实例
late final RustLib rustLib;

void _log(String msg) {
  // 使用 print 确保在 release 模式下也能看到日志
  // ignore: avoid_print
  print('MAIN: $msg');
  developer.log(msg);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _log('Flutter binding initialized');

  // 初始化 Rust FFI 桥接
  // 注意：由于手动修改了 MediaType 枚举，跳过 codegen hash 检查
  try {
    _log('Starting RustLib.init()...');
    await RustLib.init(forceSameCodegenVersion: false);
    rustLib = RustLib.instance;
    _log('RustLib.init() completed successfully');
  } catch (e, stackTrace) {
    _log('RustLib.init() FAILED: $e');
    _log('Stack trace: $stackTrace');
    // 即使 Rust 初始化失败，也尝试运行 APP（使用降级模式）
    runApp(ErrorApp(error: 'Rust 初始化失败: $e'));
    return;
  }

  // 初始化数据库（调用 Rust 的 init_app）
  try {
    _log('Getting application documents directory...');
    final appDir = await getApplicationDocumentsDirectory();
    _log('App dir: ${appDir.path}');
    
    // 在 Android 上，尝试使用外部存储目录（更可靠）
    String targetDir = appDir.path;
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        targetDir = '${externalDir.path}/AdvanceMediaKB';
        _log('Using external dir: $targetDir');
      }
    }
    
    _log('Calling init_app()...');
    await rust_settings.initApp(appDir: targetDir);
    _log('init_app() completed successfully');
  } catch (e, stackTrace) {
    _log('init_app() FAILED: $e');
    _log('Stack trace: $stackTrace');
    runApp(ErrorApp(error: '数据库初始化失败: $e'));
    return;
  }

  developer.log('MAIN: Calling runApp()');
  runApp(const AdvanceMediaKBApp());
}

/// 错误页面（当 Rust 初始化失败时显示）
class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  '媒体知识库 启动失败',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  error,
                  style: const TextStyle(fontSize: 14, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdvanceMediaKBApp extends StatelessWidget {
  const AdvanceMediaKBApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppBloc>(
          create: (context) => AppBloc()..add(const AppInitializeEvent()),
        ),
        BlocProvider<MediaBloc>(
          create: (context) => MediaBloc(),
        ),
        BlocProvider<AlbumBloc>(
          create: (context) => AlbumBloc(),
        ),
        BlocProvider<TagBloc>(
          create: (context) => TagBloc(),
        ),
        BlocProvider<NoteBloc>(
          create: (context) => NoteBloc(),
        ),
      ],
      child: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          return MaterialApp(
            title: 'AdvanceMediaKB',
            debugShowCheckedModeBanner: false,
            locale: _resolveLocale(state.settings?.language),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh'),
              Locale('en'),
            ],
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: _mapThemeMode(state.settings?.themeMode),
            onGenerateRoute: (settings) => generateRoute(settings),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }

  ThemeMode _mapThemeMode(rust_settings.ThemeMode? mode) {
    switch (mode) {
      case rust_settings.ThemeMode.light:
        return ThemeMode.light;
      case rust_settings.ThemeMode.dark:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// 根据设置中的语言配置解析 Locale
  Locale _resolveLocale(String? language) {
    switch (language) {
      case 'zh':
        return const Locale('zh');
      case 'en':
        return const Locale('en');
      default:
        // 跟随系统语言
        final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
        if (['zh', 'en'].contains(systemLocale.languageCode)) {
          return Locale(systemLocale.languageCode);
        }
        return const Locale('zh');
    }
  }
}
