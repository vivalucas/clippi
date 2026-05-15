use serde::{Deserialize, Serialize};
use std::sync::Arc;

/// File information returned by ffprobe
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FileInfo {
    pub width: u32,
    pub height: u32,
    pub duration_secs: f64,
    pub codec: String,
    pub frame_rate: f64,
    pub bitrate: u64,
}

/// GPU hardware acceleration capability
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GpuCapability {
    pub video_encoder: Option<String>,
    pub hw_accel: Option<String>,
}

/// Video processing task configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskConfig {
    pub input_path: String,
    pub output_path: String,
    pub operation: Operation,
    pub video_codec: Option<String>,
    pub audio_codec: Option<String>,
    pub hw_accel: Option<String>,
}

/// Supported operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Operation {
    /// Trim video with start/end time (seconds)
    Trim { start: f64, end: f64, fast_mode: bool },
    /// Convert to target format
    Convert { format: OutputFormat },
    /// Scale resolution
    Scale { width: u32, height: u32 },
    /// Extract audio only
    ExtractAudio { format: AudioFormat },
    /// Remove audio track
    RemoveAudio,
}

/// Supported output formats
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum OutputFormat {
    Mp4,
    Mkv,
    Mov,
    Webm,
}

/// Supported audio formats
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum AudioFormat {
    Mp3,
    Aac,
    Wav,
}

/// Progress information from ffmpeg
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Progress {
    pub percent: f32,
    pub speed: String,
    pub eta_secs: Option<u64>,
    pub state: String,
    pub message: Option<String>,
}

/// Callback function type for progress reporting
pub type ProgressFn = Arc<dyn Fn(Progress) + Send + Sync + 'static>;

/// Handle to a running task
#[derive(Debug)]
pub struct TaskHandle {
    pub id: u64,
    pub cancel_tx: tokio::sync::oneshot::Sender<()>,
}

/// Handle to a task queue
#[derive(Debug)]
pub struct QueueHandle {
    pub task_ids: Vec<u64>,
}
