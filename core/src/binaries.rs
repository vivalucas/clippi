use std::env;
use std::path::{Path, PathBuf};

pub(crate) fn ffmpeg_path() -> PathBuf {
    binary_path("ffmpeg")
}

pub(crate) fn ffprobe_path() -> PathBuf {
    binary_path("ffprobe")
}

fn binary_path(name: &str) -> PathBuf {
    let executable = executable_name(name);

    if let Ok(dir) = env::var("CLIPPI_FFMPEG_DIR") {
        let candidate = Path::new(&dir).join(&executable);
        if candidate.is_file() {
            return candidate;
        }
    }

    for candidate in bundled_candidates(&executable) {
        if candidate.is_file() {
            return candidate;
        }
    }

    PathBuf::from(executable)
}

fn executable_name(name: &str) -> String {
    if cfg!(windows) {
        format!("{}.exe", name)
    } else {
        name.to_string()
    }
}

fn bundled_candidates(executable: &str) -> Vec<PathBuf> {
    let mut candidates = Vec::new();

    if let Ok(current_exe) = env::current_exe() {
        if let Some(exe_dir) = current_exe.parent() {
            candidates.push(exe_dir.join("ffmpeg").join(executable));
            candidates.push(exe_dir.join(executable));

            if let Some(contents_dir) = exe_dir.parent() {
                candidates.push(
                    contents_dir
                        .join("Resources")
                        .join("ffmpeg")
                        .join(executable),
                );
            }
        }
    }

    if let Ok(current_dir) = env::current_dir() {
        candidates.push(
            current_dir
                .join("ffmpeg")
                .join(platform_dir())
                .join(executable),
        );
        candidates.push(current_dir.join("ffmpeg").join(executable));
    }

    candidates
}

fn platform_dir() -> &'static str {
    if cfg!(target_os = "macos") {
        if cfg!(target_arch = "aarch64") {
            "macos-arm64"
        } else {
            "macos-x64"
        }
    } else if cfg!(target_os = "windows") {
        "windows-x64"
    } else {
        "linux"
    }
}
