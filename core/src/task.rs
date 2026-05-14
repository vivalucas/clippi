use std::io::{BufRead, BufReader, Read};
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicU64, Ordering};
use anyhow::Result;
use crate::probe::probe_file;
use crate::types::{TaskConfig, Operation, AudioFormat, OutputFormat, TaskHandle, Progress, ProgressFn};
use crate::error::CoreError;

static TASK_ID_COUNTER: AtomicU64 = AtomicU64::new(1);

/// Run a single ffmpeg task
pub fn run_task(config: TaskConfig, callback: ProgressFn) -> Result<TaskHandle> {
    let id = TASK_ID_COUNTER.fetch_add(1, Ordering::Relaxed);
    validate_config(&config)?;
    let duration = task_duration_secs(&config);
    let args = build_ffmpeg_args(&config)?;
    let (cancel_tx, cancel_rx) = tokio::sync::oneshot::channel::<()>();

    std::thread::spawn(move || {
        let mut cancel_rx = cancel_rx;
        let mut child = Command::new("ffmpeg")
            .args(&args)
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| CoreError::FFmpegFailed(e.to_string()))?;

        let stdout = child
            .stdout
            .take()
            .ok_or_else(|| CoreError::FFmpegFailed("Failed to read ffmpeg progress".to_string()))?;
        let stderr = child.stderr.take().unwrap();
        let stderr_handle = std::thread::spawn(move || {
            let mut stderr_text = String::new();
            let mut reader = BufReader::new(stderr);
            let _ = reader.read_to_string(&mut stderr_text);
            stderr_text
        });

        let reader = BufReader::new(stdout);
        let mut speed = String::new();

        for line in reader.lines() {
            if let Ok(line) = line {
                if line.starts_with("out_time_us=") {
                    if let Some(time_str) = line.strip_prefix("out_time_us=") {
                        if let Ok(time_us) = time_str.trim().parse::<f64>() {
                            if duration > 0.0 {
                                let percent = (time_us / 1_000_000.0 / duration * 100.0).min(100.0);
                                callback(Progress {
                                    percent: percent as f32,
                                    speed: speed.clone(),
                                    eta_secs: None,
                                });
                            }
                        }
                    }
                } else if line.starts_with("speed=") {
                    speed = line
                        .strip_prefix("speed=")
                        .unwrap_or_default()
                        .trim()
                        .to_string();
                }
            }

            if cancel_rx.try_recv().is_ok() {
                let _ = child.kill();
                return Err(CoreError::Cancelled);
            }
        }

        let status = child.wait().map_err(|e| CoreError::FFmpegFailed(e.to_string()))?;
        if !status.success() {
            let stderr_text = stderr_handle.join().unwrap_or_default();
            return Err(CoreError::FFmpegFailed(format!(
                "ffmpeg exited with status {}: {}",
                status,
                stderr_text.trim()
            )));
        }

        callback(Progress {
            percent: 100.0,
            speed,
            eta_secs: Some(0),
        });
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
    let mut args = vec![
        "-y".to_string(),
        "-hide_banner".to_string(),
        "-nostats".to_string(),
        "-loglevel".to_string(),
        "error".to_string(),
        "-progress".to_string(),
        "pipe:1".to_string(),
    ];

    // Add hardware acceleration if available
    if let Some(ref hw_accel) = config.hw_accel {
        args.extend(["-hwaccel".to_string(), hw_accel.clone()]);
    }

    if let Operation::Trim { start, fast_mode: true, .. } = &config.operation {
        args.extend(["-ss".to_string(), start.to_string()]);
    }

    args.extend(["-i".to_string(), config.input_path.clone()]);

    match &config.operation {
        Operation::Trim { start, end, fast_mode } => {
            if !fast_mode {
                args.extend(["-ss".to_string(), start.to_string()]);
            }
            args.extend(["-t".to_string(), (*end - *start).to_string()]);
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
            if matches!(format, OutputFormat::Webm) && config.video_codec.as_deref().is_some_and(|c| c.contains("264") || c.contains("265") || c.contains("videotoolbox") || c.contains("nvenc") || c.contains("qsv")) {
                args.extend(["-c:v".to_string(), "libvpx-vp9".to_string()]);
            } else if let Some(ref vc) = config.video_codec {
                args.extend(["-c:v".to_string(), vc.clone()]);
            }
            if matches!(format, OutputFormat::Webm) {
                args.extend(["-c:a".to_string(), "libopus".to_string()]);
            } else if let Some(ref ac) = config.audio_codec {
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

    args.extend(["-threads".to_string(), "0".to_string()]);
    args.push(config.output_path.clone());
    Ok(args)
}

fn validate_config(config: &TaskConfig) -> Result<()> {
    if config.input_path.trim().is_empty() {
        return Err(CoreError::InvalidParams("input path is empty".to_string()).into());
    }

    if config.output_path.trim().is_empty() {
        return Err(CoreError::InvalidParams("output path is empty".to_string()).into());
    }

    if let Operation::Trim { start, end, .. } = &config.operation {
        if *start < 0.0 || *end <= *start {
            return Err(CoreError::InvalidParams("trim end time must be greater than start time".to_string()).into());
        }
    }

    Ok(())
}

fn task_duration_secs(config: &TaskConfig) -> f64 {
    if let Operation::Trim { start, end, .. } = &config.operation {
        return (*end - *start).max(0.0);
    }

    probe_file(&config.input_path)
        .map(|info| info.duration_secs)
        .unwrap_or(0.0)
}
