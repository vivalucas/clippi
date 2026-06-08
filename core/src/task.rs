use crate::binaries::ffmpeg_path;
use crate::error::CoreError;
use crate::probe::probe_file;
use crate::types::{
    AudioFormat, Operation, OutputFormat, Progress, ProgressFn, TaskConfig, TaskHandle,
};
use anyhow::Result;
use std::io::{BufRead, BufReader, Read};
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc;
use std::time::Duration;

/// RAII wrapper that kills the child process on drop if still running.
struct KillOnDrop(Option<Child>);

impl KillOnDrop {
    fn new(child: Child) -> Self {
        Self(Some(child))
    }

    fn inner_mut(&mut self) -> &mut Child {
        self.0.as_mut().expect("child already taken")
    }

    fn take(&mut self) -> Child {
        self.0.take().expect("child already taken")
    }
}

impl Drop for KillOnDrop {
    fn drop(&mut self) {
        if let Some(mut child) = self.0.take() {
            let _ = child.kill();
            let _ = child.wait();
        }
    }
}

static TASK_ID_COUNTER: AtomicU64 = AtomicU64::new(1);

/// Run a single ffmpeg task
pub fn run_task(config: TaskConfig, callback: ProgressFn) -> Result<TaskHandle> {
    let id = next_task_id();
    validate_config(&config)?;
    let duration = task_duration_secs(&config);
    let args = build_ffmpeg_args(&config)?;
    let (cancel_tx, cancel_rx) = tokio::sync::oneshot::channel::<()>();

    std::thread::spawn(move || {
        let _ = execute_task_blocking(id, args, duration, cancel_rx, callback);
    });

    Ok(TaskHandle { id, cancel_tx })
}

pub(crate) fn next_task_id() -> u64 {
    TASK_ID_COUNTER.fetch_add(1, Ordering::Relaxed)
}

pub(crate) fn prepare_task(config: &TaskConfig) -> Result<(Vec<String>, f64)> {
    validate_config(config)?;
    Ok((build_ffmpeg_args(config)?, task_duration_secs(config)))
}

