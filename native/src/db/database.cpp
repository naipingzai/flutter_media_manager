/**
 * @file native/src/db/database.cpp
 * @brief AdvanceMediaKB 核心数据库实现
 *
 * 本文件实现基于 SQLite3 的本地数据库层，负责：
 *   - 相册 (albums)、媒体项 (media_items)、标签 (tags)、笔记 (notes) 的 CRUD
 *   - 文件系统路径管理、缩略图缓存、导入/导出、扫描目录
 *   - 设置持久化、高级搜索、标签 AND/OR 过滤
 * 所有公共方法均使用 mutex_ 保证线程安全，便于从 Dart FFI 多线程 isolate 调用。
 */

// 引入本模块对外声明：数据结构与 Database 类接口
#include "database.h"

// 标准库：文件系统操作
#include <filesystem>
// 标准库：文件读写
#include <fstream>
// 标准库：时间戳
#include <chrono>
// 标准库：随机数
#include <random>
// 标准库：字符串流
#include <sstream>
// 标准库：算法（transform 等）
#include <algorithm>
// 标准库：集合
#include <set>
// 标准库：C 风格字符串操作
#include <cstring>

// 创建 std::filesystem 的短别名 fs，避免代码冗长
namespace fs = std::filesystem;
// 将当前文件置于 fmm::db 命名空间，与 database.h 保持一致
using namespace fmm::db;

/**
 * @brief 匿名命名空间
 * 限制以下工具函数仅在当前翻译单元可见，避免符号冲突。
 */
namespace {

/**
 * @brief 生成 UUID 版本 4 字符串
 * 使用伪随机数构造 8-4-4-4-12 的 UUID 格式，并把 variant 固定为 10xx。
 * 返回值：36 字符带连字符的 UUID 字符串。
 */
std::string generate_uuid() {
    // 随机设备，用于提供非确定性种子
    static std::random_device rd;
    // Mersenne Twister 19937 随机数引擎
    static std::mt19937 gen(rd());
    // 32 位无符号均匀分布
    static std::uniform_int_distribution<uint32_t> dist(0, 0xFFFFFFFF);
    // 生成 4 个 32 位随机数
    uint32_t d[4];
    for (int i = 0; i < 4; i++) d[i] = dist(gen);
    // 格式化缓冲区，37 字节容纳 36 字符 + '\0'
    char buf[37];
    // 按 UUID v4 格式写入：
    // d[1] 高位 -> 4 位版本 4
    // d[2] 高位 -> 设置 variant 10xx
    snprintf(buf, sizeof(buf), "%08x-%04x-%04x-%04x-%04x%08x",
        d[0], (d[1]>>16)&0xFFFF, (d[1]&0xFFFF)|0x4000,
        (d[2]>>16)|0x8000, d[2]&0xFFFF, d[3]);
    // 返回标准字符串
    return std::string(buf);
}

/**
 * @brief 返回当前 UTC 时间戳（毫秒）
 * 用于 created_at / updated_at 等字段。
 */
int64_t current_timestamp_ms() {
    // 获取当前系统时间
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count();
}

/**
 * @brief 将字符串转为小写
 * 用于统一文件扩展名比较。
 */
std::string to_lower(const std::string& s) {
    // 复制输入字符串
    std::string r = s;
    // 对每一个字符调用 tolower
    std::transform(r.begin(), r.end(), r.begin(), ::tolower);
    // 返回转换后的结果
    return r;
}

/**
 * @brief 提取文件路径中的扩展名（小写）
 * 若路径无 '.' 则返回空字符串。
 */
std::string get_extension(const std::string& p) {
    // 从右向左查找最后一个 '.'
    auto pos = p.rfind('.');
    // 若找不到则返回空串，否则返回 '.' 之后的小写子串
    return pos == std::string::npos ? "" : to_lower(p.substr(pos + 1));
}

/**
 * @brief 根据扩展名判断媒体类型
 * 返回：image / video / audio / document / other
 */
std::string detect_media_type(const std::string& ext) {
    // 常见图片扩展名
    if (ext == "jpg" || ext == "jpeg" || ext == "png" || ext == "gif" || ext == "bmp" || ext == "webp" || ext == "svg") return "image";
    // 常见视频扩展名
    if (ext == "mp4" || ext == "avi" || ext == "mkv" || ext == "mov" || ext == "webm") return "video";
    // 常见音频扩展名
    if (ext == "mp3" || ext == "wav" || ext == "flac" || ext == "aac" || ext == "ogg") return "audio";
    // 常见文档扩展名
    if (ext == "pdf" || ext == "doc" || ext == "docx" || ext == "txt" || ext == "md") return "document";
    // 未知类型
    return "other";
}

/**
 * @brief 根据扩展名返回 MIME 类型
 * 用于 HTTP 头或播放器内容类型识别。
 */
std::string detect_mime_type(const std::string& ext) {
    // 图片
    if (ext == "jpg" || ext == "jpeg") return "image/jpeg";
    if (ext == "png") return "image/png";
    if (ext == "gif") return "image/gif";
    // 视频
    if (ext == "mp4") return "video/mp4";
    // 音频
    if (ext == "mp3") return "audio/mpeg";
    // 文档
    if (ext == "pdf") return "application/pdf";
    if (ext == "txt") return "text/plain";
    // 默认二进制流
    return "application/octet-stream";
}

/**
 * @brief 绑定 TEXT 参数到 SQLite 语句
 * @param s sqlite3_stmt 指针
 * @param i 参数索引（从 1 开始）
 * @param v 要绑定的字符串
 * 使用 SQLITE_TRANSIENT 让 SQLite 复制字符串内容，避免外部字符串生命周期问题。
 */
void bind_text(sqlite3_stmt* s, int i, const std::string& v) {
    sqlite3_bind_text(s, i, v.c_str(), -1, SQLITE_TRANSIENT);
}

/**
 * @brief 绑定可选 TEXT 参数
 * 若 optional 有值则绑定文本，否则绑定 NULL。
 */
void bind_opt_text(sqlite3_stmt* s, int i, const std::optional<std::string>& v) {
    if (v.has_value()) bind_text(s, i, v.value());
    else sqlite3_bind_null(s, i);
}

/**
 * @brief 将 UTF-8 字符串转换为 std::filesystem::path
 * Windows 上 std::filesystem 默认使用 ANSI 编码解析路径
 * 对于含中文等非 ASCII 字符的路径，std::filesystem 会失败
 * 使用 fs::u8path() 显式指定 UTF-8 编码以正确处理 Windows 上的中文路径
 */
static fs::path to_path(const std::string& s) {
#ifdef _WIN32
    return fs::u8path(s);
#else
    return fs::path(s);
#endif
}

// 匿名命名空间结束
} // anon

/**
 * @brief 单例访问
 * 使用函数内 static 变量保证 C++11 起线程安全初始化。
 */
Database& Database::instance() {
    static Database db;  // 仅首次调用时构造
    return db;           // 返回全局唯一实例
}

/**
 * @brief 析构函数
 * 关闭已打开的 SQLite 数据库连接，防止资源泄漏。
 */
Database::~Database() {
    if (db_) {
        // 关闭数据库句柄
        sqlite3_close(db_);
        // 标记为已关闭
        db_ = nullptr;
    }
}

/**
 * @brief 判断数据库是否已初始化
 */
bool Database::is_initialized() const { return db_ != nullptr; }

/**
 * @brief 初始化数据库
 * @param app_dir 应用私有数据目录（如 /home/user/.advance_media_kb）
 * 创建子目录、打开 SQLite 数据库、启用外键并建表。
 */
int Database::init(const std::string& app_dir) {
    // 加互斥锁，保护数据库初始化过程
    std::lock_guard<std::mutex> lock(mutex_);
    // 保存应用目录路径
    app_dir_ = app_dir;
    // 在 Windows 上使用 UTF-8 路径对象以便正确处理中文路径
    fs::path app_path = to_path(app_dir);
    // 创建应用根目录
    std::error_code ec;
    fs::create_directories(app_path, ec);
    // 创建媒体文件存放目录
    fs::create_directories(app_path / "media", ec);
    // 创建缩略图存放目录
    fs::create_directories(app_path / "media" / "thumbnails", ec);
    // 数据库文件完整路径
    fs::path db_path = app_path / "advance_media_kb.db";
    // 打开 SQLite 数据库
    int rc = sqlite3_open(db_path.string().c_str(), &db_);
    // 打开失败则返回错误码
    if (rc != SQLITE_OK) return rc;
    // 启用外键约束（SQLite 默认关闭）
    sqlite3_exec(db_, "PRAGMA foreign_keys = ON", nullptr, nullptr, nullptr);
    // 创建表、索引、默认设置
    return create_tables();
}

