use sqlx::{sqlite::{SqlitePoolOptions, SqliteConnectOptions}, Pool, Sqlite};
use std::path::PathBuf;
use std::str::FromStr;

pub mod models;

/// 数据库连接池（全局单例）
static mut DB_POOL: Option<Pool<Sqlite>> = None;
/// 应用目录（全局存储）
static mut APP_DIR: Option<String> = None;

/// 初始化数据库连接池
pub async fn init_db(app_dir: &str) -> Result<(), sqlx::Error> {
    // 确保应用目录存在
    let app_dir_path = PathBuf::from(app_dir);
    if !app_dir_path.exists() {
        std::fs::create_dir_all(&app_dir_path)
            .map_err(|e| sqlx::Error::Io(e.into()))?;
    }
    
    let db_path = app_dir_path.join("advance_media_kb.db");
    // 确保数据库父目录存在
    if let Some(parent) = db_path.parent() {
        if !parent.exists() {
            std::fs::create_dir_all(parent)
                .map_err(|e| sqlx::Error::Io(e.into()))?;
        }
    }
    
    // 使用 SqliteConnectOptions 直接创建连接（避免 URL 解析问题）
    let db_path_str = db_path.to_string_lossy();
    let connect_options = SqliteConnectOptions::from_str(&db_path_str)?
        .create_if_missing(true);
    
    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect_with(connect_options)
        .await?;

    // 创建表结构
    create_tables(&pool).await?;

    unsafe {
        DB_POOL = Some(pool);
        APP_DIR = Some(app_dir.to_string());
    }

    Ok(())
}

/// 获取数据库连接池
pub fn get_pool() -> Result<Pool<Sqlite>, String> {
    unsafe {
        DB_POOL
            .clone()
            .ok_or_else(|| "数据库未初始化".to_string())
    }
}

/// 获取数据库文件路径
pub fn get_db_path() -> Result<String, String> {
    unsafe {
        let app_dir = APP_DIR.as_ref().ok_or("应用目录未初始化")?;
        Ok(PathBuf::from(app_dir).join("advance_media_kb.db").to_string_lossy().to_string())
    }
}

/// 获取媒体文件目录
pub fn get_media_dir() -> Result<String, String> {
    unsafe {
        let app_dir = APP_DIR.as_ref().ok_or("应用目录未初始化")?;
        Ok(PathBuf::from(app_dir).join("media").to_string_lossy().to_string())
    }
}

/// 获取应用根目录
pub fn get_app_dir() -> Result<String, String> {
    unsafe {
        let app_dir = APP_DIR.as_ref().ok_or("应用目录未初始化")?;
        Ok(app_dir.to_string())
    }
}

/// 创建数据库表结构
async fn create_tables(pool: &Pool<Sqlite>) -> Result<(), sqlx::Error> {
    // 媒体文件表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS media_items (
            id TEXT PRIMARY KEY,
            original_name TEXT NOT NULL,
            storage_name TEXT NOT NULL,
            file_path TEXT NOT NULL UNIQUE,
            thumbnail_path TEXT NOT NULL,
            media_type INTEGER NOT NULL,
            mime_type TEXT NOT NULL,
            size INTEGER NOT NULL,
            width INTEGER,
            height INTEGER,
            duration INTEGER,
            sha256_hash TEXT NOT NULL UNIQUE,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
        "#,
    )
    .execute(pool)
    .await?;

    // 相册表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS albums (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parent_id TEXT,
            cover_media_id TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (parent_id) REFERENCES albums(id) ON DELETE CASCADE,
            FOREIGN KEY (cover_media_id) REFERENCES media_items(id) ON DELETE SET NULL
        )
        "#,
    )
    .execute(pool)
    .await?;

    // 标签表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS tags (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            color TEXT,
            parent_id TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (parent_id) REFERENCES tags(id) ON DELETE CASCADE
        )
        "#,
    )
    .execute(pool)
    .await?;

    // 媒体-相册关联表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS media_albums (
            media_id TEXT NOT NULL,
            album_id TEXT NOT NULL,
            PRIMARY KEY (media_id, album_id),
            FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE,
            FOREIGN KEY (album_id) REFERENCES albums(id) ON DELETE CASCADE
        )
        "#,
    )
    .execute(pool)
    .await?;

    // 媒体-标签关联表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS media_tags (
            media_id TEXT NOT NULL,
            tag_id TEXT NOT NULL,
            PRIMARY KEY (media_id, tag_id),
            FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE,
            FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
        )
        "#,
    )
    .execute(pool)
    .await?;

    // 笔记表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS notes (
            id TEXT PRIMARY KEY,
            media_id TEXT NOT NULL UNIQUE,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE
        )
        "#,
    )
    .execute(pool)
    .await?;

    // 设置表
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS app_settings (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            theme_mode INTEGER NOT NULL DEFAULT 0,
            grid_columns INTEGER NOT NULL DEFAULT 3,
            album_grid_columns INTEGER NOT NULL DEFAULT 2,
            show_content_previews INTEGER NOT NULL DEFAULT 1,
            thumbnail_quality INTEGER NOT NULL DEFAULT 85,
            language TEXT NOT NULL DEFAULT 'zh_CN'
        )
        "#,
    )
    .execute(pool)
    .await?;

    // 创建索引
    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_media_type ON media_items(media_type)"
    ).execute(pool).await?;

    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_media_created ON media_items(created_at)"
    ).execute(pool).await?;

    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_album_parent ON albums(parent_id)"
    ).execute(pool).await?;

    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_tag_parent ON tags(parent_id)"
    ).execute(pool).await?;

    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_media_albums ON media_albums(album_id)"
    ).execute(pool).await?;

    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_media_tags ON media_tags(tag_id)"
    ).execute(pool).await?;

    // 插入默认设置
    sqlx::query(
        r#"
        INSERT OR IGNORE INTO app_settings (id, theme_mode, grid_columns, album_grid_columns, show_content_previews, thumbnail_quality, language)
        VALUES (1, 0, 3, 2, 1, 85, 'zh_CN')
        "#
    ).execute(pool).await?;

    Ok(())
}
