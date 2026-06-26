use flutter_rust_bridge::frb;
use crate::db::{init_db, get_pool, models::row_to_settings};
use sqlx::Row;
use std::path::PathBuf;

/// 主题模式
#[frb]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ThemeMode {
    System,
    Light,
    Dark,
}

/// 应用设置
#[frb]
#[derive(Debug, Clone)]
pub struct AppSettings {
    pub theme_mode: ThemeMode,
    pub grid_columns: i32,
    pub album_grid_columns: i32,
    pub show_content_previews: i32,
    pub thumbnail_quality: i32,
    pub language: String,
}

/// 存储统计
#[frb]
#[derive(Debug, Clone)]
pub struct StorageStats {
    pub total_media_count: i32,
    pub total_size: i64,
    pub thumbnail_cache_size: i64,
    pub database_size: i64,
}

/// 获取设置
#[frb]
pub async fn get_settings() -> Result<AppSettings, String> {
    let pool = get_pool()?;
    let row = sqlx::query("SELECT * FROM app_settings WHERE id = 1")
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询设置失败: {}", e))?;

    match row {
        Some(row) => Ok(row_to_settings(&row)),
        None => {
            // 返回默认设置
            Ok(AppSettings {
                theme_mode: ThemeMode::System,
                grid_columns: 3,
                album_grid_columns: 2,
                show_content_previews: 1,
                thumbnail_quality: 85,
                language: "zh_CN".to_string(),
            })
        }
    }
}

