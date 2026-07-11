import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:advance_media_kb/core/i18n/app_localizations.dart';
import 'package:advance_media_kb/core/design_system/app_theme.dart';
import 'package:advance_media_kb/bridge/native/api/settings.dart' as native_api;
import 'package:advance_media_kb/bridge/native/api/import_export.dart' as native_export;
import 'package:advance_media_kb/bridge/native/api/media.dart' as media_api;
import 'package:advance_media_kb/ui/media/api_test_screen.dart';
import 'package:advance_media_kb/functionality/tag/tag_bloc.dart';
import 'package:advance_media_kb/functionality/album/album_bloc.dart';
import 'package:advance_media_kb/functionality/media/media_bloc.dart';
import 'package:advance_media_kb/functionality/home/app_bloc.dart';


/// 设置页面
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  native_api.StorageStats? _stats;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final stats = await native_api.getStorageStats();
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).settings),
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.xxl)),
        ),
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          final settings = state.settings;
          final loc = AppLocalizations.of(context);
          final cs = Theme.of(context).colorScheme;
          if (settings == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
            child: ListView(
              children: [
                _SectionHeader(title: AppLocalizations.of(context).themeMode),
              ListTile(
                leading: const Icon(Icons.palette),
                title: Text(AppLocalizations.of(context).themeMode),
                subtitle: Text(_themeModeLabel(settings.themeMode)),
                onTap: () => _showThemeModeDialog(context, settings),
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
              ListTile(
                leading: const Icon(Icons.photo_size_select_small),
                title: Text(loc.thumbnailQualityLabel),
                subtitle: Text('${settings.thumbnailQuality}%'),
                onTap: () => _showThumbnailQualityDialog(context, settings),
              ),
              ListTile(
                leading: const Icon(Icons.grid_view),
                title: Text(loc.gridColumns),
                subtitle: Text('${settings.gridColumns} ${loc.columns}'),
                onTap: () => _showGridColumnsDialog(context, settings),
              ),
              const Divider(),
              _SectionHeader(title: loc.storageSection),
              if (_loadingStats)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else ...[
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: Text(loc.storageStats),
                  subtitle: Text(_buildStatsText(context)),
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
                leading: Icon(Icons.delete_forever, color: cs.error),
                title: Text(
                  loc.clearAllData,
                  style: TextStyle(color: cs.error),
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
          ),
        );
      },
    ),
  );
}

  String _buildStatsText(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (_stats == null) return loc.storageStats;
    final s = _stats!;
    return '${s.totalMediaCount} ${loc.files} · ${_formatSize(s.totalSize)} · DB ${_formatSize(s.databaseSize)}';
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
    final loc = AppLocalizations.of(context);
    try {
      final deleted = await native_api.clearThumbnailCache();
      await _loadStats();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.clearedThumbnailCount.replaceAll('%d', deleted.toString()))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.cleanFailed.replaceAll('%s', e.toString()))),
      );
    }
  }

  String _themeModeLabel(native_api.ThemeMode mode) {
    final loc = AppLocalizations.of(context);
    switch (mode) {
      case native_api.ThemeMode.light:
        return loc.themeLight;
      case native_api.ThemeMode.dark:
        return loc.themeDark;
      default:
        return loc.themeSystem;
    }
  }

  String _languageLabel(String lang) {
    final loc = AppLocalizations.of(context);
    switch (lang) {
      case 'zh':
        return loc.languageZh;
      case 'en':
        return loc.languageEn;
      default:
        return loc.languageSystem;
    }
  }

  void _showLanguageDialog(
      BuildContext context, native_api.AppSettings settings) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(loc.selectLanguage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(loc.languageSystem),
                value: 'system',
                groupValue: settings.language,
                onChanged: (value) => _changeLanguage(context, dialogCtx, settings, value),
              ),
              RadioListTile<String>(
                title: Text(loc.languageZh),
                value: 'zh',
                groupValue: settings.language,
                onChanged: (value) => _changeLanguage(context, dialogCtx, settings, value),
              ),
              RadioListTile<String>(
                title: Text(loc.languageEn),
                value: 'en',
                groupValue: settings.language,
                onChanged: (value) => _changeLanguage(context, dialogCtx, settings, value),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Skill-16：语言切换 + 重启提示
  void _changeLanguage(
    BuildContext outerCtx,
    BuildContext dialogCtx,
    native_api.AppSettings settings,
    String? value,
  ) {
    if (value == null || value == settings.language) {
      Navigator.pop(dialogCtx);
      return;
    }
    final newSettings = native_api.AppSettings(
      themeMode: settings.themeMode,
      gridColumns: settings.gridColumns,
      albumGridColumns: settings.albumGridColumns,
      thumbnailQuality: settings.thumbnailQuality,
      language: value,
      dynamicColor: settings.dynamicColor,
      lastScanPath: settings.lastScanPath,
    );
    outerCtx.read<AppBloc>().add(AppSettingsUpdatedEvent(newSettings));
    Navigator.pop(dialogCtx);
    // Skill-16 §3：语言切换后提示重启
    ScaffoldMessenger.of(outerCtx).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(outerCtx).languageChangeRestart),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showThemeModeDialog(
      BuildContext context, native_api.AppSettings settings) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(loc.themeMode),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<native_api.ThemeMode>(
                title: Text(loc.themeSystem),
                value: native_api.ThemeMode.system,
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
              RadioListTile<native_api.ThemeMode>(
                title: Text(loc.themeLight),
                value: native_api.ThemeMode.light,
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
              RadioListTile<native_api.ThemeMode>(
                title: Text(loc.themeDark),
                value: native_api.ThemeMode.dark,
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

  void _showThumbnailQualityDialog(
      BuildContext context, native_api.AppSettings settings) {
    final loc = AppLocalizations.of(context);
    final qualities = [50, 60, 70, 80, 85, 90, 95, 100];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(loc.thumbnailQualityLabel),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: qualities.map((q) {
              return RadioListTile<int>(
                title: Text('$q%'),
                value: q,
                groupValue: settings.thumbnailQuality,
                onChanged: (value) {
                  if (value != null) {
                    final newSettings = native_api.AppSettings(
                      themeMode: settings.themeMode,
                      gridColumns: settings.gridColumns,
                      albumGridColumns: settings.albumGridColumns,
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

  void _showGridColumnsDialog(
      BuildContext context, native_api.AppSettings settings) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(loc.gridColumns),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [2, 3, 4, 5, 6].map((c) {
              return RadioListTile<int>(
                title: Text('$c ${loc.columns}'),
                value: c,
                groupValue: settings.gridColumns,
                onChanged: (value) {
                  if (value != null) {
                    final newSettings = native_api.AppSettings(
                      themeMode: settings.themeMode,
                      gridColumns: value,
                      albumGridColumns: value,
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

  void _showImportDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(loc.importData),
          content: Text(loc.importDataDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.cancel),
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
                    await native_api.importData(importPath: path);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(loc.importDataSuccess)),
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
                        SnackBar(content: Text('${loc.importFailed}: $e')),
                      );
                    }
                  }
                }
              },
              child: Text(loc.selectFile),
            ),
          ],
        );
      },
    );
  }

  void _showExportDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(loc.exportData),
          content: Text(loc.exportDataDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.getDirectoryPath();
                if (result != null) {
                  final exportPath =
                      '$result/advance_media_kb_backup.db';
                  try {
                    await native_api.exportData(
                        exportPath: exportPath);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${loc.exportedTo}: $exportPath')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${loc.exportFailed}: $e')),
                      );
                    }
                  }
                }
              },
              child: Text(loc.export),
            ),
          ],
        );
      },
    );
  }

  void _showClearDataConfirmDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(loc.clearDataConfirmTitle),
          content: Text(loc.clearDataConfirmContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _clearAllData(context);
              },
              child: Text(loc.clear),
            ),
          ],
        );
      },
    );
  }

  void _showImportZipDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.importZip),
        content: Text(loc.importZipDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
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
                final strategy = await showDialog<native_export.ConflictStrategy>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(loc.conflictStrategy),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text(loc.strategySkip),
                          subtitle: Text(loc.strategySkipDesc),
                          leading: const Icon(Icons.skip_next),
                          onTap: () => Navigator.pop(ctx, native_export.ConflictStrategy.skip),
                        ),
                        ListTile(
                          title: Text(loc.strategyReplace),
                          subtitle: Text(loc.strategyReplaceDesc),
                          leading: const Icon(Icons.swap_horiz),
                          onTap: () => Navigator.pop(ctx, native_export.ConflictStrategy.replace),
                        ),
                        ListTile(
                          title: Text(loc.strategyRename),
                          subtitle: Text(loc.strategyRenameDesc),
                          leading: const Icon(Icons.drive_file_rename_outline),
                          onTap: () => Navigator.pop(ctx, native_export.ConflictStrategy.rename),
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
                  builder: (_) => AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        SizedBox(height: AppSpacing.lg),
                        Text(loc.importingZip),
                      ],
                    ),
                  ),
                );

                try {
                  final result = await native_export.importPackage(
                    packagePath: path,
                    conflictStrategy: strategy,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context); // 关闭进度
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${loc.importCompleted}: ')),
                  );
                  context.read<AppBloc>().add(const AppInitializeEvent());
                  context.read<MediaBloc>().add(const MediaLoadAllEvent());
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.pop(context); // 关闭进度
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${loc.zipImportFailed}: $e')),
                  );
                }
              }
            },
            child: Text(loc.selectZipFile),
          ),
        ],
      ),
    );
  }

  void _showExportZipDialog(BuildContext context) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.exportZip),
        content: Text(loc.exportZipDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel),
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
                  title: Text(loc.exportOptions),
                  content: Text(loc.exportOptionsDesc),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(loc.dbOnly),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(loc.includeMedia),
                    ),
                  ],
                ),
              );
              if (includeMedia == null || !context.mounted) return;

              // 显示导出进度
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      SizedBox(height: AppSpacing.lg),
                      Text(loc.exportingZip),
                    ],
                  ),
                ),
              );

              try {
                final exportResult = await native_export.exportPackage(
                  exportPath: result,
                  includeMedia: includeMedia,
                );
                if (!context.mounted) return;
                Navigator.pop(context); // 关闭进度
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${loc.exportCompleted}: done')),
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.pop(context); // 关闭进度
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${loc.zipExportFailed}: $e')),
                );
              }
            },
            child: Text(loc.exportZipButton),
          ),
        ],
      ),
    );
  }

  /// 查找未引用的文件
  void _showFindUnreferencedDialog(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: AppSpacing.lg),
            Text(loc.scanningUnreferenced),
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
            title: Text(loc.scanComplete),
            content: Text(loc.noUnreferencedFiles),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(loc.confirm),
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
          title: Text(loc.unreferencedFound.replaceAll('%d', '${unreferenced.length}')),
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
                  leading: const Icon(Icons.insert_drive_file, size: AppSpacing.xl),
                  title: Text(fileName, style: AppTextStyles.body),
                  subtitle: Text(
                    '${(size / 1024).toStringAsFixed(1)} KB',
                    style: AppTextStyles.caption,
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: cs.error),
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
                  SnackBar(content: Text(loc.unreferencedDeleted.replaceAll('%d', deleted.toString()))),
                );
                await _loadStats();
              },
              child: Text(loc.deleteAll.replaceAll('%d', '${unreferenced.length}')),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.scanFailed}: $e')),
      );
    }
  }

  Future<void> _clearAllData(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    try {
      await native_api.deleteAllData();
      await _loadStats();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.allDataCleared)),
        );
        context.read<AppBloc>().add(const AppInitializeEvent());
        context.read<MediaBloc>().add(const MediaLoadAllEvent());
        context.read<AlbumBloc>().add(const AlbumLoadEvent());
        context.read<TagBloc>().add(const TagLoadEvent());
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.clearFailed}: $e')),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
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
