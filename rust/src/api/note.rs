use flutter_rust_bridge::frb;
use crate::db::{get_pool, models::row_to_note};
use sqlx::Row;
use uuid::Uuid;

/// 笔记实体（Skill-14）
///
/// - 字段：id, media_id, content, created_at, updated_at
/// - 与媒体一对一：media_id 唯一索引 + ForeignKey.CASCADE
/// - 渲染层按 Markdown 解析（`flutter_markdown`）
#[frb]
#[derive(Debug, Clone)]
pub struct Note {
    pub id: String,
    pub media_id: String,
    pub content: String,
    pub created_at: i64,
    pub updated_at: i64,
}

/// 获取指定媒体的笔记（一对一，LIMIT 1）
#[frb]
pub async fn get_note_by_media_id(media_id: String) -> Result<Option<Note>, String> {
    let pool = get_pool()?;
    let row = sqlx::query("SELECT * FROM notes WHERE media_id = ? LIMIT 1")
        .bind(&media_id)
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询笔记失败: {}", e))?;

    Ok(row.as_ref().map(row_to_note))
}

/// 获取单条笔记
#[frb]
pub async fn get_note_by_id(id: String) -> Result<Option<Note>, String> {
    let pool = get_pool()?;
    let row = sqlx::query("SELECT * FROM notes WHERE id = ?")
        .bind(&id)
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询笔记失败: {}", e))?;

    Ok(row.as_ref().map(row_to_note))
}

/// 获取全部笔记（按 updated_at DESC）
#[frb]
pub async fn get_all_notes() -> Result<Vec<Note>, String> {
    let pool = get_pool()?;
    let rows = sqlx::query("SELECT * FROM notes ORDER BY updated_at DESC")
        .fetch_all(&pool)
        .await
        .map_err(|e| format!("查询全部笔记失败: {}", e))?;

    Ok(rows.iter().map(row_to_note).collect())
}

/// 创建或更新笔记（Skill-14 一对一 upsert）
///
/// - 若该 media_id 已有笔记则更新 content（保留 id、created_at）
/// - 若不存在则新建
/// - 返回笔记 id
#[frb]
pub async fn save_note(media_id: String, content: String) -> Result<String, String> {
    let pool = get_pool()?;
    let now = chrono::Utc::now().timestamp();

    let existing = sqlx::query("SELECT id, created_at FROM notes WHERE media_id = ? LIMIT 1")
        .bind(&media_id)
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询笔记失败: {}", e))?;

    if let Some(row) = existing {
        let id: String = row.get("id");
        sqlx::query("UPDATE notes SET content = ?, updated_at = ? WHERE id = ?")
            .bind(&content)
            .bind(now)
            .bind(&id)
            .execute(&pool)
            .await
            .map_err(|e| format!("更新笔记失败: {}", e))?;
        return Ok(id);
    }

    let id = Uuid::new_v4().to_string();
    sqlx::query(
        "INSERT INTO notes (id, media_id, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
    )
    .bind(&id)
    .bind(&media_id)
    .bind(&content)
    .bind(now)
    .bind(now)
    .execute(&pool)
    .await
    .map_err(|e| format!("创建笔记失败: {}", e))?;

    Ok(id)
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
