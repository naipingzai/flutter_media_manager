import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'src/rust/frb_generated.dart';
import 'bloc/bloc.dart';
import 'screens/home_screen.dart';

/// 全局 Rust API 实例
late final RustLib rustLib;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Rust FFI 桥接
  await RustLib.init();
  rustLib = RustLib.instance;

  runApp(const AdvanceMediaKBApp());
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
      ],
      child: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          return MaterialApp(
            title: 'AdvanceMediaKB',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6750A4),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6750A4),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: _mapThemeMode(state.settings?.themeMode),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }

  ThemeMode _mapThemeMode(ThemeMode? mode) {
    switch (mode) {
      case ThemeMode.light:
        return ThemeMode.light;
      case ThemeMode.dark:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
