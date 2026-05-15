//! Clippi Core Library
//!
//! Provides video processing capabilities through ffmpeg/ffprobe.
//! Used by macOS (SwiftUI) and Windows (WinUI 3) UI layers via FFI.

mod probe;
mod gpu;
mod task;
mod queue;
mod error;
mod types;
mod ffi;
mod binaries;

pub use error::CoreError;
pub use types::*;
pub use probe::probe_file;
pub use gpu::detect_gpu;
pub use task::{run_task, cancel_task};
pub use queue::queue_tasks;
