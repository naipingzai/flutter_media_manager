use flutter_rust_bridge::frb;
use std::fs;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use zip::ZipArchive;
use zip::write::FileOptions;
use zip::CompressionMethod;

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
    let path = Path::new(&package_path);
    if !path.exists() {
        return Err("导入文件不存在".to_string());
    }

    // 检查是否是 .db 文件（直接数据库导入）
    if path.extension().map_or(false, |ext| ext == "db" || ext == "sqlite" || ext == "sqlite3") {
        let db_path = crate::db::get_db_path().map_err(|e| e.to_string())?;
        fs::copy(&package_path, &db_path).map_err(|e| format!("复制数据库失败: {}", e))?;
        return Ok(ImportProgress {
            total_files: 1,
            processed_files: 1,
            current_phase: "数据库导入".to_string(),
            status: "数据库导入完成".to_string(),
        });
    }

    // ZIP 导入
    let file = fs::File::open(&package_path)
        .map_err(|e| format!("打开ZIP文件失败: {}", e))?;
    let mut archive = ZipArchive::new(file)
        .map_err(|e| format!("读取ZIP文件失败: {}", e))?;

    let total = archive.len() as i32;
    let mut processed = 0i32;
    let app_dir = crate::db::get_app_dir().map_err(|e| e.to_string())?;
    let media_dir = crate::db::get_media_dir().map_err(|e| e.to_string())?;

    for i in 0..archive.len() {
        let mut entry = archive.by_index(i)
            .map_err(|e| format!("读取ZIP条目失败: {}", e))?;

        let entry_name = entry.name().to_string();

        // 处理目录条目
        if entry.is_dir() {
            let target_dir = if entry_name.starts_with("db/") {
                PathBuf::from(&app_dir).join(entry_name.strip_prefix("db/").unwrap_or(&entry_name))
            } else if entry_name.starts_with("media/") {
                PathBuf::from(&media_dir).join(entry_name.strip_prefix("media/").unwrap_or(&entry_name))
            } else {
                PathBuf::from(&app_dir).join(&entry_name)
            };
            let _ = fs::create_dir_all(&target_dir);
            processed += 1;
            continue;
        }

        // 处理数据库文件
        if entry_name == "db/advance_media_kb.db" || entry_name == "advance_media_kb.db" {
            let db_path = crate::db::get_db_path().map_err(|e| e.to_string())?;
            let mut data = Vec::new();
            entry.read_to_end(&mut data).map_err(|e| format!("读取数据库条目失败: {}", e))?;

            match conflict_strategy {
                ConflictStrategy::Skip => {
                    if Path::new(&db_path).exists() {
                        processed += 1;
                        continue;
                    }
                }
                ConflictStrategy::Replace => {
                    // 直接覆盖
                }
                ConflictStrategy::Rename => {
                    // 重命名现有文件
                    if Path::new(&db_path).exists() {
                        let backup = format!("{}.backup", db_path);
                        let _ = fs::rename(&db_path, &backup);
                    }
                }
            }

            fs::write(&db_path, &data).map_err(|e| format!("写入数据库失败: {}", e))?;
            processed += 1;
            continue;
        }

        // 处理媒体文件
        if entry_name.starts_with("media/") {
            let relative_path = entry_name.strip_prefix("media/").unwrap_or(&entry_name);
            let target_path = PathBuf::from(&media_dir).join(relative_path);

            // 创建父目录
            if let Some(parent) = target_path.parent() {
                fs::create_dir_all(parent).ok();
            }

            match conflict_strategy {
                ConflictStrategy::Skip => {
                    if target_path.exists() {
                        processed += 1;
                        continue;
                    }
                }
                ConflictStrategy::Replace => {
                    // 直接覆盖
                }
                ConflictStrategy::Rename => {
                    if target_path.exists() {
                        let backup = format!("{}.backup", target_path.to_string_lossy());
                        let _ = fs::rename(&target_path, &backup);
                    }
                }
            }

            let mut data = Vec::new();
            entry.read_to_end(&mut data).map_err(|e| format!("读取媒体条目失败: {}", e))?;
            fs::write(&target_path, &data).map_err(|e| format!("写入媒体文件失败: {}", e))?;
            processed += 1;
        }
    }

    // 重新初始化数据库（如果是全量导入）
    if archive.by_name("db/advance_media_kb.db").is_ok() || archive.by_name("advance_media_kb.db").is_ok() {
        // 重新创建数据库连接
        crate::db::get_pool()?;
    }

    Ok(ImportProgress {
        total_files: total,
        processed_files: processed,
        current_phase: "导入完成".to_string(),
        status: format!("成功导入 {} / {} 个条目", processed, total),
    })
}

