use flutter_rust_bridge::frb;
use crate::api::media::{MediaItem, MediaType};
use crate::db::get_pool;
use std::path::PathBuf;
use std::fs;
use std::io::Read;
use sha2::{Sha256, Digest};
use uuid::Uuid;
use walkdir::WalkDir;

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

/// 扫描目录并导入媒体（返回结果）
#[frb]
pub async fn scan_directory(path: String) -> Result<ScanResult, String> {
    let pool = get_pool()?;
    let supported_exts = get_supported_extensions_set();

    // 收集所有支持的媒体文件
    let mut media_files = vec![];
    for entry in WalkDir::new(&path)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_type().is_file())
    {
        let path = entry.path();
        if let Some(ext) = path.extension() {
            let ext = ext.to_string_lossy().to_lowercase();
            if supported_exts.contains(ext.as_str()) {
                media_files.push(path.to_path_buf());
            }
        }
    }

    let mut imported = 0;
    let mut duplicates = 0;
    let mut failed = 0;
    let mut imported_items = vec![];

    for file_path in &media_files {
        let path_str = file_path.to_string_lossy().to_string();

        // 计算文件哈希
        let hash = match calculate_file_hash_sync(&path_str) {
            Ok(h) => h,
            Err(_) => {
                failed += 1;
                continue;
            }
        };

        // 检查重复
        let existing = sqlx::query("SELECT id FROM media_items WHERE sha256_hash = ?")
            .bind(&hash)
            .fetch_optional(&pool)
            .await
            .map_err(|e| format!("检查重复失败: {}", e))?;

        if existing.is_some() {
            duplicates += 1;
            continue;
        }

        // 获取文件信息
        let file_name = file_path.file_stem()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_else(|| "unknown".to_string());
        let ext = file_path.extension()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or_default();
        // 存储名 = 原名 + 时间戳
        let ts = chrono::Utc::now().format("%Y%m%d_%H%M%S").to_string();
        let safe_base: String = file_name.chars().take(60).collect();
        let storage_name = format!("{}_{}.{}", safe_base, ts, ext);
        let mime = mime_guess::from_path(&file_path).first_or_octet_stream().to_string();

        // 获取文件大小
        let size = match fs::metadata(&file_path) {
            Ok(meta) => meta.len() as i64,
            Err(_) => {
                failed += 1;
                continue;
            }
        };

        // 判断媒体类型
        let media_type = determine_media_type(&ext);

        // 获取图片尺寸（如果是图片）
        let (width, height) = if media_type == MediaType::Image {
            get_image_dimensions(&path_str).unwrap_or((None, None))
        } else {
            (None, None)
        };

        // 生成缩略图路径
        let thumbnail_path = generate_thumbnail_path(&storage_name);

        // 生成缩略图
        let _ = generate_thumbnail_sync(&path_str, &thumbnail_path, 85);

        let now = chrono::Utc::now().timestamp();
        let id = Uuid::new_v4().to_string();

        // 插入数据库
        let result = sqlx::query(
            "INSERT INTO media_items (
                id, original_name, storage_name, file_path, thumbnail_path,
                type, mime_type, size, width, height, duration,
                sha256_hash, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
        )
        .bind(&id)
        .bind(&file_name)
        .bind(&storage_name)
        .bind(&path_str)
        .bind(&thumbnail_path)
        .bind(media_type.as_str())
        .bind(&mime)
        .bind(size)
        .bind(width)
        .bind(height)
        .bind(None::<i64>) // duration
        .bind(&hash)
        .bind(now)
        .bind(now)
        .execute(&pool)
        .await;

        match result {
            Ok(_) => {
                imported += 1;
                imported_items.push(MediaItem {
                    id,
                    original_name: file_name,
                    storage_name,
                    file_path: path_str,
                    thumbnail_path,
                    media_type,
                    mime_type: mime,
                    size,
                    width,
                    height,
                    duration: None,
                    sha256_hash: hash,
                    created_at: now,
                    updated_at: now,
                });
            }
            Err(e) => {
                log::error!("导入文件失败 {}: {}", path_str, e);
                failed += 1;
            }
        }
    }

    Ok(ScanResult {
        imported_count: imported as i32,
        duplicate_count: duplicates as i32,
        failed_count: failed as i32,
        media_items: imported_items,
    })
}

