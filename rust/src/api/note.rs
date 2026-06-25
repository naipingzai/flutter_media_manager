use flutter_rust_bridge::frb;
use crate::db::{get_pool, models::row_to_note};
use sqlx::Row;
use uuid::Uuid;

/// 笔记实体
#[frb]
#[derive(Debug, Clone)]
pub struct Note {
    pub id: String,
    pub media_id: String,
    pub content: String,
    pub created_at: i64,
    pub updated_at: i64,
}

/// 获取媒体的笔记
#[frb]
pub async fn get_note_by_media_id(media_id: String) -> Result<Option<Note>, String> {
    let pool = get_pool()?;
    let row = sqlx::query("SELECT * FROM notes WHERE media_id = ?")
        .bind(&media_id)
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询笔记失败: {}", e))?;

    Ok(row.as_ref().map(row_to_note))
}

/// 创建或更新笔记（UPSERT）
#[frb]
pub async fn save_note(media_id: String, content: String) -> Result<(), String> {
    let pool = get_pool()?;
    let now = chrono::Utc::now().timestamp();

    // 先检查是否存在
    let existing = sqlx::query("SELECT id FROM notes WHERE media_id = ?")
        .bind(&media_id)
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询笔记失败: {}", e))?;

    if let Some(row) = existing {
        let id: String = row.get("id");
        // 更新
        sqlx::query("UPDATE notes SET content = ?, updated_at = ? WHERE id = ?")
            .bind(&content)
            .bind(now)
            .bind(&id)
            .execute(&pool)
            .await
            .map_err(|e| format!("更新笔记失败: {}", e))?;
    } else {
        // 创建
        let id = Uuid::new_v4().to_string();
        sqlx::query(
            "INSERT INTO notes (id, media_id, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?)"
        )
        .bind(&id)
        .bind(&media_id)
        .bind(&content)
        .bind(now)
        .bind(now)
        .execute(&pool)
        .await
        .map_err(|e| format!("创建笔记失败: {}", e))?;
    }

    Ok(())
}

/// 删除笔记
#[frb]
pub async fn delete_note(id: String) -> Result<(), String> {
    let pool = get_pool()?;

    sqlx::query("DELETE FROM notes WHERE id = ?")
        .bind(&id)
        .execute(&pool)
        .await
        .map_err(|e| format!("删除笔记失败: {}", e))?;

    Ok(())
}
