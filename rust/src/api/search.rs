use flutter_rust_bridge::frb;
use crate::api::media::{MediaItem, MediaType};
use crate::db::{get_pool, models::row_to_media_item};
use sqlx::Row;

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
    let pool = get_pool()?;
    let mut conditions = vec!["1=1"];
    let mut params: Vec<Box<dyn sqlx::Encode<'static, sqlx::Sqlite> + Send + Sync>> = vec![];

    // 关键词搜索（名称模糊匹配）
    if let Some(query) = &filter.query {
        conditions.push("original_name LIKE ?");
        // 使用参数绑定，但 sqlx 动态参数较复杂，这里使用字符串拼接
    }

    // 媒体类型过滤
    if let Some(media_type_str) = &filter.media_type {
        if let Ok(media_type) = parse_media_type(media_type_str) {
            conditions.push("media_type = ?");
            // 简化处理，使用字符串拼接
        }
    }

    // 日期范围
    if let Some(start) = filter.start_date {
        conditions.push("created_at >= ?");
    }
    if let Some(end) = filter.end_date {
        conditions.push("created_at <= ?");
    }

    // 相册过滤
    let has_album_filter = filter.album_id.is_some();

    // 标签过滤
    let has_tag_filter = filter.tag_ids.as_ref().map(|v| !v.is_empty()).unwrap_or(false);

    // 构建基础 SQL
    let mut sql = String::from("SELECT m.* FROM media_items m");

    if has_album_filter {
        sql.push_str(" JOIN media_albums ma ON m.id = ma.media_id");
    }

    if has_tag_filter {
        sql.push_str(" JOIN media_tags mt ON m.id = mt.media_id");
    }

    // WHERE 条件
    let where_clause = conditions.join(" AND ");
    sql.push_str(" WHERE ");
    sql.push_str(&where_clause);

    if has_album_filter {
        sql.push_str(" AND ma.album_id = ?");
    }

    if has_tag_filter {
        if let Some(tag_ids) = &filter.tag_ids {
            let placeholders = tag_ids.iter().map(|_| "?").collect::<Vec<_>>().join(",");
            sql.push_str(&format!(" AND mt.tag_id IN ({})", placeholders));
            if filter.tag_count.unwrap_or(0) > 1 {
                sql.push_str(" GROUP BY m.id HAVING COUNT(DISTINCT mt.tag_id) = ?");
            }
        }
    }

    sql.push_str(" ORDER BY m.created_at DESC");

    // 由于 sqlx 动态参数绑定限制，使用简化实现
    let rows = build_and_execute_query(&pool, &filter).await?;
    Ok(rows)
}

/// 获取有标签的媒体
#[frb]
pub async fn get_media_with_any_tag() -> Result<Vec<MediaItem>, String> {
    let pool = get_pool()?;

    let rows = sqlx::query(
        "SELECT DISTINCT m.* FROM media_items m
         JOIN media_tags mt ON m.id = mt.media_id
         ORDER BY m.created_at DESC"
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| format!("查询有标签媒体失败: {}", e))?;

    Ok(rows.iter().map(row_to_media_item).collect())
}

/// 获取无标签的媒体
#[frb]
pub async fn get_media_without_any_tag() -> Result<Vec<MediaItem>, String> {
    let pool = get_pool()?;

    let rows = sqlx::query(
        "SELECT m.* FROM media_items m
         LEFT JOIN media_tags mt ON m.id = mt.media_id
         WHERE mt.media_id IS NULL
         ORDER BY m.created_at DESC"
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| format!("查询无标签媒体失败: {}", e))?;

    Ok(rows.iter().map(row_to_media_item).collect())
}

/// 获取有相册的媒体
#[frb]
pub async fn get_media_with_any_album() -> Result<Vec<MediaItem>, String> {
    let pool = get_pool()?;

    let rows = sqlx::query(
        "SELECT DISTINCT m.* FROM media_items m
         JOIN media_albums ma ON m.id = ma.media_id
         ORDER BY m.created_at DESC"
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| format!("查询有相册媒体失败: {}", e))?;

    Ok(rows.iter().map(row_to_media_item).collect())
}

