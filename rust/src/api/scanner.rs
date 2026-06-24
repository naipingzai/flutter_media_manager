use flutter_rust_bridge::frb;
use crate::api::media::MediaItem;

/// 扫描进度
#[frb]
#[derive(Debug, Clone)]
pub struct ScanProgress {
    pub total_files: i32,
    pub processed_files: i32,
    pub current_file: Option<String>,
    pub status: String,
}

/// 扫描结果
#[frb]
#[derive(Debug, Clone)]
pub struct ScanResult {
    pub imported_count: i32,
    pub duplicate_count: i32,
    pub failed_count: i32,
    pub media_items: Vec<MediaItem>,
}

/// 扫描目录并导入媒体
#[frb]
pub async fn scan_directory(path: String) -> Result<ScanResult, String> {
    Ok(ScanResult {
        imported_count: 0,
        duplicate_count: 0,
        failed_count: 0,
        media_items: vec![],
    })
}

/// 生成缩略图
#[frb]
pub async fn generate_thumbnail(file_path: String, quality: i32) -> Result<String, String> {
    Ok(String::new())
}

/// 计算文件 SHA256 哈希
#[frb]
pub async fn calculate_file_hash(file_path: String) -> Result<String, String> {
    Ok(String::new())
}

/// 检查文件是否已存在（通过哈希）
#[frb]
pub async fn is_hash_exists(hash: String) -> Result<bool, String> {
    Ok(false)
}

/// 支持的媒体扩展名列表
#[frb]
pub fn get_supported_extensions() -> Vec<String> {
    vec![
        "jpg".to_string(), "jpeg".to_string(), "png".to_string(),
        "gif".to_string(), "webp".to_string(), "bmp".to_string(), "heic".to_string(),
        "mp4".to_string(), "mkv".to_string(), "avi".to_string(),
        "mov".to_string(), "webm".to_string(),
        "mp3".to_string(), "wav".to_string(), "flac".to_string(),
        "aac".to_string(), "ogg".to_string(), "m4a".to_string(),
    ]
}