/// 生成缩略图
#[frb]
pub async fn generate_thumbnail(file_path: String, quality: i32) -> Result<String, String> {
    let storage_name = format!("{}.jpg", Uuid::new_v4());
    let thumbnail_path = generate_thumbnail_path(&storage_name);
    generate_thumbnail_sync(&file_path, &thumbnail_path, quality)
}

/// 计算文件 SHA256 哈希
#[frb]
pub async fn calculate_file_hash(file_path: String) -> Result<String, String> {
    calculate_file_hash_sync(&file_path)
}

/// 检查文件是否已存在（通过哈希）
#[frb]
pub async fn is_hash_exists(hash: String) -> Result<bool, String> {
    let pool = get_pool()?;
    let row = sqlx::query("SELECT id FROM media_items WHERE sha256_hash = ?")
        .bind(&hash)
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询哈希失败: {}", e))?;

    Ok(row.is_some())
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

// ============ 内部辅助函数 ============

fn get_supported_extensions_set() -> std::collections::HashSet<&'static str> {
    let mut set = std::collections::HashSet::new();
    for ext in &[
        "jpg", "jpeg", "png", "gif", "webp", "bmp", "heic",
        "mp4", "mkv", "avi", "mov", "webm",
        "mp3", "wav", "flac", "aac", "ogg", "m4a",
    ] {
        set.insert(*ext);
    }
    set
}

fn determine_media_type(ext: &str) -> MediaType {
    let ext = ext.to_lowercase();
    match ext.as_str() {
        "jpg" | "jpeg" | "png" | "gif" | "webp" | "bmp" | "heic" | "heif" | "raw" | "cr2" | "nef" => MediaType::Image,
        "mp4" | "mkv" | "avi" | "mov" | "webm" | "flv" | "wmv" => MediaType::Video,
        "mp3" | "wav" | "flac" | "aac" | "ogg" | "m4a" | "wma" => MediaType::Audio,
        "pdf" | "doc" | "docx" | "xls" | "xlsx" | "ppt" | "pptx" | "txt" | "md" | "epub" => MediaType::Document,
        _ => MediaType::Other,
    }
}

fn calculate_file_hash_sync(file_path: &str) -> Result<String, String> {
    let mut file = fs::File::open(file_path)
        .map_err(|e| format!("打开文件失败: {}", e))?;
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 8192];

    loop {
        let n = file.read(&mut buffer)
            .map_err(|e| format!("读取文件失败: {}", e))?;
        if n == 0 {
            break;
        }
        hasher.update(&buffer[..n]);
    }

    Ok(hex::encode(hasher.finalize()))
}

fn generate_thumbnail_path(storage_name: &str) -> String {
    // 获取应用数据目录下的 thumbnails 目录（使用数据库中注册的媒体目录）
    let media_dir = crate::db::get_media_dir()
        .unwrap_or_else(|_| {
            dirs::data_dir()
                .unwrap_or_else(|| PathBuf::from("."))
                .join("AdvanceMediaKB")
                .join("media")
                .to_string_lossy()
                .to_string()
        });
    let thumb_dir = PathBuf::from(&media_dir).join("thumbnails");

    let _ = fs::create_dir_all(&thumb_dir);
    thumb_dir.join(format!("thumb_{}", storage_name))
        .to_string_lossy()
        .to_string()
}

fn generate_thumbnail_sync(file_path: &str, output_path: &str, quality: i32) -> Result<String, String> {
    use image::imageops::FilterType;

    let img = image::open(file_path)
        .map_err(|e| format!("打开图片失败: {}", e))?;

    // 计算缩略图尺寸（最大 512px）
    let width = img.width();
    let height = img.height();
    let max_dim = 512;
    let ratio = (max_dim as f32 / (width.max(height) as f32)).min(1.0);
    let new_width = (width as f32 * ratio) as u32;
    let new_height = (height as f32 * ratio) as u32;

    let thumbnail = img.resize(new_width, new_height, FilterType::Lanczos3);

    // 保存为 JPEG
    let output_path = if output_path.ends_with(".jpg") || output_path.ends_with(".jpeg") {
        output_path.to_string()
    } else {
        format!("{}.jpg", output_path)
    };

    let mut output_file = fs::File::create(&output_path)
        .map_err(|e| format!("创建缩略图文件失败: {}", e))?;

    let quality = quality.clamp(1, 100) as u8;
    thumbnail.write_to(&mut output_file, image::ImageOutputFormat::Jpeg(quality))
        .map_err(|e| format!("保存缩略图失败: {}", e))?;

    Ok(output_path)
}

