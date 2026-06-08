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
    pub has_audio: bool,
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
    Trim {
        start: f64,
        end: f64,
        fast_mode: bool,
    },
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
    pub task_id: Option<u64>,
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

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn deserializes_external_tagged_operations_from_ui_json() {
        let trim: Operation = serde_json::from_value(json!({
            "Trim": { "start": 1.5, "end": 3.0, "fast_mode": true }
        }))
        .unwrap();
        assert!(matches!(
            trim,
            Operation::Trim {
                start: 1.5,
                end: 3.0,
                fast_mode: true
            }
        ));

        let extract: Operation = serde_json::from_value(json!({
            "ExtractAudio": { "format": "wav" }
        }))
        .unwrap();
        assert!(matches!(
            extract,
            Operation::ExtractAudio {
                format: AudioFormat::Wav
            }
        ));

        let remove: Operation = serde_json::from_value(json!("RemoveAudio")).unwrap();
        assert!(matches!(remove, Operation::RemoveAudio));
    }

    #[test]
    fn output_and_audio_formats_use_lowercase_json() {
        assert!(matches!(
            serde_json::from_str::<OutputFormat>("\"webm\"").unwrap(),
            OutputFormat::Webm
        ));
        assert_eq!(serde_json::to_string(&AudioFormat::Aac).unwrap(), "\"aac\"");
    }
}
