use flutter_rust_bridge::frb;

/// 相册实体
#[frb]
#[derive(Debug, Clone)]
pub struct Album {
    pub id: String,
    pub name: String,
    pub parent_id: Option<String>,
    pub cover_media_id: Option<String>,
    pub sort_order: i32,
    pub created_at: i64,
}

/// 相册信息（包含媒体数量和子相册标志）
#[frb]
#[derive(Debug, Clone)]
pub struct AlbumWithInfo {
    pub album: Album,
    pub media_count: i32,
    pub cover_thumbnail_path: Option<String>,
    pub has_children: bool,
}

/// 面包屑项
#[frb]
#[derive(Debug, Clone)]
pub struct BreadcrumbItem {
    pub id: String,
    pub name: String,
}

/// 获取根相册列表
#[frb]
pub async fn get_root_albums() -> Result<Vec<AlbumWithInfo>, String> {
    Ok(vec![])
}

/// 获取子相册
#[frb]
pub async fn get_child_albums(parent_id: String) -> Result<Vec<AlbumWithInfo>, String> {
    Ok(vec![])
}

/// 创建相册
#[frb]
pub async fn create_album(name: String, parent_id: Option<String>) -> Result<String, String> {
    Ok(String::new())
}

/// 删除相册
#[frb]
pub async fn delete_album(id: String) -> Result<(), String> {
    Ok(())
}

/// 重命名相册
#[frb]
pub async fn rename_album(id: String, new_name: String) -> Result<(), String> {
    Ok(())
}

/// 获取相册面包屑路径
#[frb]
pub async fn get_album_breadcrumb(album_id: String) -> Result<Vec<BreadcrumbItem>, String> {
    Ok(vec![])
}

/// 添加媒体到相册
#[frb]
pub async fn add_media_to_album(media_ids: Vec<String>, album_id: String) -> Result<(), String> {
    Ok(())
}

/// 从相册移除媒体
#[frb]
pub async fn remove_media_from_album(media_ids: Vec<String>, album_id: String) -> Result<(), String> {
    Ok(())
}

/// 设置相册封面
#[frb]
pub async fn set_album_cover(album_id: String, media_id: String) -> Result<(), String> {
    Ok(())
}

/// 确保默认相册存在
#[frb]
pub async fn ensure_default_album(name: String) -> Result<String, String> {
    Ok(String::new())
}
