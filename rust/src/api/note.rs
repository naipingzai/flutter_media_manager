use flutter_rust_bridge::frb;
use crate::db::{get_pool, models::row_to_note};
use sqlx::Row;
use uuid::Uuid;

/// 笔记实体
/// 按设计方案：media_id 可为 null（独立笔记），新增 title 字段
#[frb]
#[derive(Debug, Clone)]
pub struct Note {
    pub id: String,
    pub media_id: Option<String>,  // 可为 null，独立笔记
    pub title: String,
    pub content: String,
    pub created_at: i64,
    pub updated_at: i64,
}

/// 获取指定媒体的笔记（可能有多篇）
#[frb]
pub async fn get_notes_by_media_id(media_id: String) -> Result<Vec<Note>, String> {
    let pool = get_pool()?;
    let rows = sqlx::query(
        "SELECT * FROM notes WHERE media_id = ? ORDER BY updated_at DESC"
    )
    .bind(&media_id)
    .fetch_all(&pool)
    .await
    .map_err(|e| format!("查询笔记失败: {}", e))?;

    Ok(rows.iter().map(row_to_note).collect())
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

/// 观察全部笔记（包括独立笔记和关联笔记）
#[frb]
pub async fn get_all_notes() -> Result<Vec<Note>, String> {
    let pool = get_pool()?;
    let rows = sqlx::query(
        "SELECT * FROM notes ORDER BY updated_at DESC"
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| format!("查询全部笔记失败: {}", e))?;

    Ok(rows.iter().map(row_to_note).collect())
}

/// 创建笔记
/// media_id 为 None 时创建独立笔记
#[frb]
pub async fn create_note(
    media_id: Option<String>,
    title: String,
    content: String,
) -> Result<String, String> {
    let pool = get_pool()?;
    let id = Uuid::new_v4().to_string();
    let now = chrono::Utc::now().timestamp();

    sqlx::query(
        "INSERT INTO notes (id, media_id, title, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)"
    )
    .bind(&id)
    .bind(&media_id)
    .bind(&title)
    .bind(&content)
    .bind(now)
    .bind(now)
    .execute(&pool)
    .await
    .map_err(|e| format!("创建笔记失败: {}", e))?;

    Ok(id)
}

/// 更新笔记
#[frb]
pub async fn update_note(
    id: String,
    title: Option<String>,
    content: Option<String>,
) -> Result<(), String> {
    let pool = get_pool()?;
    let now = chrono::Utc::now().timestamp();

    // 获取现有笔记
    let existing = sqlx::query("SELECT * FROM notes WHERE id = ?")
        .bind(&id)
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询笔记失败: {}", e))?
        .ok_or("笔记不存在")?;

    let new_title: String = title.unwrap_or_else(|| existing.get("title"));
    let new_content: String = content.unwrap_or_else(|| existing.get("content"));

    sqlx::query(
        "UPDATE notes SET title = ?, content = ?, updated_at = ? WHERE id = ?"
    )
    .bind(&new_title)
    .bind(&new_content)
    .bind(now)
    .bind(&id)
    .execute(&pool)
    .await
    .map_err(|e| format!("更新笔记失败: {}", e))?;

    Ok(())
}

/// 保存笔记（兼容旧接口：创建或更新）
#[frb]
pub async fn save_note(media_id: String, content: String) -> Result<(), String> {
    let pool = get_pool()?;
    let now = chrono::Utc::now().timestamp();

    // 先检查是否存在
    let existing = sqlx::query("SELECT id FROM notes WHERE media_id = ? LIMIT 1")
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
    } else {
        let id = Uuid::new_v4().to_string();
        sqlx::query(
            "INSERT INTO notes (id, media_id, title, content, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)"
        )
        .bind(&id)
        .bind(&media_id)
        .bind("")
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

/// 搜索笔记（按标题和内容模糊匹配）
#[frb]
pub async fn search_notes(query: String) -> Result<Vec<Note>, String> {
    let pool = get_pool()?;
    let search_pattern = format!("%{}%", query);

    let rows = sqlx::query(
        "SELECT * FROM notes WHERE title LIKE ? OR content LIKE ? ORDER BY updated_at DESC"
    )
    .bind(&search_pattern)
    .bind(&search_pattern)
    .fetch_all(&pool)
    .await
    .map_err(|e| format!("搜索笔记失败: {}", e))?;

    Ok(rows.iter().map(row_to_note).collect())
}