/**
 * @brief 创建数据库表、索引、默认设置
 * 所有建表语句合并为一次 sqlite3_exec 执行。
 */
int Database::create_tables() {
    // 多行 SQL 字符串，使用原始字符串字面量 R"SQL(...)"SQL"
    const char* sql = R"SQL(
        -- 相册表：支持层级关系（parent_id），支持封面（cover_media_id）
        CREATE TABLE IF NOT EXISTS albums (id TEXT PRIMARY KEY, name TEXT NOT NULL, parent_id TEXT, cover_media_id TEXT, sort_order INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, FOREIGN KEY (parent_id) REFERENCES albums(id) ON DELETE CASCADE, FOREIGN KEY (cover_media_id) REFERENCES media_items(id) ON DELETE SET NULL);
        -- 媒体项表：保存文件元数据、尺寸、时长、哈希等
        CREATE TABLE IF NOT EXISTS media_items (id TEXT PRIMARY KEY, original_name TEXT NOT NULL, storage_name TEXT NOT NULL, file_path TEXT NOT NULL, thumbnail_path TEXT NOT NULL, type TEXT NOT NULL, mime_type TEXT NOT NULL, size INTEGER NOT NULL, width INTEGER, height INTEGER, duration INTEGER, sha256_hash TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);
        -- 笔记表：与媒体项一对一
        CREATE TABLE IF NOT EXISTS notes (id TEXT PRIMARY KEY, media_id TEXT NOT NULL, content TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE);
        -- 保证一个媒体项只有一条笔记
        CREATE UNIQUE INDEX IF NOT EXISTS idx_notes_media_id_unique ON notes(media_id);
        -- 标签表：支持层级关系与颜色
        CREATE TABLE IF NOT EXISTS tags (id TEXT PRIMARY KEY, name TEXT NOT NULL, color TEXT, parent_id TEXT, created_at INTEGER NOT NULL, FOREIGN KEY (parent_id) REFERENCES tags(id) ON DELETE CASCADE);
        -- 相册与媒体项关联表
        CREATE TABLE IF NOT EXISTS album_media (album_id TEXT NOT NULL, media_id TEXT NOT NULL, added_at INTEGER NOT NULL, PRIMARY KEY (album_id, media_id), FOREIGN KEY (album_id) REFERENCES albums(id) ON DELETE CASCADE, FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE);
        -- 媒体项与标签关联表
        CREATE TABLE IF NOT EXISTS media_tags (media_id TEXT NOT NULL, tag_id TEXT NOT NULL, created_at INTEGER NOT NULL, PRIMARY KEY (media_id, tag_id), FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE, FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE);
        -- 应用设置表：仅允许 id=1 的单行
        CREATE TABLE IF NOT EXISTS app_settings (id INTEGER PRIMARY KEY CHECK (id = 1), theme_mode INTEGER NOT NULL DEFAULT 0, grid_columns INTEGER NOT NULL DEFAULT 3, album_grid_columns INTEGER NOT NULL DEFAULT 2, thumbnail_quality INTEGER NOT NULL DEFAULT 85, language TEXT NOT NULL DEFAULT 'system', dynamic_color INTEGER NOT NULL DEFAULT 1, last_scan_path TEXT NOT NULL DEFAULT '');
        -- 媒体项创建时间索引
        CREATE INDEX IF NOT EXISTS idx_media_created_at ON media_items(created_at);
        -- 媒体项类型索引
        CREATE INDEX IF NOT EXISTS idx_media_type ON media_items(type);
        -- 媒体项 sha256 唯一索引
        CREATE UNIQUE INDEX IF NOT EXISTS idx_media_sha256 ON media_items(sha256_hash);
        -- 相册父级索引
        CREATE INDEX IF NOT EXISTS idx_albums_parent_id ON albums(parent_id);
        -- 标签父级索引
        CREATE INDEX IF NOT EXISTS idx_tags_parent_id ON tags(parent_id);
        -- 笔记媒体索引
        CREATE INDEX IF NOT EXISTS idx_notes_media_id ON notes(media_id);
        -- 插入默认设置，若已存在则忽略
        INSERT OR IGNORE INTO app_settings (id, theme_mode, grid_columns, album_grid_columns, thumbnail_quality, language, dynamic_color) VALUES (1, 0, 3, 2, 85, 'zh', 1);
    )SQL";
    // 错误信息指针
    char* err = nullptr;
    // 执行建表 SQL
    int rc = sqlite3_exec(db_, sql, nullptr, nullptr, &err);
    // 失败则释放错误信息并返回错误码
    if (rc != SQLITE_OK) { if (err) sqlite3_free(err); return rc; }
    // 对旧数据库做兼容性升级：若不存在 dynamic_color 列则添加
    sqlite3_exec(db_, "ALTER TABLE app_settings ADD COLUMN dynamic_color INTEGER NOT NULL DEFAULT 1", nullptr, nullptr, nullptr);
    // 对旧数据库做兼容性升级：若不存在 last_scan_path 列则添加
    sqlite3_exec(db_, "ALTER TABLE app_settings ADD COLUMN last_scan_path TEXT NOT NULL DEFAULT ''", nullptr, nullptr, nullptr);
    // 返回成功
    return SQLITE_OK;
}

/**
 * @brief 将当前 sqlite3_stmt 的一行转换为 MediaItem 结构体
 * 列顺序必须与 SELECT * FROM media_items 一致。
 */
MediaItem Database::row_to_media_item(sqlite3_stmt* s) {
    MediaItem m;
    // 第 0 列：id
    m.id = reinterpret_cast<const char*>(sqlite3_column_text(s, 0));
    // 第 1 列：原始文件名
    m.original_name = reinterpret_cast<const char*>(sqlite3_column_text(s, 1));
    // 第 2 列：存储文件名
    m.storage_name = reinterpret_cast<const char*>(sqlite3_column_text(s, 2));
    // 第 3 列：文件路径
    m.file_path = reinterpret_cast<const char*>(sqlite3_column_text(s, 3));
    // 第 4 列：缩略图路径
    m.thumbnail_path = reinterpret_cast<const char*>(sqlite3_column_text(s, 4));
    // 第 5 列：媒体类型
    m.media_type = reinterpret_cast<const char*>(sqlite3_column_text(s, 5));
    // 第 6 列：MIME 类型
    m.mime_type = reinterpret_cast<const char*>(sqlite3_column_text(s, 6));
    // 第 7 列：文件大小
    m.size = sqlite3_column_int64(s, 7);
    // 第 8 列：宽度（可为 NULL）
    if (sqlite3_column_type(s, 8) != SQLITE_NULL) m.width = sqlite3_column_int(s, 8);
    // 第 9 列：高度（可为 NULL）
    if (sqlite3_column_type(s, 9) != SQLITE_NULL) m.height = sqlite3_column_int(s, 9);
    // 第 10 列：时长（可为 NULL）
    if (sqlite3_column_type(s, 10) != SQLITE_NULL) m.duration = sqlite3_column_int64(s, 10);
    // 第 11 列：sha256 哈希
    m.sha256_hash = reinterpret_cast<const char*>(sqlite3_column_text(s, 11));
    // 第 12 列：创建时间
    m.created_at = sqlite3_column_int64(s, 12);
    // 第 13 列：更新时间
    m.updated_at = sqlite3_column_int64(s, 13);
// 返回构造完成的媒体项
    return m;
}

/**
 * @brief 将当前 sqlite3_stmt 的一行转换为 Album 结构体
 */
