import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../bloc/bloc.dart';
import '../core/i18n/app_localizations.dart';
import '../src/rust/api/settings.dart' as rust_settings;
import '../src/rust/api/import_export.dart' as rust_import_export;
import '../src/rust/api/media.dart' as media_api;
import 'api_test_screen.dart';

/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  rust_settings.StorageStats? _stats;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final stats = await rust_settings.getStorageStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // 忽略加载失败
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).settings),
        centerTitle: true,
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          final settings = state.settings;
          final loc = AppLocalizations.of(context);
          if (settings == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: [
              _SectionHeader(title: AppLocalizations.of(context).themeMode),
              ListTile(
                leading: const Icon(Icons.palette),
                title: Text(AppLocalizations.of(context).themeMode),
                subtitle: Text(_themeModeLabel(settings.themeMode)),
                onTap: () => _showThemeModeDialog(context, settings),
              ),
              // 动态颜色 (Android 12+)
              SwitchListTile(
                secondary: const Icon(Icons.color_lens_outlined),
                title: Text(AppLocalizations.of(context).dynamicColor),
                subtitle: Text(AppLocalizations.of(context).dynamicColorDesc),
                value: settings.dynamicColor != 0,
                onChanged: (val) {
                  final updated = rust_settings.AppSettings(
                    themeMode: settings.themeMode,
                    gridColumns: settings.gridColumns,
                    albumGridColumns: settings.albumGridColumns,
                    showContentPreviews: settings.showContentPreviews,
                    thumbnailQuality: settings.thumbnailQuality,
                    language: settings.language,
                    dynamicColor: val ? 1 : 0,
                    lastScanPath: settings.lastScanPath,
                  );
                  context.read<AppBloc>().add(AppSettingsUpdatedEvent(updated));
                },
              ),
              ListTile(
                leading: const Icon(Icons.grid_on),
                title: Text(AppLocalizations.of(context).mediaGridColumns),
                subtitle: Text('${settings.gridColumns} ${AppLocalizations.of(context).columns}'),
                onTap: () => _showGridColumnsDialog(context, settings),
              ),
              ListTile(
                leading: const Icon(Icons.grid_view),
                title: Text(AppLocalizations.of(context).albumGridColumns),
                subtitle: Text('${settings.albumGridColumns} ${AppLocalizations.of(context).columns}'),
                onTap: () => _showAlbumGridColumnsDialog(context, settings),
              ),
              // 语言设置
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(AppLocalizations.of(context).language),
                subtitle: Text(_languageLabel(settings.language)),
                onTap: () => _showLanguageDialog(context, settings),
              ),
              const Divider(),
              _SectionHeader(title: AppLocalizations.of(context).display),
              SwitchListTile(
                secondary: const Icon(Icons.preview),
                title: Text(loc.contentPreview),
                subtitle: Text(loc.contentPreviewDesc),
                value: settings.showContentPreviews != 0,
                onChanged: (val) {
                  final updated = rust_settings.AppSettings(
                    themeMode: settings.themeMode,
                    gridColumns: settings.gridColumns,
                    albumGridColumns: settings.albumGridColumns,
                    showContentPreviews: val ? 1 : 0,
                    thumbnailQuality: settings.thumbnailQuality,
                    language: settings.language,
                    dynamicColor: settings.dynamicColor,
                    lastScanPath: settings.lastScanPath,
                  );
                  context.read<AppBloc>().add(
                        AppSettingsUpdatedEvent(updated),
                      );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_size_select_small),
                title: Text(loc.thumbnailQualityLabel),
                subtitle: Text('${settings.thumbnailQuality}%'),
                onTap: () => _showThumbnailQualityDialog(context, settings),
              ),
              const Divider(),
              _SectionHeader(title: loc.storageSection),
              if (_loadingStats)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else ...[
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: Text(loc.storageStats),
                  subtitle: Text(_buildStatsText()),
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services),
                  title: Text(loc.clearThumbnailCache),
                  subtitle: Text(_stats != null
                      ? _formatSize(_stats!.thumbnailCacheSize)
                      : loc.clickToClearUnreferenced),
                  onTap: () => _clearThumbnailCache(context),
                ),
              ],
              const Divider(),
              _SectionHeader(title: loc.dataSection),
              ListTile(
                leading: const Icon(Icons.import_export),
                title: Text(loc.importDb),
                subtitle: Text(loc.importDbDesc),
                onTap: () => _showImportDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.folder_zip),
                title: Text(loc.importZip),
                subtitle: Text(loc.importZipDesc),
                onTap: () => _showImportZipDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.backup),
                title: Text(loc.exportDb),
                onTap: () => _showExportDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.archive),
                title: Text(loc.exportZip),
                subtitle: Text(loc.exportZipDesc),
                onTap: () => _showExportZipDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.find_in_page),
                title: Text(loc.findUnreferenced),
                subtitle: Text(loc.findUnreferencedDesc),
                onTap: () => _showFindUnreferencedDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: Text(
                  loc.clearAllData,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () => _showClearDataConfirmDialog(context),
              ),
              const Divider(),
              _SectionHeader(title: loc.devSection),
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: Text(loc.apiTest),
                subtitle: Text(loc.apiTestDesc),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ApiTestScreen(),
                    ),
                  );
                },
              ),
              const Divider(),
              _SectionHeader(title: loc.aboutSection),
              ListTile(
                leading: const Icon(Icons.info),
                title: Text(loc.versionLabel),
                subtitle: const Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(loc.techStack),
                subtitle: Text(loc.techStackValue),
              ),
            ],
          );
        },
      ),
    );
  }

  String _buildStatsText() {
    if (_stats == null) return '点击刷新';
    final s = _stats!;
    return '${s.totalMediaCount} 个文件 · 总计 ${_formatSize(s.totalSize)} · 数据库 ${_formatSize(s.databaseSize)}';
  }

  String _formatSize(dynamic size) {
    final bytes = size is int ? size : (size as int);
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _clearThumbnailCache(BuildContext context) async {
    try {
      final deleted = await rust_settings.clearThumbnailCache();
      await _loadStats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清理 $deleted 个缩略图文件')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清理失败: $e')),
      );
    }
  }

  String _themeModeLabel(rust_settings.ThemeMode mode) {
    switch (mode) {
      case rust_settings.ThemeMode.light:
        return '浅色';
      case rust_settings.ThemeMode.dark:
        return '深色';
      default:
        return '跟随系统';
    }
  }

  String _languageLabel(String lang) {
    switch (lang) {
      case 'zh':
        return '中文';
      case 'en':
        return 'English';
      default:
        return '跟随系统';
    }
  }

  void _showLanguageDialog(
      BuildContext context, rust_settings.AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择语言'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('跟随系统'),
                value: 'system',
                groupValue: settings.language,
                onChanged: (value) {
                  if (value != null) {
                    final newSettings = rust_settings.AppSettings(
                      themeMode: settings.themeMode,
                      gridColumns: settings.gridColumns,
                      albumGridColumns: settings.albumGridColumns,
                      showContentPreviews: settings.showContentPreviews,
                      thumbnailQuality: settings.thumbnailQuality,
                      language: value,
                      dynamicColor: settings.dynamicColor,
                      lastScanPath: settings.lastScanPath,
                    );
                    context
                        .read<AppBloc>()
                        .add(AppSettingsUpdatedEvent(newSettings));
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('中文'),
                value: 'zh',
                groupValue: settings.language,
                onChanged: (value) {
                  if (value != null) {
                    final newSettings = rust_settings.AppSettings(
                      themeMode: settings.themeMode,
                      gridColumns: settings.gridColumns,
                      albumGridColumns: settings.albumGridColumns,
                      showContentPreviews: settings.showContentPreviews,
                      thumbnailQuality: settings.thumbnailQuality,
                      language: value,
                      dynamicColor: settings.dynamicColor,
                      lastScanPath: settings.lastScanPath,
                    );
                    context
                        .read<AppBloc>()
                        .add(AppSettingsUpdatedEvent(newSettings));
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<String>(
                title: const Text('English'),
                value: 'en',
                groupValue: settings.language,
                onChanged: (value) {
                  if (value != null) {
                    final newSettings = rust_settings.AppSettings(
                      themeMode: settings.themeMode,
                      gridColumns: settings.gridColumns,
                      albumGridColumns: settings.albumGridColumns,
                      showContentPreviews: settings.showContentPreviews,
                      thumbnailQuality: settings.thumbnailQuality,
                      language: value,
                      dynamicColor: settings.dynamicColor,
                      lastScanPath: settings.lastScanPath,
                    );
                    context
                        .read<AppBloc>()
                        .add(AppSettingsUpdatedEvent(newSettings));
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showThemeModeDialog(
      BuildContext context, rust_settings.AppSettings settings) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择主题模式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<rust_settings.ThemeMode>(
                title: const Text('跟随系统'),
                value: rust_settings.ThemeMode.system,
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    context
                        .read<AppBloc>()
                        .add(AppThemeChangedEvent(value));
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<rust_settings.ThemeMode>(
                title: const Text('浅色'),
                value: rust_settings.ThemeMode.light,
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    context
                        .read<AppBloc>()
                        .add(AppThemeChangedEvent(value));
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<rust_settings.ThemeMode>(
                title: const Text('深色'),
                value: rust_settings.ThemeMode.dark,
                groupValue: settings.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    context
                        .read<AppBloc>()
                        .add(AppThemeChangedEvent(value));
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGridColumnsDialog(
      BuildContext context, rust_settings.AppSettings settings) {
    final columns = [2, 3, 4, 5];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择网格列数'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: columns.map((count) {
              return RadioListTile<int>(
                title: Text('$count 列'),
                value: count,
                groupValue: settings.gridColumns,
                onChanged: (value) {
                  if (value != null) {
                    final newSettings = rust_settings.AppSettings(
                      themeMode: settings.themeMode,
                      gridColumns: value,
                      albumGridColumns: settings.albumGridColumns,
                      showContentPreviews: settings.showContentPreviews,
                      thumbnailQuality: settings.thumbnailQuality,
                      language: settings.language,
                      dynamicColor: settings.dynamicColor,
                      lastScanPath: settings.lastScanPath,
                    );
                    context
                        .read<AppBloc>()
                        .add(AppSettingsUpdatedEvent(newSettings));
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showAlbumGridColumnsDialog(
      BuildContext context, rust_settings.AppSettings settings) {
    final columns = [2, 3, 4, 5];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择相册网格列数'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: columns.map((count) {
              return RadioListTile<int>(
                title: Text('$count 列'),
                value: count,
                groupValue: settings.albumGridColumns,
                onChanged: (value) {
                  if (value != null) {
                    final newSettings = rust_settings.AppSettings(
                      themeMode: settings.themeMode,
                      gridColumns: settings.gridColumns,
                      albumGridColumns: value,
                      showContentPreviews: settings.showContentPreviews,
                      thumbnailQuality: settings.thumbnailQuality,
                      language: settings.language,
                      dynamicColor: settings.dynamicColor,
                      lastScanPath: settings.lastScanPath,
                    );
                    context
                        .read<AppBloc>()
                        .add(AppSettingsUpdatedEvent(newSettings));
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showThumbnailQualityDialog(
      BuildContext context, rust_settings.AppSettings settings) {
    final qualities = [50, 60, 70, 80, 85, 90, 95, 100];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('缩略图质量'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: qualities.map((q) {
              return RadioListTile<int>(
                title: Text('$q%'),
                value: q,
                groupValue: settings.thumbnailQuality,
                onChanged: (value) {
                  if (value != null) {
                    final newSettings = rust_settings.AppSettings(
                      themeMode: settings.themeMode,
                      gridColumns: settings.gridColumns,
                      albumGridColumns: settings.albumGridColumns,
                      showContentPreviews: settings.showContentPreviews,
                      thumbnailQuality: value,
                      language: settings.language,
                      dynamicColor: settings.dynamicColor,
                      lastScanPath: settings.lastScanPath,
                    );
                    context
                        .read<AppBloc>()
                        .add(AppSettingsUpdatedEvent(newSettings));
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('导入数据'),
          content: const Text(
            '导入功能将替换当前数据库。请确保已备份重要数据。\n\n'
            '选择之前导出的数据库文件（.db）进行导入。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.any,
                  allowedExtensions: ['db', 'sqlite', 'sqlite3'],
                );
                if (result != null && result.files.single.path != null) {
                  final path = result.files.single.path!;
                  try {
                    await rust_settings.importData(importPath: path);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('数据导入成功')),
                      );
                      context
                          .read<AppBloc>()
                          .add(const AppInitializeEvent());
                      context
                          .read<MediaBloc>()
                          .add(const MediaLoadAllEvent());
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('导入失败: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('选择文件'),
            ),
          ],
        );
      },
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('导出数据'),
          content: const Text(
            '导出将创建当前数据库的备份副本。\n\n'
            '请选择保存位置。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.getDirectoryPath();
                if (result != null) {
                  final exportPath =
                      '$result/advance_media_kb_backup.db';
                  try {
                    await rust_settings.exportData(
                        exportPath: exportPath);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已导出到: $exportPath')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('导出失败: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('导出'),
            ),
          ],
        );
      },
    );
  }

  void _showClearDataConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认清除'),
          content: const Text(
            '此操作将删除所有媒体、相册、标签和笔记数据，不可恢复。是否继续？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _clearAllData(context);
              },
              child: const Text('清除'),
            ),
          ],
        );
      },
    );
  }

  void _showImportZipDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入 ZIP 包'),
        content: const Text(
          '选择包含数据库和媒体文件的 ZIP 备份包进行导入。\n\n'
          '支持的冲突策略：\n'
          '- 跳过：跳过已存在的文件\n'
          '- 替换：覆盖已存在的文件\n'
          '- 重命名：将已存在文件重命名为 .backup',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await FilePicker.platform.pickFiles(
                type: FileType.any,
                allowedExtensions: ['zip'],
              );
              if (result != null && result.files.single.path != null) {
                final path = result.files.single.path!;
                // 显示冲突策略选择
                if (!context.mounted) return;
                final strategy = await showDialog<rust_import_export.ConflictStrategy>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('选择冲突策略'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('跳过'),
                          subtitle: const Text('跳过已存在的文件'),
                          leading: const Icon(Icons.skip_next),
                          onTap: () => Navigator.pop(ctx, rust_import_export.ConflictStrategy.skip),
                        ),
                        ListTile(
                          title: const Text('替换'),
                          subtitle: const Text('覆盖已存在的文件'),
                          leading: const Icon(Icons.swap_horiz),
                          onTap: () => Navigator.pop(ctx, rust_import_export.ConflictStrategy.replace),
                        ),
                        ListTile(
                          title: const Text('重命名'),
                          subtitle: const Text('重命名已存在文件为 .backup'),
                          leading: const Icon(Icons.drive_file_rename_outline),
                          onTap: () => Navigator.pop(ctx, rust_import_export.ConflictStrategy.rename),
                        ),
                      ],
                    ),
                  ),
                );
                if (strategy == null || !context.mounted) return;

                // 显示导入进度
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('正在导入 ZIP 包...'),
                      ],
                    ),
                  ),
                );

                try {
                  final result = await rust_import_export.importPackage(
                    packagePath: path,
                    conflictStrategy: strategy,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context); // 关闭进度
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('导入完成: ${result.status}')),
                  );
                  context.read<AppBloc>().add(const AppInitializeEvent());
                  context.read<MediaBloc>().add(const MediaLoadAllEvent());
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.pop(context); // 关闭进度
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('ZIP 导入失败: $e')),
                  );
                }
              }
            },
            child: const Text('选择 ZIP 文件'),
          ),
        ],
      ),
    );
  }

  void _showExportZipDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导出 ZIP 包'),
        content: const Text(
          '导出为 ZIP 格式，包含数据库和媒体文件。\n\n'
          '请选择保存位置和文件名（以 .zip 结尾）。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await FilePicker.platform.saveFile(
                type: FileType.any,
                fileName: 'advance_media_kb_backup.zip',
                allowedExtensions: ['zip'],
              );
              if (result == null || !context.mounted) return;

              // 询问是否包含媒体文件
              final includeMedia = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('导出选项'),
                  content: const Text('是否包含媒体文件？\n不包含仅导出数据库。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('仅数据库'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('包含媒体'),
                    ),
                  ],
                ),
              );
              if (includeMedia == null || !context.mounted) return;

              // 显示导出进度
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在导出 ZIP 包...'),
                    ],
                  ),
                ),
              );

              try {
                final exportResult = await rust_import_export.exportPackage(
                  exportPath: result,
                  includeMedia: includeMedia,
                );
                if (!context.mounted) return;
                Navigator.pop(context); // 关闭进度
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('导出完成: ${exportResult.status}')),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context); // 关闭进度
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('ZIP 导出失败: $e')),
                );
              }
            },
            child: const Text('导出 ZIP'),
          ),
        ],
      ),
    );
  }

  /// 查找未引用的文件
  void _showFindUnreferencedDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在扫描未引用文件...'),
          ],
        ),
      ),
    );

    try {
      // 获取数据库中所有媒体的文件路径
      final allMedia = await media_api.getAllMedia();
      final dbPaths = <String>{};
      for (final m in allMedia) {
        dbPaths.add(m.filePath);
      }

      // 获取应用媒体目录
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${appDir.path}/media');
      final unreferenced = <String>[];

      if (await mediaDir.exists()) {
        await for (final entity in mediaDir.list(recursive: true)) {
          if (entity is File) {
            final path = entity.path;
            // 跳过缩略图目录
            if (path.contains('/thumbnails/')) continue;
            if (!dbPaths.contains(path)) {
              unreferenced.add(path);
            }
          }
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // 关闭进度

      if (unreferenced.isEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('扫描完成'),
            content: const Text('未发现未引用的文件，所有文件都在数据库中有记录。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        return;
      }

      // 显示结果并提供删除选项
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('发现 ${unreferenced.length} 个未引用文件'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: unreferenced.length,
              itemBuilder: (_, i) {
                final fileName = unreferenced[i].split('/').last;
                final file = File(unreferenced[i]);
                final size = file.existsSync() ? file.lengthSync() : 0;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.insert_drive_file, size: 20),
                  title: Text(fileName, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    '${(size / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                var deleted = 0;
                for (final path in unreferenced) {
                  try {
                    await File(path).delete();
                    deleted++;
                  } catch (_) {}
                }
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除 $deleted 个未引用文件')),
                );
                await _loadStats();
              },
              child: Text('全部删除 (${unreferenced.length})'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫描失败: $e')),
      );
    }
  }

  Future<void> _clearAllData(BuildContext context) async {
    try {
      await rust_settings.deleteAllData();
      await _loadStats();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所有数据已清除')),
        );
        context.read<AppBloc>().add(const AppInitializeEvent());
        context.read<MediaBloc>().add(const MediaLoadAllEvent());
        context.read<AlbumBloc>().add(const AlbumLoadEvent());
        context.read<TagBloc>().add(const TagLoadEvent());
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除失败: $e')),
        );
      }
    }
  }
}

/// 设置分组标题
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
