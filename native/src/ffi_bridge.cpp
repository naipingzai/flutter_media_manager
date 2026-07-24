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
#include "ffi_export.h"

// --------------------------------------------------------------------
// 用于 std::strlen 等字符串操作
#include <cstring>

// --------------------------------------------------------------------
// 告诉 C++ 编译器这部分函数使用 C 语言链接规则，
// 防止函数名被修饰（mangling），让 Dart 的 ffi 能按名称查找到
extern "C" {

// --------------------------------------------------------------------
// 简化后续 Database 类及结构体的访问
using namespace fmm::db;

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
FFI_EXPORT int fmm_init(const char* app_dir) {
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
// 使用 thread_local 静态缓冲区确保字符串指针在回调期间稳定
struct SettingsSlot {
    char lang[64];
    char last_scan[1024];
};
FFI_EXPORT int fmm_get_settings_cb(settings_callback cb) {
    // 从数据库单例读取设置
    auto s = Database::instance().get_settings();
    static thread_local SettingsSlot slot;
    strncpy(slot.lang, s.language.c_str(), sizeof(slot.lang) - 1); slot.lang[sizeof(slot.lang) - 1] = '\0';
    strncpy(slot.last_scan, s.last_scan_path.c_str(), sizeof(slot.last_scan) - 1); slot.last_scan[sizeof(slot.last_scan) - 1] = '\0';
    // 如果回调函数非空，则调用并传入所有字段
    if (cb) cb(s.theme_mode, s.grid_columns, s.album_grid_columns,
               s.thumbnail_quality, slot.lang,
               s.dynamic_color, slot.last_scan);
    return 0;
}

// --------------------------------------------------------------------
// 注意：返回的 const char* 指向 std::string 内部，需要立即使用
FFI_EXPORT CAppSettings fmm_get_settings() {
    auto s = Database::instance().get_settings();
    return {
        s.theme_mode, s.grid_columns, s.album_grid_columns,
        s.thumbnail_quality, s.language.c_str(),
        s.dynamic_color, s.last_scan_path.c_str()
    };
}

// --------------------------------------------------------------------
// 将传入的 C 字符串转换为 C++ std::string 后保存
FFI_EXPORT int fmm_save_settings(int theme_mode, int grid_cols, int album_cols,
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
FFI_EXPORT int fmm_get_storage_stats(int* out_count, int64_t* out_size,
                           int64_t* out_thumb, int64_t* out_db) {
    auto s = Database::instance().get_storage_stats();
    if (out_count) *out_count = s.total_media_count;
    if (out_size)  *out_size  = s.total_size;
    if (out_thumb) *out_thumb = s.thumbnail_cache_size;
    if (out_db)    *out_db    = s.database_size;
    return 0;
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_clear_thumbnail_cache() {
    return Database::instance().clear_thumbnail_cache();
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_delete_all_data() {
    return Database::instance().delete_all_data();
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_export_data(const char* path) {
    return Database::instance().export_data(path ? path : "");
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_import_data(const char* path) {
    return Database::instance().import_data(path ? path : "");
}

// ====================================================================
// 媒体
// ====================================================================

// --------------------------------------------------------------------
// 通过回调函数逐个返回媒体项
// 使用 thread_local 静态缓冲区确保字符串指针在回调期间稳定
// 避免 Windows 上 FFI 同步回调可能导致的 use-after-free 问题
struct MediaSlot {
    char id[128];
    char name[512];
    char type[32];
    int64_t size;
    char path[1024];
    char thumb[1024];
};
FFI_EXPORT int fmm_get_all_media(media_callback cb) {
    auto items = Database::instance().get_all_media();
    static thread_local MediaSlot slot;
    for (auto& m : items) {
        strncpy(slot.id, m.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, m.original_name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        strncpy(slot.type, m.media_type.c_str(), sizeof(slot.type) - 1); slot.type[sizeof(slot.type) - 1] = '\0';
        strncpy(slot.path, m.file_path.c_str(), sizeof(slot.path) - 1); slot.path[sizeof(slot.path) - 1] = '\0';
        strncpy(slot.thumb, m.thumbnail_path.c_str(), sizeof(slot.thumb) - 1); slot.thumb[sizeof(slot.thumb) - 1] = '\0';
        slot.size = m.size;
        if (cb) cb(slot.id, slot.name, slot.type, slot.size, slot.path, slot.thumb);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
// 第 72-78 行: 按关键词搜索媒体
FFI_EXPORT int fmm_search_media(const char* query, media_callback cb) {
    auto items = Database::instance().search_media(query ? query : "");
    static thread_local MediaSlot slot;
    for (auto& m : items) {
        strncpy(slot.id, m.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, m.original_name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        strncpy(slot.type, m.media_type.c_str(), sizeof(slot.type) - 1); slot.type[sizeof(slot.type) - 1] = '\0';
        strncpy(slot.path, m.file_path.c_str(), sizeof(slot.path) - 1); slot.path[sizeof(slot.path) - 1] = '\0';
        strncpy(slot.thumb, m.thumbnail_path.c_str(), sizeof(slot.thumb) - 1); slot.thumb[sizeof(slot.thumb) - 1] = '\0';
        slot.size = m.size;
        if (cb) cb(slot.id, slot.name, slot.type, slot.size, slot.path, slot.thumb);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_filter_media_by_type(const char* type, media_callback cb) {
    auto items = Database::instance().filter_media_by_type(type ? type : "");
    static thread_local MediaSlot slot;
    for (auto& m : items) {
        strncpy(slot.id, m.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, m.original_name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        strncpy(slot.type, m.media_type.c_str(), sizeof(slot.type) - 1); slot.type[sizeof(slot.type) - 1] = '\0';
        strncpy(slot.path, m.file_path.c_str(), sizeof(slot.path) - 1); slot.path[sizeof(slot.path) - 1] = '\0';
        strncpy(slot.thumb, m.thumbnail_path.c_str(), sizeof(slot.thumb) - 1); slot.thumb[sizeof(slot.thumb) - 1] = '\0';
        slot.size = m.size;
        if (cb) cb(slot.id, slot.name, slot.type, slot.size, slot.path, slot.thumb);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_delete_media(const char* id) {
    return Database::instance().delete_media(id ? id : "");
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_import_single_file(const char* path) {
    return Database::instance().import_single_file(path ? path : "");
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_scan_directory(const char* dir, const char* app_dir) {
    return Database::instance().scan_directory(
        dir ? dir : "", app_dir ? app_dir : "");
}

// ====================================================================
// 相册
// ====================================================================

// --------------------------------------------------------------------
// 使用 thread_local 静态缓冲区确保字符串指针在回调期间稳定
struct AlbumSlot {
    char id[128];
    char name[256];
};
FFI_EXPORT int fmm_get_root_albums(album_callback cb) {
    auto items = Database::instance().get_root_albums();
    static thread_local AlbumSlot slot;
    for (auto& a : items) {
        strncpy(slot.id, a.album.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, a.album.name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        if (cb) cb(slot.id, slot.name, a.media_count);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_get_child_albums(const char* parent_id, album_callback cb) {
    auto items = Database::instance().get_child_albums(parent_id ? parent_id : "");
    static thread_local AlbumSlot slot;
    for (auto& a : items) {
        strncpy(slot.id, a.album.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, a.album.name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        if (cb) cb(slot.id, slot.name, a.media_count);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
// 返回新相册 ID 字符串
// 使用 static thread_local 使返回的字符串在当前线程生命周期内有效
FFI_EXPORT const char* fmm_create_album(const char* name, const char* parent_id) {
    static thread_local std::string result;
    std::optional<std::string> pid = parent_id
        ? std::optional<std::string>(parent_id)
        : std::nullopt;
    result = Database::instance().create_album(name ? name : "", pid);
    return result.c_str();
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_delete_album(const char* id) {
    return Database::instance().delete_album(id ? id : "");
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_rename_album(const char* id, const char* name) {
    return Database::instance().rename_album(id ? id : "", name ? name : "");
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_get_media_by_album(const char* album_id, media_callback cb) {
    auto items = Database::instance().get_media_by_album(album_id ? album_id : "");
    static thread_local MediaSlot slot;
    for (auto& m : items) {
        strncpy(slot.id, m.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, m.original_name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        strncpy(slot.type, m.media_type.c_str(), sizeof(slot.type) - 1); slot.type[sizeof(slot.type) - 1] = '\0';
        strncpy(slot.path, m.file_path.c_str(), sizeof(slot.path) - 1); slot.path[sizeof(slot.path) - 1] = '\0';
        strncpy(slot.thumb, m.thumbnail_path.c_str(), sizeof(slot.thumb) - 1); slot.thumb[sizeof(slot.thumb) - 1] = '\0';
        slot.size = m.size;
        if (cb) cb(slot.id, slot.name, slot.type, slot.size, slot.path, slot.thumb);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_add_media_to_album(const char** media_ids, int count, const char* album_id) {
    std::vector<std::string> ids;
    for (int i = 0; i < count; i++) {
        ids.push_back(media_ids[i] ? media_ids[i] : "");
    }
    return Database::instance().add_media_to_album(ids, album_id ? album_id : "");
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_add_single_media_to_album(const char* media_id, const char* album_id) {
    std::vector<std::string> ids = {media_id ? media_id : ""};
    return Database::instance().add_media_to_album(ids, album_id ? album_id : "");
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_remove_media_from_album(const char** media_ids, int count, const char* album_id) {
    std::vector<std::string> ids;
    for (int i = 0; i < count; i++) {
        ids.push_back(media_ids[i] ? media_ids[i] : "");
    }
    return Database::instance().remove_media_from_album(ids, album_id ? album_id : "");
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_remove_single_media_from_album(const char* media_id, const char* album_id) {
    std::vector<std::string> ids = {media_id ? media_id : ""};
    return Database::instance().remove_media_from_album(ids, album_id ? album_id : "");
}

// --------------------------------------------------------------------
struct BreadcrumbSlot {
    char id[128];
    char name[256];
};
FFI_EXPORT int fmm_get_album_breadcrumb(const char* album_id, breadcrumb_callback cb) {
    auto items = Database::instance().get_album_breadcrumb(album_id ? album_id : "");
    static thread_local BreadcrumbSlot slot;
    for (auto& i : items) {
        strncpy(slot.id, i.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, i.name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        if (cb) cb(slot.id, slot.name);
    }
    return (int)items.size();
}

// ====================================================================
// 标签
// ====================================================================

// --------------------------------------------------------------------
// 使用 thread_local 静态缓冲区确保字符串指针在回调期间稳定
struct TagSlot {
    char id[128];
    char name[128];
    char color[32];
};
FFI_EXPORT int fmm_get_all_tags(tag_callback cb) {
    auto items = Database::instance().get_all_tags();
    static thread_local TagSlot slot;
    for (auto& t : items) {
        strncpy(slot.id, t.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, t.name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        strncpy(slot.color, t.color.value_or("").c_str(), sizeof(slot.color) - 1); slot.color[sizeof(slot.color) - 1] = '\0';
        if (cb) cb(slot.id, slot.name, slot.color);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_get_root_tags(tag_callback cb) {
    auto items = Database::instance().get_root_tags();
    static thread_local TagSlot slot;
    for (auto& i : items) {
        strncpy(slot.id, i.tag.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, i.tag.name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        strncpy(slot.color, i.tag.color.value_or("").c_str(), sizeof(slot.color) - 1); slot.color[sizeof(slot.color) - 1] = '\0';
        if (cb) cb(slot.id, slot.name, slot.color);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_get_child_tags(const char* parent_id, tag_callback cb) {
    auto items = Database::instance().get_child_tags(parent_id ? parent_id : "");
    static thread_local TagSlot slot;
    for (auto& i : items) {
        strncpy(slot.id, i.tag.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, i.tag.name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        strncpy(slot.color, i.tag.color.value_or("").c_str(), sizeof(slot.color) - 1); slot.color[sizeof(slot.color) - 1] = '\0';
        if (cb) cb(slot.id, slot.name, slot.color);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
FFI_EXPORT const char* fmm_create_tag(const char* name, const char* color, const char* parent_id) {
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
FFI_EXPORT int fmm_delete_tag(const char* id) {
    return Database::instance().delete_tag(id ? id : "");
}

FFI_EXPORT int fmm_rename_tag(const char* id, const char* name) {
    return Database::instance().rename_tag(id ? id : "", name ? name : "");
}

FFI_EXPORT int fmm_update_tag_color(const char* id, const char* color) {
    return Database::instance().update_tag_color(id ? id : "", color ? color : "");
}

FFI_EXPORT int fmm_update_tag_parent(const char* id, const char* parent_id) {
    std::optional<std::string> pid = parent_id
        ? std::optional<std::string>(parent_id)
        : std::nullopt;
    return Database::instance().update_tag_parent(id ? id : "", pid);
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_add_tag_to_media(const char* media_id, const char* tag_id) {
    return Database::instance().add_tag_to_media(
        media_id ? media_id : "", tag_id ? tag_id : "");
}

FFI_EXPORT int fmm_remove_tag_from_media(const char* media_id, const char* tag_id) {
    return Database::instance().remove_tag_from_media(
        media_id ? media_id : "", tag_id ? tag_id : "");
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_get_media_tags(const char* media_id, tag_callback cb) {
    auto items = Database::instance().get_media_tags(media_id ? media_id : "");
    static thread_local TagSlot slot;
    for (auto& t : items) {
        strncpy(slot.id, t.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, t.name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        strncpy(slot.color, t.color.value_or("").c_str(), sizeof(slot.color) - 1); slot.color[sizeof(slot.color) - 1] = '\0';
        if (cb) cb(slot.id, slot.name, slot.color);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_get_media_by_tags_and(const char** tag_ids, int count, media_callback cb) {
    std::vector<std::string> ids;
    for (int i = 0; i < count; i++) {
        ids.push_back(tag_ids[i] ? tag_ids[i] : "");
    }
    auto items = Database::instance().get_media_by_tags_and(ids);
    static thread_local MediaSlot slot;
    for (auto& m : items) {
        strncpy(slot.id, m.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, m.original_name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        strncpy(slot.type, m.media_type.c_str(), sizeof(slot.type) - 1); slot.type[sizeof(slot.type) - 1] = '\0';
        strncpy(slot.path, m.file_path.c_str(), sizeof(slot.path) - 1); slot.path[sizeof(slot.path) - 1] = '\0';
        strncpy(slot.thumb, m.thumbnail_path.c_str(), sizeof(slot.thumb) - 1); slot.thumb[sizeof(slot.thumb) - 1] = '\0';
        slot.size = m.size;
        if (cb) cb(slot.id, slot.name, slot.type, slot.size, slot.path, slot.thumb);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_get_media_by_tags_or(const char** tag_ids, int count, media_callback cb) {
    std::vector<std::string> ids;
    for (int i = 0; i < count; i++) {
        ids.push_back(tag_ids[i] ? tag_ids[i] : "");
    }
    auto items = Database::instance().get_media_by_tags_or(ids);
    static thread_local MediaSlot slot;
    for (auto& m : items) {
        strncpy(slot.id, m.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, m.original_name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        strncpy(slot.type, m.media_type.c_str(), sizeof(slot.type) - 1); slot.type[sizeof(slot.type) - 1] = '\0';
        strncpy(slot.path, m.file_path.c_str(), sizeof(slot.path) - 1); slot.path[sizeof(slot.path) - 1] = '\0';
        strncpy(slot.thumb, m.thumbnail_path.c_str(), sizeof(slot.thumb) - 1); slot.thumb[sizeof(slot.thumb) - 1] = '\0';
        slot.size = m.size;
        if (cb) cb(slot.id, slot.name, slot.type, slot.size, slot.path, slot.thumb);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
// 内部使用 OR 条件并构造单元素 ID 列表
FFI_EXPORT int fmm_get_media_by_single_tag(const char* tag_id, media_callback cb) {
    std::vector<std::string> ids = {tag_id ? tag_id : ""};
    auto items = Database::instance().get_media_by_tags_or(ids);
    static thread_local MediaSlot slot;
    for (auto& m : items) {
        strncpy(slot.id, m.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.name, m.original_name.c_str(), sizeof(slot.name) - 1); slot.name[sizeof(slot.name) - 1] = '\0';
        strncpy(slot.type, m.media_type.c_str(), sizeof(slot.type) - 1); slot.type[sizeof(slot.type) - 1] = '\0';
        strncpy(slot.path, m.file_path.c_str(), sizeof(slot.path) - 1); slot.path[sizeof(slot.path) - 1] = '\0';
        strncpy(slot.thumb, m.thumbnail_path.c_str(), sizeof(slot.thumb) - 1); slot.thumb[sizeof(slot.thumb) - 1] = '\0';
        slot.size = m.size;
        if (cb) cb(slot.id, slot.name, slot.type, slot.size, slot.path, slot.thumb);
    }
    return (int)items.size();
}

// ====================================================================
// 笔记
// ====================================================================

// --------------------------------------------------------------------
// 如果 media_id 已存在笔记则更新，否则插入
FFI_EXPORT int fmm_save_note(const char* media_id, const char* content) {
    return Database::instance().save_note(
        media_id ? media_id : "", content ? content : "");
}

// --------------------------------------------------------------------
FFI_EXPORT int fmm_delete_note(const char* id) {
    return Database::instance().delete_note(id ? id : "");
}

// --------------------------------------------------------------------
// 使用 thread_local 静态缓冲区确保字符串指针在回调期间稳定
struct NoteSlot {
    char id[128];
    char media_id[128];
    char content[8192];
};
FFI_EXPORT int fmm_get_all_notes(note_callback cb) {
    auto items = Database::instance().get_all_notes();
    static thread_local NoteSlot slot;
    for (auto& n : items) {
        strncpy(slot.id, n.id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.media_id, n.media_id.c_str(), sizeof(slot.media_id) - 1); slot.media_id[sizeof(slot.media_id) - 1] = '\0';
        strncpy(slot.content, n.content.c_str(), sizeof(slot.content) - 1); slot.content[sizeof(slot.content) - 1] = '\0';
        if (cb) cb(slot.id, slot.media_id, slot.content, n.created_at, n.updated_at);
    }
    return (int)items.size();
}

// --------------------------------------------------------------------
// 如果找到返回 1，否则返回 0
FFI_EXPORT int fmm_get_note_by_media_id(const char* media_id, note_callback cb) {
    auto n = Database::instance().get_note_by_media_id(
        media_id ? media_id : "");
    if (n.has_value() && cb) {
        static thread_local NoteSlot slot;
        strncpy(slot.id, n->id.c_str(), sizeof(slot.id) - 1); slot.id[sizeof(slot.id) - 1] = '\0';
        strncpy(slot.media_id, n->media_id.c_str(), sizeof(slot.media_id) - 1); slot.media_id[sizeof(slot.media_id) - 1] = '\0';
        strncpy(slot.content, n->content.c_str(), sizeof(slot.content) - 1); slot.content[sizeof(slot.content) - 1] = '\0';
        cb(slot.id, slot.media_id, slot.content, n->created_at, n->updated_at);
        return 1;
    }
    return 0;
}

// --------------------------------------------------------------------
// 块内所有函数使用 C 语言链接，避免名称修饰
} // extern "C"