Album Database::row_to_album(sqlite3_stmt* s) {
    Album a;
    // 第 0 列：id
    a.id = reinterpret_cast<const char*>(sqlite3_column_text(s, 0));
    // 第 1 列：相册名称
    a.name = reinterpret_cast<const char*>(sqlite3_column_text(s, 1));
    // 第 2 列：父相册 id（可为 NULL）
    if (sqlite3_column_type(s, 2) != SQLITE_NULL) a.parent_id = reinterpret_cast<const char*>(sqlite3_column_text(s, 2));
    // 第 3 列：封面媒体 id（可为 NULL）
    if (sqlite3_column_type(s, 3) != SQLITE_NULL) a.cover_media_id = reinterpret_cast<const char*>(sqlite3_column_text(s, 3));
    // 第 4 列：排序号
    a.sort_order = sqlite3_column_int(s, 4);
    // 第 5 列：创建时间
    a.created_at = sqlite3_column_int64(s, 5);
    return a;
}

/**
 * @brief 将当前 sqlite3_stmt 的一行转换为 Tag 结构体
 */
Tag Database::row_to_tag(sqlite3_stmt* s) {
    Tag t;
    // 第 0 列：id
    t.id = reinterpret_cast<const char*>(sqlite3_column_text(s, 0));
    // 第 1 列：标签名
    t.name = reinterpret_cast<const char*>(sqlite3_column_text(s, 1));
    // 第 2 列：颜色（可为 NULL）
    if (sqlite3_column_type(s, 2) != SQLITE_NULL) t.color = reinterpret_cast<const char*>(sqlite3_column_text(s, 2));
    // 第 3 列：父标签 id（可为 NULL）
    if (sqlite3_column_type(s, 3) != SQLITE_NULL) t.parent_id = reinterpret_cast<const char*>(sqlite3_column_text(s, 3));
    // 第 4 列：创建时间
    t.created_at = sqlite3_column_int64(s, 4);
    // 返回构造完成的标签
    return t;
}

/**
 * @brief 将当前 sqlite3_stmt 的一行转换为 Note 结构体
 */
Note Database::row_to_note(sqlite3_stmt* s) {
    Note n;
    // 第 0 列：id
    n.id = reinterpret_cast<const char*>(sqlite3_column_text(s, 0));
    // 第 1 列：关联媒体 id
    n.media_id = reinterpret_cast<const char*>(sqlite3_column_text(s, 1));
    // 第 2 列：笔记内容
    n.content = reinterpret_cast<const char*>(sqlite3_column_text(s, 2));
    // 第 3 列：创建时间
    n.created_at = sqlite3_column_int64(s, 3);
    // 第 4 列：更新时间
    n.updated_at = sqlite3_column_int64(s, 4);
    // 返回构造完成的笔记
    return n;
}

// ===== Settings =====

/**
 * @brief 读取应用设置
 * 从 app_settings 表读取 id=1 的单行记录。
 */
AppSettings Database::get_settings() {
    // 加锁保护数据库访问
    std::lock_guard<std::mutex> lock(mutex_);
    // 默认构造设置对象
    AppSettings s;
    // SQL 语句指针
    sqlite3_stmt* stmt;
    // 准备查询 id=1 的设置
    sqlite3_prepare_v2(db_, "SELECT * FROM app_settings WHERE id = 1", -1, &stmt, nullptr);
    // 执行并读取一行
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        // 第 1 列：主题模式
        s.theme_mode = sqlite3_column_int(stmt, 1);
        // 第 2 列：媒体网格列数
        s.grid_columns = sqlite3_column_int(stmt, 2);
        // 第 3 列：相册网格列数
        s.album_grid_columns = sqlite3_column_int(stmt, 3);
        // 第 4 列：缩略图质量
        s.thumbnail_quality = sqlite3_column_int(stmt, 4);
        // 第 5 列：语言
        s.language = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 5));
        // 第 6 列：动态取色
        s.dynamic_color = sqlite3_column_int(stmt, 6);
        // 第 7 列：上次扫描路径
        s.last_scan_path = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 7));
    }
    // 释放语句资源
    sqlite3_finalize(stmt);
    // 返回设置对象
    return s;
}

/**
 * @brief 保存应用设置
 * 使用 UPSERT 语法，不存在则插入，存在则更新。
 */
int Database::save_settings(const AppSettings& s) {
    // 加锁保护数据库写入
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* stmt;
    // 准备 UPSERT 语句，id 固定为 1
    sqlite3_prepare_v2(db_,
        "INSERT INTO app_settings(id,theme_mode,grid_columns,album_grid_columns,thumbnail_quality,language,dynamic_color,last_scan_path) VALUES(1,?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET theme_mode=excluded.theme_mode,grid_columns=excluded.grid_columns,album_grid_columns=excluded.album_grid_columns,thumbnail_quality=excluded.thumbnail_quality,language=excluded.language,dynamic_color=excluded.dynamic_color,last_scan_path=excluded.last_scan_path",
        -1, &stmt, nullptr);
    // 绑定主题模式
    sqlite3_bind_int(stmt, 1, s.theme_mode);
    // 绑定媒体网格列数
    sqlite3_bind_int(stmt, 2, s.grid_columns);
    // 绑定相册网格列数
    sqlite3_bind_int(stmt, 3, s.album_grid_columns);
    // 绑定缩略图质量
    sqlite3_bind_int(stmt, 4, s.thumbnail_quality);
    // 绑定语言
    bind_text(stmt, 5, s.language);
    // 绑定动态取色
    sqlite3_bind_int(stmt, 6, s.dynamic_color);
    // 绑定上次扫描路径
    bind_text(stmt, 7, s.last_scan_path);
    // 执行 UPSERT
    int rc = sqlite3_step(stmt);
    // 释放语句
    sqlite3_finalize(stmt);
    return rc;
}

/**
 * @brief 获取存储统计信息
 * 包括媒体数量、总大小、数据库文件大小、缩略图缓存大小。
 */
StorageStats Database::get_storage_stats() {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 默认构造统计对象
    StorageStats st;
    // SQL 语句指针
    sqlite3_stmt* stmt;
    // 查询媒体总数与总大小
    sqlite3_prepare_v2(db_, "SELECT COUNT(*),COALESCE(SUM(size),0) FROM media_items", -1, &stmt, nullptr);
    // 读取结果
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        // 第 0 列：媒体总数
        st.total_media_count = sqlite3_column_int(stmt, 0);
        // 第 1 列：总字节数
        st.total_size = sqlite3_column_int64(stmt, 1);
    }
    // 释放语句
    sqlite3_finalize(stmt);
    // 数据库文件路径
    std::string dbp = app_dir_ + "/advance_media_kb.db";
    // 若数据库文件存在，获取其大小
    if (fs::exists(dbp)) st.database_size = fs::file_size(dbp);
    // 缩略图目录路径
    std::string td = app_dir_ + "/media/thumbnails";
    // 遍历目录累加缓存大小
    if (fs::exists(td)) {
        for (auto& e : fs::directory_iterator(td)) {
            if (e.is_regular_file()) st.thumbnail_cache_size += e.file_size();
        }
    }
    return st;
}

/**
 * @brief 清理未引用的缩略图文件
 * 保留 media_items.thumbnail_path 中记录的文件，删除其他文件。
 * 返回删除的文件数量。
 */
int Database::clear_thumbnail_cache() {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 收集所有被引用的缩略图路径
    std::set<std::string> vp;
    // SQL 语句指针
    sqlite3_stmt* stmt;
    // 查询所有非空缩略图路径
    sqlite3_prepare_v2(db_, "SELECT thumbnail_path FROM media_items WHERE thumbnail_path!=''", -1, &stmt, nullptr);
    // 逐行插入集合
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        vp.insert(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0)));
    }
    // 释放语句
    sqlite3_finalize(stmt);
    // 删除计数
    int d = 0;
    // 缩略图目录
    std::string td = app_dir_ + "/media/thumbnails";
    // 遍历目录
    if (fs::exists(td)) {
        for (auto& e : fs::directory_iterator(td)) {
            // 仅处理常规文件，且不在引用集合中
            if (e.is_regular_file() && vp.find(e.path().string()) == vp.end()) {
                // 删除文件
                fs::remove(e.path());
                d++;
            }
        }
    }
    return d;
}

/**
 * @brief 导出数据库到指定路径
 * 使用 SQLite VACUUM INTO 生成一个紧凑副本。
 */
int Database::export_data(const std::string& p) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 错误信息指针
    char* err = nullptr;
    // 构造并执行 VACUUM INTO 'path'
    int rc = sqlite3_exec(db_, ("VACUUM INTO '" + p + "'").c_str(), nullptr, nullptr, &err);
    // 释放错误信息
    if (err) sqlite3_free(err);
    return rc;
}

