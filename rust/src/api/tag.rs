use flutter_rust_bridge::frb;
use crate::db::{get_pool, models::{row_to_tag, row_to_media_item}};
use crate::api::media::MediaItem;
use sqlx::Row;
use uuid::Uuid;

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
    pub has_children: i32,
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
    let pool = get_pool()?;
    let rows = sqlx::query("SELECT * FROM tags ORDER BY name")
        .fetch_all(&pool)
        .await
        .map_err(|e| format!("查询所有标签失败: {}", e))?;

    Ok(rows.iter().map(row_to_tag).collect())
}

/// 获取根标签
#[frb]
pub async fn get_root_tags() -> Result<Vec<TagWithInfo>, String> {
    get_tags_by_parent(None).await
}

/// 获取子标签
#[frb]
pub async fn get_child_tags(parent_id: String) -> Result<Vec<TagWithInfo>, String> {
    get_tags_by_parent(Some(parent_id)).await
}

async fn get_tags_by_parent(parent_id: Option<String>) -> Result<Vec<TagWithInfo>, String> {
    let pool = get_pool()?;

    let rows = match &parent_id {
        Some(pid) => sqlx::query(
            "SELECT t.*,
                (SELECT COUNT(*) FROM media_tags mt WHERE mt.tag_id = t.id) as media_count,
                (SELECT COUNT(*) FROM tags ct WHERE ct.parent_id = t.id) as child_count,
                (SELECT m.thumbnail_path FROM media_items m
                 JOIN media_tags mt ON m.id = mt.media_id
                 WHERE mt.tag_id = t.id LIMIT 1) as cover_thumbnail
             FROM tags t WHERE t.parent_id = ? ORDER BY t.name"
        )
        .bind(pid)
        .fetch_all(&pool)
        .await
        .map_err(|e| format!("查询子标签失败: {}", e))?,
        None => sqlx::query(
            "SELECT t.*,
                (SELECT COUNT(*) FROM media_tags mt WHERE mt.tag_id = t.id) as media_count,
                (SELECT COUNT(*) FROM tags ct WHERE ct.parent_id = t.id) as child_count,
                (SELECT m.thumbnail_path FROM media_items m
                 JOIN media_tags mt ON m.id = mt.media_id
                 WHERE mt.tag_id = t.id LIMIT 1) as cover_thumbnail
             FROM tags t WHERE t.parent_id IS NULL ORDER BY t.name"
        )
        .fetch_all(&pool)
        .await
        .map_err(|e| format!("查询根标签失败: {}", e))?,
    };

    Ok(rows.iter().map(|row| {
        let tag = row_to_tag(row);
        let media_count: i64 = row.get("media_count");
        let child_count: i64 = row.get("child_count");
        let cover_thumbnail: Option<String> = row.get("cover_thumbnail");
        TagWithInfo {
            tag,
            media_count: media_count as i32,
            cover_thumbnail_path: cover_thumbnail,
            has_children: if child_count > 0 { 1 } else { 0 },
        }
    }).collect())
}

/// 创建标签
#[frb]
pub async fn create_tag(name: String, color: Option<String>, parent_id: Option<String>) -> Result<String, String> {
    let pool = get_pool()?;
    let id = Uuid::new_v4().to_string();
    let now = chrono::Utc::now().timestamp();

    sqlx::query(
        "INSERT INTO tags (id, name, color, parent_id, created_at) VALUES (?, ?, ?, ?, ?)"
    )
    .bind(&id)
    .bind(&name)
    .bind(&color)
    .bind(&parent_id)
    .bind(now)
    .execute(&pool)
    .await
    .map_err(|e| format!("创建标签失败: {}", e))?;

    Ok(id)
}

/// 删除标签（级联删除子标签和媒体关联）
#[frb]
pub async fn delete_tag(id: String) -> Result<(), String> {
    let pool = get_pool()?;

    // 外键设置了 ON DELETE CASCADE
    sqlx::query("DELETE FROM tags WHERE id = ?")
        .bind(&id)
        .execute(&pool)
        .await
        .map_err(|e| format!("删除标签失败: {}", e))?;

    Ok(())
}

/// 重命名标签
#[frb]
pub async fn rename_tag(id: String, new_name: String) -> Result<(), String> {
    let pool = get_pool()?;

    sqlx::query("UPDATE tags SET name = ? WHERE id = ?")
        .bind(&new_name)
        .bind(&id)
        .execute(&pool)
        .await
        .map_err(|e| format!("重命名标签失败: {}", e))?;

    Ok(())
}

