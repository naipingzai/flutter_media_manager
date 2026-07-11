import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'bridge/native/native_library.dart';
import 'bridge/native/api/settings.dart' as native_api;
import 'core/design_system/app_theme.dart';
import 'core/i18n/app_localizations.dart';
import 'core/navigation/app_router.dart';
import 'functionality/home/app_bloc.dart';
import 'ui/home/home_screen.dart';
import 'functionality/media/media_bloc.dart';
import 'functionality/album/album_bloc.dart';
import 'functionality/tag/tag_bloc.dart';
import 'functionality/note/note_bloc.dart';

late final NativeLibrary nativeLib;

void _log(String msg) {
  // ignore: avoid_print
  print('MAIN: $msg');
  developer.log(msg);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _log('Flutter binding initialized');

  try {
    _log('Initializing native library...');
    nativeLib = NativeLibrary.instance;
    _log('Getting application documents directory...');
    final appDir = await getApplicationDocumentsDirectory();
    _log('App dir: ${appDir.path}');

    String targetDir = appDir.path;
    if (Platform.isAndroid) {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        targetDir = '${externalDir.path}/AdvanceMediaKB';
        _log('Using external dir: $targetDir');
      }
    }

    _log('Calling native init...');
    final result = nativeLib.init(targetDir);
    if (result != 0) {
      throw Exception('Native init failed with code: $result');
    }
    _log('Native init completed successfully');
  } catch (e, stackTrace) {
    _log('Native init FAILED: $e');
    _log('Stack trace: $stackTrace');
    runApp(ErrorApp(error: '初始化失败: $e'));
    return;
  }

  developer.log('MAIN: Calling runApp()');
  runApp(const AdvanceMediaKBApp());
}

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
            child: SingleChildScrollView(
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
                  SelectableText(
                    error,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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

  ThemeMode _mapThemeMode(native_api.ThemeMode? mode) {
    switch (mode) {
      case native_api.ThemeMode.light:
        return ThemeMode.light;
      case native_api.ThemeMode.dark:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Locale _resolveLocale(String? language) {
    switch (language) {
      case 'zh':
        return const Locale('zh');
      case 'en':
        return const Locale('en');
      default:
        final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
        if (['zh', 'en'].contains(systemLocale.languageCode)) {
          return Locale(systemLocale.languageCode);
        }
        return const Locale('zh');
    }
  }
}