/**
 * @brief 从指定路径导入数据库
 * 先备份原数据库，再替换，失败则回滚。
 */
int Database::import_data(const std::string& p) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 源文件不存在则返回 -1
    if (!fs::exists(p)) return -1;
    // 目标数据库路径
    std::string dp = app_dir_ + "/advance_media_kb.db";
    // 备份路径
    std::string bp = dp + ".backup";
    // 备份原数据库
    fs::copy_file(dp, bp, fs::copy_options::overwrite_existing);
    // 关闭原数据库连接
    sqlite3_close(db_);
    db_ = nullptr;
    try {
        // 尝试复制新数据库文件
        fs::copy_file(p, dp, fs::copy_options::overwrite_existing);
    } catch (...) {
        // 复制失败则回滚
        fs::copy_file(bp, dp, fs::copy_options::overwrite_existing);
        // 删除备份
        fs::remove(bp);
        // 重新打开原数据库
        sqlite3_open(dp.c_str(), &db_);
        return -1;
    }
    // 删除备份
    fs::remove(bp);
    // 重新打开新数据库
    sqlite3_open(dp.c_str(), &db_);
    // 重新启用外键
    sqlite3_exec(db_, "PRAGMA foreign_keys=ON", nullptr, nullptr, nullptr);
    return SQLITE_OK;
}

/**
 * @brief 删除所有数据并重置设置
 * 清空业务表，并将设置恢复到默认值。
 */
int Database::delete_all_data() {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 错误信息指针
    char* err = nullptr;
    // 依次清空各表并重置设置
    int rc = sqlite3_exec(db_,
        "DELETE FROM media_tags;DELETE FROM album_media;DELETE FROM notes;DELETE FROM media_items;DELETE FROM albums;DELETE FROM tags;UPDATE app_settings SET theme_mode=0,grid_columns=3,album_grid_columns=2,thumbnail_quality=85,language='system',last_scan_path='' WHERE id=1;",
        nullptr, nullptr, &err);
    // 释放错误信息
    if (err) sqlite3_free(err);
    return rc;
}

/**
 * @brief 查找未引用的媒体文件
 * 扫描 media 目录，返回不在 media_items.file_path 中的文件路径。
 */
std::vector<std::string> Database::find_unreferenced_files() {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<std::string> r;
    // 已引用路径集合
    std::set<std::string> vp;
    // SQL 语句指针
    sqlite3_stmt* stmt;
    // 收集已引用文件路径
    sqlite3_prepare_v2(db_, "SELECT file_path FROM media_items", -1, &stmt, nullptr);
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        vp.insert(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0)));
    }
    // 释放语句
    sqlite3_finalize(stmt);
    // 媒体目录路径
    std::string md = app_dir_ + "/media";
    // 目录不存在则返回空列表
    if (!fs::exists(md)) return r;
    // 遍历 media 目录
    for (auto& e : fs::directory_iterator(md)) {
        if (e.is_regular_file()) {
            // 文件完整路径
            auto s = e.path().string();
            // 跳过 thumbnails 子目录
            if (s.find("thumbnails") != std::string::npos) continue;
            // 若未引用则加入结果
            if (vp.find(s) == vp.end()) r.push_back(s);
        }
    }
    return r;
}

/**
 * @brief 删除未引用的媒体文件
 * 调用 find_unreferenced_files 并逐个删除。
 */
int Database::delete_unreferenced_files() {
    // 获取未引用文件列表
    auto f = find_unreferenced_files();
    // 删除计数
    int c = 0;
    // 逐个删除
    for (auto& x : f) {
        if (fs::remove(x)) c++;
    }
    return c;
}

// ===== Media =====
/**
 * @brief 获取所有媒体项
 * 按创建时间降序排列。
 */
std::vector<MediaItem> Database::get_all_media() {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<MediaItem> r;
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备查询所有媒体项，按创建时间降序
    sqlite3_prepare_v2(db_, "SELECT * FROM media_items ORDER BY created_at DESC", -1, &s, nullptr);
    // 逐行读取并转换
    while (sqlite3_step(s) == SQLITE_ROW) r.push_back(row_to_media_item(s));
    // 释放语句
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 按原始文件名模糊搜索媒体
 */
std::vector<MediaItem> Database::search_media(const std::string& q) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<MediaItem> r;
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备 LIKE 查询，按创建时间降序
    sqlite3_prepare_v2(db_, "SELECT * FROM media_items WHERE original_name LIKE ? ORDER BY created_at DESC", -1, &s, nullptr);
    // 绑定包含通配符的查询串
    bind_text(s, 1, "%" + q + "%");
    // 逐行读取
    while (sqlite3_step(s) == SQLITE_ROW) r.push_back(row_to_media_item(s));
    // 释放语句
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 按类型过滤媒体
 */
std::vector<MediaItem> Database::filter_media_by_type(const std::string& t) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<MediaItem> r;
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备按类型查询
    sqlite3_prepare_v2(db_, "SELECT * FROM media_items WHERE type=? ORDER BY created_at DESC", -1, &s, nullptr);
    // 绑定类型
    bind_text(s, 1, t);
    // 逐行读取
    while (sqlite3_step(s) == SQLITE_ROW) r.push_back(row_to_media_item(s));
    // 释放语句
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 按 id 获取单个媒体项
 */
std::optional<MediaItem> Database::get_media_by_id(const std::string& id) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备按 id 查询
    sqlite3_prepare_v2(db_, "SELECT * FROM media_items WHERE id=?", -1, &s, nullptr);
    // 绑定 id
    bind_text(s, 1, id);
    // 可选结果
    std::optional<MediaItem> r;
    // 若存在记录则转换
    if (sqlite3_step(s) == SQLITE_ROW) r = row_to_media_item(s);
    // 释放语句
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 删除指定媒体项
 */
int Database::delete_media(const std::string& id) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备删除语句
    sqlite3_prepare_v2(db_, "DELETE FROM media_items WHERE id=?", -1, &s, nullptr);
    // 绑定 id
    bind_text(s, 1, id);
    // 执行
    int rc = sqlite3_step(s);
    // 释放语句
    sqlite3_finalize(s);
    return rc;
}

/**
 * @brief 更新媒体项元数据
 * 可更新原始名、缩略图路径、尺寸、大小等。
 */
int Database::update_media(const MediaItem& m) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备更新语句
    sqlite3_prepare_v2(db_, "UPDATE media_items SET original_name=?,thumbnail_path=?,size=?,width=?,height=?,updated_at=? WHERE id=?", -1, &s, nullptr);
    // 绑定原始文件名
    bind_text(s, 1, m.original_name);
    // 绑定缩略图路径
    bind_text(s, 2, m.thumbnail_path);
    // 绑定文件大小
    sqlite3_bind_int64(s, 3, m.size);
    // 绑定宽度，若存在
    if (m.width) sqlite3_bind_int(s, 4, *m.width);
    else sqlite3_bind_null(s, 4);
    // 绑定高度，若存在
    if (m.height) sqlite3_bind_int(s, 5, *m.height);
    else sqlite3_bind_null(s, 5);
    // 绑定当前时间戳到 updated_at
    sqlite3_bind_int64(s, 6, current_timestamp_ms());
    // 绑定 id
    bind_text(s, 7, m.id);
    // 执行
    int rc = sqlite3_step(s);
    // 释放语句
    sqlite3_finalize(s);
    return rc;
}

/**
 * @brief 将文件名中的非法字符替换为下划线
 * 保证复制到目标目录的文件名安全。
 */
static std::string sanitize_filename(const std::string& name) {
    // 复制输入
    std::string r = name;
    // 遍历每个字符
    for (auto& c : r) {
        // 若字符为 / \ 空格或 Windows 非法字符，替换为 '_'
        if (c == '/' || c == '\\' || c == ' ' || c == '?' || c == '*' || c == '<' || c == '>' || c == '|' || c == '"') c = '_';
    }
    return r;
}

/**
 * @brief 生成当前时间戳文件名后缀
 * 格式：YYYYMMDD_HHMMSS
 */