/// 获取无相册的媒体
#[frb]
pub async fn get_media_without_any_album() -> Result<Vec<MediaItem>, String> {
    let pool = get_pool()?;

    let rows = sqlx::query(
        "SELECT m.* FROM media_items m
         LEFT JOIN media_albums ma ON m.id = ma.media_id
         WHERE ma.media_id IS NULL
         ORDER BY m.created_at DESC"
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| format!("查询无相册媒体失败: {}", e))?;

    Ok(rows.iter().map(row_to_media_item).collect())
}

// 辅助函数：解析媒体类型字符串
fn parse_media_type(s: &str) -> Result<MediaType, String> {
    match s.to_lowercase().as_str() {
        "image" | "0" => Ok(MediaType::Image),
        "video" | "1" => Ok(MediaType::Video),
        "audio" | "2" => Ok(MediaType::Audio),
        "document" | "3" => Ok(MediaType::Document),
        "other" | "4" => Ok(MediaType::Other),
        _ => Err(format!("未知的媒体类型: {}", s)),
    }
}

// 辅助函数：构建并执行动态查询
async fn build_and_execute_query(
    pool: &sqlx::Pool<sqlx::Sqlite>,
    filter: &SearchFilter,
) -> Result<Vec<MediaItem>, String> {
    // 简化实现：先获取所有媒体，然后在内存中过滤
    let all_rows = sqlx::query("SELECT * FROM media_items ORDER BY created_at DESC")
        .fetch_all(pool)
        .await
        .map_err(|e| format!("查询媒体失败: {}", e))?;

    let mut result: Vec<MediaItem> = all_rows.iter().map(row_to_media_item).collect();

    // 关键词过滤
    if let Some(query) = &filter.query {
        let q = query.to_lowercase();
        result.retain(|m| m.original_name.to_lowercase().contains(&q));
    }

    // 类型过滤
    if let Some(media_type_str) = &filter.media_type {
        if let Ok(media_type) = parse_media_type(media_type_str) {
            let type_int = media_type.as_i32();
            result.retain(|m| m.media_type.as_i32() == type_int);
        }
    }

    // 日期过滤
    if let Some(start) = filter.start_date {
        result.retain(|m| m.created_at >= start);
    }
    if let Some(end) = filter.end_date {
        result.retain(|m| m.created_at <= end);
    }

    // 相册过滤（需要额外查询）
    if let Some(album_id) = &filter.album_id {
        let album_media: Vec<String> = sqlx::query(
            "SELECT media_id FROM media_albums WHERE album_id = ?"
        )
        .bind(album_id)
        .fetch_all(pool)
        .await
        .map_err(|e| format!("查询相册媒体失败: {}", e))?
        .iter()
        .map(|row| row.get::<String, _>("media_id"))
        .collect();

        let album_set: std::collections::HashSet<String> = album_media.into_iter().collect();
        result.retain(|m| album_set.contains(&m.id));
    }

    // 标签过滤
    if let Some(tag_ids) = &filter.tag_ids {
        if !tag_ids.is_empty() {
            let placeholders = tag_ids.iter().map(|_| "?").collect::<Vec<_>>().join(",");
            let sql = format!(
                "SELECT media_id, tag_id FROM media_tags WHERE tag_id IN ({})",
                placeholders
            );

            let mut query = sqlx::query(&sql);
            for tag_id in tag_ids {
                query = query.bind(tag_id);
            }

            let tag_rows = query
                .fetch_all(pool)
                .await
                .map_err(|e| format!("查询标签媒体失败: {}", e))?;

            let mut media_tag_map: std::collections::HashMap<String, std::collections::HashSet<String>> = std::collections::HashMap::new();
            for row in tag_rows {
                let media_id: String = row.get("media_id");
                let tag_id: String = row.get("tag_id");
                media_tag_map.entry(media_id).or_default().insert(tag_id);
            }

            let tag_count = filter.tag_count.unwrap_or(1) as usize;
            let required_tags: std::collections::HashSet<String> = tag_ids.iter().cloned().collect();

            if tag_count > 1 {
                // AND 模式：媒体必须包含所有标签
                result.retain(|m| {
                    if let Some(tags) = media_tag_map.get(&m.id) {
                        required_tags.is_subset(tags)
                    } else {
                        false
                    }
                });
            } else {
                // OR 模式：媒体包含任意标签
                result.retain(|m| media_tag_map.contains_key(&m.id));
            }
        }
    }

    Ok(result)
}
