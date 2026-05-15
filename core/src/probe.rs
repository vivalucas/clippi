use std::process::Command;
use anyhow::{Context, Result};
use crate::types::FileInfo;
use crate::error::CoreError;
use crate::binaries::ffprobe_path;

/// Probe file metadata using ffprobe
pub fn probe_file(path: &str) -> Result<FileInfo> {
    let output = Command::new(ffprobe_path())
        .args([
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            path,
        ])
        .output()
        .context("Failed to run ffprobe")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(CoreError::ProbeFailed(stderr.to_string()).into());
    }

    let json: serde_json::Value = serde_json::from_slice(&output.stdout)
        .context("Failed to parse ffprobe output")?;

    // Extract video stream info
    let video_stream = json["streams"]
        .as_array()
        .and_then(|streams| streams.iter().find(|s| s["codec_type"] == "video"))
        .ok_or_else(|| CoreError::ProbeFailed("No video stream found".to_string()))?;

    let width = video_stream["width"].as_u64().unwrap_or(0) as u32;
    let height = video_stream["height"].as_u64().unwrap_or(0) as u32;
    let codec = video_stream["codec_name"].as_str().unwrap_or("unknown").to_string();

    // Parse frame rate (e.g., "30/1" -> 30.0)
    let frame_rate = video_stream["r_frame_rate"]
        .as_str()
        .and_then(|r| {
            let parts: Vec<&str> = r.split('/').collect();
            if parts.len() == 2 {
                let num: f64 = parts[0].parse().ok()?;
                let den: f64 = parts[1].parse().ok()?;
                Some(num / den)
            } else {
                None
            }
        })
        .unwrap_or(0.0);

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
    })
}
