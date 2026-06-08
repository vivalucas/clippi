use crate::binaries::ffprobe_path;
use crate::error::CoreError;
use crate::types::FileInfo;
use anyhow::{Context, Result};
use std::io::Read;
use std::process::{Command, Output, Stdio};
use std::sync::mpsc;
use std::time::{Duration, Instant};

const FFPROBE_TIMEOUT: Duration = Duration::from_secs(20);

/// Probe file metadata using ffprobe
pub fn probe_file(path: &str) -> Result<FileInfo> {
    let mut command = Command::new(ffprobe_path());
    command.args([
        "-v",
        "quiet",
        "-print_format",
        "json",
        "-show_format",
        "-show_streams",
        path,
    ]);

    let output = run_with_timeout(command, FFPROBE_TIMEOUT).context("Failed to run ffprobe")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(CoreError::ProbeFailed(stderr.to_string()).into());
    }

    let json: serde_json::Value =
        serde_json::from_slice(&output.stdout).context("Failed to parse ffprobe output")?;

    // Extract video stream info
    let video_stream = json["streams"]
        .as_array()
        .and_then(|streams| streams.iter().find(|s| s["codec_type"] == "video"))
        .ok_or_else(|| CoreError::ProbeFailed("No video stream found".to_string()))?;
    let has_audio = json["streams"]
        .as_array()
        .is_some_and(|streams| streams.iter().any(|s| s["codec_type"] == "audio"));

    let width = video_stream["width"].as_u64().unwrap_or(0) as u32;
    let height = video_stream["height"].as_u64().unwrap_or(0) as u32;
    let codec = video_stream["codec_name"]
        .as_str()
        .unwrap_or("unknown")
        .to_string();

    // Parse frame rate (e.g., "30/1" -> 30.0)
    let frame_rate = parse_frame_rate(video_stream);

    let format = &json["format"];
    let duration_secs = format["duration"]
        .as_str()
        .and_then(|d| d.parse::<f64>().ok())
        .unwrap_or(0.0);

    let bitrate = format["bit_rate"]
        .as_str()
        .and_then(|b| b.parse::<u64>().ok())
        .unwrap_or(0);

    Ok(FileInfo {
        width,
        height,
        duration_secs,
        codec,
        frame_rate,
        bitrate,
        has_audio,
    })
}

fn run_with_timeout(mut command: Command, timeout: Duration) -> Result<Output> {
    let mut child = command
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .context("Failed to spawn ffprobe")?;

    let mut stdout = child
        .stdout
        .take()
        .ok_or_else(|| CoreError::ProbeFailed("Failed to read ffprobe stdout".to_string()))?;
    let mut stderr = child
        .stderr
        .take()
        .ok_or_else(|| CoreError::ProbeFailed("Failed to read ffprobe stderr".to_string()))?;

    let (stdout_tx, stdout_rx) = mpsc::channel();
    std::thread::spawn(move || {
        let mut buffer = Vec::new();
        let _ = stdout.read_to_end(&mut buffer);
        let _ = stdout_tx.send(buffer);
    });

    let (stderr_tx, stderr_rx) = mpsc::channel();
    std::thread::spawn(move || {
        let mut buffer = Vec::new();
        let _ = stderr.read_to_end(&mut buffer);
        let _ = stderr_tx.send(buffer);
    });

    let started = Instant::now();
    loop {
        if let Some(status) = child.try_wait().context("Failed to poll ffprobe")? {
            let stdout = stdout_rx.recv().unwrap_or_default();
            let stderr = stderr_rx.recv().unwrap_or_default();
            return Ok(Output {
                status,
                stdout,
                stderr,
            });
        }

        if started.elapsed() >= timeout {
            let _ = child.kill();
            let _ = child.wait();
            return Err(CoreError::ProbeFailed("ffprobe timed out".to_string()).into());
        }

        std::thread::sleep(Duration::from_millis(50));
    }
}

fn parse_frame_rate(stream: &serde_json::Value) -> f64 {
    parse_rational(stream.get("r_frame_rate"))
        .or_else(|| parse_rational(stream.get("avg_frame_rate")))
        .filter(|rate| rate.is_finite() && *rate > 0.0)
        .unwrap_or(0.0)
}

fn parse_rational(value: Option<&serde_json::Value>) -> Option<f64> {
    let raw = value?.as_str()?;
    let parts: Vec<&str> = raw.split('/').collect();
    if parts.len() != 2 {
        return None;
    }

    let numerator: f64 = parts[0].parse().ok()?;
    let denominator: f64 = parts[1].parse().ok()?;
    if denominator == 0.0 {
        return None;
    }

    let rate = numerator / denominator;
    rate.is_finite().then_some(rate)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parses_valid_frame_rate() {
        let stream = json!({
            "r_frame_rate": "30000/1001",
            "avg_frame_rate": "0/0"
        });

        let rate = parse_frame_rate(&stream);
        assert!((rate - 29.970_029_970_029_97).abs() < f64::EPSILON);
    }

    #[test]
    fn falls_back_to_avg_frame_rate_when_primary_is_invalid() {
        let stream = json!({
            "r_frame_rate": "0/0",
            "avg_frame_rate": "24000/1001"
        });

        let rate = parse_frame_rate(&stream);
        assert!((rate - 23.976_023_976_023_978).abs() < f64::EPSILON);
    }

    #[test]
    fn rejects_invalid_frame_rate_values() {
        assert_eq!(parse_rational(Some(&json!("30"))), None);
        assert_eq!(parse_rational(Some(&json!("30/0"))), None);
        assert_eq!(parse_rational(Some(&json!("abc/1"))), None);
        assert_eq!(parse_frame_rate(&json!({ "r_frame_rate": "0/0" })), 0.0);
    }
}
