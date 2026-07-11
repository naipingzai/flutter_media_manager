#pragma once

#include <string>
#include <vector>
#include <optional>
#include <mutex>
#include <sqlite3.h>

namespace amkb {
namespace db {

// Data models matching the Rust structures
struct MediaItem {
    std::string id;
    std::string original_name;
    std::string storage_name;
    std::string file_path;
    std::string thumbnail_path;
    std::string media_type; // "image", "video", "audio", "document", "other"
    std::string mime_type;
    int64_t size = 0;
    std::optional<int32_t> width;
    std::optional<int32_t> height;
    std::optional<int64_t> duration;
    std::string sha256_hash;
    int64_t created_at = 0;
    int64_t updated_at = 0;
};

struct Album {
    std::string id;
    std::string name;
    std::optional<std::string> parent_id;
    std::optional<std::string> cover_media_id;
    int32_t sort_order = 0;
    int64_t created_at = 0;
};

struct Tag {
    std::string id;
    std::string name;
    std::optional<std::string> color;
    std::optional<std::string> parent_id;
    int64_t created_at = 0;
};

struct Note {
    std::string id;
    std::string media_id;
    std::string content;
    int64_t created_at = 0;
    int64_t updated_at = 0;
};

struct AppSettings {
    int theme_mode = 0; // 0=system, 1=light, 2=dark
    int grid_columns = 3;
    int album_grid_columns = 2;
    int thumbnail_quality = 85;
    std::string language = "system";
    int dynamic_color = 1;
    std::string last_scan_path;
};

struct AlbumWithInfo {
    Album album;
    int32_t media_count = 0;
    std::optional<std::string> cover_path;
};

struct TagWithInfo {
    Tag tag;
    int32_t media_count = 0;
};

struct BreadcrumbItem {
    std::string id;
    std::string name;
};

struct StorageStats {
    int32_t total_media_count = 0;
    int64_t total_size = 0;
    int64_t thumbnail_cache_size = 0;
    int64_t database_size = 0;
};

// Database singleton
class Database {
public:
    static Database& instance();

    int init(const std::string& app_dir);
    bool is_initialized() const;

    // Settings
    AppSettings get_settings();
    int save_settings(const AppSettings& settings);
    StorageStats get_storage_stats();
    int clear_thumbnail_cache();
    int export_data(const std::string& export_path);
    int import_data(const std::string& import_path);
    int delete_all_data();
    std::vector<std::string> find_unreferenced_files();
    int delete_unreferenced_files();

    // Media
    std::vector<MediaItem> get_all_media();
    std::vector<MediaItem> search_media(const std::string& query);
    std::vector<MediaItem> filter_media_by_type(const std::string& media_type);
    std::optional<MediaItem> get_media_by_id(const std::string& id);
    int delete_media(const std::string& id);
    int update_media(const MediaItem& media);
    int import_media(const std::string& file_path, const std::string& app_dir);
    std::vector<MediaItem> get_adjacent_media(const std::string& id);
    std::vector<MediaItem> get_media_by_filter(const std::string& filter_mode);

    // Albums
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

    // Tags
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

    // Notes
    std::vector<Note> get_all_notes();
    std::optional<Note> get_note_by_media_id(const std::string& media_id);
    int save_note(const std::string& media_id, const std::string& content);
    int delete_note(const std::string& id);

    // Scanner
    int scan_directory(const std::string& directory, const std::string& app_dir);
    int import_single_file(const std::string& file_path);

    // Search (advanced)
    struct SearchFilter {
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

    sqlite3* db_ = nullptr;
    std::string app_dir_;
    mutable std::mutex mutex_;

    int create_tables();
    MediaItem row_to_media_item(sqlite3_stmt* stmt);
    Album row_to_album(sqlite3_stmt* stmt);
    Tag row_to_tag(sqlite3_stmt* stmt);
    Note row_to_note(sqlite3_stmt* stmt);
};

} // namespace db
} // namespace amkb
