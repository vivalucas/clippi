use thiserror::Error;

#[derive(Error, Debug)]
pub enum CoreError {
    #[error("File not found: {0}")]
    FileNotFound(String),

    #[error("Unsupported format: {0}")]
    UnsupportedFormat(String),

    #[error("ffprobe failed: {0}")]
    ProbeFailed(String),

    #[error("ffmpeg failed: {0}")]
    FFmpegFailed(String),

    #[error("Task cancelled")]
    Cancelled,

    #[error("Invalid parameters: {0}")]
    InvalidParams(String),

    #[error("GPU detection failed: {0}")]
    GpuDetectionFailed(String),
}
