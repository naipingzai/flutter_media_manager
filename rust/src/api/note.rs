use flutter_rust_bridge::frb;

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
    Ok(None)
}

/// 创建或更新笔记
#[frb]
pub async fn save_note(media_id: String, content: String) -> Result<(), String> {
    Ok(())
}

/// 删除笔记
#[frb]
pub async fn delete_note(id: String) -> Result<(), String> {
    Ok(())
}
