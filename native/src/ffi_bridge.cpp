////////////////////////////////////////////////////////////////////////
// 文件坐标: native/src/ffi_bridge.cpp
// 作用:     Dart FFI C ABI 导出层
// 说明:     将 C++ 的 Database 单例方法封装为 C 语言导出函数，
//           使用 extern "C" 避免 C++ 名称修饰，确保 Dart 可以通过
//           DynamicLibrary 查找符号。
////////////////////////////////////////////////////////////////////////

// --------------------------------------------------------------------
// 路径相对于 native/src，因此 include "db/database.h"
#include "db/database.h"

// --------------------------------------------------------------------
// 用于 std::strlen 等字符串操作
#include <cstring>

// --------------------------------------------------------------------
// 告诉 C++ 编译器这部分函数使用 C 语言链接规则，
// 防止函数名被修饰（mangling），让 Dart 的 ffi 能按名称查找到
extern "C" {

// --------------------------------------------------------------------
// 简化后续 Database 类及结构体的访问
using namespace amkb::db;

// --------------------------------------------------------------------
// Dart 侧传入 NativeCallable 函数指针，C++ 遍历结果时逐个调用
typedef void (*media_callback)(
    const char* id,           // 媒体 ID
    const char* name,         // 原始文件名
    const char* type,         // 媒体类型
    int64_t size,             // 文件大小
    const char* path,         // 文件路径
    const char* thumb         // 缩略图路径
);

// --------------------------------------------------------------------
// 返回相册 ID、名称、媒体数量
typedef void (*album_callback)(
    const char* id,
    const char* name,
    int media_count
);

// --------------------------------------------------------------------
// 返回标签 ID、名称、颜色（十六进制字符串）
typedef void (*tag_callback)(
    const char* id,
    const char* name,
    const char* color
);

// --------------------------------------------------------------------
typedef void (*breadcrumb_callback)(
    const char* id,
    const char* name
);

// --------------------------------------------------------------------
typedef void (*note_callback)(
    const char* id,
    const char* media_id,
    const char* content,
    int64_t created_at,
    int64_t updated_at
);

// ====================================================================
// 初始化
// ====================================================================

// --------------------------------------------------------------------
// app_dir: 应用私有目录，用于存放数据库和缩略图
// 返回: 0 表示成功，非 0 表示失败
int amkb_init(const char* app_dir) {
    // 调用 Database 单例的 init 方法
    return Database::instance().init(app_dir ? app_dir : "");
}

// ====================================================================
// 设置
// ====================================================================

// --------------------------------------------------------------------
// 字段与 Dart 侧 Settings 对象对应
struct CAppSettings {
    int theme_mode;             // 主题模式
    int grid_columns;           // 媒体网格列数
    int album_grid_columns;     // 相册网格列数
    int thumbnail_quality;      // 缩略图质量
    const char* language;       // 语言代码
    int dynamic_color;          // 动态颜色开关
    const char* last_scan_path; // 上次扫描目录
};

// --------------------------------------------------------------------
// 逐个字段返回，避免 Dart 侧处理结构体内存布局
typedef void (*settings_callback)(
    int theme_mode,
    int grid_cols,
    int album_cols,
    int thumb_q,
    const char* lang,
    int dyn_color,
    const char* last_scan
);

// --------------------------------------------------------------------
// 适合 Dart NativeCallable 回调模式
int amkb_get_settings_cb(settings_callback cb) {
    // 从数据库单例读取设置
    auto s = Database::instance().get_settings();
    // 如果回调函数非空，则调用并传入所有字段
    if (cb) cb(s.theme_mode, s.grid_columns, s.album_grid_columns,
               s.thumbnail_quality, s.language.c_str(),
               s.dynamic_color, s.last_scan_path.c_str());
    return 0;
}

// --------------------------------------------------------------------
// 注意：返回的 const char* 指向 std::string 内部，需要立即使用
CAppSettings amkb_get_settings() {
    auto s = Database::instance().get_settings();
    return {
        s.theme_mode, s.grid_columns, s.album_grid_columns,
        s.thumbnail_quality, s.language.c_str(),
        s.dynamic_color, s.last_scan_path.c_str()
    };
}

// --------------------------------------------------------------------
// 将传入的 C 字符串转换为 C++ std::string 后保存
int amkb_save_settings(int theme_mode, int grid_cols, int album_cols,
                       int thumb_q, const char* lang, int dyn_color,
                       const char* last_scan) {
    AppSettings s{
        theme_mode, grid_cols, album_cols, thumb_q,
        lang ? lang : "", dyn_color,
        last_scan ? last_scan : ""
    };
    return Database::instance().save_settings(s);
}

// --------------------------------------------------------------------
// 通过指针参数返回，避免 ABI 结构体传递兼容性问题
int amkb_get_storage_stats(int* out_count, int64_t* out_size,
                           int64_t* out_thumb, int64_t* out_db) {
    auto s = Database::instance().get_storage_stats();
    if (out_count) *out_count = s.total_media_count;
    if (out_size)  *out_size  = s.total_size;
    if (out_thumb) *out_thumb = s.thumbnail_cache_size;
    if (out_db)    *out_db    = s.database_size;
    return 0;
}

// --------------------------------------------------------------------
int amkb_clear_thumbnail_cache() {
    return Database::instance().clear_thumbnail_cache();
}

// --------------------------------------------------------------------
int amkb_delete_all_data() {
    return Database::instance().delete_all_data();
}

// --------------------------------------------------------------------
int amkb_export_data(const char* path) {
    return Database::instance().export_data(path ? path : "");
}

// --------------------------------------------------------------------
int amkb_import_data(const char* path) {
    return Database::instance().import_data(path ? path : "");
}

// ====================================================================
// 媒体
// ====================================================================

// --------------------------------------------------------------------
// 通过回调函数逐个返回媒体项
int amkb_get_all_media(media_callback cb) {
    auto items = Database::instance().get_all_media();
    for (auto& m : items) {
        if (cb) cb(m.id.c_str(), m.original_name.c_str(),
                   m.media_type.c_str(), m.size,
                   m.file_path.c_str(), m.thumbnail_path.c_str());
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
// 第 72-78 行: 按关键词搜索媒体
int amkb_search_media(const char* query, media_callback cb) {
    auto items = Database::instance().search_media(query ? query : "");
    for (auto& m : items) {
        if (cb) cb(m.id.c_str(), m.original_name.c_str(),
                   m.media_type.c_str(), m.size,
                   m.file_path.c_str(), m.thumbnail_path.c_str());
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
int amkb_filter_media_by_type(const char* type, media_callback cb) {
    auto items = Database::instance().filter_media_by_type(type ? type : "");
    for (auto& m : items) {
        if (cb) cb(m.id.c_str(), m.original_name.c_str(),
                   m.media_type.c_str(), m.size,
                   m.file_path.c_str(), m.thumbnail_path.c_str());
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
int amkb_delete_media(const char* id) {
    return Database::instance().delete_media(id ? id : "");
}

// --------------------------------------------------------------------
int amkb_import_single_file(const char* path) {
    return Database::instance().import_single_file(path ? path : "");
}

// --------------------------------------------------------------------
int amkb_scan_directory(const char* dir, const char* app_dir) {
    return Database::instance().scan_directory(
        dir ? dir : "", app_dir ? app_dir : "");
}

// ====================================================================
// 相册
// ====================================================================

// --------------------------------------------------------------------
int amkb_get_root_albums(album_callback cb) {
    auto items = Database::instance().get_root_albums();
    for (auto& a : items) {
        if (cb) cb(a.album.id.c_str(), a.album.name.c_str(), a.media_count);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
int amkb_get_child_albums(const char* parent_id, album_callback cb) {
    auto items = Database::instance().get_child_albums(parent_id ? parent_id : "");
    for (auto& a : items) {
        if (cb) cb(a.album.id.c_str(), a.album.name.c_str(), a.media_count);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
// 返回新相册 ID 字符串
// 使用 static thread_local 使返回的字符串在当前线程生命周期内有效
const char* amkb_create_album(const char* name, const char* parent_id) {
    static thread_local std::string result;
    std::optional<std::string> pid = parent_id
        ? std::optional<std::string>(parent_id)
        : std::nullopt;
    result = Database::instance().create_album(name ? name : "", pid);
    return result.c_str();
}

// --------------------------------------------------------------------
int amkb_delete_album(const char* id) {
    return Database::instance().delete_album(id ? id : "");
}

// --------------------------------------------------------------------
int amkb_rename_album(const char* id, const char* name) {
    return Database::instance().rename_album(id ? id : "", name ? name : "");
}

// --------------------------------------------------------------------
int amkb_get_media_by_album(const char* album_id, media_callback cb) {
    auto items = Database::instance().get_media_by_album(album_id ? album_id : "");
    for (auto& m : items) {
        if (cb) cb(m.id.c_str(), m.original_name.c_str(),
                   m.media_type.c_str(), m.size,
                   m.file_path.c_str(), m.thumbnail_path.c_str());
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
int amkb_add_media_to_album(const char** media_ids, int count, const char* album_id) {
    std::vector<std::string> ids;
    for (int i = 0; i < count; i++) {
        ids.push_back(media_ids[i] ? media_ids[i] : "");
    }
    return Database::instance().add_media_to_album(ids, album_id ? album_id : "");
}

// --------------------------------------------------------------------
int amkb_add_single_media_to_album(const char* media_id, const char* album_id) {
    std::vector<std::string> ids = {media_id ? media_id : ""};
    return Database::instance().add_media_to_album(ids, album_id ? album_id : "");
}

// --------------------------------------------------------------------
int amkb_remove_media_from_album(const char** media_ids, int count, const char* album_id) {
    std::vector<std::string> ids;
    for (int i = 0; i < count; i++) {
        ids.push_back(media_ids[i] ? media_ids[i] : "");
    }
    return Database::instance().remove_media_from_album(ids, album_id ? album_id : "");
}

// --------------------------------------------------------------------
int amkb_remove_single_media_from_album(const char* media_id, const char* album_id) {
    std::vector<std::string> ids = {media_id ? media_id : ""};
    return Database::instance().remove_media_from_album(ids, album_id ? album_id : "");
}

// --------------------------------------------------------------------
int amkb_get_album_breadcrumb(const char* album_id, breadcrumb_callback cb) {
    auto items = Database::instance().get_album_breadcrumb(album_id ? album_id : "");
    for (auto& i : items) {
        if (cb) cb(i.id.c_str(), i.name.c_str());
    }
    return (int)items.size();
}

// ====================================================================
// 标签
// ====================================================================

// --------------------------------------------------------------------
int amkb_get_all_tags(tag_callback cb) {
    auto items = Database::instance().get_all_tags();
    for (auto& t : items) {
        if (cb) cb(t.id.c_str(), t.name.c_str(),
                   t.color.value_or("").c_str());
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
int amkb_get_root_tags(tag_callback cb) {
    auto items = Database::instance().get_root_tags();
    for (auto& i : items) {
        if (cb) cb(i.tag.id.c_str(), i.tag.name.c_str(),
                   i.tag.color.value_or("").c_str());
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
int amkb_get_child_tags(const char* parent_id, tag_callback cb) {
    auto items = Database::instance().get_child_tags(parent_id ? parent_id : "");
    for (auto& i : items) {
        if (cb) cb(i.tag.id.c_str(), i.tag.name.c_str(),
                   i.tag.color.value_or("").c_str());
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
const char* amkb_create_tag(const char* name, const char* color, const char* parent_id) {
    static thread_local std::string result;
    std::optional<std::string> c = color
        ? std::optional<std::string>(color)
        : std::nullopt;
    std::optional<std::string> pid = parent_id
        ? std::optional<std::string>(parent_id)
        : std::nullopt;
    result = Database::instance().create_tag(name ? name : "", c, pid);
    return result.c_str();
}

// --------------------------------------------------------------------
int amkb_delete_tag(const char* id) {
    return Database::instance().delete_tag(id ? id : "");
}

int amkb_rename_tag(const char* id, const char* name) {
    return Database::instance().rename_tag(id ? id : "", name ? name : "");
}

int amkb_update_tag_color(const char* id, const char* color) {
    return Database::instance().update_tag_color(id ? id : "", color ? color : "");
}

int amkb_update_tag_parent(const char* id, const char* parent_id) {
    std::optional<std::string> pid = parent_id
        ? std::optional<std::string>(parent_id)
        : std::nullopt;
    return Database::instance().update_tag_parent(id ? id : "", pid);
}

// --------------------------------------------------------------------
int amkb_add_tag_to_media(const char* media_id, const char* tag_id) {
    return Database::instance().add_tag_to_media(
        media_id ? media_id : "", tag_id ? tag_id : "");
}

int amkb_remove_tag_from_media(const char* media_id, const char* tag_id) {
    return Database::instance().remove_tag_from_media(
        media_id ? media_id : "", tag_id ? tag_id : "");
}

// --------------------------------------------------------------------
int amkb_get_media_tags(const char* media_id, tag_callback cb) {
    auto items = Database::instance().get_media_tags(media_id ? media_id : "");
    for (auto& t : items) {
        if (cb) cb(t.id.c_str(), t.name.c_str(),
                   t.color.value_or("").c_str());
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
int amkb_get_media_by_tags_and(const char** tag_ids, int count, media_callback cb) {
    std::vector<std::string> ids;
    for (int i = 0; i < count; i++) {
        ids.push_back(tag_ids[i] ? tag_ids[i] : "");
    }
    auto items = Database::instance().get_media_by_tags_and(ids);
    for (auto& m : items) {
        if (cb) cb(m.id.c_str(), m.original_name.c_str(),
                   m.media_type.c_str(), m.size,
                   m.file_path.c_str(), m.thumbnail_path.c_str());
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
int amkb_get_media_by_tags_or(const char** tag_ids, int count, media_callback cb) {
    std::vector<std::string> ids;
    for (int i = 0; i < count; i++) {
        ids.push_back(tag_ids[i] ? tag_ids[i] : "");
    }
    auto items = Database::instance().get_media_by_tags_or(ids);
    for (auto& m : items) {
        if (cb) cb(m.id.c_str(), m.original_name.c_str(),
                   m.media_type.c_str(), m.size,
                   m.file_path.c_str(), m.thumbnail_path.c_str());
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
// 内部使用 OR 条件并构造单元素 ID 列表
int amkb_get_media_by_single_tag(const char* tag_id, media_callback cb) {
    std::vector<std::string> ids = {tag_id ? tag_id : ""};
    auto items = Database::instance().get_media_by_tags_or(ids);
    for (auto& m : items) {
        if (cb) cb(m.id.c_str(), m.original_name.c_str(),
                   m.media_type.c_str(), m.size,
                   m.file_path.c_str(), m.thumbnail_path.c_str());
    }
    return (int)items.size();
}

// ====================================================================
// 笔记
// ====================================================================

// --------------------------------------------------------------------
// 如果 media_id 已存在笔记则更新，否则插入
int amkb_save_note(const char* media_id, const char* content) {
    return Database::instance().save_note(
        media_id ? media_id : "", content ? content : "");
}

// --------------------------------------------------------------------
int amkb_delete_note(const char* id) {
    return Database::instance().delete_note(id ? id : "");
}

// --------------------------------------------------------------------
int amkb_get_all_notes(note_callback cb) {
    auto items = Database::instance().get_all_notes();
    for (auto& n : items) {
        if (cb) cb(n.id.c_str(), n.media_id.c_str(),
                   n.content.c_str(), n.created_at, n.updated_at);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
// 如果找到返回 1，否则返回 0
int amkb_get_note_by_media_id(const char* media_id, note_callback cb) {
    auto n = Database::instance().get_note_by_media_id(
        media_id ? media_id : "");
    if (n.has_value() && cb) {
        cb(n->id.c_str(), n->media_id.c_str(),
           n->content.c_str(), n->created_at, n->updated_at);
        return 1;
    }
    return 0;
}

// --------------------------------------------------------------------
// 块内所有函数使用 C 语言链接，避免名称修饰
} // extern "C"
