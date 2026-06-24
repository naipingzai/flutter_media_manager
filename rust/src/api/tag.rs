use flutter_rust_bridge::frb;

/// 标签实体
#[frb]
#[derive(Debug, Clone)]
pub struct Tag {
    pub id: String,
    pub name: String,
    pub color: Option<String>,
    pub parent_id: Option<String>,
    pub created_at: i64,
}

/// 标签信息（包含媒体数量和子标签标志）
#[frb]
#[derive(Debug, Clone)]
pub struct TagWithInfo {
    pub tag: Tag,
    pub media_count: i32,
    pub cover_thumbnail_path: Option<String>,
    pub has_children: bool,
}

/// 标签面包屑项
#[frb]
#[derive(Debug, Clone)]
pub struct TagBreadcrumb {
    pub id: String,
    pub name: String,
}

/// 过滤模式
#[frb]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FilterMode {
    And,
    Or,
}

/// 获取所有标签
#[frb]
pub async fn get_all_tags() -> Result<Vec<Tag>, String> {
    Ok(vec![])
}

/// 获取根标签
#[frb]
pub async fn get_root_tags() -> Result<Vec<TagWithInfo>, String> {
    Ok(vec![])
}

/// 获取子标签
#[frb]
pub async fn get_child_tags(parent_id: String) -> Result<Vec<TagWithInfo>, String> {
    Ok(vec![])
}

/// 创建标签
#[frb]
pub async fn create_tag(name: String, color: Option<String>, parent_id: Option<String>) -> Result<String, String> {
    Ok(String::new())
}

/// 删除标签
#[frb]
pub async fn delete_tag(id: String) -> Result<(), String> {
    Ok(())
}

/// 重命名标签
#[frb]
pub async fn rename_tag(id: String, new_name: String) -> Result<(), String> {
    Ok(())
}

/// 获取标签面包屑路径
#[frb]
pub async fn get_tag_breadcrumb(tag_id: String) -> Result<Vec<TagBreadcrumb>, String> {
    Ok(vec![])
}

/// 添加标签到媒体
#[frb]
pub async fn add_tag_to_media(media_id: String, tag_id: String) -> Result<(), String> {
    Ok(())
}

/// 从媒体移除标签
#[frb]
pub async fn remove_tag_from_media(media_id: String, tag_id: String) -> Result<(), String> {
    Ok(())
}

/// 获取媒体的标签
#[frb]
pub async fn get_media_tags(media_id: String) -> Result<Vec<Tag>, String> {
    Ok(vec![])
}

/// 按标签筛选媒体（AND 模式）
#[frb]
pub async fn get_media_by_tags_and(tag_ids: Vec<String>) -> Result<Vec<crate::api::media::MediaItem>, String> {
    Ok(vec![])
}

/// 按标签筛选媒体（OR 模式）
#[frb]
pub async fn get_media_by_tags_or(tag_ids: Vec<String>) -> Result<Vec<crate::api::media::MediaItem>, String> {
    Ok(vec![])
}

/// 确保默认标签存在
#[frb]
pub async fn ensure_default_tag(name: String, color: Option<String>) -> Result<String, String> {
    Ok(String::new())
}
