use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// 媒体类型枚举
#[frb]
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum MediaType {
    Image,
    Video,
    Audio,
    Unknown,
}

/// 媒体项实体（对应参考项目的 MediaItemEntity）
#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MediaItem {
    pub id: String,
    pub original_name: String,
    pub storage_name: String,
    pub file_path: String,
    pub thumbnail_path: String,
    pub media_type: MediaType,
    pub mime_type: String,
    pub size: i64,
    pub width: Option<i32>,
    pub height: Option<i32>,
    pub duration: Option<i64>,
    pub sha256_hash: String,
    pub created_at: i64,
    pub updated_at: i64,
}

/// 相邻媒体（用于查看器导航）
#[frb]
#[derive(Debug, Clone)]
pub struct AdjacentMedia {
    pub previous: Option<MediaItem>,
    pub current: MediaItem,
    pub next: Option<MediaItem>,
}

/// 获取所有媒体列表
#[frb]
pub async fn get_all_media() -> Result<Vec<MediaItem>, String> {
    // TODO: 实现数据库查询
    Ok(vec![])
}

/// 按ID获取媒体
#[frb]
pub async fn get_media_by_id(id: String) -> Result<Option<MediaItem>, String> {
    // TODO: 实现
    Ok(None)
}

/// 删除媒体
#[frb]
pub async fn delete_media(id: String) -> Result<(), String> {
    // TODO: 实现
    Ok(())
}

/// 获取相邻媒体
#[frb]
pub async fn get_adjacent_media(id: String) -> Result<Option<AdjacentMedia>, String> {
    // TODO: 实现
    Ok(None)
}

/// 搜索媒体
#[frb]
pub async fn search_media(query: String) -> Result<Vec<MediaItem>, String> {
    // TODO: 实现
    Ok(vec![])
}

/// 按类型过滤媒体
#[frb]
pub async fn filter_media_by_type(media_type: MediaType) -> Result<Vec<MediaItem>, String> {
    // TODO: 实现
    Ok(vec![])
}

/// 更新媒体信息
#[frb]
pub async fn update_media(media: MediaItem) -> Result<(), String> {
    // TODO: 实现
    Ok(())
}