pub(crate) fn execute_task_blocking(
    task_id: u64,
    args: Vec<String>,
    duration: f64,
    mut cancel_rx: tokio::sync::oneshot::Receiver<()>,
    callback: ProgressFn,
) -> Result<()> {
    let mut child = match spawn_ffmpeg(&args) {
        Ok(child) => KillOnDrop::new(child),
        Err(error) => {
            report_failure(&callback, task_id, error.to_string());
            return Err(error);
        }
    };

    let stdout = child
        .inner_mut()
        .stdout
        .take()
        .ok_or_else(|| CoreError::FFmpegFailed("Failed to read ffmpeg progress".to_string()))
        .map_err(|error| {
            report_failure(&callback, task_id, error.to_string());
            error
        })?;
    let stderr = child
        .inner_mut()
        .stderr
        .take()
        .ok_or_else(|| CoreError::FFmpegFailed("Failed to read ffmpeg stderr".to_string()))
        .map_err(|error| {
            report_failure(&callback, task_id, error.to_string());
            error
        })?;
    let stderr_handle = std::thread::spawn(move || {
        let mut stderr_text = String::new();
        let mut reader = BufReader::new(stderr);
        let _ = reader.read_to_string(&mut stderr_text);
        stderr_text
    });

    let (line_tx, line_rx) = mpsc::channel();
    let stdout_handle = std::thread::spawn(move || {
        let reader = BufReader::new(stdout);
        for line in reader.lines() {
            match line {
                Ok(line) => {
                    if line_tx.send(line).is_err() {
                        break;
                    }
                }
                Err(_) => break,
            }
        }
    });

    let mut speed = String::new();

    loop {
        match line_rx.recv_timeout(Duration::from_millis(100)) {
            Ok(line) => {
                if line.starts_with("out_time_us=") {
                    if let Some(time_str) = line.strip_prefix("out_time_us=") {
                        if let Ok(time_us) = time_str.trim().parse::<f64>() {
                            if duration > 0.0 {
                                let percent = (time_us / 1_000_000.0 / duration * 100.0).min(100.0);
                                let eta_secs = estimate_eta_secs(duration, percent, &speed);
                                callback(Progress {
                                    task_id: Some(task_id),
                                    percent: percent as f32,
                                    speed: speed.clone(),
                                    eta_secs,
                                    state: "running".to_string(),
                                    message: None,
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
            Err(mpsc::RecvTimeoutError::Timeout) => {}
            Err(mpsc::RecvTimeoutError::Disconnected) => {
                break;
            }
        }

        if cancel_rx.try_recv().is_ok() {
            let mut raw = child.take();
            let _ = raw.kill();
            let _ = raw.wait();
            let _ = stdout_handle.join();
            let _ = stderr_handle.join();
            callback(Progress {
                task_id: Some(task_id),
                percent: 0.0,
                speed: String::new(),
                eta_secs: None,
                state: "cancelled".to_string(),
                message: Some("Task cancelled".to_string()),
            });
            return Err(CoreError::Cancelled.into());
        }
    }

    let _ = stdout_handle.join();

    let status = child.inner_mut().wait().map_err(|e| {
        let error = CoreError::FFmpegFailed(e.to_string());
        report_failure(&callback, task_id, error.to_string());
        error
    })?;
    if !status.success() {
        let stderr_text = stderr_handle.join().unwrap_or_default();
        let message = format!(
            "ffmpeg exited with status {}: {}",
            status,
            stderr_text.trim()
        );
        report_failure(&callback, task_id, message.clone());
        return Err(CoreError::FFmpegFailed(message).into());
    }
    let _ = stderr_handle.join();

    callback(Progress {
        task_id: Some(task_id),
        percent: 100.0,
        speed,
        eta_secs: Some(0),
        state: "completed".to_string(),
        message: None,
    });

    Ok(())
}

fn report_failure(callback: &ProgressFn, task_id: u64, message: String) {
    callback(Progress {
        task_id: Some(task_id),
        percent: 0.0,
        speed: String::new(),
        eta_secs: None,
        state: "failed".to_string(),
        message: Some(message),
    });
}

fn estimate_eta_secs(duration: f64, percent: f64, speed: &str) -> Option<u64> {
    let speed_factor = parse_speed_factor(speed)?;
    if !(duration.is_finite() && duration > 0.0) || !(percent.is_finite() && percent >= 0.0) {
        return None;
    }

    let remaining = duration * (100.0 - percent).max(0.0) / 100.0;
    let eta = (remaining / speed_factor).ceil();
    eta.is_finite().then_some(eta as u64)
}

fn parse_speed_factor(speed: &str) -> Option<f64> {
    let raw = speed.trim().strip_suffix('x').unwrap_or(speed.trim());
    let value: f64 = raw.parse().ok()?;
    (value.is_finite() && value > 0.0).then_some(value)
}

fn spawn_ffmpeg(args: &[String]) -> Result<Child> {
    Command::new(ffmpeg_path())
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| CoreError::FFmpegFailed(e.to_string()).into())
}

/// Cancel a running task
pub fn cancel_task(_task_id: u64, cancel_tx: tokio::sync::oneshot::Sender<()>) {
    let _ = cancel_tx.send(());
}

/// Build ffmpeg arguments from task config
fn build_ffmpeg_args(config: &TaskConfig) -> Result<Vec<String>> {
    let mut args = vec![
        "-n".to_string(),
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

    if let Operation::Trim {
        start,
        fast_mode: true,
        ..
    } = &config.operation
    {
        args.extend(["-ss".to_string(), start.to_string()]);
    }

    args.extend(["-i".to_string(), config.input_path.clone()]);

    match &config.operation {
        Operation::Trim {
            start,
            end,
            fast_mode,
        } => {
            if !fast_mode {
                args.extend(["-ss".to_string(), start.to_string()]);
            }
            let trim_duration = trim_duration_secs(config).unwrap_or((*end - *start).max(0.0));
            args.extend(["-t".to_string(), trim_duration.to_string()]);
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
            if matches!(format, OutputFormat::Webm)
                && config.video_codec.as_deref().is_some_and(|c| {
                    c.contains("264")
                        || c.contains("265")
                        || c.contains("videotoolbox")
                        || c.contains("nvenc")
                        || c.contains("qsv")
                })
            {
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
            args.extend(["-c:v".to_string(), "copy".to_string()]);
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
        if !start.is_finite() || !end.is_finite() {
            return Err(CoreError::InvalidParams("trim times must be finite".to_string()).into());
        }
        if *start < 0.0 || *end <= *start {
            return Err(CoreError::InvalidParams(
                "trim end time must be greater than start time".to_string(),
            )
            .into());
        }
    }

    Ok(())
}

fn task_duration_secs(config: &TaskConfig) -> f64 {
    if let Operation::Trim { start, end, .. } = &config.operation {
        return trim_duration_secs(config).unwrap_or((*end - *start).max(0.0));
    }

    probe_file(&config.input_path)
        .map(|info| info.duration_secs)
        .unwrap_or(0.0)
}

fn trim_duration_secs(config: &TaskConfig) -> Option<f64> {
    let Operation::Trim { start, end, .. } = &config.operation else {
        return None;
    };

    let requested = (*end - *start).max(0.0);
    let source_duration = probe_file(&config.input_path).ok()?.duration_secs;
    if !(source_duration.is_finite() && source_duration > 0.0) {
        return Some(requested);
    }

    Some((source_duration - *start).max(0.0).min(requested))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn config(operation: Operation) -> TaskConfig {
        TaskConfig {
            input_path: "/tmp/input.mp4".to_string(),
            output_path: "/tmp/output.mp4".to_string(),
            operation,
            video_codec: Some("h264_videotoolbox".to_string()),
            audio_codec: Some("aac".to_string()),
            hw_accel: Some("videotoolbox".to_string()),
        }
    }

    fn arg_pair(args: &[String], key: &str) -> Option<String> {
        args.windows(2)
            .find(|pair| pair[0] == key)
            .map(|pair| pair[1].clone())
    }

    #[test]
    fn convert_webm_falls_back_to_webm_compatible_codecs() {
        let args = build_ffmpeg_args(&config(Operation::Convert {
            format: OutputFormat::Webm,
        }))
        .unwrap();

        assert_eq!(arg_pair(&args, "-c:v").as_deref(), Some("libvpx-vp9"));
        assert_eq!(arg_pair(&args, "-c:a").as_deref(), Some("libopus"));
        assert_eq!(arg_pair(&args, "-progress").as_deref(), Some("pipe:1"));
        assert_eq!(arg_pair(&args, "-threads").as_deref(), Some("0"));
        assert_eq!(args.first().map(String::as_str), Some("-n"));
    }

    #[test]
    fn remove_audio_copies_video_stream_without_reencoding() {
        let args = build_ffmpeg_args(&config(Operation::RemoveAudio)).unwrap();

        assert!(args.iter().any(|arg| arg == "-an"));
        assert_eq!(arg_pair(&args, "-c:v").as_deref(), Some("copy"));
    }

    #[test]
    fn extract_audio_selects_requested_audio_codec() {
        let args = build_ffmpeg_args(&config(Operation::ExtractAudio {
            format: AudioFormat::Wav,
        }))
        .unwrap();

        assert!(args.iter().any(|arg| arg == "-vn"));
        assert_eq!(arg_pair(&args, "-acodec").as_deref(), Some("pcm_s16le"));
    }

    #[test]
    fn scale_sets_filter_and_video_codec() {
        let args = build_ffmpeg_args(&config(Operation::Scale {
            width: 1280,
            height: 720,
        }))
        .unwrap();

        assert_eq!(arg_pair(&args, "-vf").as_deref(), Some("scale=1280:720"));
        assert_eq!(
            arg_pair(&args, "-c:v").as_deref(),
            Some("h264_videotoolbox")
        );
    }

    #[test]
    fn validate_config_rejects_invalid_trim_ranges() {
        let negative_start = config(Operation::Trim {
            start: -1.0,
            end: 2.0,
            fast_mode: true,
        });
        assert!(validate_config(&negative_start).is_err());

        let reversed = config(Operation::Trim {
            start: 5.0,
            end: 2.0,
            fast_mode: true,
        });
        assert!(validate_config(&reversed).is_err());

        let nan = config(Operation::Trim {
            start: f64::NAN,
            end: 2.0,
            fast_mode: true,
        });
        assert!(validate_config(&nan).is_err());
    }

    #[test]
    fn parses_speed_and_estimates_eta() {
        assert_eq!(parse_speed_factor("2.5x"), Some(2.5));
        assert_eq!(parse_speed_factor("0x"), None);
        assert_eq!(parse_speed_factor("not-a-speed"), None);
        assert_eq!(estimate_eta_secs(100.0, 25.0, "2x"), Some(38));
    }
}