/// 获取标签面包屑路径
#[frb]
pub async fn get_tag_breadcrumb(tag_id: String) -> Result<Vec<TagBreadcrumb>, String> {
    let pool = get_pool()?;
    let mut breadcrumbs = vec![];

    let mut current_id = Some(tag_id);
    while let Some(id) = current_id {
        let row = sqlx::query("SELECT id, name, parent_id FROM tags WHERE id = ?")
            .bind(&id)
            .fetch_optional(&pool)
            .await
            .map_err(|e| format!("查询标签失败: {}", e))?;

        if let Some(row) = row {
            let id: String = row.get("id");
            let name: String = row.get("name");
            let parent_id: Option<String> = row.get("parent_id");
            breadcrumbs.push(TagBreadcrumb { id, name });
            current_id = parent_id;
        } else {
            break;
        }
    }

    breadcrumbs.reverse();
    Ok(breadcrumbs)
}

/// 添加标签到媒体
#[frb]
pub async fn add_tag_to_media(media_id: String, tag_id: String) -> Result<(), String> {
    let pool = get_pool()?;

    sqlx::query(
        "INSERT OR IGNORE INTO media_tags (media_id, tag_id) VALUES (?, ?)"
    )
    .bind(&media_id)
    .bind(&tag_id)
    .execute(&pool)
    .await
    .map_err(|e| format!("添加标签到媒体失败: {}", e))?;

    Ok(())
}

/// 从媒体移除标签
#[frb]
pub async fn remove_tag_from_media(media_id: String, tag_id: String) -> Result<(), String> {
    let pool = get_pool()?;

    sqlx::query("DELETE FROM media_tags WHERE media_id = ? AND tag_id = ?")
        .bind(&media_id)
        .bind(&tag_id)
        .execute(&pool)
        .await
        .map_err(|e| format!("从媒体移除标签失败: {}", e))?;

    Ok(())
}

/// 获取媒体的标签
#[frb]
pub async fn get_media_tags(media_id: String) -> Result<Vec<Tag>, String> {
    let pool = get_pool()?;

    let rows = sqlx::query(
        "SELECT t.* FROM tags t
         JOIN media_tags mt ON t.id = mt.tag_id
         WHERE mt.media_id = ? ORDER BY t.name"
    )
    .bind(&media_id)
    .fetch_all(&pool)
    .await
    .map_err(|e| format!("获取媒体标签失败: {}", e))?;

    Ok(rows.iter().map(row_to_tag).collect())
}

/// 按标签筛选媒体（AND 模式 - 媒体必须包含所有指定标签）
#[frb]
pub async fn get_media_by_tags_and(tag_ids: Vec<String>) -> Result<Vec<MediaItem>, String> {
    if tag_ids.is_empty() {
        return Ok(vec![]);
    }

    let pool = get_pool()?;
    let tag_count = tag_ids.len() as i64;

    // 构建 IN 子句
    let placeholders = tag_ids.iter().map(|_| "?").collect::<Vec<_>>().join(",");
    let sql = format!(
        "SELECT m.* FROM media_items m
         JOIN media_tags mt ON m.id = mt.media_id
         WHERE mt.tag_id IN ({})
         GROUP BY m.id
         HAVING COUNT(DISTINCT mt.tag_id) = ?
         ORDER BY m.created_at DESC",
        placeholders
    );

    let mut query = sqlx::query(&sql);
    for tag_id in &tag_ids {
        query = query.bind(tag_id);
    }
    query = query.bind(tag_count);

    let rows = query
        .fetch_all(&pool)
        .await
        .map_err(|e| format!("AND 标签筛选失败: {}", e))?;

    Ok(rows.iter().map(row_to_media_item).collect())
}

/// 按标签筛选媒体（OR 模式 - 媒体包含任意指定标签）
#[frb]
pub async fn get_media_by_tags_or(tag_ids: Vec<String>) -> Result<Vec<MediaItem>, String> {
    if tag_ids.is_empty() {
        return Ok(vec![]);
    }

    let pool = get_pool()?;

    let placeholders = tag_ids.iter().map(|_| "?").collect::<Vec<_>>().join(",");
    let sql = format!(
        "SELECT DISTINCT m.* FROM media_items m
         JOIN media_tags mt ON m.id = mt.media_id
         WHERE mt.tag_id IN ({})
         ORDER BY m.created_at DESC",
        placeholders
    );

    let mut query = sqlx::query(&sql);
    for tag_id in &tag_ids {
        query = query.bind(tag_id);
    }

    let rows = query
        .fetch_all(&pool)
        .await
        .map_err(|e| format!("OR 标签筛选失败: {}", e))?;

    Ok(rows.iter().map(row_to_media_item).collect())
}

/// 确保默认标签存在（如果不存在则创建）
#[frb]
pub async fn ensure_default_tag(name: String, color: Option<String>) -> Result<String, String> {
    let pool = get_pool()?;

    let row = sqlx::query("SELECT id FROM tags WHERE name = ? AND parent_id IS NULL")
        .bind(&name)
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询默认标签失败: {}", e))?;

    if let Some(row) = row {
        let id: String = row.get("id");
        return Ok(id);
    }

    create_tag(name, color, None).await
}