static std::string format_timestamp_filename() {
    // 获取当前系统时间点
    auto now_tp = std::chrono::system_clock::now();
    // 转换为 time_t
    auto now_t = std::chrono::system_clock::to_time_t(now_tp);
    // 本地时间缓冲区
    struct tm tm_buf;
    // 线程安全地转换为本地时间
#ifdef _WIN32
    localtime_s(&tm_buf, &now_t);
#else
    localtime_r(&now_t, &tm_buf);
#endif
    // 格式化缓冲区
    char buf[32];
    // 按格式写入
    strftime(buf, sizeof(buf), "%Y%m%d_%H%M%S", &tm_buf);
    return std::string(buf);
}

/**
 * @brief 获取或创建默认相册
 * 用于导入媒体时自动归类。
 */
static std::string get_or_create_default_album(sqlite3* database) {
    // SQL 语句指针
    sqlite3_stmt* s;
    // 查询名为“默认相册”且没有父相册的记录
    sqlite3_prepare_v2(database, "SELECT id FROM albums WHERE name='默认相册' AND parent_id IS NULL LIMIT 1", -1, &s, nullptr);
    // 默认相册 id
    std::string id;
    // 若已存在则读取 id
    if (sqlite3_step(s) == SQLITE_ROW) {
        id = reinterpret_cast<const char*>(sqlite3_column_text(s, 0));
    }
    // 释放语句
    sqlite3_finalize(s);
    // 若不存在则创建
    if (id.empty()) {
        // 生成新 UUID
        id = generate_uuid();
        // 当前时间戳
        auto ts = current_timestamp_ms();
        // 准备插入
        sqlite3_prepare_v2(database, "INSERT INTO albums(id,name,created_at) VALUES(?,?,?)", -1, &s, nullptr);
        // 绑定 id
        bind_text(s, 1, id);
        // 绑定名称
        bind_text(s, 2, std::string("默认相册"));
        // 绑定时间戳
        sqlite3_bind_int64(s, 3, ts);
        // 执行
        sqlite3_step(s);
        // 释放
        sqlite3_finalize(s);
    }
    return id;
}

/**
 * @brief 获取或创建默认标签
 * 用于导入媒体时自动打标签。
 */
static std::string get_or_create_default_tag(sqlite3* database) {
    // SQL 语句指针
    sqlite3_stmt* s;
    // 查询名为“默认标签”的记录
    sqlite3_prepare_v2(database, "SELECT id FROM tags WHERE name='默认标签' LIMIT 1", -1, &s, nullptr);
    // 默认标签 id
    std::string id;
    // 若已存在则读取
    if (sqlite3_step(s) == SQLITE_ROW) {
        id = reinterpret_cast<const char*>(sqlite3_column_text(s, 0));
    }
    // 释放语句
    sqlite3_finalize(s);
    // 若不存在则创建
    if (id.empty()) {
        // 生成新 UUID
        id = generate_uuid();
        // 当前时间戳
        auto ts = current_timestamp_ms();
        // 准备插入
        sqlite3_prepare_v2(database, "INSERT INTO tags(id,name,color,created_at) VALUES(?,?,?,?)", -1, &s, nullptr);
        // 绑定 id
        bind_text(s, 1, id);
        // 绑定名称
        bind_text(s, 2, std::string("默认标签"));
        // 绑定颜色
        bind_text(s, 3, std::string("#FF6750A4"));
        // 绑定时间戳
        sqlite3_bind_int64(s, 4, ts);
        // 执行
        sqlite3_step(s);
        // 释放
        sqlite3_finalize(s);
    }
    return id;
}

/**
 * @brief 导入单个媒体文件
 * 将文件复制到应用目录，创建缩略图占位，并插入数据库。
 * 导入后会自动关联到默认相册和默认标签。
 */
// to_path() 辅助函数已定义于匿名命名空间内（init 之前），
// 这里仅调用 to_path() 来避免 Windows 上的 ANSI 路径解析问题。

int Database::import_media(const std::string& fp, const std::string& ad) {
    // 源文件不存在则返回 -1
    fs::path src = to_path(fp);
    if (!fs::exists(src)) return -1;
    // 提取扩展名、媒体类型、MIME 类型
    std::string ext = get_extension(fp);
    std::string mt = detect_media_type(ext);
    std::string mime = detect_mime_type(ext);
    // 当前时间戳
    auto now = current_timestamp_ms();
    // 生成媒体 UUID
    std::string id = generate_uuid();
    // 原文件名
    std::string on = src.filename().string();
    // 文件命名：原文件名_导入时间.扩展名
    std::string stem = sanitize_filename(src.stem().string());
    std::string time_str = format_timestamp_filename();
    std::string sn = stem + "_" + time_str + "." + ext;
    // 防止重名
    std::string dp = ad + "/media/" + sn;
    int counter = 1;
    fs::path dst = to_path(dp);
    while (fs::exists(dst)) {
        sn = stem + "_" + time_str + "_" + std::to_string(counter) + "." + ext;
        dp = ad + "/media/" + sn;
        dst = to_path(dp);
        counter++;
    }
    // 缩略图路径：图片类型直接用原文件路径，非图片创建空占位
    std::string tp;
    if (mt == "image") {
        tp = dp;  // 图片直接用存储路径作为缩略图
    } else {
        tp = ad + "/media/thumbnails/" + generate_uuid() + ".jpg";
        fs::path thumb_path = to_path(tp);
        { std::ofstream th(thumb_path.string()); th << ""; }
    }
    // 复制文件到目标目录
    fs::copy_file(src, dst, fs::copy_options::overwrite_existing);
    // 加锁保护数据库写入
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备插入媒体项
    sqlite3_prepare_v2(db_, "INSERT INTO media_items(id,original_name,storage_name,file_path,thumbnail_path,type,mime_type,size,sha256_hash,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)", -1, &s, nullptr);
    // 绑定 id
    bind_text(s, 1, id);
    // 绑定原文件名
    bind_text(s, 2, on);
    // 绑定存储文件名
    bind_text(s, 3, sn);
    // 绑定文件路径
    bind_text(s, 4, dp);
    // 绑定缩略图路径
    bind_text(s, 5, tp);
    // 绑定媒体类型
    bind_text(s, 6, mt);
    // 绑定 MIME 类型
    bind_text(s, 7, mime);
    // 绑定文件大小
    sqlite3_bind_int64(s, 8, (int64_t)fs::file_size(src));
    // 绑定占位哈希
    bind_text(s, 9, "hash_" + id);
    // 绑定创建时间
    sqlite3_bind_int64(s, 10, now);
    // 绑定更新时间
    sqlite3_bind_int64(s, 11, now);
    // 执行插入
    int rc = sqlite3_step(s);
    // 释放语句
    sqlite3_finalize(s);
    // 导入成功后不再自动分配到默认相册和默认标签
    // 用户可以手动将媒体添加到相册或标签
    return rc;
}

/**
 * @brief 获取相邻媒体项
 * 返回当前媒体按时间顺序的前一条和后一条。
 */
std::vector<MediaItem> Database::get_adjacent_media(const std::string& id) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<MediaItem> r;
    // SQL 语句指针
    sqlite3_stmt* s;
    // 查询创建时间比当前媒体早的最近一条（上一条）
    sqlite3_prepare_v2(db_, "SELECT * FROM media_items WHERE created_at<(SELECT created_at FROM media_items WHERE id=?) ORDER BY created_at DESC LIMIT 1", -1, &s, nullptr);
    bind_text(s, 1, id);
    if (sqlite3_step(s) == SQLITE_ROW) r.push_back(row_to_media_item(s));
    sqlite3_finalize(s);
    // 查询创建时间比当前媒体晚的最近一条（下一条）
    sqlite3_prepare_v2(db_, "SELECT * FROM media_items WHERE created_at>(SELECT created_at FROM media_items WHERE id=?) ORDER BY created_at ASC LIMIT 1", -1, &s, nullptr);
    bind_text(s, 1, id);
    if (sqlite3_step(s) == SQLITE_ROW) r.push_back(row_to_media_item(s));
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 按筛选字符串获取媒体
 * 特殊值：image/video/audio/document/other，其他则返回全部。
 */
