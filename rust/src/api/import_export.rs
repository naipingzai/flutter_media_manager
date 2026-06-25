use flutter_rust_bridge::frb;
use std::fs;
use std::path::{Path, PathBuf};

/// 导入进度
#[frb]
#[derive(Debug, Clone)]
pub struct ImportProgress {
    pub total_files: i32,
    pub processed_files: i32,
    pub current_phase: String,
    pub status: String,
}

/// 导出进度
#[frb]
#[derive(Debug, Clone)]
pub struct ExportProgress {
    pub total_files: i32,
    pub processed_files: i32,
    pub current_file: Option<String>,
    pub status: String,
}

/// 冲突策略
#[frb]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConflictStrategy {
    Skip,
    Replace,
    Rename,
}

/// 导入包（ZIP 格式的数据库备份 + 媒体文件）
#[frb]
pub async fn import_package(package_path: String, conflict_strategy: ConflictStrategy) -> Result<ImportProgress, String> {
    use std::fs;
    use std::path::Path;
    
    let path = Path::new(&package_path);
    if !path.exists() {
        return Err("导入文件不存在".to_string());
    }
    
    // 检查是否是 .db 文件（直接数据库导入）
    if path.extension().map_or(false, |ext| ext == "db" || ext == "sqlite" || ext == "sqlite3") {
        // 直接复制数据库文件
        let db_path = crate::db::get_db_path().map_err(|e| e.to_string())?;
        fs::copy(&package_path, &db_path).map_err(|e| format!("复制数据库失败: {}", e))?;
        return Ok(ImportProgress {
            total_files: 1,
            processed_files: 1,
            current_phase: "数据库导入".to_string(),
            status: "数据库导入完成".to_string(),
        });
    }
    
    // ZIP 导入（简化实现）
    Err("ZIP 导入功能尚未实现，请使用 .db 文件直接导入".to_string())
}

/// 导出数据包（导出数据库 + 媒体文件为 ZIP）
#[frb]
pub async fn export_package(export_path: String, include_media: bool) -> Result<ExportProgress, String> {
    // 先导出数据库
    let db_result = crate::api::settings::export_data(export_path.clone()).await;

    if let Err(e) = db_result {
        return Ok(ExportProgress {
            total_files: 0,
            processed_files: 0,
            current_file: None,
            status: format!("数据库导出失败: {}", e),
        });
    }

    if include_media {
        // 复制媒体文件到导出目录
        let media_dir = crate::db::get_media_dir().map_err(|e| e.to_string())?;
        let export_media_dir = format!("{}/media", export_path.rfind('.').map_or(export_path.as_str(), |i| &export_path[..i]));
        
        if let Err(e) = fs::create_dir_all(&export_media_dir) {
            return Ok(ExportProgress {
                total_files: 0,
                processed_files: 0,
                current_file: None,
                status: format!("创建导出媒体目录失败: {}", e),
            });
        }
        
        // 遍历并复制媒体文件
        if let Ok(entries) = fs::read_dir(&media_dir) {
            let mut processed = 0;
            for entry in entries.flatten() {
                let src = entry.path();
                let dst = Path::new(&export_media_dir).join(entry.file_name());
                if let Err(e) = fs::copy(&src, &dst) {
                    return Ok(ExportProgress {
                        total_files: 0,
                        processed_files: processed,
                        current_file: Some(src.to_string_lossy().to_string()),
                        status: format!("复制媒体文件失败: {}", e),
                    });
                }
                processed += 1;
            }
        }
    }

    Ok(ExportProgress {
        total_files: 0,
        processed_files: 0,
        current_file: None,
        status: "导出完成".to_string(),
    })
}

/// 导出指定媒体到下载目录
/// 
/// 注意：在 Android 上，由于 Scoped Storage 限制，无法直接写入系统 Download 目录。
/// 改为导出到应用的外部存储目录（Android/data/<package>/files/Exports）
#[frb]
pub async fn export_to_download(media_ids: Vec<String>) -> Result<String, String> {
    use crate::api::media::get_media_by_id;

    // 在 Android 上，使用应用的外部存储目录而不是系统 Download 目录
    let export_dir = if cfg!(target_os = "android") {
        // 使用应用外部存储目录（Android/data/<package>/files/Exports）
        let app_dir = crate::db::get_app_dir().map_err(|e| e.to_string())?;
        PathBuf::from(&app_dir).join("Exports").join(format!("Export_{}", chrono::Local::now().format("%Y%m%d_%H%M%S")))
    } else {
        // 桌面平台使用 Download 目录
        let download_dir = dirs::download_dir()
            .unwrap_or_else(|| PathBuf::from("."));
        download_dir.join(format!("AdvanceMediaKB_Export_{}", chrono::Local::now().format("%Y%m%d_%H%M%S")))
    };

    fs::create_dir_all(&export_dir)
        .map_err(|e| format!("创建导出目录失败: {}", e))?;

    let mut exported = 0;
    for media_id in media_ids {
        if let Ok(Some(media)) = get_media_by_id(media_id).await {
            let src_path = Path::new(&media.file_path);
            if src_path.exists() {
                let dest_name = format!("{}_{}", media.storage_name, media.original_name);
                let dest_path = export_dir.join(&dest_name);
                if let Err(e) = fs::copy(src_path, &dest_path) {
                    log::warn!("复制文件失败 {}: {}", media.file_path, e);
                    continue;
                }
                exported += 1;
            }
        }
    }

    Ok(format!("已导出 {} 个文件到 {}", exported, export_dir.to_string_lossy()))
}
