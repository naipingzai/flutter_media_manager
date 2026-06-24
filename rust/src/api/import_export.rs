use flutter_rust_bridge::frb;

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

/// 导入包
#[frb]
pub async fn import_package(package_path: String, conflict_strategy: ConflictStrategy) -> Result<ImportProgress, String> {
    Ok(ImportProgress {
        total_files: 0,
        processed_files: 0,
        current_phase: "准备".to_string(),
        status: "完成".to_string(),
    })
}

/// 导出数据包
#[frb]
pub async fn export_package(export_path: String, include_media: bool) -> Result<ExportProgress, String> {
    Ok(ExportProgress {
        total_files: 0,
        processed_files: 0,
        current_file: None,
        status: "完成".to_string(),
    })
}

/// 导出到下载目录
#[frb]
pub async fn export_to_download(media_ids: Vec<String>) -> Result<String, String> {
    Ok(String::new())
}
