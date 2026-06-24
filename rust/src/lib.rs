pub mod api;
mod frb_generated;

// 重新导出所有 API 模块，使 flutter_rust_bridge 能正确生成绑定
pub use api::media::*;
pub use api::album::*;
pub use api::tag::*;
pub use api::note::*;
pub use api::search::*;
pub use api::settings::*;
pub use api::scanner::*;
pub use api::import_export::*;
