use flutter_rust_bridge::frb;
use crate::db::{get_pool, models::row_to_album};
use sqlx::Row;
use uuid::Uuid;

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
    get_albums_by_parent(None).await
}

/// 获取子相册
#[frb]
pub async fn get_child_albums(parent_id: String) -> Result<Vec<AlbumWithInfo>, String> {
    get_albums_by_parent(Some(parent_id)).await
}

async fn get_albums_by_parent(parent_id: Option<String>) -> Result<Vec<AlbumWithInfo>, String> {
    let pool = get_pool()?;

    let rows = match &parent_id {
        Some(pid) => sqlx::query(
            "SELECT a.*,
                (SELECT COUNT(*) FROM media_albums ma WHERE ma.album_id = a.id) as media_count,
                (SELECT COUNT(*) FROM albums ca WHERE ca.parent_id = a.id) as child_count,
                (SELECT m.thumbnail_path FROM media_items m WHERE m.id = a.cover_media_id LIMIT 1) as cover_thumbnail
             FROM albums a WHERE a.parent_id = ? ORDER BY a.sort_order, a.created_at"
        )
        .bind(pid)
        .fetch_all(&pool)
        .await
        .map_err(|e| format!("查询子相册失败: {}", e))?,
        None => sqlx::query(
            "SELECT a.*,
                (SELECT COUNT(*) FROM media_albums ma WHERE ma.album_id = a.id) as media_count,
                (SELECT COUNT(*) FROM albums ca WHERE ca.parent_id = a.id) as child_count,
                (SELECT m.thumbnail_path FROM media_items m WHERE m.id = a.cover_media_id LIMIT 1) as cover_thumbnail
             FROM albums a WHERE a.parent_id IS NULL ORDER BY a.sort_order, a.created_at"
        )
        .fetch_all(&pool)
        .await
        .map_err(|e| format!("查询根相册失败: {}", e))?,
    };

    Ok(rows.iter().map(|row| {
        let album = row_to_album(row);
        let media_count: i64 = row.get("media_count");
        let child_count: i64 = row.get("child_count");
        let cover_thumbnail: Option<String> = row.get("cover_thumbnail");
        AlbumWithInfo {
            album,
            media_count: media_count as i32,
            cover_thumbnail_path: cover_thumbnail,
            has_children: child_count > 0,
        }
    }).collect())
}

/// 创建相册
#[frb]
pub async fn create_album(name: String, parent_id: Option<String>) -> Result<String, String> {
    let pool = get_pool()?;
    let id = Uuid::new_v4().to_string();
    let now = chrono::Utc::now().timestamp();

    sqlx::query(
        "INSERT INTO albums (id, name, parent_id, cover_media_id, sort_order, created_at)
         VALUES (?, ?, ?, NULL, 0, ?)"
    )
    .bind(&id)
    .bind(&name)
    .bind(&parent_id)
    .bind(now)
    .execute(&pool)
    .await
    .map_err(|e| format!("创建相册失败: {}", e))?;

    Ok(id)
}

/// 删除相册（级联删除子相册和媒体关联）
#[frb]
pub async fn delete_album(id: String) -> Result<(), String> {
    let pool = get_pool()?;

    // 由于外键设置了 ON DELETE CASCADE，直接删除即可
    sqlx::query("DELETE FROM albums WHERE id = ?")
        .bind(&id)
        .execute(&pool)
        .await
        .map_err(|e| format!("删除相册失败: {}", e))?;

    Ok(())
}

/// 重命名相册
#[frb]
pub async fn rename_album(id: String, new_name: String) -> Result<(), String> {
    let pool = get_pool()?;

    sqlx::query("UPDATE albums SET name = ? WHERE id = ?")
        .bind(&new_name)
        .bind(&id)
        .execute(&pool)
        .await
        .map_err(|e| format!("重命名相册失败: {}", e))?;

    Ok(())
}

/// 获取相册面包屑路径
#[frb]
pub async fn get_album_breadcrumb(album_id: String) -> Result<Vec<BreadcrumbItem>, String> {
    let pool = get_pool()?;
    let mut breadcrumbs = vec![];

    let mut current_id = Some(album_id);
    while let Some(id) = current_id {
        let row = sqlx::query("SELECT id, name, parent_id FROM albums WHERE id = ?")
            .bind(&id)
            .fetch_optional(&pool)
            .await
            .map_err(|e| format!("查询相册失败: {}", e))?;

        if let Some(row) = row {
            let id: String = row.get("id");
            let name: String = row.get("name");
            let parent_id: Option<String> = row.get("parent_id");
            breadcrumbs.push(BreadcrumbItem { id, name });
            current_id = parent_id;
        } else {
            break;
        }
    }

    // 反转使根相册在前
    breadcrumbs.reverse();
    Ok(breadcrumbs)
}

/// 添加媒体到相册
#[frb]
pub async fn add_media_to_album(media_ids: Vec<String>, album_id: String) -> Result<(), String> {
    let pool = get_pool()?;
    let mut tx = pool.begin().await.map_err(|e| format!("开启事务失败: {}", e))?;

    for media_id in media_ids {
        sqlx::query(
            "INSERT OR IGNORE INTO media_albums (media_id, album_id) VALUES (?, ?)"
        )
        .bind(&media_id)
        .bind(&album_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| format!("添加媒体到相册失败: {}", e))?;
    }

    tx.commit().await.map_err(|e| format!("提交事务失败: {}", e))?;
    Ok(())
}

/// 从相册移除媒体
#[frb]
pub async fn remove_media_from_album(media_ids: Vec<String>, album_id: String) -> Result<(), String> {
    let pool = get_pool()?;

    for media_id in media_ids {
        sqlx::query("DELETE FROM media_albums WHERE media_id = ? AND album_id = ?")
            .bind(&media_id)
            .bind(&album_id)
            .execute(&pool)
            .await
            .map_err(|e| format!("从相册移除媒体失败: {}", e))?;
    }

    Ok(())
}

/// 设置相册封面
#[frb]
pub async fn set_album_cover(album_id: String, media_id: String) -> Result<(), String> {
    let pool = get_pool()?;

    sqlx::query("UPDATE albums SET cover_media_id = ? WHERE id = ?")
        .bind(&media_id)
        .bind(&album_id)
        .execute(&pool)
        .await
        .map_err(|e| format!("设置相册封面失败: {}", e))?;

    Ok(())
}

/// 确保默认相册存在（如果不存在则创建）
#[frb]
pub async fn ensure_default_album(name: String) -> Result<String, String> {
    let pool = get_pool()?;

    let row = sqlx::query("SELECT id FROM albums WHERE name = ? AND parent_id IS NULL")
        .bind(&name)
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询默认相册失败: {}", e))?;

    if let Some(row) = row {
        let id: String = row.get("id");
        return Ok(id);
    }

    // 不存在则创建
    create_album(name, None).await
}