std::vector<MediaItem> Database::get_media_by_filter(const std::string& f) {
    // 图片过滤
    if (f == "image") return filter_media_by_type("image");
    // 视频过滤
    if (f == "video") return filter_media_by_type("video");
    // 音频过滤
    if (f == "audio") return filter_media_by_type("audio");
    // 文档过滤
    if (f == "document") return filter_media_by_type("document");
    // 其他类型过滤
    if (f == "other") return filter_media_by_type("other");
    // 默认返回全部
    return get_all_media();
}

// ===== Albums =====
/**
 * @brief 获取根相册
 * 返回 parent_id 为 NULL 的相册，并附带媒体数量与封面路径。
 */
std::vector<AlbumWithInfo> Database::get_root_albums() {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<AlbumWithInfo> r;
    // SQL 语句指针
    sqlite3_stmt* s;
    // 查询根相册，附带子查询统计媒体数和封面路径
    sqlite3_prepare_v2(db_,
        "SELECT a.*,(SELECT COUNT(*) FROM album_media WHERE album_id=a.id),(SELECT thumbnail_path FROM media_items WHERE id=a.cover_media_id) FROM albums a WHERE a.parent_id IS NULL ORDER BY a.sort_order,a.created_at DESC",
        -1, &s, nullptr);
    // 逐行读取
    while (sqlite3_step(s) == SQLITE_ROW) {
        AlbumWithInfo i;
        // 转换相册基础字段
        i.album = row_to_album(s);
        // 第 6 列：媒体数量
        i.media_count = sqlite3_column_int(s, 6);
        // 第 7 列：封面路径（可为 NULL）
        if (sqlite3_column_type(s, 7) != SQLITE_NULL) i.cover_path = reinterpret_cast<const char*>(sqlite3_column_text(s, 7));
        // 加入结果
        r.push_back(i);
    }
    // 释放语句
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 获取子相册
 * @param pid 父相册 id
 */
std::vector<AlbumWithInfo> Database::get_child_albums(const std::string& pid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<AlbumWithInfo> r;
    // SQL 语句指针
    sqlite3_stmt* s;
    // 查询指定父相册下的相册
    sqlite3_prepare_v2(db_,
        "SELECT a.*,(SELECT COUNT(*) FROM album_media WHERE album_id=a.id),(SELECT thumbnail_path FROM media_items WHERE id=a.cover_media_id) FROM albums a WHERE a.parent_id=? ORDER BY a.sort_order,a.created_at DESC",
        -1, &s, nullptr);
    // 绑定父相册 id
    bind_text(s, 1, pid);
    // 逐行读取
    while (sqlite3_step(s) == SQLITE_ROW) {
        AlbumWithInfo i;
        i.album = row_to_album(s);
        i.media_count = sqlite3_column_int(s, 6);
        if (sqlite3_column_type(s, 7) != SQLITE_NULL) i.cover_path = reinterpret_cast<const char*>(sqlite3_column_text(s, 7));
        r.push_back(i);
    }
    // 释放语句
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 创建相册
 * @param n 相册名称
 * @param pid 父相册 id（可选）
 * @return 新相册 id
 */
std::string Database::create_album(const std::string& n, const std::optional<std::string>& pid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 生成新 UUID
    std::string id = generate_uuid();
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备插入
    sqlite3_prepare_v2(db_, "INSERT INTO albums(id,name,parent_id,created_at) VALUES(?,?,?,?)", -1, &s, nullptr);
    // 绑定 id
    bind_text(s, 1, id);
    // 绑定名称
    bind_text(s, 2, n);
    // 绑定父相册 id（可选）
    bind_opt_text(s, 3, pid);
    // 绑定创建时间
    sqlite3_bind_int64(s, 4, current_timestamp_ms());
    // 执行
    sqlite3_step(s);
    // 释放
    sqlite3_finalize(s);
    return id;
}

/**
 * @brief 删除相册
 */
int Database::delete_album(const std::string& id) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备删除语句
    sqlite3_prepare_v2(db_, "DELETE FROM albums WHERE id=?", -1, &s, nullptr);
    // 绑定 id
    bind_text(s, 1, id);
    // 执行
    int rc = sqlite3_step(s);
    // 释放
    sqlite3_finalize(s);
    return rc;
}

/**
 * @brief 重命名相册
 */
int Database::rename_album(const std::string& id, const std::string& n) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备更新语句
    sqlite3_prepare_v2(db_, "UPDATE albums SET name=? WHERE id=?", -1, &s, nullptr);
    // 绑定新名称
    bind_text(s, 1, n);
    // 绑定 id
    bind_text(s, 2, id);
    // 执行
    int rc = sqlite3_step(s);
    // 释放
    sqlite3_finalize(s);
    return rc;
}

/**
 * @brief 批量添加媒体到相册
 */
int Database::add_media_to_album(const std::vector<std::string>& mids, const std::string& aid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备插入或忽略语句
    sqlite3_prepare_v2(db_, "INSERT OR IGNORE INTO album_media(album_id,media_id,added_at) VALUES(?,?,?)", -1, &s, nullptr);
    // 遍历所有媒体 id
    for (auto& m : mids) {
        // 重置语句
        sqlite3_reset(s);
        // 绑定相册 id
        bind_text(s, 1, aid);
        // 绑定媒体 id
        bind_text(s, 2, m);
        // 绑定添加时间
        sqlite3_bind_int64(s, 3, current_timestamp_ms());
        // 执行
        sqlite3_step(s);
    }
    // 释放
    sqlite3_finalize(s);
    return 0;
}

/**
 * @brief 批量从相册移除媒体
 */
int Database::remove_media_from_album(const std::vector<std::string>& mids, const std::string& aid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备删除语句
    sqlite3_prepare_v2(db_, "DELETE FROM album_media WHERE album_id=? AND media_id=?", -1, &s, nullptr);
    // 遍历所有媒体 id
    for (auto& m : mids) {
        // 重置语句
        sqlite3_reset(s);
        // 绑定相册 id
        bind_text(s, 1, aid);
        // 绑定媒体 id
        bind_text(s, 2, m);
        // 执行
        sqlite3_step(s);
    }
    // 释放
    sqlite3_finalize(s);
    return 0;
}

/**
 * @brief 设置相册封面
 */
int Database::set_album_cover(const std::string& aid, const std::string& mid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备更新封面
    sqlite3_prepare_v2(db_, "UPDATE albums SET cover_media_id=? WHERE id=?", -1, &s, nullptr);
    // 绑定媒体 id
    bind_text(s, 1, mid);
    // 绑定相册 id
    bind_text(s, 2, aid);
    // 执行
    int rc = sqlite3_step(s);
    // 释放
    sqlite3_finalize(s);
    return rc;
}

/**
 * @brief 获取相册面包屑路径
 * 从当前相册向上追溯至根相册。
 */
std::vector<BreadcrumbItem> Database::get_album_breadcrumb(const std::string& aid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<BreadcrumbItem> r;
    // 当前节点 id
    std::string cur = aid;
    // 循环向上追溯
    while (!cur.empty()) {
        // SQL 语句指针
        sqlite3_stmt* s;
        // 查询当前相册
        sqlite3_prepare_v2(db_, "SELECT id,name,parent_id FROM albums WHERE id=?", -1, &s, nullptr);
        // 绑定当前 id
        bind_text(s, 1, cur);
        // 若存在记录
        if (sqlite3_step(s) == SQLITE_ROW) {
            BreadcrumbItem i;
            // 读取 id
            i.id = reinterpret_cast<const char*>(sqlite3_column_text(s, 0));
            // 读取名称
            i.name = reinterpret_cast<const char*>(sqlite3_column_text(s, 1));
            // 插入到结果头部
            r.insert(r.begin(), i);
            // 读取父相册 id
            cur = sqlite3_column_type(s, 2) != SQLITE_NULL ? reinterpret_cast<const char*>(sqlite3_column_text(s, 2)) : std::string();
        } else {
            // 记录不存在则终止
            cur.clear();
        }
        // 释放语句
        sqlite3_finalize(s);
    }
    return r;
}

/**
 * @brief 获取相册内的所有媒体
 */
