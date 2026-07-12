////////////////////////////////////////////////////////////////////////
// 文件坐标: native/src/db/database.h
// 作用:     C++ 原生层数据模型定义与数据库单例接口声明
// 说明:     所有结构体对应 Dart 侧的数据模型，Database 类提供线程安全
//           的 SQLite 访问接口。
////////////////////////////////////////////////////////////////////////

// --------------------------------------------------------------------
// 防止同一个头文件被重复包含，替代传统的 include guard
#pragma once

// --------------------------------------------------------------------
#include <string>      // std::string 字符串类型
#include <vector>      // std::vector 动态数组
#include <optional>    // std::optional 可选值（C++17）
#include <mutex>       // std::mutex 互斥锁，用于线程安全

// --------------------------------------------------------------------
#include <sqlite3.h>

// --------------------------------------------------------------------
// amkb  = Advance Media Knowledge Base 项目缩写
// db    = 数据库模块命名空间
namespace amkb {
namespace db {

// --------------------------------------------------------------------
// 这样 Dart 侧可以沿用之前的 JSON 序列化逻辑

// --------------------------------------------------------------------
// 表示一条多媒体文件记录
struct MediaItem {
    std::string id;
    std::string original_name;
    std::string storage_name;
    std::string file_path;
    std::string thumbnail_path;
    // 可选值: "image", "video", "audio", "document", "other"
    std::string media_type;
    std::string mime_type;
    int64_t size = 0;
    std::optional<int32_t> width;
    std::optional<int32_t> height;
    std::optional<int64_t> duration;
    std::string sha256_hash;
    int64_t created_at = 0;
    int64_t updated_at = 0;
};

// --------------------------------------------------------------------
// 表示相册/目录
struct Album {
    std::string id;
    std::string name;
    std::optional<std::string> parent_id;
    std::optional<std::string> cover_media_id;
    int32_t sort_order = 0;
    int64_t created_at = 0;
};

// --------------------------------------------------------------------
// 表示标签，支持层级结构
struct Tag {
    std::string id;
    std::string name;
    std::optional<std::string> color;
    std::optional<std::string> parent_id;
    int64_t created_at = 0;
};

// --------------------------------------------------------------------
// 表示与媒体文件关联的笔记
struct Note {
    std::string id;
    std::string media_id;
    std::string content;
    int64_t created_at = 0;
    int64_t updated_at = 0;
};

// --------------------------------------------------------------------
// 表示应用级设置，与 settings 表字段对应
struct AppSettings {
    int theme_mode = 0;
    int grid_columns = 3;
    int album_grid_columns = 2;
    int thumbnail_quality = 85;
    std::string language = "system";
    int dynamic_color = 1;
    std::string last_scan_path;
};

// --------------------------------------------------------------------
// 相册信息聚合，包含媒体数量和封面路径
struct AlbumWithInfo {
    Album album;
    int32_t media_count = 0;
    std::optional<std::string> cover_path;
};

// --------------------------------------------------------------------
// 标签信息聚合，包含媒体数量
struct TagWithInfo {
    Tag tag;
    int32_t media_count = 0;
};

// --------------------------------------------------------------------
// 面包屑导航项
struct BreadcrumbItem {
    std::string id;
    std::string name;
};

// --------------------------------------------------------------------
// 存储统计信息
struct StorageStats {
    int32_t total_media_count = 0;
    int64_t total_size = 0;
    int64_t thumbnail_cache_size = 0;
    int64_t database_size = 0;
};

// --------------------------------------------------------------------
// 负责 SQLite 数据库连接、表创建、所有 CRUD 操作
class Database {
public:
    // 保证全局唯一数据库连接对象
    static Database& instance();

    // ----------------------------------------------------------------
    // 初始化与状态
    // ----------------------------------------------------------------

    // app_dir: 应用私有目录，用于存放数据库和缩略图文件
    int init(const std::string& app_dir);

    bool is_initialized() const;

    // ----------------------------------------------------------------
    // 设置相关接口
    // ----------------------------------------------------------------

    AppSettings get_settings();

    int save_settings(const AppSettings& settings);

    StorageStats get_storage_stats();

    int clear_thumbnail_cache();

    int export_data(const std::string& export_path);

    int import_data(const std::string& import_path);

    int delete_all_data();

    std::vector<std::string> find_unreferenced_files();

    int delete_unreferenced_files();

    // ----------------------------------------------------------------
    // 媒体相关接口
    // ----------------------------------------------------------------

