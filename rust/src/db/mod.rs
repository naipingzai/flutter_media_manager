use sqlx::{sqlite::{SqlitePoolOptions, SqliteConnectOptions}, Pool, Sqlite};
use std::path::PathBuf;
use std::str::FromStr;
use std::sync::OnceLock;

pub mod models;

/// 数据库连接池（全局单例，线程安全）
static DB_POOL: OnceLock<Pool<Sqlite>> = OnceLock::new();
/// 应用目录（全局存储，线程安全）
static APP_DIR: OnceLock<String> = OnceLock::new();

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
        .create_if_missing(true)
        .foreign_keys(true);  // 启用外键约束
    
    let pool = SqlitePoolOptions::new()
        .max_connections(5)
        .connect_with(connect_options)
        .await?;

    // 创建表结构
    create_tables(&pool).await?;

    // 如果已初始化（如 Android 返回手势后重新打开），忽略
    let _ = DB_POOL.set(pool);
    let _ = APP_DIR.set(app_dir.to_string());

    Ok(())
}

/// 获取数据库连接池
pub fn get_pool() -> Result<Pool<Sqlite>, String> {
    DB_POOL
        .get()
        .cloned()
        .ok_or_else(|| "数据库未初始化".to_string())
}

/// 获取数据库文件路径
pub fn get_db_path() -> Result<String, String> {
    let app_dir = APP_DIR.get().ok_or("应用目录未初始化")?;
    Ok(PathBuf::from(app_dir).join("advance_media_kb.db").to_string_lossy().to_string())
}

/// 获取媒体文件目录
pub fn get_media_dir() -> Result<String, String> {
    let app_dir = APP_DIR.get().ok_or("应用目录未初始化")?;
    Ok(PathBuf::from(app_dir).join("media").to_string_lossy().to_string())
}

/// 获取应用根目录
pub fn get_app_dir() -> Result<String, String> {
    let app_dir = APP_DIR.get().ok_or("应用目录未初始化")?;
    Ok(app_dir.to_string())
}

