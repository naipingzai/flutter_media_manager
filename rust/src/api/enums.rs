use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// Skill-01 §2.4 - FilterMode 枚举
/// 用于首页"所有媒体"Tab 的内容过滤器
#[frb]
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum FilterMode {
    /// 显示全部媒体
    All,
    /// 仅显示已打标签的媒体
    WithTags,
    /// 仅显示未打标签的媒体
    WithoutTags,
    /// 仅显示已加入相册的媒体
    WithAlbums,
    /// 仅显示未加入相册的媒体
    WithoutAlbums,
}

impl FilterMode {
    pub fn as_str(&self) -> &'static str {
        match self {
            FilterMode::All => "all",
            FilterMode::WithTags => "with_tags",
            FilterMode::WithoutTags => "without_tags",
            FilterMode::WithAlbums => "with_albums",
            FilterMode::WithoutAlbums => "without_albums",
        }
    }

    pub fn display_name(&self) -> &'static str {
        match self {
            FilterMode::All => "全部",
            FilterMode::WithTags => "有标签的",
            FilterMode::WithoutTags => "无标签的",
            FilterMode::WithAlbums => "有相册的",
            FilterMode::WithoutAlbums => "无相册的",
        }
    }
}

/// Skill-01 §2.2 - ThemeMode 枚举（设置用）
#[frb]
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ThemeModeSetting {
    System,
    Light,
    Dark,
}

impl ThemeModeSetting {
    pub fn as_str(&self) -> &'static str {
        match self {
            ThemeModeSetting::System => "system",
            ThemeModeSetting::Light => "light",
            ThemeModeSetting::Dark => "dark",
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s {
            "light" => ThemeModeSetting::Light,
            "dark" => ThemeModeSetting::Dark,
            _ => ThemeModeSetting::System,
        }
    }
}

/// Skill-01 §2.3 - Language 枚举（设置用）
#[frb]
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum LanguageSetting {
    System,
    Zh,
    En,
}

impl LanguageSetting {
    pub fn as_str(&self) -> &'static str {
        match self {
            LanguageSetting::System => "system",
            LanguageSetting::Zh => "zh",
            LanguageSetting::En => "en",
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s {
            "zh" => LanguageSetting::Zh,
            "en" => LanguageSetting::En,
            _ => LanguageSetting::System,
        }
    }
}