    std::vector<MediaItem> get_all_media();

    // 第 109 行: 按关键词搜索媒体
    std::vector<MediaItem> search_media(const std::string& query);

    std::vector<MediaItem> filter_media_by_type(const std::string& media_type);

    std::optional<MediaItem> get_media_by_id(const std::string& id);

    int delete_media(const std::string& id);

    int update_media(const MediaItem& media);

    int import_media(const std::string& file_path, const std::string& app_dir);

    std::vector<MediaItem> get_adjacent_media(const std::string& id);

    std::vector<MediaItem> get_media_by_filter(const std::string& filter_mode);

    // ----------------------------------------------------------------
    // 相册相关接口
    // ----------------------------------------------------------------

    std::vector<AlbumWithInfo> get_root_albums();

    std::vector<AlbumWithInfo> get_child_albums(const std::string& parent_id);

    std::string create_album(const std::string& name, const std::optional<std::string>& parent_id);

    int delete_album(const std::string& id);

    int rename_album(const std::string& id, const std::string& new_name);

    int add_media_to_album(const std::vector<std::string>& media_ids, const std::string& album_id);

    int remove_media_from_album(const std::vector<std::string>& media_ids, const std::string& album_id);

    int set_album_cover(const std::string& album_id, const std::string& media_id);

    std::vector<BreadcrumbItem> get_album_breadcrumb(const std::string& album_id);

    std::vector<MediaItem> get_media_by_album(const std::string& album_id);

    // ----------------------------------------------------------------
    // 标签相关接口
    // ----------------------------------------------------------------

    std::vector<Tag> get_all_tags();

    std::vector<TagWithInfo> get_root_tags();

    std::vector<TagWithInfo> get_child_tags(const std::string& parent_id);

    std::string create_tag(const std::string& name, const std::optional<std::string>& color, const std::optional<std::string>& parent_id);

    int delete_tag(const std::string& id);

    int rename_tag(const std::string& id, const std::string& new_name);

    int update_tag_color(const std::string& id, const std::string& color);

    int update_tag_parent(const std::string& id, const std::optional<std::string>& parent_id);

    int add_tag_to_media(const std::string& media_id, const std::string& tag_id);

    int remove_tag_from_media(const std::string& media_id, const std::string& tag_id);

    std::vector<Tag> get_media_tags(const std::string& media_id);

    std::vector<MediaItem> get_media_by_tags_and(const std::vector<std::string>& tag_ids);

    std::vector<MediaItem> get_media_by_tags_or(const std::vector<std::string>& tag_ids);

    // ----------------------------------------------------------------
    // 笔记相关接口
    // ----------------------------------------------------------------

    std::vector<Note> get_all_notes();

    std::optional<Note> get_note_by_media_id(const std::string& media_id);

    int save_note(const std::string& media_id, const std::string& content);

    int delete_note(const std::string& id);

    // ----------------------------------------------------------------
    // 扫描与导入
    // ----------------------------------------------------------------

    int scan_directory(const std::string& directory, const std::string& app_dir);

    int import_single_file(const std::string& file_path);

    // ----------------------------------------------------------------
    // 高级搜索
    // ----------------------------------------------------------------

    struct SearchFilter {
        // 第 157 行: 文本关键词
        std::string query;
        std::optional<std::string> media_type;
        std::optional<std::vector<std::string>> tags;
        std::optional<int64_t> start_date;
        std::optional<int64_t> end_date;
        std::optional<int64_t> min_size;
        std::optional<int64_t> max_size;
        bool has_notes = false;
    };

    std::vector<MediaItem> search_media_advanced(const SearchFilter& filter);

private:
    Database() = default;

    ~Database();

    Database(const Database&) = delete;

    Database& operator=(const Database&) = delete;

    // ----------------------------------------------------------------
    // 内部状态
    // ----------------------------------------------------------------

    sqlite3* db_ = nullptr;

    std::string app_dir_;

    mutable std::mutex mutex_;

    // ----------------------------------------------------------------
    // 私有辅助函数
    // ----------------------------------------------------------------

    // 在 init 时调用，建立 media、albums、tags、notes 等表
    int create_tables();

    MediaItem row_to_media_item(sqlite3_stmt* stmt);

    Album row_to_album(sqlite3_stmt* stmt);

    Tag row_to_tag(sqlite3_stmt* stmt);

    Note row_to_note(sqlite3_stmt* stmt);
};

// --------------------------------------------------------------------
} // namespace db

// --------------------------------------------------------------------
} // namespace amkb
