import 'package:flutter/material.dart';

/// Skill-18: 国际化和本地化 (i18n / l10n)
/// 支持中文(zh)、英文(en)，默认跟随系统语言

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _translations = {
    'zh': _zhStrings,
    'en': _enStrings,
  };

  String _get(String key) {
    final lang = locale.languageCode;
    return _translations[lang]?[key] ?? _translations['en']?[key] ?? key;
  }

  // ─── 通用 ───
  String get appName => _get('appName');
  String get confirm => _get('confirm');
  String get cancel => _get('cancel');
  String get save => _get('save');
  String get delete => _get('delete');
  String get edit => _get('edit');
  String get preview => _get('preview');
  String get markdownSupported => _get('markdownSupported');
  String get back => _get('back');
  String get close => _get('close');
  String get done => _get('done');
  String get retry => _get('retry');
  String get ok => _get('ok');
  String get loading => _get('loading');
  String get error => _get('error');
  String get success => _get('success');
  String get unknown => _get('unknown');
  String get selectAll => _get('selectAll');
  String get deselectAll => _get('deselectAll');
  String get selected => _get('selected');

  // ─── 导航 ───
  String get tabAllMedia => _get('tabAllMedia');
  String get tabAlbums => _get('tabAlbums');
  String get tabTags => _get('tabTags');
  String get tabNotes => _get('tabNotes');
  String get tabMedia => _get('tabMedia');

  // ─── 媒体 ───
  String get importMedia => _get('importMedia');
  String get importFromDevice => _get('importFromDevice');
  String get importFromDirectory => _get('importFromDirectory');
  String get noMedia => _get('noMedia');
  String get noMediaDesc => _get('noMediaDesc');
  String get image => _get('image');
  String get video => _get('video');
  String get audio => _get('audio');
  String get document => _get('document');

  // ─── 过滤器 ───
  String get filterAll => _get('filterAll');
  String get filterImages => _get('filterImages');
  String get filterVideos => _get('filterVideos');
  String get filterAudios => _get('filterAudios');
  String get filterDocuments => _get('filterDocuments');
  String get filterWithTags => _get('filterWithTags');
  String get filterWithoutTags => _get('filterWithoutTags');
  String get filterWithAlbums => _get('filterWithAlbums');
  String get filterWithoutAlbums => _get('filterWithoutAlbums');

  // ─── 相册 ───
  String get album => _get('album');
  String get albums => _get('albums');
  String get createAlbum => _get('createAlbum');
  String get editAlbum => _get('editAlbum');
  String get deleteAlbum => _get('deleteAlbum');
  String get albumName => _get('albumName');
  String get noAlbums => _get('noAlbums');
  String get noAlbumsDesc => _get('noAlbumsDesc');
  String get albumMedia => _get('albumMedia');
  String get removeFromAlbum => _get('removeFromAlbum');
  String get confirmDeleteAlbum => _get('confirmDeleteAlbum');

  // ─── 标签 ───
  String get tag => _get('tag');
  String get tags => _get('tags');
  String get createTag => _get('createTag');
  String get editTag => _get('editTag');
  String get deleteTag => _get('deleteTag');
  String get tagName => _get('tagName');
  String get noTags => _get('noTags');
  String get noTagsDesc => _get('noTagsDesc');
  String get addTag => _get('addTag');
  String get removeTag => _get('removeTag');
  String get confirmDeleteTag => _get('confirmDeleteTag');
  String get selectTagColor => _get('selectTagColor');
  String get tagParent => _get('tagParent');
  String get none => _get('none');

  // ─── 笔记（Skill-14） ───
  String get note => _get('note');
  String get notes => _get('notes');
  String get createNote => _get('createNote');
  String get editNote => _get('editNote');
  String get deleteNote => _get('deleteNote');
  String get noteContent => _get('noteContent');
  String get noNotes => _get('noNotes');
  String get noNotesDesc => _get('noNotesDesc');
  String get noteContentHint => _get('noteContentHint');
  String get unsavedChanges => _get('unsavedChanges');
  String get unsavedChangesDesc => _get('unsavedChangesDesc');
  String get confirmDeleteNote => _get('confirmDeleteNote');
  String get noteEmpty => _get('noteEmpty');
  String get leaveEditor => _get('leaveEditor');
  String get continueEditing => _get('continueEditing');
  String get saveFailed => _get('saveFailed');
  String get loadFailed => _get('loadFailed');

  // ─── 搜索 ───
  String get search => _get('search');
  String get searchHint => _get('searchHint');
  String get searchMedia => _get('searchMedia');
  String get searchNotes => _get('searchNotes');
  String get noResults => _get('noResults');
  String get noResultsDesc => _get('noResultsDesc');

  // ─── 详情 ───
  String get details => _get('details');
  String get infoPanel => _get('infoPanel');
  String get notePanel => _get('notePanel');
  String get tagPanel => _get('tagPanel');
  String get fileName => _get('fileName');
  String get fileSize => _get('fileSize');
  String get resolution => _get('resolution');
  String get duration => _get('duration');
  String get createdAt => _get('createdAt');
  String get updatedAt => _get('updatedAt');
  String get mimeType => _get('mimeType');
  String get hash => _get('hash');
  String get fullPath => _get('fullPath');
  String get addToAlbum => _get('addToAlbum');

  // ─── 设置 ───
  String get settings => _get('settings');
  String get theme => _get('theme');
  String get themeMode => _get('themeMode');
  String get display => _get('display');
  String get mediaGridColumns => _get('mediaGridColumns');
  String get columns => _get('columns');
  String get dynamicColorDesc => _get('dynamicColorDesc');
  String get themeSystem => _get('themeSystem');
  String get themeLight => _get('themeLight');
  String get themeDark => _get('themeDark');
  String get language => _get('language');
  String get languageSystem => _get('languageSystem');
  String get languageZh => _get('languageZh');
  String get languageEn => _get('languageEn');
  String get gridColumns => _get('gridColumns');
  String get albumGridColumns => _get('albumGridColumns');
  String get showPreview => _get('showPreview');
  String get thumbnailQuality => _get('thumbnailQuality');
  String get dynamicColor => _get('dynamicColor');
  String get clearData => _get('clearData');
  String get clearDataDesc => _get('clearDataDesc');
  String get confirmClearData => _get('confirmClearData');
  String get storageManagement => _get('storageManagement');
  String get storageManagementDesc => _get('storageManagementDesc');
  String get languageChangeRestart => _get('languageChangeRestart');
  String get version => _get('version');
  String get detailMode => _get('detailMode');
  String get copyPath => _get('copyPath');
  String get operationFailed => _get('operationFailed');
  String get typeLabel => _get('typeLabel');
  String get fileManager => _get('fileManager');
  String get sortByName => _get('sortByName');
  String get sort => _get('sort');
  String get sortNewestFirst => _get('sortNewestFirst');
  String get sortOldestFirst => _get('sortOldestFirst');
  String get sortNameAsc => _get('sortNameAsc');
  String get sortNameDesc => _get('sortNameDesc');
  String get sortSizeDesc => _get('sortSizeDesc');
  String get sortSizeAsc => _get('sortSizeAsc');
  String get filterAnd => _get('filterAnd');
  String get filterOr => _get('filterOr');
  String get sortByType => _get('sortByType');
  String get importSelected => _get('importSelected');
  String get backToHome => _get('backToHome');
  String get selectThisFolder => _get('selectThisFolder');
  String get noSubfolders => _get('noSubfolders');
  String get needStoragePermission => _get('needStoragePermission');
  String get gotoSettings => _get('gotoSettings');
  String get advSearch => _get('advSearch');
  String get reset => _get('reset');
  String get keyword => _get('keyword');
  String get searchFileName => _get('searchFileName');
  String get mediaType => _get('mediaType');
  String get dateRange => _get('dateRange');
  String get selectDateRange => _get('selectDateRange');
  String get tagFilter => _get('tagFilter');
  String get matchMode => _get('matchMode');
  String get matchAnyTag => _get('matchAnyTag');
  String get matchAllTags => _get('matchAllTags');
  String get albumFilter => _get('albumFilter');
  String get selectAlbum => _get('selectAlbum');
  String get searchMediaHint => _get('searchMediaHint');
  String get directoryNotAccessible => _get('directoryNotAccessible');
  String cannotReadDirectory(String err) =>
      _get('cannotReadDirectory').replaceAll('%s', err);
  String get manageAllFilesPermissionDesc =>
      _get('manageAllFilesPermissionDesc');
  String importSelectedWithCount(int count) =>
      _get('importSelected').replaceAll('%s', count == 0 ? '' : ' ($count)');

  // ─── 文件浏览器 ───
  String get selectFolder => _get('selectFolder');
  String get internalStorage => _get('internalStorage');
  String get sdCard => _get('sdCard');
  String get noFiles => _get('noFiles');
  String get noFilesDesc => _get('noFilesDesc');
  String get folders => _get('folders');
  String get files => _get('files');
  String get selectFiles => _get('selectFiles');

  // ─── 导入 ───
  String get importing => _get('importing');
  String get importComplete => _get('importComplete');
  String get importSkipped => _get('importSkipped');
  String get importFailed => _get('importFailed');
  String get importCancelled => _get('importCancelled');
  String get duplicateFile => _get('duplicateFile');

  // ─── 权限 ───
  String get permissionRequired => _get('permissionRequired');
  String get permissionDesc => _get('permissionDesc');
  String get permissionGranted => _get('permissionGranted');
  String get permissionDenied => _get('permissionDenied');
  String get permissionPermanentlyDenied => _get('permissionPermanentlyDenied');
  String get openSettings => _get('openSettings');
  String get grantPermission => _get('grantPermission');

  // ─── 查看器 ───
  String get viewer => _get('viewer');
  String get share => _get('share');
  String get deleteMedia => _get('deleteMedia');
  String get confirmDeleteMedia => _get('confirmDeleteMedia');

  // ─── 多选 ───
  String get multiSelectMode => _get('multiSelectMode');
  String get batchAddToAlbum => _get('batchAddToAlbum');
  String get batchAddTag => _get('batchAddTag');
  String get batchDelete => _get('batchDelete');
  String get confirmBatchDelete => _get('confirmBatchDelete');

  // ─── 详情页额外 ───
  String get fileInfo => _get('fileInfo');
  String get storageName => _get('storageName');
  String get rename => _get('rename');
  String get newName => _get('newName');
  String get manageTags => _get('manageTags');
  String get exportToDownload => _get('exportToDownload');
  String get filePathCopied => _get('filePathCopied');
  String get exportedTo => _get('exportedTo');
  String get exportFailed => _get('exportFailed');
  String get noTagsCreateFirst => _get('noTagsCreateFirst');
  String get confirmDeleteMediaMsg => _get('confirmDeleteMediaMsg');
  String get contentPreview => _get('contentPreview');
  String get contentPreviewDesc => _get('contentPreviewDesc');
  String get thumbnailQualityLabel => _get('thumbnailQualityLabel');
  String get storageSection => _get('storageSection');
  String get storageStats => _get('storageStats');
  String get clearThumbnailCache => _get('clearThumbnailCache');
  String get clickToClearUnreferenced => _get('clickToClearUnreferenced');
  String get dataSection => _get('dataSection');
  String get importDb => _get('importDb');
  String get importDbDesc => _get('importDbDesc');
  String get importZip => _get('importZip');
  String get importZipDesc => _get('importZipDesc');
  String get exportDb => _get('exportDb');
  String get exportZip => _get('exportZip');
  String get exportZipDesc => _get('exportZipDesc');
  String get findUnreferenced => _get('findUnreferenced');
  String get findUnreferencedDesc => _get('findUnreferencedDesc');
  String get clearAllData => _get('clearAllData');
  String get devSection => _get('devSection');
  String get apiTest => _get('apiTest');
  String get apiTestDesc => _get('apiTestDesc');
  String get aboutSection => _get('aboutSection');
  String get versionLabel => _get('versionLabel');
  String get techStack => _get('techStack');
  String get techStackValue => _get('techStackValue');
  String get clearedThumbnailCount => _get('clearedThumbnailCount');
  String get cleanFailed => _get('cleanFailed');
  String get selectLanguage => _get('selectLanguage');
  String get moveLeft => _get('moveLeft');
  String get moveRight => _get('moveRight');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['zh', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

const Map<String, String> _zhStrings = {
  'appName': '媒体知识库',
  'confirm': '确定', 'cancel': '取消', 'save': '保存', 'delete': '删除',
  'edit': '编辑', 'preview': '预览', 'markdownSupported': '支持 Markdown 语法',
  'back': '返回', 'close': '关闭', 'done': '完成',
  'retry': '重试', 'ok': '好', 'loading': '加载中...', 'error': '错误',
  'success': '成功', 'unknown': '未知', 'selectAll': '全选',
  'deselectAll': '取消全选', 'selected': '已选中',
  'tabAllMedia': '所有媒体', 'tabAlbums': '相册', 'tabTags': '标签',
  'tabNotes': '笔记', 'tabMedia': '所有媒体',
  'importMedia': '导入媒体', 'importFromDevice': '从设备导入',
  'importFromDirectory': '从文件夹导入',
  'noMedia': '还没有媒体文件', 'noMediaDesc': '点击下方按钮导入您的第一张图片或视频',
  'image': '图片', 'video': '视频', 'audio': '音频', 'document': '文档',
  'filterAll': '全部', 'filterImages': '图片', 'filterVideos': '视频',
  'filterAudios': '音频', 'filterDocuments': '文档',
  'filterWithTags': '有标签的', 'filterWithoutTags': '无标签的',
  'filterWithAlbums': '有相册的', 'filterWithoutAlbums': '无相册的',
  'album': '相册', 'albums': '相册', 'createAlbum': '创建相册',
  'editAlbum': '编辑相册', 'deleteAlbum': '删除相册', 'albumName': '相册名称',
  'noAlbums': '还没有相册', 'noAlbumsDesc': '点击下方按钮创建您的第一个相册',
  'albumMedia': '相册内的媒体', 'removeFromAlbum': '移出相册',
  'confirmDeleteAlbum': '确定删除此相册吗？相册内的媒体不会被删除。',
  'tag': '标签', 'tags': '标签', 'createTag': '创建标签', 'editTag': '编辑标签',
  'deleteTag': '删除标签', 'tagName': '标签名称', 'noTags': '还没有标签',
  'noTagsDesc': '点击下方按钮创建您的第一个标签', 'addTag': '添加标签',
  'removeTag': '移除标签', 'confirmDeleteTag': '确定删除此标签吗？',
  'selectTagColor': '选择标签颜色',
  'tagParent': '父标签', 'none': '无',
  'note': '笔记', 'notes': '笔记', 'createNote': '创建笔记', 'editNote': '编辑笔记',
  'deleteNote': '删除笔记', 'noteTitle': '笔记标题', 'noteContent': '笔记内容',
  'noNotes': '还没有笔记', 'noNotesDesc': '点击下方按钮创建您的第一条笔记',
  'noteTitleHint': '输入标题（可选）', 'noteContentHint': '输入笔记内容...',
  'saveNote': '保存笔记', 'discardChanges': '放弃修改',
  'unsavedChanges': '未保存的修改', 'unsavedChangesDesc': '您有未保存的修改，确定要离开吗？',
  'confirmDeleteNote': '确定要删除此笔记吗？',
  'linkedMedia': '关联媒体',
  'emptyTitle': '（无标题）',
  'noteEmpty': '（笔记为空）',
  'leaveEditor': '离开',
  'continueEditing': '继续编辑',
  'noteLinkToMedia': '关联到媒体',
  'noteUnlinkFromMedia': '取消关联媒体',
  'noteCreatedAt': '创建于',
  'noteUpdatedAt': '更新于',
  'allNotes': '全部笔记',
  'mediaNotes': '关联笔记',
  'saveFailed': '保存失败',
  'loadFailed': '加载失败',
  'search': '搜索', 'searchHint': '搜索媒体和笔记...',
  'searchMedia': '搜索媒体', 'searchNotes': '搜索笔记',
  'noResults': '未找到结果', 'noResultsDesc': '尝试使用其他关键词搜索',
  'details': '详情', 'infoPanel': '信息', 'notePanel': '笔记', 'tagPanel': '标签',
  'fileName': '文件名', 'fileSize': '文件大小', 'resolution': '分辨率',
  'duration': '时长', 'createdAt': '创建时间', 'mimeType': 'MIME 类型',
  'hash': '哈希值', 'fullPath': '完整路径', 'addToAlbum': '添加到相册',
  'updatedAt': '更新时间',
  'settings': '设置', 'theme': '主题', 'themeMode': '主题模式',
  'display': '显示', 'mediaGridColumns': '媒体网格列数',
  'columns': '列', 'dynamicColorDesc': '跟随系统壁纸颜色（Android 12+）',
  'themeSystem': '跟随系统',
  'themeLight': '浅色', 'themeDark': '深色', 'language': '语言',
  'languageSystem': '跟随系统', 'languageZh': '简体中文', 'languageEn': 'English',
  'gridColumns': '网格列数', 'albumGridColumns': '相册网格列数',
  'showPreview': '显示内容预览', 'thumbnailQuality': '缩略图质量',
  'dynamicColor': '动态颜色', 'clearData': '清除所有数据',
  'clearDataDesc': '删除所有媒体、相册、标签和笔记',
  'confirmClearData': '确定要清除所有数据吗？此操作不可恢复！',
  'storageManagement': '存储管理', 'storageManagementDesc': '管理缩略图缓存和未引用的文件',
  'languageChangeRestart': '语言设置将在应用重启后生效', 'version': '版本',
  'detailMode': '详情模式', 'copyPath': '复制路径',
  'operationFailed': '操作失败', 'typeLabel': '类型',
  'fileManager': '文件管理器', 'sortByName': '按名称', 'sort': '排序', 'sortNewestFirst': '最新优先', 'sortOldestFirst': '最旧优先', 'sortNameAsc': '名称 A-Z', 'sortNameDesc': '名称 Z-A', 'sortSizeDesc': '最大优先', 'sortSizeAsc': '最小优先', 'filterAnd': '并且', 'filterOr': '或者',
  'sortByType': '按类型', 'importSelected': '导入%s',
  'backToHome': '返回首页', 'selectThisFolder': '选择此文件夹',
  'noSubfolders': '此目录无子文件夹',
  'needStoragePermission': '需要存储权限', 'gotoSettings': '去设置',
  'advSearch': '高级搜索', 'reset': '重置', 'keyword': '关键词',
  'searchFileName': '搜索文件名...', 'mediaType': '媒体类型',
  'dateRange': '日期范围', 'selectDateRange': '选择日期范围',
  'tagFilter': '标签筛选', 'matchMode': '匹配模式',
  'matchAnyTag': '任一标签', 'matchAllTags': '所有标签',
  'albumFilter': '相册筛选', 'selectAlbum': '选择相册',
  'searchMediaHint': '搜索媒体...',
  'directoryNotAccessible': '目录不可访问',
  'cannotReadDirectory': '无法读取目录: %s',
  'manageAllFilesPermissionDesc': '浏览文件需要"管理所有文件"权限。\n\n请点击"去设置"，然后在应用详情中开启"允许管理所有文件"。',
  'selectFolder': '选择文件夹', 'internalStorage': '内部存储', 'sdCard': 'SD 卡',
  'noFiles': '此目录为空', 'noFilesDesc': '没有找到文件或文件夹',
  'folders': '文件夹', 'files': '文件', 'selectFiles': '选择文件',
  'importing': '正在导入...', 'importComplete': '导入完成',
  'importSkipped': '跳过 %d 个重复文件', 'importFailed': '导入失败',
  'importCancelled': '导入已取消', 'duplicateFile': '重复文件',
  'permissionRequired': '需要存储权限', 'permissionDesc': '应用需要存储权限来访问您的媒体文件',
  'permissionGranted': '权限已授予', 'permissionDenied': '权限被拒绝',
  'permissionPermanentlyDenied': '权限已被永久拒绝，请在设置中手动开启',
  'openSettings': '打开设置', 'grantPermission': '授予权限',
  'viewer': '查看', 'share': '分享', 'deleteMedia': '删除媒体',
  'confirmDeleteMedia': '确定要删除此媒体吗？',
  'multiSelectMode': '多选模式', 'batchAddToAlbum': '批量添加到相册',
  'batchAddTag': '批量打标签', 'batchDelete': '批量删除',
  'confirmBatchDelete': '确定要删除选中的媒体吗？',
  'fileInfo': '文件信息', 'storageName': '存储名',
  'rename': '重命名', 'newName': '新名称',
  'manageTags': '管理标签', 'exportToDownload': '导出到 Download',
  'filePathCopied': '文件路径已复制', 'exportedTo': '已导出到',
  'exportFailed': '导出失败',
  'noTagsCreateFirst': '暂无标签，请先在标签页面创建',
  'confirmDeleteMediaMsg': '确定要删除此媒体吗？',
  'moveLeft': '左移', 'moveRight': '右移',
  'contentPreview': '内容预览', 'contentPreviewDesc': '在网格中显示文件预览信息',
  'thumbnailQualityLabel': '缩略图质量', 'storageSection': '存储',
  'storageStats': '存储统计', 'clearThumbnailCache': '清理缩略图缓存',
  'clickToClearUnreferenced': '点击清理未引用的缩略图',
  'dataSection': '数据', 'importDb': '导入数据库 (.db)', 'importDbDesc': '替换当前数据库',
  'importZip': '导入 ZIP 包', 'importZipDesc': '导入数据库+媒体文件',
  'exportDb': '导出数据库 (.db)', 'exportZip': '导出 ZIP 包',
  'exportZipDesc': '导出数据库+媒体文件',
  'findUnreferenced': '查找未引用文件', 'findUnreferencedDesc': '查找磁盘上存在但数据库未记录的文件',
  'clearAllData': '清除所有数据', 'devSection': '开发',
  'apiTest': 'API 接口测试', 'apiTestDesc': '测试所有 Rust FFI 接口',
  'aboutSection': '关于', 'versionLabel': '版本', 'techStack': '技术栈',
  'techStackValue': 'Flutter + Rust (flutter_rust_bridge)',
  'clearedThumbnailCount': '已清理 %d 个缩略图文件', 'cleanFailed': '清理失败: %s',
  'selectLanguage': '选择语言',
};


const Map<String, String> _enStrings = {
  'appName': 'Media KB',
  'confirm': 'OK', 'cancel': 'Cancel', 'save': 'Save', 'delete': 'Delete',
  'edit': 'Edit', 'preview': 'Preview', 'markdownSupported': 'Markdown supported',
  'back': 'Back', 'close': 'Close', 'done': 'Done',
  'retry': 'Retry', 'ok': 'OK', 'loading': 'Loading...', 'error': 'Error',
  'success': 'Success', 'unknown': 'Unknown', 'selectAll': 'Select All',
  'deselectAll': 'Deselect All', 'selected': 'Selected',
  'tabAllMedia': 'All Media', 'tabAlbums': 'Albums', 'tabTags': 'Tags',
  'tabNotes': 'Notes', 'tabMedia': 'All Media',
  'importMedia': 'Import Media', 'importFromDevice': 'Import from Device',
  'importFromDirectory': 'Import from Folder',
  'noMedia': 'No media files yet', 'noMediaDesc': 'Tap below to import your first photo or video',
  'image': 'Image', 'video': 'Video', 'audio': 'Audio', 'document': 'Document',
  'filterAll': 'All', 'filterImages': 'Images', 'filterVideos': 'Videos',
  'filterAudios': 'Audios', 'filterDocuments': 'Documents',
  'filterWithTags': 'With Tags', 'filterWithoutTags': 'Without Tags',
  'filterWithAlbums': 'In Albums', 'filterWithoutAlbums': 'Not in Albums',
  'album': 'Album', 'albums': 'Albums', 'createAlbum': 'Create Album',
  'editAlbum': 'Edit Album', 'deleteAlbum': 'Delete Album', 'albumName': 'Album Name',
  'noAlbums': 'No albums yet', 'noAlbumsDesc': 'Tap below to create your first album',
  'albumMedia': 'Album Media', 'removeFromAlbum': 'Remove from Album',
  'confirmDeleteAlbum': 'Delete this album? Media inside will not be deleted.',
  'tag': 'Tag', 'tags': 'Tags', 'createTag': 'Create Tag', 'editTag': 'Edit Tag',
  'deleteTag': 'Delete Tag', 'tagName': 'Tag Name', 'noTags': 'No tags yet',
  'noTagsDesc': 'Tap below to create your first tag', 'addTag': 'Add Tag',
  'removeTag': 'Remove Tag', 'confirmDeleteTag': 'Delete this tag?',
  'selectTagColor': 'Select Tag Color',
  'tagParent': 'Parent Tag', 'none': 'None',
  'note': 'Note', 'notes': 'Notes', 'createNote': 'Create Note', 'editNote': 'Edit Note',
  'deleteNote': 'Delete Note', 'noteTitle': 'Note Title', 'noteContent': 'Note Content',
  'noNotes': 'No notes yet', 'noNotesDesc': 'Tap below to create your first note',
  'noteTitleHint': 'Enter title (optional)', 'noteContentHint': 'Enter note content...',
  'saveNote': 'Save Note', 'discardChanges': 'Discard Changes',
  'unsavedChanges': 'Unsaved Changes', 'unsavedChangesDesc': 'You have unsaved changes. Leave?',
  'confirmDeleteNote': 'Delete this note?',
  'linkedMedia': 'Linked Media',
  'emptyTitle': '(Untitled)',
  'noteEmpty': '(Empty note)',
  'leaveEditor': 'Leave',
  'continueEditing': 'Continue Editing',
  'noteLinkToMedia': 'Link to Media',
  'noteUnlinkFromMedia': 'Unlink Media',
  'noteCreatedAt': 'Created at',
  'noteUpdatedAt': 'Updated at',
  'allNotes': 'All Notes',
  'mediaNotes': 'Media Notes',
  'saveFailed': 'Save failed',
  'loadFailed': 'Load failed',
  'search': 'Search', 'searchHint': 'Search media and notes...',
  'searchMedia': 'Search Media', 'searchNotes': 'Search Notes',
  'noResults': 'No Results Found', 'noResultsDesc': 'Try different keywords',
  'details': 'Details', 'infoPanel': 'Info', 'notePanel': 'Notes', 'tagPanel': 'Tags',
  'fileName': 'File Name', 'fileSize': 'File Size', 'resolution': 'Resolution',
  'duration': 'Duration', 'createdAt': 'Created At', 'mimeType': 'MIME Type',
  'hash': 'Hash', 'fullPath': 'Full Path', 'addToAlbum': 'Add to Album',
  'updatedAt': 'Updated At',
  'settings': 'Settings', 'theme': 'Theme', 'themeMode': 'Theme Mode',
  'display': 'Display', 'mediaGridColumns': 'Media Grid Columns',
  'columns': 'cols', 'dynamicColorDesc': 'Follow system wallpaper color (Android 12+)',
  'themeSystem': 'Follow System',
  'themeLight': 'Light', 'themeDark': 'Dark', 'language': 'Language',
  'languageSystem': 'Follow System', 'languageZh': '简体中文', 'languageEn': 'English',
  'gridColumns': 'Grid Columns', 'albumGridColumns': 'Album Grid Columns',
  'showPreview': 'Show Content Previews', 'thumbnailQuality': 'Thumbnail Quality',
  'dynamicColor': 'Dynamic Color', 'clearData': 'Clear All Data',
  'clearDataDesc': 'Delete all media, albums, tags and notes',
  'confirmClearData': 'Clear all data? This cannot be undone!',
  'storageManagement': 'Storage Management', 'storageManagementDesc': 'Manage thumbnail cache and unreferenced files',
  'languageChangeRestart': 'Language change takes effect after restart', 'version': 'Version',
  'detailMode': 'Detail Mode', 'copyPath': 'Copy Path',
  'operationFailed': 'Operation failed', 'typeLabel': 'Type',
  'fileManager': 'File Manager', 'sortByName': 'Name', 'sort': 'Sort', 'sortNewestFirst': 'Newest First', 'sortOldestFirst': 'Oldest First', 'sortNameAsc': 'Name A-Z', 'sortNameDesc': 'Name Z-A', 'sortSizeDesc': 'Largest First', 'sortSizeAsc': 'Smallest First', 'filterAnd': 'AND', 'filterOr': 'OR',
  'sortByType': 'Type', 'importSelected': 'Import%s',
  'backToHome': 'Back to Home', 'selectThisFolder': 'Select This Folder',
  'noSubfolders': 'No subfolders in this directory',
  'needStoragePermission': 'Storage Permission Required',
  'gotoSettings': 'Go to Settings',
  'advSearch': 'Advanced Search', 'reset': 'Reset', 'keyword': 'Keyword',
  'searchFileName': 'Search file name...', 'mediaType': 'Media Type',
  'dateRange': 'Date Range', 'selectDateRange': 'Select date range',
  'tagFilter': 'Tag Filter', 'matchMode': 'Match Mode',
  'matchAnyTag': 'Any Tag', 'matchAllTags': 'All Tags',
  'albumFilter': 'Album Filter', 'selectAlbum': 'Select Album',
  'searchMediaHint': 'Search media...',
  'directoryNotAccessible': 'Directory not accessible',
  'cannotReadDirectory': 'Cannot read directory: %s',
  'manageAllFilesPermissionDesc': 'Browsing files requires "All files access" permission.\n\nPlease tap "Go to Settings" and enable "Allow access to manage all files" in the app details.',
  'selectFolder': 'Select Folder', 'internalStorage': 'Internal Storage', 'sdCard': 'SD Card',
  'noFiles': 'This directory is empty', 'noFilesDesc': 'No files or folders found',
  'folders': 'Folders', 'files': 'Files', 'selectFiles': 'Select Files',
  'importing': 'Importing...', 'importComplete': 'Import Complete',
  'importSkipped': 'Skipped %d duplicates', 'importFailed': 'Import failed',
  'importCancelled': 'Import cancelled', 'duplicateFile': 'Duplicate File',
  'permissionRequired': 'Storage Permission Required', 'permissionDesc': 'App needs storage permission to access media files',
  'permissionGranted': 'Permission granted', 'permissionDenied': 'Permission Denied',
  'permissionPermanentlyDenied': 'Permission permanently denied. Enable in Settings.',
  'openSettings': 'Open Settings', 'grantPermission': 'Grant Permission',
  'viewer': 'Viewer', 'share': 'Share', 'deleteMedia': 'Delete Media',
  'confirmDeleteMedia': 'Delete this media?',
  'multiSelectMode': 'Multi-select Mode', 'batchAddToAlbum': 'Batch Add to Album',
  'batchAddTag': 'Batch Add Tag', 'batchDelete': 'Batch Delete',
  'confirmBatchDelete': 'Delete selected media?',
  'fileInfo': 'File Info', 'storageName': 'Storage Name',
  'rename': 'Rename', 'newName': 'New Name',
  'manageTags': 'Manage Tags', 'exportToDownload': 'Export to Download',
  'filePathCopied': 'File path copied', 'exportedTo': 'Exported to',
  'exportFailed': 'Export failed',
  'noTagsCreateFirst': 'No tags yet. Create tags first in the Tags tab.',
  'confirmDeleteMediaMsg': 'Delete this media?',
  'moveLeft': 'Move Left', 'moveRight': 'Move Right',
  'contentPreview': 'Content Preview', 'contentPreviewDesc': 'Show file preview in grid',
  'thumbnailQualityLabel': 'Thumbnail Quality', 'storageSection': 'Storage',
  'storageStats': 'Storage Statistics', 'clearThumbnailCache': 'Clear Thumbnail Cache',
  'clickToClearUnreferenced': 'Tap to clear unreferenced thumbnails',
  'dataSection': 'Data', 'importDb': 'Import Database (.db)', 'importDbDesc': 'Replace current database',
  'importZip': 'Import ZIP', 'importZipDesc': 'Import database + media files',
  'exportDb': 'Export Database (.db)', 'exportZip': 'Export ZIP',
  'exportZipDesc': 'Export database + media files',
  'findUnreferenced': 'Find Unreferenced Files', 'findUnreferencedDesc': 'Find files on disk not in database',
  'clearAllData': 'Clear All Data', 'devSection': 'Development',
  'apiTest': 'API Test', 'apiTestDesc': 'Test all Rust FFI interfaces',
  'aboutSection': 'About', 'versionLabel': 'Version', 'techStack': 'Tech Stack',
  'techStackValue': 'Flutter + Rust (flutter_rust_bridge)',
  'clearedThumbnailCount': 'Cleared %d thumbnail files', 'cleanFailed': 'Clean failed: %s',
  'selectLanguage': 'Select Language',
};

