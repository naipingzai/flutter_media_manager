use crate::api::{
    media::{MediaItem, MediaType},
    album::{Album, AlbumWithInfo, BreadcrumbItem},
    tag::{Tag, TagWithInfo, TagBreadcrumb},
    note::Note,
    settings::{AppSettings, ThemeMode},
};
use sqlx::Row;

/// 从数据库行转换为 MediaItem
/// 注意：数据库中 type 字段存储为 TEXT（"image"/"video"/"audio"/"document"/"other"）
pub fn row_to_media_item(row: &sqlx::sqlite::SqliteRow) -> MediaItem {
    MediaItem {
        id: row.get("id"),
        original_name: row.get("original_name"),
        storage_name: row.get("storage_name"),
        file_path: row.get("file_path"),
        thumbnail_path: row.get("thumbnail_path"),
        media_type: match row.get::<String, _>("type").as_str() {
            "image" => MediaType::Image,
            "video" => MediaType::Video,
            "audio" => MediaType::Audio,
            "document" => MediaType::Document,
            _ => MediaType::Other,
        },
        mime_type: row.get("mime_type"),
        size: row.get::<i64, _>("size"),
        width: row.get::<Option<i32>, _>("width"),
        height: row.get::<Option<i32>, _>("height"),
        duration: row.get::<Option<i64>, _>("duration"),
        sha256_hash: row.get("sha256_hash"),
        created_at: row.get::<i64, _>("created_at"),
        updated_at: row.get::<i64, _>("updated_at"),
    }
}

/// 从数据库行转换为 Album
pub fn row_to_album(row: &sqlx::sqlite::SqliteRow) -> Album {
    Album {
        id: row.get("id"),
        name: row.get("name"),
        parent_id: row.get::<Option<String>, _>("parent_id"),
        cover_media_id: row.get::<Option<String>, _>("cover_media_id"),
        sort_order: row.get::<i32, _>("sort_order"),
        created_at: row.get::<i64, _>("created_at"),
    }
}

/// 从数据库行转换为 Tag
pub fn row_to_tag(row: &sqlx::sqlite::SqliteRow) -> Tag {
    Tag {
        id: row.get("id"),
        name: row.get("name"),
        color: row.get::<Option<String>, _>("color"),
        parent_id: row.get::<Option<String>, _>("parent_id"),
        created_at: row.get::<i64, _>("created_at"),
    }
}

/// 从数据库行转换为 Note
/// 注意：media_id 现在可为 null（支持独立笔记），新增 title 字段
pub fn row_to_note(row: &sqlx::sqlite::SqliteRow) -> Note {
    Note {
        id: row.get("id"),
        media_id: row.get::<Option<String>, _>("media_id"),
        title: row.get("title"),
        content: row.get("content"),
        created_at: row.get::<i64, _>("created_at"),
        updated_at: row.get::<i64, _>("updated_at"),
    }
}

/// 从数据库行转换为 AppSettings
pub fn row_to_settings(row: &sqlx::sqlite::SqliteRow) -> AppSettings {
    AppSettings {
        theme_mode: match row.get::<i32, _>("theme_mode") {
            0 => ThemeMode::System,
            1 => ThemeMode::Light,
            2 => ThemeMode::Dark,
            _ => ThemeMode::System,
        },
        grid_columns: row.get::<i32, _>("grid_columns"),
        album_grid_columns: row.get::<i32, _>("album_grid_columns"),
        show_content_previews: row.get::<i32, _>("show_content_previews"),
        thumbnail_quality: row.get::<i32, _>("thumbnail_quality"),
        language: row.get("language"),
        dynamic_color: row.try_get::<i32, _>("dynamic_color").unwrap_or(1),
    }
}