/// 创建数据库表结构（严格按照设计方案）
async fn create_tables(pool: &Pool<Sqlite>) -> Result<(), sqlx::Error> {
    // ========== 四、core-model 数据模型层 ==========
    
    // 4.1 AlbumEntity（相册表）
    // - parent_id: 自引用外键，支持无限层级子相册，CASCADE 删除
    // - cover_media_id: 引用 media_items 表的 ID
    // - sort_order: 用于拖拽排序
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

    // 4.2 MediaItemEntity（媒体项表）
    // - sha256_hash: 文件指纹，防重复导入
    // - thumbnail_path: 始终非空，导入时自动生成缩略图
    // - type: "image" 或 "video"（存储为 TEXT）
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS media_items (
            id TEXT PRIMARY KEY,
            original_name TEXT NOT NULL,
            storage_name TEXT NOT NULL,
            file_path TEXT NOT NULL,
            thumbnail_path TEXT NOT NULL,
            type TEXT NOT NULL,
            mime_type TEXT NOT NULL,
            size INTEGER NOT NULL,
            width INTEGER,
            height INTEGER,
            duration INTEGER,
            sha256_hash TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
        "#,
    )
    .execute(pool)
    .await?;

    // 4.3 NoteEntity（笔记表）—— Skill-14 一对一关系
    // - 一对一：每个媒体最多 1 条笔记（由 UNIQUE 索引保证）
    // - CASCADE 删除：媒体删除时自动清理关联笔记（ForeignKey.CASCADE）
    // - 字段：id, media_id, content, created_at, updated_at（无 title）
    // - content: 笔记正文（纯文本存储，渲染时按 Markdown 解析）
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS notes (
            id TEXT PRIMARY KEY,
            media_id TEXT NOT NULL,
            content TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE
        )
        "#,
    )
    .execute(pool)
    .await?;

    // Skill-14 一对一：media_id 唯一（每个媒体最多 1 条笔记）
    sqlx::query(
        r#"CREATE UNIQUE INDEX IF NOT EXISTS idx_notes_media_id_unique
           ON notes(media_id)"#,
    )
    .execute(pool)
    .await?;

    // 4.4 TagEntity（标签表）
    // - parent_id: 自引用，支持层级标签
    // - color: 标签颜色（十六进制，可为 null）
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS tags (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color TEXT,
            parent_id TEXT,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (parent_id) REFERENCES tags(id) ON DELETE CASCADE
        )
        "#,
    )
    .execute(pool)
    .await?;

    // 4.5 AlbumMediaEntity（相册-媒体关联表）
    // - 复合主键 (album_id, media_id)
    // - 双向外键 CASCADE 删除
    // - added_at: 添加时间
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS album_media (
            album_id TEXT NOT NULL,
            media_id TEXT NOT NULL,
            added_at INTEGER NOT NULL,
            PRIMARY KEY (album_id, media_id),
            FOREIGN KEY (album_id) REFERENCES albums(id) ON DELETE CASCADE,
            FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE
        )
        "#,
    )
    .execute(pool)
    .await?;

    // 4.6 MediaTagEntity（媒体-标签关联表）
    // - 复合主键 (media_id, tag_id)
    // - 双向外键 CASCADE 删除
    // - created_at: 关联时间
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS media_tags (
            media_id TEXT NOT NULL,
            tag_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (media_id, tag_id),
            FOREIGN KEY (media_id) REFERENCES media_items(id) ON DELETE CASCADE,
            FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
        )
        "#,
    )
    .execute(pool)
    .await?;

    // 设置表（不在设计文档的 core-model 中，但功能上需要）
    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS app_settings (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            theme_mode INTEGER NOT NULL DEFAULT 0,
            grid_columns INTEGER NOT NULL DEFAULT 3,
            album_grid_columns INTEGER NOT NULL DEFAULT 2,
            thumbnail_quality INTEGER NOT NULL DEFAULT 85,
            language TEXT NOT NULL DEFAULT 'system',
            dynamic_color INTEGER NOT NULL DEFAULT 1,
            last_scan_path TEXT NOT NULL DEFAULT ''
        )
        "#,
    )
    .execute(pool)
    .await?;

    // 动态添加新列（已有数据库的兼容）
    let _ = sqlx::query("ALTER TABLE app_settings ADD COLUMN dynamic_color INTEGER NOT NULL DEFAULT 1")
        .execute(pool).await;
    let _ = sqlx::query("ALTER TABLE app_settings ADD COLUMN last_scan_path TEXT NOT NULL DEFAULT ''")
        .execute(pool).await;

    // ========== 索引 ==========
    
    // media_items 索引
    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_media_created_at ON media_items(created_at)"
    ).execute(pool).await?;

    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_media_type ON media_items(type)"
    ).execute(pool).await?;

    sqlx::query(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_media_sha256 ON media_items(sha256_hash)"
    ).execute(pool).await?;

    // albums 索引
    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_albums_parent_id ON albums(parent_id)"
    ).execute(pool).await?;

    // tags 索引
    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_tags_parent_id ON tags(parent_id)"
    ).execute(pool).await?;

    // notes 索引
    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_notes_media_id ON notes(media_id)"
    ).execute(pool).await?;

    // album_media 索引
    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_album_media_media_id ON album_media(media_id)"
    ).execute(pool).await?;

    // media_tags 索引
    sqlx::query(
        "CREATE INDEX IF NOT EXISTS idx_media_tags_tag_id ON media_tags(tag_id)"
    ).execute(pool).await?;

    // 插入默认设置
    sqlx::query(
        r#"
        INSERT OR IGNORE INTO app_settings (id, theme_mode, grid_columns, album_grid_columns, thumbnail_quality, language, dynamic_color)
        VALUES (1, 0, 3, 2, 85, 'zh', 1)
        "#
    ).execute(pool).await?;

    Ok(())
}
