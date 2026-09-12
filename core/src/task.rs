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
    let source_duration = probe_file(&config.input_path)
        .map(|info| info.duration_secs)
        .unwrap_or(0.0);
    let duration = task_duration_secs(&config, source_duration);
    let args = build_ffmpeg_args(&config, source_duration)?;
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
    let source_duration = probe_file(&config.input_path)
        .map(|info| info.duration_secs)
        .unwrap_or(0.0);
    Ok((
        build_ffmpeg_args(config, source_duration)?,
        task_duration_secs(config, source_duration),
    ))
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
        .inspect_err(|error| {
            report_failure(&callback, task_id, error.to_string());
        })?;
    let stderr = child
        .inner_mut()
        .stderr
        .take()
        .ok_or_else(|| CoreError::FFmpegFailed("Failed to read ffmpeg stderr".to_string()))
        .inspect_err(|error| {
            report_failure(&callback, task_id, error.to_string());
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
    if speed_factor < 0.1 {
        return None;
    }
    if !(duration.is_finite() && duration > 0.0 && percent.is_finite() && percent >= 0.0) {
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
fn build_ffmpeg_args(config: &TaskConfig, source_duration: f64) -> Result<Vec<String>> {
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
        Operation::Transform {
            rotation_degrees,
            flip_horizontal,
            flip_vertical,
        } => {
            let filter =
                build_transform_filter(*rotation_degrees, *flip_horizontal, *flip_vertical)?;
            if !filter.is_empty() {
                args.extend(["-vf".to_string(), filter]);
            }
            args.extend([
                "-map".to_string(),
                "0:v:0".to_string(),
                "-map".to_string(),
                "0:a?".to_string(),
                "-map_metadata".to_string(),
                "0".to_string(),
            ]);
            let webm_output = std::path::Path::new(&config.output_path)
                .extension()
                .and_then(|extension| extension.to_str())
                .is_some_and(|extension| extension.eq_ignore_ascii_case("webm"));
            if webm_output
                && config.video_codec.as_deref().is_some_and(|codec| {
                    codec.contains("264")
                        || codec.contains("265")
                        || codec.contains("videotoolbox")
                        || codec.contains("nvenc")
                        || codec.contains("qsv")
                })
            {
                args.extend(["-c:v".to_string(), "libvpx-vp9".to_string()]);
            } else if let Some(ref vc) = config.video_codec {
                args.extend(["-c:v".to_string(), vc.clone()]);
            }
            let selected_codec = arg_value(&args, "-c:v").map(str::to_owned);
            append_quality_args(&mut args, selected_codec.as_deref());
            if webm_output
                && config.audio_codec.as_deref().is_some_and(|codec| {
                    codec != "copy" && codec != "libopus" && codec != "libvorbis"
                })
            {
                args.extend(["-c:a".to_string(), "libopus".to_string()]);
            } else if let Some(ref ac) = config.audio_codec {
                args.extend(["-c:a".to_string(), ac.clone()]);
            }
            if config.audio_codec.as_deref() == Some("aac") {
                args.extend(["-b:a".to_string(), "192k".to_string()]);
            }
            args.extend(["-metadata:s:v:0".to_string(), "rotate=0".to_string()]);
            if selected_codec
                .as_deref()
                .is_some_and(|codec| codec.contains("hevc") || codec.contains("265"))
            {
                args.extend(["-tag:v".to_string(), "hvc1".to_string()]);
            }
            if std::path::Path::new(&config.output_path)
                .extension()
                .and_then(|extension| extension.to_str())
                .is_some_and(|extension| extension.eq_ignore_ascii_case("mp4"))
            {
                args.extend(["-movflags".to_string(), "+faststart".to_string()]);
            }
        }
        Operation::Trim {
            start,
            end,
            fast_mode,
        } => {
            if !fast_mode {
                args.extend(["-ss".to_string(), start.to_string()]);
            }
            let trim_duration =
                trim_duration_secs(config, source_duration).unwrap_or((*end - *start).max(0.0));
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
            args.extend(["-vf".to_string(), format!("scale={}:{}:force_original_aspect_ratio=decrease:force_divisible_by=2,setsar=1", width, height)]);
            if let Some(ref vc) = config.video_codec {
                args.extend(["-c:v".to_string(), vc.clone()]);
            }
            if let Some(ref ac) = config.audio_codec {
                args.extend(["-c:a".to_string(), ac.clone()]);
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

    // Re-encoded WebM sources (scale and precise trim included) need WebM codecs.
    let webm = std::path::Path::new(&config.output_path)
        .extension()
        .and_then(|value| value.to_str())
        .is_some_and(|value| value.eq_ignore_ascii_case("webm"));
    if webm
        && matches!(
            config.operation,
            Operation::Scale { .. }
                | Operation::Trim {
                    fast_mode: false,
                    ..
                }
        )
    {
        args.extend([
            "-c:v".to_string(),
            "libvpx-vp9".to_string(),
            "-c:a".to_string(),
            "libopus".to_string(),
        ]);
    }

    args.extend(["-threads".to_string(), "0".to_string()]);
    args.push(config.output_path.clone());
    Ok(args)
}

fn build_transform_filter(
    rotation_degrees: i32,
    flip_horizontal: bool,
    flip_vertical: bool,
) -> Result<String> {
    let mut filters: Vec<&str> = match rotation_degrees.rem_euclid(360) {
        0 => Vec::new(),
        90 => vec!["transpose=clock"],
        180 => vec!["hflip", "vflip"],
        270 => vec!["transpose=cclock"],
        _ => {
            return Err(CoreError::InvalidParams(
                "rotation must be a multiple of 90 degrees".to_string(),
            )
            .into())
        }
    };
    if flip_horizontal {
        filters.push("hflip");
    }
    if flip_vertical {
        filters.push("vflip");
    }
    Ok(filters.join(","))
}

fn arg_value<'a>(args: &'a [String], key: &str) -> Option<&'a str> {
    args.windows(2)
        .find(|pair| pair[0] == key)
        .map(|pair| pair[1].as_str())
}

fn append_quality_args(args: &mut Vec<String>, codec: Option<&str>) {
    match codec.unwrap_or_default() {
        "libx264" => args.extend([
            "-crf".to_string(),
            "18".to_string(),
            "-preset".to_string(),
            "medium".to_string(),
            "-pix_fmt".to_string(),
            "yuv420p".to_string(),
        ]),
        "libx265" => args.extend([
            "-crf".to_string(),
            "20".to_string(),
            "-preset".to_string(),
            "medium".to_string(),
            "-pix_fmt".to_string(),
            "yuv420p10le".to_string(),
        ]),
        "h264_nvenc" => args.extend([
            "-cq".to_string(),
            "19".to_string(),
            "-b:v".to_string(),
            "0".to_string(),
            "-pix_fmt".to_string(),
            "yuv420p".to_string(),
        ]),
        "h264_qsv" => args.extend([
            "-global_quality".to_string(),
            "19".to_string(),
            "-pix_fmt".to_string(),
            "nv12".to_string(),
        ]),
        "h264_videotoolbox" => args.extend([
            "-q:v".to_string(),
            "65".to_string(),
            "-pix_fmt".to_string(),
            "yuv420p".to_string(),
        ]),
        "hevc_videotoolbox" => args.extend([
            "-q:v".to_string(),
            "65".to_string(),
            "-pix_fmt".to_string(),
            "p010le".to_string(),
        ]),
        "libvpx-vp9" => args.extend([
            "-crf".to_string(),
            "30".to_string(),
            "-b:v".to_string(),
            "0".to_string(),
        ]),
        _ => {}
    }
}

pub(crate) fn validate_config(config: &TaskConfig) -> Result<()> {
    if config.input_path.trim().is_empty() {
        return Err(CoreError::InvalidParams("input path is empty".to_string()).into());
    }

    if config.output_path.trim().is_empty() {
        return Err(CoreError::InvalidParams("output path is empty".to_string()).into());
    }

    if std::path::Path::new(&config.output_path).exists() {
        return Err(CoreError::InvalidParams("output file already exists".to_string()).into());
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

    if let Operation::Scale { width, height } = &config.operation {
        if *width < 2 || *height < 2 || width % 2 != 0 || height % 2 != 0 {
            return Err(CoreError::InvalidParams(
                "scale dimensions must be positive even numbers".to_string(),
            )
            .into());
        }
    }

    if let Operation::Transform {
        rotation_degrees, ..
    } = &config.operation
    {
        if rotation_degrees.rem_euclid(90) != 0 {
            return Err(CoreError::InvalidParams(
                "rotation must be a multiple of 90 degrees".to_string(),
            )
            .into());
        }
    }

    Ok(())
}

fn task_duration_secs(config: &TaskConfig, source_duration: f64) -> f64 {
    if let Operation::Trim { start, end, .. } = &config.operation {
        return trim_duration_secs(config, source_duration).unwrap_or((*end - *start).max(0.0));
    }

    source_duration
}

fn trim_duration_secs(config: &TaskConfig, source_duration: f64) -> Option<f64> {
    let Operation::Trim { start, end, .. } = &config.operation else {
        return None;
    };

    let requested = (*end - *start).max(0.0);
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
        let args = build_ffmpeg_args(
            &config(Operation::Convert {
                format: OutputFormat::Webm,
            }),
            10.0,
        )
        .unwrap();

        assert_eq!(arg_pair(&args, "-c:v").as_deref(), Some("libvpx-vp9"));
        assert_eq!(arg_pair(&args, "-c:a").as_deref(), Some("libopus"));
        assert_eq!(arg_pair(&args, "-progress").as_deref(), Some("pipe:1"));
        assert_eq!(arg_pair(&args, "-threads").as_deref(), Some("0"));
        assert_eq!(args.first().map(String::as_str), Some("-n"));
    }

    #[test]
    fn remove_audio_copies_video_stream_without_reencoding() {
        let args = build_ffmpeg_args(&config(Operation::RemoveAudio), 10.0).unwrap();

        assert!(args.iter().any(|arg| arg == "-an"));
        assert_eq!(arg_pair(&args, "-c:v").as_deref(), Some("copy"));
    }

    #[test]
    fn extract_audio_selects_requested_audio_codec() {
        let args = build_ffmpeg_args(
            &config(Operation::ExtractAudio {
                format: AudioFormat::Wav,
            }),
            10.0,
        )
        .unwrap();

        assert!(args.iter().any(|arg| arg == "-vn"));
        assert_eq!(arg_pair(&args, "-acodec").as_deref(), Some("pcm_s16le"));
    }

    #[test]
    fn scale_sets_filter_and_video_codec() {
        let args = build_ffmpeg_args(
            &config(Operation::Scale {
                width: 1280,
                height: 720,
            }),
            10.0,
        )
        .unwrap();

        assert_eq!(
            arg_pair(&args, "-vf").as_deref(),
            Some(
                "scale=1280:720:force_original_aspect_ratio=decrease:force_divisible_by=2,setsar=1"
            )
        );
        assert_eq!(
            arg_pair(&args, "-c:v").as_deref(),
            Some("h264_videotoolbox")
        );
    }

    #[test]
    fn transform_composes_rotation_and_flips_and_clears_metadata() {
        let args = build_ffmpeg_args(
            &config(Operation::Transform {
                rotation_degrees: 90,
                flip_horizontal: true,
                flip_vertical: false,
            }),
            10.0,
        )
        .unwrap();

        assert_eq!(
            arg_pair(&args, "-vf").as_deref(),
            Some("transpose=clock,hflip")
        );
        assert_eq!(
            arg_pair(&args, "-metadata:s:v:0").as_deref(),
            Some("rotate=0")
        );
        assert_eq!(arg_pair(&args, "-c:a").as_deref(), Some("aac"));
        assert_eq!(arg_pair(&args, "-b:a").as_deref(), Some("192k"));
        assert_eq!(arg_pair(&args, "-q:v").as_deref(), Some("65"));
        assert!(args.windows(2).any(|pair| pair == ["-map", "0:a?"]));
    }

    #[test]
    fn transform_rejects_non_quarter_turn_rotation() {
        assert!(build_transform_filter(45, false, false).is_err());
        assert_eq!(
            build_transform_filter(-90, false, true).unwrap(),
            "transpose=cclock,vflip"
        );
    }

    #[test]
    fn transform_webm_uses_container_compatible_codecs() {
        let mut task = config(Operation::Transform {
            rotation_degrees: 180,
            flip_horizontal: false,
            flip_vertical: false,
        });
        task.output_path = "/tmp/output.webm".to_string();

        let args = build_ffmpeg_args(&task, 10.0).unwrap();

        assert_eq!(arg_pair(&args, "-c:v").as_deref(), Some("libvpx-vp9"));
        assert_eq!(arg_pair(&args, "-c:a").as_deref(), Some("libopus"));
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
    fn scale_rejects_invalid_dimensions() {
        for (width, height) in [(0, 720), (1280, 0), (1279, 720)] {
            assert!(validate_config(&config(Operation::Scale { width, height })).is_err());
        }
    }

    #[test]
    fn webm_scale_and_precise_trim_select_compatible_codecs() {
        for operation in [
            Operation::Scale {
                width: 1280,
                height: 720,
            },
            Operation::Trim {
                start: 0.0,
                end: 1.0,
                fast_mode: false,
            },
        ] {
            let mut task = config(operation);
            task.output_path = "/tmp/result.webm".to_string();
            let args = build_ffmpeg_args(&task, 2.0).unwrap();
            assert_eq!(
                args.windows(2).rev().find(|p| p[0] == "-c:v").unwrap()[1],
                "libvpx-vp9"
            );
            assert_eq!(
                args.windows(2).rev().find(|p| p[0] == "-c:a").unwrap()[1],
                "libopus"
            );
        }
    }

    #[test]
    fn parses_speed_and_estimates_eta() {
        assert_eq!(parse_speed_factor("2.5x"), Some(2.5));
        assert_eq!(parse_speed_factor("0x"), None);
        assert_eq!(parse_speed_factor("not-a-speed"), None);
        assert_eq!(estimate_eta_secs(100.0, 25.0, "2x"), Some(38));
    }
}