std::vector<MediaItem> Database::get_media_by_album(const std::string& aid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<MediaItem> r;
    // SQL 语句指针
    sqlite3_stmt* s;
    // 联表查询相册内的媒体，按添加时间降序
    sqlite3_prepare_v2(db_,
        "SELECT m.* FROM media_items m JOIN album_media am ON m.id=am.media_id WHERE am.album_id=? ORDER BY am.added_at DESC",
        -1, &s, nullptr);
    // 绑定相册 id
    bind_text(s, 1, aid);
    // 逐行读取
    while (sqlite3_step(s) == SQLITE_ROW) r.push_back(row_to_media_item(s));
    // 释放
    sqlite3_finalize(s);
    return r;
}

// ===== Tags =====
/**
 * @brief 获取所有标签
 * 按标签名称升序排列。
 */
std::vector<Tag> Database::get_all_tags() {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<Tag> r;
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备查询
    sqlite3_prepare_v2(db_, "SELECT * FROM tags ORDER BY name", -1, &s, nullptr);
    // 逐行读取
    while (sqlite3_step(s) == SQLITE_ROW) r.push_back(row_to_tag(s));
    // 释放
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 获取根标签
 * 返回 parent_id 为 NULL 的标签，并附带媒体数量。
 */
std::vector<TagWithInfo> Database::get_root_tags() {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<TagWithInfo> r;
    // SQL 语句指针
    sqlite3_stmt* s;
    // 查询根标签，附带子查询统计媒体数
    sqlite3_prepare_v2(db_,
        "SELECT t.*,(SELECT COUNT(*) FROM media_tags WHERE tag_id=t.id) FROM tags t WHERE t.parent_id IS NULL ORDER BY t.name",
        -1, &s, nullptr);
    // 逐行读取
    while (sqlite3_step(s) == SQLITE_ROW) {
        TagWithInfo i;
        // 转换标签基础字段
        i.tag = row_to_tag(s);
        // 第 5 列：媒体数量
        i.media_count = sqlite3_column_int(s, 5);
        // 加入结果
        r.push_back(i);
    }
    // 释放
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 获取子标签
 * @param pid 父标签 id
 */
std::vector<TagWithInfo> Database::get_child_tags(const std::string& pid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<TagWithInfo> r;
    // SQL 语句指针
    sqlite3_stmt* s;
    // 查询指定父标签下的标签
    sqlite3_prepare_v2(db_,
        "SELECT t.*,(SELECT COUNT(*) FROM media_tags WHERE tag_id=t.id) FROM tags t WHERE t.parent_id=? ORDER BY t.name",
        -1, &s, nullptr);
    // 绑定父标签 id
    bind_text(s, 1, pid);
    // 逐行读取
    while (sqlite3_step(s) == SQLITE_ROW) {
        TagWithInfo i;
        i.tag = row_to_tag(s);
        i.media_count = sqlite3_column_int(s, 5);
        r.push_back(i);
    }
    // 释放
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 创建标签
 * @param n 标签名称
 * @param c 标签颜色（可选）
 * @param pid 父标签 id（可选）
 * @return 新标签 id
 */
std::string Database::create_tag(const std::string& n, const std::optional<std::string>& c, const std::optional<std::string>& pid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 生成新 UUID
    std::string id = generate_uuid();
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备插入
    sqlite3_prepare_v2(db_, "INSERT INTO tags(id,name,color,parent_id,created_at) VALUES(?,?,?,?,?)", -1, &s, nullptr);
    // 绑定 id
    bind_text(s, 1, id);
    // 绑定名称
    bind_text(s, 2, n);
    // 绑定颜色（可选）
    bind_opt_text(s, 3, c);
    // 绑定父标签 id（可选）
    bind_opt_text(s, 4, pid);
    // 绑定创建时间
    sqlite3_bind_int64(s, 5, current_timestamp_ms());
    // 执行
    sqlite3_step(s);
    // 释放
    sqlite3_finalize(s);
    return id;
}

/**
 * @brief 删除标签
 */
int Database::delete_tag(const std::string& id) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备删除
    sqlite3_prepare_v2(db_, "DELETE FROM tags WHERE id=?", -1, &s, nullptr);
    // 绑定 id
    bind_text(s, 1, id);
    // 执行
    int rc = sqlite3_step(s);
    // 释放
    sqlite3_finalize(s);
    return rc;
}

/**
 * @brief 重命名标签
 */
int Database::rename_tag(const std::string& id, const std::string& n) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备更新
    sqlite3_prepare_v2(db_, "UPDATE tags SET name=? WHERE id=?", -1, &s, nullptr);
    // 绑定新名称
    bind_text(s, 1, n);
    // 绑定 id
    bind_text(s, 2, id);
    // 执行
    int rc = sqlite3_step(s);
    // 释放
    sqlite3_finalize(s);
    return rc;
}

/**
 * @brief 更新标签颜色
 */
int Database::update_tag_color(const std::string& id, const std::string& c) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备更新颜色
    sqlite3_prepare_v2(db_, "UPDATE tags SET color=? WHERE id=?", -1, &s, nullptr);
    // 绑定颜色
    bind_text(s, 1, c);
    // 绑定 id
    bind_text(s, 2, id);
    // 执行
    int rc = sqlite3_step(s);
    // 释放
    sqlite3_finalize(s);
    return rc;
}

/**
 * @brief 更新标签父级
 */
int Database::update_tag_parent(const std::string& id, const std::optional<std::string>& pid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备更新父标签
    sqlite3_prepare_v2(db_, "UPDATE tags SET parent_id=? WHERE id=?", -1, &s, nullptr);
    // 绑定父标签 id（可选）
    bind_opt_text(s, 1, pid);
    // 绑定 id
    bind_text(s, 2, id);
    // 执行
    int rc = sqlite3_step(s);
    // 释放
    sqlite3_finalize(s);
    return rc;
}

/**
 * @brief 给媒体添加标签
 */
int Database::add_tag_to_media(const std::string& mid, const std::string& tid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备插入或忽略
    sqlite3_prepare_v2(db_, "INSERT OR IGNORE INTO media_tags(media_id,tag_id,created_at) VALUES(?,?,?)", -1, &s, nullptr);
    // 绑定媒体 id
    bind_text(s, 1, mid);
    // 绑定标签 id
    bind_text(s, 2, tid);
    // 绑定创建时间
    sqlite3_bind_int64(s, 3, current_timestamp_ms());
    // 执行
    int rc = sqlite3_step(s);
    // 释放
    sqlite3_finalize(s);
    return rc;
}

/**
 * @brief 从媒体移除标签
 */
int Database::remove_tag_from_media(const std::string& mid, const std::string& tid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备删除
    sqlite3_prepare_v2(db_, "DELETE FROM media_tags WHERE media_id=? AND tag_id=?", -1, &s, nullptr);
    // 绑定媒体 id
    bind_text(s, 1, mid);
    // 绑定标签 id
    bind_text(s, 2, tid);
    // 执行
    int rc = sqlite3_step(s);
    // 释放
    sqlite3_finalize(s);
    return rc;
}

/**
 * @brief 获取媒体的所有标签
 */
std::vector<Tag> Database::get_media_tags(const std::string& mid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<Tag> r;
    // SQL 语句指针
    sqlite3_stmt* s;
    // 联表查询媒体关联的标签，按名称排序
    sqlite3_prepare_v2(db_,
        "SELECT t.* FROM tags t JOIN media_tags mt ON t.id=mt.tag_id WHERE mt.media_id=? ORDER BY t.name",
        -1, &s, nullptr);
    // 绑定媒体 id
    bind_text(s, 1, mid);
    // 逐行读取
    while (sqlite3_step(s) == SQLITE_ROW) r.push_back(row_to_tag(s));
    // 释放
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 按标签 AND 条件查询媒体
 * 返回同时包含所有指定标签的媒体。
 */
std::vector<MediaItem> Database::get_media_by_tags_and(const std::vector<std::string>& tids) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<MediaItem> r;
    // 空标签列表直接返回
    if (tids.empty()) return r;
    // 动态构造 SQL
    std::string sql = "SELECT m.* FROM media_items m WHERE ";
    for (size_t i = 0; i < tids.size(); i++) {
        if (i) sql += " AND ";
        sql += "EXISTS(SELECT 1 FROM media_tags WHERE media_id=m.id AND tag_id=?)";
    }
    sql += " ORDER BY m.created_at DESC";
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备查询
    sqlite3_prepare_v2(db_, sql.c_str(), -1, &s, nullptr);
    // 绑定所有标签 id
    for (size_t i = 0; i < tids.size(); i++) bind_text(s, static_cast<int>(i + 1), tids[i]);
    // 逐行读取
    while (sqlite3_step(s) == SQLITE_ROW) r.push_back(row_to_media_item(s));
    // 释放
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 按标签 OR 条件查询媒体
 * 返回包含任意一个指定标签的媒体。
 */
std::vector<MediaItem> Database::get_media_by_tags_or(const std::vector<std::string>& tids) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<MediaItem> r;
    // 空标签列表直接返回
    if (tids.empty()) return r;
    // 动态构造 SQL IN 子句
    std::string sql = "SELECT DISTINCT m.* FROM media_items m JOIN media_tags mt ON m.id=mt.media_id WHERE mt.tag_id IN (";
    for (size_t i = 0; i < tids.size(); i++) {
        if (i) sql += ",";
        sql += "?";
    }
    sql += ") ORDER BY m.created_at DESC";
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备查询
    sqlite3_prepare_v2(db_, sql.c_str(), -1, &s, nullptr);
    // 绑定所有标签 id
    for (size_t i = 0; i < tids.size(); i++) bind_text(s, static_cast<int>(i + 1), tids[i]);
    // 逐行读取
    while (sqlite3_step(s) == SQLITE_ROW) r.push_back(row_to_media_item(s));
    // 释放
    sqlite3_finalize(s);
    return r;
}

