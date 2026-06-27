use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use crate::db::{get_pool, models::row_to_media_item};
use crate::api::enums::FilterMode;

/// 媒体类型枚举
#[frb]
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum MediaType {
    Image,
    Video,
    Audio,
    Document,
    Other,
}

impl MediaType {
    /// 转换为数据库存储的 TEXT 值
    pub fn as_str(&self) -> &'static str {
        match self {
            MediaType::Image => "image",
            MediaType::Video => "video",
            MediaType::Audio => "audio",
            MediaType::Document => "document",
            MediaType::Other => "other",
        }
    }
    
    /// 从数据库 TEXT 值解析
    pub fn from_str(s: &str) -> Self {
        match s {
            "image" => MediaType::Image,
            "video" => MediaType::Video,
            "audio" => MediaType::Audio,
            "document" => MediaType::Document,
            _ => MediaType::Other,
        }
    }
    
    /// 兼容旧接口：转换为 i32
    pub fn as_i32(&self) -> i32 {
        match self {
            MediaType::Image => 0,
            MediaType::Video => 1,
            MediaType::Audio => 2,
            MediaType::Document => 3,
            MediaType::Other => 4,
        }
    }
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

/// 获取所有媒体列表（按创建时间倒序）
#[frb]
pub async fn get_all_media() -> Result<Vec<MediaItem>, String> {
    let pool = get_pool()?;
    let rows = sqlx::query(
        "SELECT * FROM media_items ORDER BY created_at DESC"
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| format!("查询媒体失败: {}", e))?;

    Ok(rows.iter().map(row_to_media_item).collect())
}

/// 按ID获取媒体
#[frb]
pub async fn get_media_by_id(id: String) -> Result<Option<MediaItem>, String> {
    let pool = get_pool()?;
    let row = sqlx::query("SELECT * FROM media_items WHERE id = ?")
        .bind(&id)
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询媒体失败: {}", e))?;

    Ok(row.as_ref().map(row_to_media_item))
}

/// 删除媒体（同时删除关联的相册、标签、笔记关系）
#[frb]
pub async fn delete_media(id: String) -> Result<(), String> {
    let pool = get_pool()?;
    let mut tx = pool.begin().await.map_err(|e| format!("开启事务失败: {}", e))?;

    // 删除关联关系
    sqlx::query("DELETE FROM album_media WHERE media_id = ?")
        .bind(&id)
        .execute(&mut *tx)
        .await
        .map_err(|e| format!("删除相册关联失败: {}", e))?;

    sqlx::query("DELETE FROM media_tags WHERE media_id = ?")
        .bind(&id)
        .execute(&mut *tx)
        .await
        .map_err(|e| format!("删除标签关联失败: {}", e))?;

    sqlx::query("DELETE FROM notes WHERE media_id = ?")
        .bind(&id)
        .execute(&mut *tx)
        .await
        .map_err(|e| format!("删除笔记失败: {}", e))?;

    // 删除媒体本身
    sqlx::query("DELETE FROM media_items WHERE id = ?")
        .bind(&id)
        .execute(&mut *tx)
        .await
        .map_err(|e| format!("删除媒体失败: {}", e))?;

    tx.commit().await.map_err(|e| format!("提交事务失败: {}", e))?;
    Ok(())
}

/// 获取相邻媒体（按创建时间排序）
#[frb]
pub async fn get_adjacent_media(id: String) -> Result<Option<AdjacentMedia>, String> {
    let pool = get_pool()?;

    // 获取当前媒体
    let current_row = sqlx::query("SELECT * FROM media_items WHERE id = ?")
        .bind(&id)
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询当前媒体失败: {}", e))?;

    let current = match current_row {
        Some(row) => row_to_media_item(&row),
        None => return Ok(None),
    };

    // 获取上一个媒体（创建时间更早）
    let previous_row = sqlx::query(
        "SELECT * FROM media_items WHERE created_at < ? ORDER BY created_at DESC LIMIT 1"
    )
    .bind(current.created_at)
    .fetch_optional(&pool)
    .await
    .map_err(|e| format!("查询上一个媒体失败: {}", e))?;

    // 获取下一个媒体（创建时间更晚）
    let next_row = sqlx::query(
        "SELECT * FROM media_items WHERE created_at > ? ORDER BY created_at ASC LIMIT 1"
    )
    .bind(current.created_at)
    .fetch_optional(&pool)
    .await
    .map_err(|e| format!("查询下一个媒体失败: {}", e))?;

    Ok(Some(AdjacentMedia {
        previous: previous_row.as_ref().map(row_to_media_item),
        current,
        next: next_row.as_ref().map(row_to_media_item),
    }))
}