/// 导出数据包（导出数据库 + 媒体文件为 ZIP）
#[frb]
pub async fn export_package(export_path: String, include_media: bool) -> Result<ExportProgress, String> {
    let export_path_buf = PathBuf::from(&export_path);

    // 创建ZIP文件
    let file = fs::File::create(&export_path_buf)
        .map_err(|e| format!("创建ZIP文件失败: {}", e))?;
    let mut zip_writer = zip::ZipWriter::new(file);
    let options = FileOptions::default()
        .compression_method(CompressionMethod::Deflated)
        .unix_permissions(0o644);

    // 1. 导出数据库
    let db_path = crate::db::get_db_path().map_err(|e| e.to_string())?;
    let db_data = fs::read(&db_path)
        .map_err(|e| format!("读取数据库文件失败: {}", e))?;

    zip_writer.start_file("db/advance_media_kb.db", options)
        .map_err(|e| format!("写入ZIP数据库条目失败: {}", e))?;
    zip_writer.write_all(&db_data)
        .map_err(|e| format!("写入数据库数据到ZIP失败: {}", e))?;

    let mut total = 1i32;
    let mut processed = 1i32;

    if include_media {
        // 2. 导出媒体文件
        let media_dir = crate::db::get_media_dir().map_err(|e| e.to_string())?;
        let media_path = PathBuf::from(&media_dir);

        if media_path.exists() {
            // 递归遍历媒体目录
            fn add_directory_to_zip(
                zip: &mut zip::ZipWriter<fs::File>,
                dir: &Path,
                base_path: &Path,
                options: &FileOptions<'_, ()>,
                total: &mut i32,
                processed: &mut i32,
            ) -> Result<(), String> {
                for entry in fs::read_dir(dir).map_err(|e| format!("读取目录失败: {}", e))? {
                    let entry = entry.map_err(|e| format!("读取条目失败: {}", e))?;
                    let path = entry.path();
                    let relative = path.strip_prefix(base_path)
                        .map_err(|_| "路径前缀错误".to_string())?;
                    let zip_path = format!("media/{}", relative.to_string_lossy());

                    if path.is_dir() {
                        // 添加目录条目
                        zip.add_directory(&zip_path, *options)
                            .map_err(|e| format!("添加目录到ZIP失败: {}", e))?;
                        *total += 1;

                        // 递归子目录
                        add_directory_to_zip(zip, &path, base_path, options, total, processed)?;
                    } else if path.is_file() {
                        let file_data = fs::read(&path)
                            .map_err(|e| format!("读取媒体文件失败: {}", e))?;

                        zip.start_file(&zip_path, *options)
                            .map_err(|e| format!("写入ZIP媒体条目失败: {}", e))?;
                        zip.write_all(&file_data)
                            .map_err(|e| format!("写入媒体数据到ZIP失败: {}", e))?;

                        *total += 1;
                        *processed += 1;
                    }
                }
                Ok(())
            }

            add_directory_to_zip(&mut zip_writer, &media_path, &media_path, &options, &mut total, &mut processed)?;
        }
    }

    // 完成ZIP写入
    zip_writer.finish()
        .map_err(|e| format!("完成ZIP写入失败: {}", e))?;

    Ok(ExportProgress {
        total_files: total,
        processed_files: processed,
        current_file: None,
        status: format!("导出完成! 共 {} 个条目", processed),
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
        let app_dir = crate::db::get_app_dir().map_err(|e| e.to_string())?;
        PathBuf::from(&app_dir).join("Exports").join(format!("Export_{}", chrono::Local::now().format("%Y%m%d_%H%M%S")))
    } else {
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
