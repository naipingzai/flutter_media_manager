import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'src/rust/frb_generated.dart';

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
      home: const HomeScreen(),
    );
  }
}

/// 主屏幕占位
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AdvanceMediaKB'),
        centerTitle: true,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'AdvanceMediaKB',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Flutter + Rust 跨平台多媒体管理',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 24),
            Text('Rust FFI 桥接已初始化'),
          ],
        ),
      ),
    );
  }
}
