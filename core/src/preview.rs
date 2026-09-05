use crate::binaries::ffmpeg_path;
use crate::error::CoreError;
use anyhow::Result;
use std::process::Command;

/// Generate a lightweight, auto-oriented JPEG used when the native player
/// cannot decode a source container.
pub fn generate_preview_image(input_path: &str, output_path: &str) -> Result<()> {
    if input_path.trim().is_empty() || output_path.trim().is_empty() {
        return Err(CoreError::InvalidParams("preview paths cannot be empty".to_string()).into());
    }

    let output = Command::new(ffmpeg_path())
        .args([
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-ss",
            "0",
            "-i",
            input_path,
            "-frames:v",
            "1",
            "-vf",
            "scale=1280:-2:force_original_aspect_ratio=decrease",
            output_path,
        ])
        .output()
        .map_err(|error| CoreError::FFmpegFailed(error.to_string()))?;

    if !output.status.success() {
        return Err(CoreError::FFmpegFailed(
            String::from_utf8_lossy(&output.stderr).trim().to_string(),
        )
        .into());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_empty_preview_paths() {
        assert!(generate_preview_image("", "preview.jpg").is_err());
        assert!(generate_preview_image("input.mp4", "").is_err());
    }
}
