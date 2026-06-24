use flutter_rust_bridge::frb;

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
    pub show_content_previews: bool,
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
    Ok(AppSettings {
        theme_mode: ThemeMode::System,
        grid_columns: 3,
        album_grid_columns: 3,
        show_content_previews: true,
        thumbnail_quality: 70,
        language: "zh".to_string(),
    })
}

/// 保存设置
#[frb]
pub async fn save_settings(settings: AppSettings) -> Result<(), String> {
    Ok(())
}

/// 获取存储统计
#[frb]
pub async fn get_storage_stats() -> Result<StorageStats, String> {
    Ok(StorageStats {
        total_media_count: 0,
        total_size: 0,
        thumbnail_cache_size: 0,
        database_size: 0,
    })
}

/// 清理缩略图缓存
#[frb]
pub async fn clear_thumbnail_cache() -> Result<(), String> {
    Ok(())
}

/// 导出数据
#[frb]
pub async fn export_data(export_path: String) -> Result<(), String> {
    Ok(())
}

/// 导入数据
#[frb]
pub async fn import_data(import_path: String) -> Result<(), String> {
    Ok(())
}

/// 删除所有数据
#[frb]
pub async fn delete_all_data() -> Result<(), String> {
    Ok(())
}