/// 保存设置
#[frb]
pub async fn save_settings(settings: AppSettings) -> Result<(), String> {
    let pool = get_pool()?;
    let theme_int = match settings.theme_mode {
        ThemeMode::System => 0,
        ThemeMode::Light => 1,
        ThemeMode::Dark => 2,
    };

    sqlx::query(
        "INSERT INTO app_settings (id, theme_mode, grid_columns, album_grid_columns, show_content_previews, thumbnail_quality, language)
         VALUES (1, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(id) DO UPDATE SET
            theme_mode = excluded.theme_mode,
            grid_columns = excluded.grid_columns,
            album_grid_columns = excluded.album_grid_columns,
            show_content_previews = excluded.show_content_previews,
            thumbnail_quality = excluded.thumbnail_quality,
            language = excluded.language"
    )
    .bind(theme_int)
    .bind(settings.grid_columns)
    .bind(settings.album_grid_columns)
    .bind(settings.show_content_previews)
    .bind(settings.thumbnail_quality)
    .bind(&settings.language)
    .execute(&pool)
    .await
    .map_err(|e| format!("保存设置失败: {}", e))?;

    Ok(())
}

/// 获取存储统计
#[frb]
pub async fn get_storage_stats() -> Result<StorageStats, String> {
    let pool = get_pool()?;

    // 媒体统计
    let media_stats = sqlx::query(
        "SELECT COUNT(*) as count, COALESCE(SUM(size), 0) as total_size FROM media_items"
    )
    .fetch_one(&pool)
    .await
    .map_err(|e| format!("查询媒体统计失败: {}", e))?;

    let total_media_count: i64 = media_stats.get("count");
    let total_size: i64 = media_stats.get("total_size");

    // 数据库文件大小
    let db_path = get_db_path().await?;
    let database_size = std::fs::metadata(&db_path)
        .map(|m| m.len() as i64)
        .unwrap_or(0);

    // 缩略图缓存大小（估算：统计 thumbnail_path 目录大小）
    let thumbnail_cache_size = estimate_thumbnail_size(&pool).await.unwrap_or(0);

    Ok(StorageStats {
        total_media_count: total_media_count as i32,
        total_size,
        thumbnail_cache_size,
        database_size,
    })
}

/// 清理缩略图缓存（删除未被引用的缩略图文件）
#[frb]
pub async fn clear_thumbnail_cache() -> Result<i32, String> {
    let pool = get_pool()?;
    let media_dir = crate::db::get_media_dir()?;
    let thumbnail_dir = std::path::PathBuf::from(&media_dir).join("thumbnails");

    if !thumbnail_dir.exists() {
        return Ok(0);
    }

    // 获取数据库中所有有效的缩略图路径
    let rows = sqlx::query("SELECT thumbnail_path FROM media_items WHERE thumbnail_path != ''")
        .fetch_all(&pool)
        .await
        .map_err(|e| format!("查询缩略图路径失败: {}", e))?;

    let valid_paths: std::collections::HashSet<String> = rows
        .iter()
        .map(|row| row.get::<String, _>("thumbnail_path"))
        .collect();

    let mut deleted_count = 0i32;

    // 遍历缩略图目录，删除未被引用的文件
    if let Ok(entries) = std::fs::read_dir(&thumbnail_dir) {
        for entry in entries.filter_map(|e| e.ok()) {
            let path = entry.path();
            if path.is_file() {
                let path_str = path.to_string_lossy().to_string();
                if !valid_paths.contains(&path_str) {
                    if let Err(e) = std::fs::remove_file(&path) {
                        eprintln!("删除缩略图文件失败 {}: {}", path_str, e);
                    } else {
                        deleted_count += 1;
                    }
                }
            }
        }
    }

    Ok(deleted_count)
}

/// 导出数据（导出数据库备份）
#[frb]
pub async fn export_data(export_path: String) -> Result<(), String> {
    let pool = get_pool()?;

    // 使用 SQLite 的备份功能
    sqlx::query(&format!("VACUUM INTO '{}'", export_path.replace("'", "''")))
        .execute(&pool)
        .await
        .map_err(|e| format!("导出数据失败: {}", e))?;

    Ok(())
}

/// 导入数据（从 SQLite 备份文件恢复）
#[frb]
pub async fn import_data(import_path: String) -> Result<(), String> {
    let pool = get_pool()?;
    let db_path = get_db_path().await?;

    // 验证导入文件存在
    if !std::path::Path::new(&import_path).exists() {
        return Err("导入文件不存在".to_string());
    }

    // 关闭当前连接池（释放数据库文件锁定）
    drop(pool);

    // 备份当前数据库
    let backup_path = format!("{}.backup", db_path);
    if let Err(e) = std::fs::copy(&db_path, &backup_path) {
        return Err(format!("备份当前数据库失败: {}", e));
    }

    // 替换数据库文件
    if let Err(e) = std::fs::copy(&import_path, &db_path) {
        // 恢复备份
        let _ = std::fs::copy(&backup_path, &db_path);
        return Err(format!("导入数据失败: {}", e));
    }

    // 清理备份文件
    let _ = std::fs::remove_file(&backup_path);

    Ok(())
}

/// 删除所有数据
#[frb]
pub async fn delete_all_data() -> Result<(), String> {
    let pool = get_pool()?;
    let mut tx = pool.begin().await.map_err(|e| format!("开启事务失败: {}", e))?;

    // 按外键依赖顺序删除
    sqlx::query("DELETE FROM media_tags").execute(&mut *tx).await.map_err(|e| format!("删除标签关联失败: {}", e))?;
    sqlx::query("DELETE FROM media_albums").execute(&mut *tx).await.map_err(|e| format!("删除相册关联失败: {}", e))?;
    sqlx::query("DELETE FROM notes").execute(&mut *tx).await.map_err(|e| format!("删除笔记失败: {}", e))?;
    sqlx::query("DELETE FROM media_items").execute(&mut *tx).await.map_err(|e| format!("删除媒体失败: {}", e))?;
    sqlx::query("DELETE FROM albums").execute(&mut *tx).await.map_err(|e| format!("删除相册失败: {}", e))?;
    sqlx::query("DELETE FROM tags").execute(&mut *tx).await.map_err(|e| format!("删除标签失败: {}", e))?;

    // 重置设置
    sqlx::query(
        "UPDATE app_settings SET theme_mode = 0, grid_columns = 3, album_grid_columns = 2,
         show_content_previews = 1, thumbnail_quality = 85, language = 'zh_CN' WHERE id = 1"
    ).execute(&mut *tx).await.map_err(|e| format!("重置设置失败: {}", e))?;

    tx.commit().await.map_err(|e| format!("提交事务失败: {}", e))?;
    Ok(())
}

// 辅助函数：获取数据库路径
async fn get_db_path() -> Result<String, String> {
    let pool = get_pool()?;
    let row = sqlx::query("PRAGMA database_list")
        .fetch_one(&pool)
        .await
        .map_err(|e| format!("获取数据库路径失败: {}", e))?;

    let path: String = row.get("file");
    Ok(path)
}

// 辅助函数：估算缩略图总大小
async fn estimate_thumbnail_size(pool: &sqlx::Pool<sqlx::Sqlite>) -> Result<i64, String> {
    let rows = sqlx::query("SELECT thumbnail_path FROM media_items WHERE thumbnail_path != ''")
        .fetch_all(pool)
        .await
        .map_err(|e| format!("查询缩略图路径失败: {}", e))?;

    let mut total_size = 0i64;
    for row in rows {
        let path: String = row.get("thumbnail_path");
        if let Ok(meta) = std::fs::metadata(&path) {
            total_size += meta.len() as i64;
        }
    }

    Ok(total_size)
}

/// 初始化应用（初始化数据库连接池）
/// 
/// 在 Android 上，app_dir 应该传入应用的私有目录（如 getApplicationDocumentsDirectory）
/// 在桌面上，可以传入当前工作目录或用户数据目录
#[frb]
pub async fn init_app(app_dir: String) -> Result<(), String> {
    // 确保目录存在
    let dir = PathBuf::from(&app_dir);
    if !dir.exists() {
        std::fs::create_dir_all(&dir)
            .map_err(|e| format!("创建应用目录失败: {}", e))?;
    }

    // 初始化媒体子目录
    let media_dir = dir.join("media");
    if !media_dir.exists() {
        std::fs::create_dir_all(&media_dir)
            .map_err(|e| format!("创建媒体目录失败: {}", e))?;
    }

    // 初始化缩略图子目录
    let thumbnail_dir = media_dir.join("thumbnails");
    if !thumbnail_dir.exists() {
        std::fs::create_dir_all(&thumbnail_dir)
            .map_err(|e| format!("创建缩略图目录失败: {}", e))?;
    }

    // 初始化数据库
    init_db(&app_dir).await
        .map_err(|e| format!("初始化数据库失败: {}", e))?;

    Ok(())
}
