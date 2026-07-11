#include "db/database.h"
#include <cstring>

// C ABI exports for Dart FFI
extern "C" {

using namespace amkb::db;

// All string returns use static buffer - caller must copy immediately
static char g_error_buf[4096] = {0};

const char* amkb_get_error() { return g_error_buf; }

int amkb_init(const char* app_dir) {
    return Database::instance().init(app_dir ? app_dir : "");
}

// Settings
struct CAppSettings {
    int theme_mode; int grid_columns; int album_grid_columns;
    int thumbnail_quality; const char* language; int dynamic_color; const char* last_scan_path;
};

CAppSettings amkb_get_settings() {
    auto s = Database::instance().get_settings();
    return {s.theme_mode, s.grid_columns, s.album_grid_columns,
            s.thumbnail_quality, s.language.c_str(), s.dynamic_color, s.last_scan_path.c_str()};
}

int amkb_save_settings(int theme_mode, int grid_cols, int album_cols, int thumb_q, const char* lang, int dyn_color, const char* last_scan) {
    AppSettings s{theme_mode, grid_cols, album_cols, thumb_q, lang?lang:"", dyn_color, last_scan?last_scan:""};
    return Database::instance().save_settings(s);
}

// Media - return count, use callback for each item
typedef void (*media_callback)(const char* id, const char* name, const char* type, int64_t size, const char* path, const char* thumb);

static media_callback g_media_cb = nullptr;

int amkb_get_all_media(media_callback cb) {
    g_media_cb = cb;
    auto items = Database::instance().get_all_media();
    for (auto& m : items) {
        if (cb) cb(m.id.c_str(), m.original_name.c_str(), m.media_type.c_str(), m.size, m.file_path.c_str(), m.thumbnail_path.c_str());
    }
    return (int)items.size();
}

int amkb_search_media(const char* query, media_callback cb) {
    auto items = Database::instance().search_media(query ? query : "");
    for (auto& m : items) {
        if (cb) cb(m.id.c_str(), m.original_name.c_str(), m.media_type.c_str(), m.size, m.file_path.c_str(), m.thumbnail_path.c_str());
    }
    return (int)items.size();
}

int amkb_filter_media_by_type(const char* type, media_callback cb) {
    auto items = Database::instance().filter_media_by_type(type ? type : "");
    for (auto& m : items) {
        if (cb) cb(m.id.c_str(), m.original_name.c_str(), m.media_type.c_str(), m.size, m.file_path.c_str(), m.thumbnail_path.c_str());
    }
    return (int)items.size();
}

int amkb_delete_media(const char* id) { return Database::instance().delete_media(id?id:""); }
int amkb_import_single_file(const char* path) { return Database::instance().import_single_file(path?path:""); }
int amkb_scan_directory(const char* dir, const char* app_dir) { return Database::instance().scan_directory(dir?dir:"", app_dir?app_dir:""); }

// Albums
typedef void (*album_callback)(const char* id, const char* name, int media_count);

int amkb_get_root_albums(album_callback cb) {
    auto items = Database::instance().get_root_albums();
    for (auto& a : items) { if(cb) cb(a.album.id.c_str(), a.album.name.c_str(), a.media_count); }
    return (int)items.size();
}

int amkb_get_child_albums(const char* parent_id, album_callback cb) {
    auto items = Database::instance().get_child_albums(parent_id?parent_id:"");
    for (auto& a : items) { if(cb) cb(a.album.id.c_str(), a.album.name.c_str(), a.media_count); }
    return (int)items.size();
}

const char* amkb_create_album(const char* name, const char* parent_id) {
    static thread_local std::string result;
    std::optional<std::string> pid = parent_id ? std::optional<std::string>(parent_id) : std::nullopt;
    result = Database::instance().create_album(name?name:"", pid);
    return result.c_str();
}

int amkb_delete_album(const char* id) { return Database::instance().delete_album(id?id:""); }
int amkb_rename_album(const char* id, const char* name) { return Database::instance().rename_album(id?id:"", name?name:""); }

int amkb_get_media_by_album(const char* album_id, media_callback cb) {
    auto items = Database::instance().get_media_by_album(album_id?album_id:"");
    for (auto& m : items) {
        if (cb) cb(m.id.c_str(), m.original_name.c_str(), m.media_type.c_str(), m.size, m.file_path.c_str(), m.thumbnail_path.c_str());
    }
    return (int)items.size();
}

// Tags
typedef void (*tag_callback)(const char* id, const char* name, const char* color);

int amkb_get_all_tags(tag_callback cb) {
    auto items = Database::instance().get_all_tags();
    for (auto& t : items) { if(cb) cb(t.id.c_str(), t.name.c_str(), t.color.value_or("").c_str()); }
    return (int)items.size();
}

const char* amkb_create_tag(const char* name, const char* color, const char* parent_id) {
    static thread_local std::string result;
    std::optional<std::string> c = color ? std::optional<std::string>(color) : std::nullopt;
    std::optional<std::string> pid = parent_id ? std::optional<std::string>(parent_id) : std::nullopt;
    result = Database::instance().create_tag(name?name:"", c, pid);
    return result.c_str();
}

int amkb_delete_tag(const char* id) { return Database::instance().delete_tag(id?id:""); }
int amkb_rename_tag(const char* id, const char* name) { return Database::instance().rename_tag(id?id:"", name?name:""); }
int amkb_add_tag_to_media(const char* media_id, const char* tag_id) { return Database::instance().add_tag_to_media(media_id?media_id:"", tag_id?tag_id:""); }
int amkb_remove_tag_from_media(const char* media_id, const char* tag_id) { return Database::instance().remove_tag_from_media(media_id?media_id:"", tag_id?tag_id:""); }

int amkb_get_media_tags(const char* media_id, tag_callback cb) {
    auto items = Database::instance().get_media_tags(media_id?media_id:"");
    for (auto& t : items) { if(cb) cb(t.id.c_str(), t.name.c_str(), t.color.value_or("").c_str()); }
    return (int)items.size();
}

// Notes
int amkb_save_note(const char* media_id, const char* content) {
    return Database::instance().save_note(media_id?media_id:"", content?content:"");
}

int amkb_delete_note(const char* id) { return Database::instance().delete_note(id?id:""); }

// Settings extras
int amkb_delete_all_data() { return Database::instance().delete_all_data(); }
int amkb_export_data(const char* path) { return Database::instance().export_data(path?path:""); }
int amkb_import_data(const char* path) { return Database::instance().import_data(path?path:""); }

} // extern "C"
