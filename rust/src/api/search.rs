use flutter_rust_bridge::frb;
use crate::api::media::MediaItem;

/// 搜索筛选条件
#[frb]
#[derive(Debug, Clone, Default)]
pub struct SearchFilter {
    pub query: Option<String>,
    pub media_type: Option<String>,
    pub start_date: Option<i64>,
    pub end_date: Option<i64>,
    pub album_id: Option<String>,
    pub tag_ids: Option<Vec<String>>,
    pub tag_count: Option<i32>,
}

/// 综合搜索
#[frb]
pub async fn search_media_advanced(filter: SearchFilter) -> Result<Vec<MediaItem>, String> {
    Ok(vec![])
}

/// 获取有标签的媒体
#[frb]
pub async fn get_media_with_any_tag() -> Result<Vec<MediaItem>, String> {
    Ok(vec![])
}

/// 获取无标签的媒体
#[frb]
pub async fn get_media_without_any_tag() -> Result<Vec<MediaItem>, String> {
    Ok(vec![])
}

/// 获取有相册的媒体
#[frb]
pub async fn get_media_with_any_album() -> Result<Vec<MediaItem>, String> {
    Ok(vec![])
}

/// 获取无相册的媒体
#[frb]
pub async fn get_media_without_any_album() -> Result<Vec<MediaItem>, String> {
    Ok(vec![])
}
