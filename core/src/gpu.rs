use std::process::Command;
use crate::types::GpuCapability;

/// Detect GPU hardware acceleration capability
pub fn detect_gpu() -> GpuCapability {
    #[cfg(target_os = "macos")]
    return detect_gpu_macos();

    #[cfg(target_os = "windows")]
    return detect_gpu_windows();

    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    return GpuCapability {
        video_encoder: None,
        hw_accel: None,
    };
}

#[cfg(target_os = "macos")]
fn detect_gpu_macos() -> GpuCapability {
    // Try VideoToolbox encoders
    for encoder in &["hevc_videotoolbox", "h264_videotoolbox"] {
        if test_encoder(encoder) {
            return GpuCapability {
                video_encoder: Some(encoder.to_string()),
                hw_accel: Some("videotoolbox".to_string()),
            };
        }
    }

    GpuCapability {
        video_encoder: None,
        hw_accel: None,
    }
}

#[cfg(target_os = "windows")]
fn detect_gpu_windows() -> GpuCapability {
    // Try NVIDIA first, then Intel QSV
    for (encoder, accel) in &[
        ("h264_nvenc", "cuda"),
        ("h264_qsv", "qsv"),
    ] {
        if test_encoder(encoder) {
            return GpuCapability {
                video_encoder: Some(encoder.to_string()),
                hw_accel: Some(accel.to_string()),
            };
        }
    }

    GpuCapability {
        video_encoder: None,
        hw_accel: None,
    }
}

/// Test if an encoder is available
fn test_encoder(encoder: &str) -> bool {
    Command::new("ffmpeg")
        .args(["-f", "lavfi", "-i", "color=c=black:s=64x64:d=0.1", "-c:v", encoder, "-f", "null", "-"])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}