fn get_image_dimensions(file_path: &str) -> Result<(Option<i32>, Option<i32>), String> {
    let img = image::open(file_path)
        .map_err(|e| format!("获取图片尺寸失败: {}", e))?;
    Ok((Some(img.width() as i32), Some(img.height() as i32)))
}

/// 导入单个文件
#[frb]
pub async fn import_single_file(file_path: String) -> Result<MediaItem, String> {
    let pool = get_pool()?;
    let app_dir = crate::db::get_media_dir()?;
    let file_path_buf = PathBuf::from(&file_path);

    // 检查文件是否存在
    if !file_path_buf.exists() {
        return Err("文件不存在".to_string());
    }

    // 计算文件哈希
    let hash = calculate_file_hash_sync(&file_path)?;

    // 检查是否重复
    let existing = sqlx::query("SELECT id FROM media_items WHERE sha256_hash = ?")
        .bind(&hash)
        .fetch_optional(&pool)
        .await
        .map_err(|e| format!("查询重复文件失败: {}", e))?;

    if existing.is_some() {
        return Err("文件已存在".to_string());
    }

    // 获取文件信息
    let original_name = file_path_buf
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unknown")
        .to_string();

    let extension = file_path_buf
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_lowercase();

    let media_type = determine_media_type(&extension);
    let mime_type = mime_guess::from_path(&file_path).first_or_octet_stream().to_string();

    let metadata = fs::metadata(&file_path)
        .map_err(|e| format!("读取文件元数据失败: {}", e))?;
    let size = metadata.len() as i64;

    // 生成存储文件名（使用原始路径哈希确保唯一性）
    // 用户要求：存储名 = 原名 + 导入时间戳
    let ts = chrono::Utc::now().format("%Y%m%d_%H%M%S").to_string();
    let base_name = file_path_buf.file_stem().and_then(|s| s.to_str()).unwrap_or("media");
    let safe_base: String = base_name.chars().take(60).collect();
    let storage_name = format!("{}_{}.{}", safe_base, ts, extension);
    let dest_path = PathBuf::from(&app_dir).join(&storage_name);

    // 复制文件到应用目录
    fs::copy(&file_path, &dest_path)
        .map_err(|e| format!("复制文件失败: {}", e))?;

    // 生成缩略图
    let thumbnail_path = if media_type == MediaType::Image || media_type == MediaType::Video {
        let thumb_dir = PathBuf::from(&app_dir).join("thumbnails");
        fs::create_dir_all(&thumb_dir).ok();
        let thumb_path = thumb_dir.join(format!("thumb_{}.jpg", storage_name));
        match generate_thumbnail_sync(&dest_path.to_string_lossy(), &thumb_path.to_string_lossy(), 85) {
            Ok(path) => path,
            Err(_) => String::new(),
        }
    } else {
        String::new()
    };

    // 获取图片尺寸
    let (width, height) = if media_type == MediaType::Image {
        get_image_dimensions(&dest_path.to_string_lossy()).unwrap_or((None, None))
    } else {
        (None, None)
    };

    let now = chrono::Utc::now().timestamp();
    let id = Uuid::new_v4().to_string();

    // 插入数据库（file_path 保存复制后的路径，original_path 保存原始路径）
    sqlx::query(
        "INSERT INTO media_items (
            id, original_name, storage_name, file_path, thumbnail_path,
            type, mime_type, size, width, height, duration,
            sha256_hash, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    )
    .bind(&id)
    .bind(&original_name)
    .bind(&storage_name)
    .bind(dest_path.to_string_lossy().to_string())
    .bind(&thumbnail_path)
    .bind(media_type.as_str())
    .bind(&mime_type)
    .bind(size)
    .bind(width)
    .bind(height)
    .bind(None::<i64>) // duration
    .bind(&hash)
    .bind(now)
    .bind(now)
    .execute(&pool)
    .await
    .map_err(|e| format!("插入数据库失败: {}", e))?;

    Ok(MediaItem {
        id,
        original_name,
        storage_name,
        file_path: dest_path.to_string_lossy().to_string(),
        thumbnail_path,
        media_type,
        mime_type,
        size,
        width,
        height,
        duration: None,
        sha256_hash: hash,
        created_at: now,
        updated_at: now,
    })
}