/// 搜索媒体（按原始名称模糊匹配）
#[frb]
pub async fn search_media(query: String) -> Result<Vec<MediaItem>, String> {
    let pool = get_pool()?;
    let search_pattern = format!("%{}%", query);

    let rows = sqlx::query(
        "SELECT * FROM media_items WHERE original_name LIKE ? ORDER BY created_at DESC"
    )
    .bind(&search_pattern)
    .fetch_all(&pool)
    .await
    .map_err(|e| format!("搜索媒体失败: {}", e))?;

    Ok(rows.iter().map(row_to_media_item).collect())
}

/// 按类型过滤媒体
#[frb]
pub async fn filter_media_by_type(media_type: MediaType) -> Result<Vec<MediaItem>, String> {
    let pool = get_pool()?;
    let type_str = media_type.as_str();

    let rows = sqlx::query(
        "SELECT * FROM media_items WHERE type = ? ORDER BY created_at DESC"
    )
    .bind(type_str)
    .fetch_all(&pool)
    .await
    .map_err(|e| format!("按类型过滤媒体失败: {}", e))?;

    Ok(rows.iter().map(row_to_media_item).collect())
}

/// 更新媒体信息（仅更新名称）
#[frb]
pub async fn update_media(media: MediaItem) -> Result<(), String> {
    let pool = get_pool()?;
    let now = chrono::Utc::now().timestamp();

    sqlx::query(
        "UPDATE media_items SET original_name = ?, updated_at = ? WHERE id = ?"
    )
    .bind(&media.original_name)
    .bind(now)
    .bind(&media.id)
    .execute(&pool)
    .await
    .map_err(|e| format!("更新媒体失败: {}", e))?;

    Ok(())
}

/// Skill-02 §1.5 - FilterMode 过滤查询
/// 根据过滤模式获取媒体列表
#[frb]
pub async fn get_media_by_filter(filter: FilterMode) -> Result<Vec<MediaItem>, String> {
    let pool = get_pool()?;

    let sql = match filter {
        FilterMode::All => {
            return get_all_media().await;
        }
        FilterMode::WithTags => {
            "SELECT DISTINCT m.* FROM media_items m
             INNER JOIN media_tags mt ON m.id = mt.media_id
             ORDER BY m.created_at DESC"
        }
        FilterMode::WithoutTags => {
            "SELECT m.* FROM media_items m
             WHERE m.id NOT IN (SELECT media_id FROM media_tags)
             ORDER BY m.created_at DESC"
        }
        FilterMode::WithAlbums => {
            "SELECT DISTINCT m.* FROM media_items m
             INNER JOIN album_media am ON m.id = am.media_id
             ORDER BY m.created_at DESC"
        }
        FilterMode::WithoutAlbums => {
            "SELECT m.* FROM media_items m
             WHERE m.id NOT IN (SELECT media_id FROM album_media)
             ORDER BY m.created_at DESC"
        }
    };

    let rows = sqlx::query(sql)
        .fetch_all(&pool)
        .await
        .map_err(|e| format!("过滤媒体失败: {}", e))?;

    Ok(rows.iter().map(row_to_media_item).collect())
}

/// 批量删除媒体
#[frb]
pub async fn batch_delete_media(ids: Vec<String>) -> Result<(), String> {
    let pool = get_pool()?;
    let mut tx = pool.begin().await.map_err(|e| format!("开启事务失败: {}", e))?;

    for id in &ids {
        // 删除关联关系
        sqlx::query("DELETE FROM album_media WHERE media_id = ?")
            .bind(id).execute(&mut *tx).await
            .map_err(|e| format!("删除相册关联失败: {}", e))?;
        sqlx::query("DELETE FROM media_tags WHERE media_id = ?")
            .bind(id).execute(&mut *tx).await
            .map_err(|e| format!("删除标签关联失败: {}", e))?;
        sqlx::query("DELETE FROM notes WHERE media_id = ?")
            .bind(id).execute(&mut *tx).await
            .map_err(|e| format!("删除笔记失败: {}", e))?;
        sqlx::query("DELETE FROM media_items WHERE id = ?")
            .bind(id).execute(&mut *tx).await
            .map_err(|e| format!("删除媒体失败: {}", e))?;
    }

    tx.commit().await.map_err(|e| format!("提交事务失败: {}", e))?;
    Ok(())
}

/// 获取带标签的媒体列表（附带标签信息）
#[frb]
pub async fn get_media_with_tags(id: String) -> Result<Option<MediaItem>, String> {
    get_media_by_id(id).await
}
