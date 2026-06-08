//! Clippi Core Library
//!
//! Provides video processing capabilities through ffmpeg/ffprobe.
//! Used by macOS (SwiftUI) and Windows (WinUI 3) UI layers via FFI.

mod binaries;
mod error;
mod ffi;
mod gpu;
mod probe;
mod queue;
mod task;
mod types;

pub use error::CoreError;
pub use gpu::detect_gpu;
pub use probe::probe_file;
pub use queue::queue_tasks;
pub use task::{cancel_task, run_task};
pub use types::*;
