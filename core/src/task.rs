use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicU64, Ordering};
use std::io::{BufRead, BufReader};
use anyhow::{Context, Result};
use crate::types::{TaskConfig, Operation, AudioFormat, TaskHandle, ProgressFn};
use crate::error::CoreError;

static TASK_ID_COUNTER: AtomicU64 = AtomicU64::new(1);

/// Run a single ffmpeg task
pub fn run_task(config: TaskConfig, callback: ProgressFn) -> Result<TaskHandle> {
    let id = TASK_ID_COUNTER.fetch_add(1, Ordering::Relaxed);
    let args = build_ffmpeg_args(&config)?;
    let (cancel_tx, cancel_rx) = tokio::sync::oneshot::channel::<()>();

    let handle = std::thread::spawn(move || {
        let mut child = Command::new("ffmpeg")
            .args(&args)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .spawn()
            .expect("Failed to spawn ffmpeg");

        let stderr = child.stderr.take().unwrap();
        let reader = BufReader::new(stderr);

        // Parse progress from stderr
        let mut duration = 0.0f64;
        // Try to get duration from config (we'll need to probe first)
        // For now, use a simple progress parser

        for line in reader.lines() {
            if let Ok(line) = line {
                // Check for progress output
                if line.starts_with("out_time_us=") {
                    if let Some(time_str) = line.strip_prefix("out_time_us=") {
                        if let Ok(time_us) = time_str.trim().parse::<f64>() {
                            if duration > 0.0 {
                                let percent = (time_us / 1_000_000.0 / duration * 100.0).min(100.0);
                                callback(crate::types::Progress {
                                    percent: percent as f32,
                                    speed: String::new(),
                                    eta_secs: None,
                                });
                            }
                        }
                    }
                } else if line.starts_with("speed=") {
                    // Parse speed
                }
            }

            // Check for cancellation
            if cancel_rx.try_recv().is_ok() {
                let _ = child.kill();
                return Err(CoreError::Cancelled);
            }
        }

        let status = child.wait().map_err(|e| CoreError::FFmpegFailed(e.to_string()))?;
        if !status.success() {
            return Err(CoreError::FFmpegFailed(format!("ffmpeg exited with status {}", status)));
        }

        Ok(())
    });

    Ok(TaskHandle { id, cancel_tx })
}

/// Cancel a running task
pub fn cancel_task(task_id: u64, cancel_tx: tokio::sync::oneshot::Sender<()>) {
    let _ = cancel_tx.send(());
}

/// Build ffmpeg arguments from task config
fn build_ffmpeg_args(config: &TaskConfig) -> Result<Vec<String>> {
    let mut args = vec!["-y".to_string()];

    // Add hardware acceleration if available
    if let Some(ref hw_accel) = config.hw_accel {
        args.extend(["-hwaccel".to_string(), hw_accel.clone()]);
    }

    args.extend(["-i".to_string(), config.input_path.clone()]);

    match &config.operation {
        Operation::Trim { start, end, fast_mode } => {
            args.extend(["-ss".to_string(), start.to_string()]);
            args.extend(["-to".to_string(), end.to_string()]);
            if *fast_mode {
                args.extend(["-c".to_string(), "copy".to_string()]);
            } else {
                if let Some(ref vc) = config.video_codec {
                    args.extend(["-c:v".to_string(), vc.clone()]);
                }
                if let Some(ref ac) = config.audio_codec {
                    args.extend(["-c:a".to_string(), ac.clone()]);
                }
            }
        }
        Operation::Convert { format } => {
            if let Some(ref vc) = config.video_codec {
                args.extend(["-c:v".to_string(), vc.clone()]);
            }
            if let Some(ref ac) = config.audio_codec {
                args.extend(["-c:a".to_string(), ac.clone()]);
            }
        }
        Operation::Scale { width, height } => {
            args.extend(["-vf".to_string(), format!("scale={}:{}", width, height)]);
            if let Some(ref vc) = config.video_codec {
                args.extend(["-c:v".to_string(), vc.clone()]);
            }
        }
        Operation::ExtractAudio { format } => {
            args.extend(["-vn".to_string()]);
            match format {
                AudioFormat::Mp3 => args.extend(["-acodec".to_string(), "libmp3lame".to_string()]),
                AudioFormat::Aac => args.extend(["-acodec".to_string(), "aac".to_string()]),
                AudioFormat::Wav => args.extend(["-acodec".to_string(), "pcm_s16le".to_string()]),
            }
        }
        Operation::RemoveAudio => {
            args.extend(["-an".to_string()]);
        }
    }

    args.push(config.output_path.clone());
    Ok(args)
}
