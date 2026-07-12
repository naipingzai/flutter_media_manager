import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_media_knowledge_base/bridge/native/api/settings.dart'
    as settings_api;
import 'package:flutter_media_knowledge_base/bridge/native/api/media.dart'
    as media_api;
import 'package:flutter_media_knowledge_base/bridge/native/api/import_export.dart'
    as import_export_api;
import 'package:flutter_media_knowledge_base/bridge/native/api/album.dart'
    as album_api;
import 'package:flutter_media_knowledge_base/bridge/native/api/tag.dart'
    as tag_api;
import 'package:flutter_media_knowledge_base/bridge/native/api/note.dart'
    as note_api;
import 'package:flutter_media_knowledge_base/bridge/native/api/search.dart'
    as search_api;
import 'package:flutter_media_knowledge_base/bridge/native/api/scanner.dart'
    as scanner_api;
import 'package:flutter_media_knowledge_base/bridge/native/api/import_export.dart'
    as import_export_api;

/// API 测试结果
class ApiTestResult {
  final String name;
  final bool success;
  final String? error;
  final String? data;
  final int durationMs;

  ApiTestResult({
    required this.name,
    required this.success,
    this.error,
    this.data,
    required this.durationMs,
  });
}

/// API 测试页面
class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  List<ApiTestResult> results = [];
  bool isRunning = false;
  int totalTests = 0;
  int completedTests = 0;
  bool _autoStarted = false;

  void _log(String msg) {
    // ignore: avoid_print
    print('API_TEST: $msg');
    developer.log(msg);
  }

  @override
  void initState() {
    super.initState();
    // 延迟自动运行测试，确保页面已渲染
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoStarted) {
        _autoStarted = true;
        _runAllTests();
      }
    });
  }

  Future<void> _runAllTests() async {
    setState(() {
      results = [];
      isRunning = true;
      completedTests = 0;
    });

    final tests = <Future<ApiTestResult> Function()>[
      _testSettings,
      _testMedia,
      _testAlbum,
      _testTag,
      _testNote,
      _testSearch,
      _testScanner,
      _testImportExport,
    ];

    totalTests = tests.length;

    for (final test in tests) {
      final result = await test();
      setState(() {
        results.add(result);
        completedTests++;
      });
    }

    setState(() {
      isRunning = false;
    });
  }

  Future<ApiTestResult> _runTest(
    String name,
    Future<dynamic> Function() testFn,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final data = await testFn();
      stopwatch.stop();
      _log('$name: SUCCESS (${stopwatch.elapsedMilliseconds}ms)');
      return ApiTestResult(
        name: name,
        success: true,
        data: data?.toString(),
        durationMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      _log('$name: FAILED - $e');
      return ApiTestResult(
        name: name,
        success: false,
        error: '$e\n$stackTrace',
        durationMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  // ===== 设置 API 测试 =====
  Future<ApiTestResult> _testSettings() async {
    return _runTest('Settings - GetSettings', () async {
      final settings = await settings_api.getSettings();
      return 'theme=${settings.themeMode}, grid=${settings.gridColumns}';
    });
  }

  // ===== 媒体 API 测试 =====
  Future<ApiTestResult> _testMedia() async {
    return _runTest('Media - GetAllMedia', () async {
      final media = await media_api.getAllMedia();
      return 'count=${media.length}';
    });
  }

  // ===== 相册 API 测试 =====
  Future<ApiTestResult> _testAlbum() async {
    return _runTest('Album - GetRootAlbums', () async {
      final albums = await album_api.getRootAlbums();
      return 'count=${albums.length}';
    });
  }

  // ===== 标签 API 测试 =====
  Future<ApiTestResult> _testTag() async {
    return _runTest('Tag - GetAllTags', () async {
      final tags = await tag_api.getAllTags();
      return 'count=${tags.length}';
    });
  }

  // ===== 笔记 API 测试 =====
  Future<ApiTestResult> _testNote() async {
    return _runTest('Note - GetNoteByMediaId', () async {
      // 使用一个不存在的 mediaId 测试空结果
      final note = await note_api.getNoteByMediaId(mediaId: 'nonexistent');
      return 'note=${note == null ? "null" : "exists"}';
    });
  }

  // ===== 搜索 API 测试 =====
  Future<ApiTestResult> _testSearch() async {
    return _runTest('Search - SearchFilterDefault', () async {
      final filter = search_api.SearchFilter.default_;
      return 'filter=$filter';
    });
  }

  // ===== 扫描 API 测试 =====
  Future<ApiTestResult> _testScanner() async {
    return _runTest('Scanner - GetSupportedExtensions', () async {
      final exts = import_export_api.getSupportedExtensions();
      return 'exts=$exts';
    });
  }

  // ===== 导入导出 API 测试 =====
  Future<ApiTestResult> _testImportExport() async {
    return _runTest('ImportExport - ExportToDownload', () async {
      // 测试空列表导出
      await import_export_api.exportToDownload(mediaIds: []);
      return 'void';
    });
  }

  @override
  Widget build(BuildContext context) {
    final successCount = results.where((r) => r.success).length;
    final failCount = results.where((r) => !r.success).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('API 接口测试'),
        actions: [
          if (isRunning)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('$completedTests/$totalTests'),
            ),
        ],
      ),
      body: Column(
        children: [
          // 测试控制按钮
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: isRunning ? null : _runAllTests,
                  icon: isRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(isRunning ? '测试中...' : '运行全部测试'),
                ),
                const SizedBox(width: 16),
                if (results.isNotEmpty) ...[
                  Chip(
                    label: Text('✅ $successCount'),
                    backgroundColor: Colors.green[100],
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text('❌ $failCount'),
                    backgroundColor: Colors.red[100],
                  ),
                ],
              ],
            ),
          ),

          // 测试结果列表
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 4.0,
                  ),
                  color: result.success ? Colors.green[50] : Colors.red[50],
                  child: ExpansionTile(
                    leading: Icon(
                      result.success ? Icons.check_circle : Icons.error,
                      color: result.success ? Colors.green : Colors.red,
                    ),
                    title: Text(result.name),
                    subtitle: Text(
                      '${result.durationMs}ms | ${result.success ? '成功' : '失败'}',
                      style: TextStyle(
                        color: result.success
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (result.data != null) ...[
                              const Text(
                                '返回数据:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(result.data!),
                              const SizedBox(height: 8),
                            ],
                            if (result.error != null) ...[
                              const Text(
                                '错误信息:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              Text(
                                result.error!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