// ===== Notes =====
/**
 * @brief 获取所有笔记
 * 按更新时间降序排列。
 */
std::vector<Note> Database::get_all_notes() {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<Note> r;
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备查询所有笔记，按更新时间降序
    sqlite3_prepare_v2(db_, "SELECT * FROM notes ORDER BY updated_at DESC", -1, &s, nullptr);
    // 逐行读取
    while (sqlite3_step(s) == SQLITE_ROW) r.push_back(row_to_note(s));
    // 释放
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 按媒体 id 获取笔记
 */
std::optional<Note> Database::get_note_by_media_id(const std::string& mid) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备按媒体 id 查询
    sqlite3_prepare_v2(db_, "SELECT * FROM notes WHERE media_id=?", -1, &s, nullptr);
    // 绑定媒体 id
    bind_text(s, 1, mid);
    // 可选结果
    std::optional<Note> r;
    // 若存在记录则转换
    if (sqlite3_step(s) == SQLITE_ROW) r = row_to_note(s);
    // 释放
    sqlite3_finalize(s);
    return r;
}

/**
 * @brief 保存笔记
 * 若该媒体已存在笔记则更新，否则插入。
 */
int Database::save_note(const std::string& mid, const std::string& content) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 当前时间戳
    auto now = current_timestamp_ms();
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备 UPSERT 语句
    sqlite3_prepare_v2(db_,
        "INSERT INTO notes(id,media_id,content,created_at,updated_at) VALUES(?,?,?,?,?) ON CONFLICT(media_id) DO UPDATE SET content=excluded.content,updated_at=excluded.updated_at",
        -1, &s, nullptr);
    // 绑定新 id
    bind_text(s, 1, generate_uuid());
    // 绑定媒体 id
    bind_text(s, 2, mid);
    // 绑定内容
    bind_text(s, 3, content);
    // 绑定创建时间
    sqlite3_bind_int64(s, 4, now);
    // 绑定更新时间
    sqlite3_bind_int64(s, 5, now);
    // 执行
    int rc = sqlite3_step(s);
    // 释放
    sqlite3_finalize(s);
    return rc;
}

/**
 * @brief 删除笔记
 */
int Database::delete_note(const std::string& id) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备删除
    sqlite3_prepare_v2(db_, "DELETE FROM notes WHERE id=?", -1, &s, nullptr);
    // 绑定 id
    bind_text(s, 1, id);
    // 执行
    int rc = sqlite3_step(s);
    // 释放
    sqlite3_finalize(s);
    return rc;
}

// ===== Scanner =====

/**
 * @brief 扫描目录并导入所有媒体文件
 * 递归遍历目录，导入识别到的媒体文件。
 * @return 导入的文件数量
 */
int Database::scan_directory(const std::string& dir, const std::string& ad) {
    // 目录不存在或不是目录则返回 -1
    fs::path dir_path = to_path(dir);
    if (!fs::exists(dir_path) || !fs::is_directory(dir_path)) return -1;
    // 导入计数
    int c = 0;
    // 递归遍历目录
    for (auto& e : fs::recursive_directory_iterator(dir_path)) {
        // 仅处理常规文件
        if (e.is_regular_file()) {
            // 获取扩展名
            auto ext = get_extension(e.path().string());
            // 仅导入可识别的媒体类型
            if (detect_media_type(ext) != "other") {
                import_media(e.path().string(), ad);
                c++;
            }
        }
    }
    return c;
}

/**
 * @brief 导入单个文件
 * 使用应用目录作为目标目录。
 */
int Database::import_single_file(const std::string& fp) {
    return import_media(fp, app_dir_);
}

// ===== Advanced Search =====

/**
 * @brief 高级搜索媒体
 * 根据 SearchFilter 结构体中的多个条件动态构造 SQL。
 */
std::vector<MediaItem> Database::search_media_advanced(const SearchFilter& f) {
    // 加锁保护
    std::lock_guard<std::mutex> lock(mutex_);
    // 结果列表
    std::vector<MediaItem> r;
    // SQL 基础部分
    std::string sql = "SELECT DISTINCT m.* FROM media_items m";
    // 条件子句列表
    std::vector<std::string> cond;
    // 是否需要关联标签表
    bool jt = f.tags.has_value() && !f.tags->empty();
    // 若需要标签过滤则 JOIN
    if (jt) sql += " JOIN media_tags mt ON m.id=mt.media_id";
    // 名称模糊搜索
    if (!f.query.empty()) cond.push_back("m.original_name LIKE ?");
    // 类型过滤
    if (f.media_type.has_value()) cond.push_back("m.type=?");
    // 开始日期
    if (f.start_date.has_value()) cond.push_back("m.created_at>=?");
    // 结束日期
    if (f.end_date.has_value()) cond.push_back("m.created_at<=?");
    // 最小大小
    if (f.min_size.has_value()) cond.push_back("m.size>=?");
    // 最大大小
    if (f.max_size.has_value()) cond.push_back("m.size<=?");
    // 标签 IN 条件
    if (jt) {
        std::string ic = "mt.tag_id IN (";
        for (size_t i = 0; i < f.tags->size(); i++) {
            if (i) ic += ",";
            ic += "?";
        }
        ic += ")";
        cond.push_back(ic);
    }
    // 仅包含有笔记的媒体
    if (f.has_notes) cond.push_back("EXISTS(SELECT 1 FROM notes WHERE media_id=m.id)");
    // 拼接 WHERE 子句
    if (!cond.empty()) {
        sql += " WHERE ";
        for (size_t i = 0; i < cond.size(); i++) {
            if (i) sql += " AND ";
            sql += cond[i];
        }
    }
    // 排序
    sql += " ORDER BY m.created_at DESC";
    // SQL 语句指针
    sqlite3_stmt* s;
    // 准备查询
    sqlite3_prepare_v2(db_, sql.c_str(), -1, &s, nullptr);
    // 参数索引
    int p = 1;
    // 绑定名称查询
    if (!f.query.empty()) {
        bind_text(s, p++, "%" + f.query + "%");
    }
    // 绑定类型
    if (f.media_type.has_value()) bind_text(s, p++, *f.media_type);
    // 绑定开始日期
    if (f.start_date.has_value()) sqlite3_bind_int64(s, p++, *f.start_date);
    // 绑定结束日期
    if (f.end_date.has_value()) sqlite3_bind_int64(s, p++, *f.end_date);
    // 绑定最小大小
    if (f.min_size.has_value()) sqlite3_bind_int64(s, p++, *f.min_size);
    // 绑定最大大小
    if (f.max_size.has_value()) sqlite3_bind_int64(s, p++, *f.max_size);
    // 绑定标签 id
    if (jt) for (auto& t : *f.tags) bind_text(s, p++, t);
    // 逐行读取
    while (sqlite3_step(s) == SQLITE_ROW) r.push_back(row_to_media_item(s));
    // 释放
    sqlite3_finalize(s);
    return r;
}

// 文件结束
