/// Parse ffmpeg stderr output for progress information
pub fn parse_progress_line(line: &str) -> Option<ProgressInfo> {
    // ffmpeg progress output format:
    // frame=  123 fps= 45 q=28.0 size=    1234kB time=00:00:05.12 bitrate= 1234.5kbits/s speed=2.5x

    let mut progress = ProgressInfo::default();

    if let Some(time) = extract_value(line, "time=") {
        progress.time = parse_time(&time);
    }

    if let Some(speed) = extract_value(line, "speed=") {
        progress.speed = speed;
    }

    Some(progress)
}

fn extract_value(line: &str, key: &str) -> Option<String> {
    line.find(key).map(|pos| {
        let start = pos + key.len();
        let rest = &line[start..];
        let end = rest.find(' ').unwrap_or(rest.len());
        rest[..end].to_string()
    })
}

fn parse_time(time: &str) -> f64 {
    // Parse HH:MM:SS.ss format
    let parts: Vec<&str> = time.split(':').collect();
    if parts.len() == 3 {
        let hours: f64 = parts[0].parse().unwrap_or(0.0);
        let minutes: f64 = parts[1].parse().unwrap_or(0.0);
        let seconds: f64 = parts[2].parse().unwrap_or(0.0);
        hours * 3600.0 + minutes * 60.0 + seconds
    } else {
        0.0
    }
}

#[derive(Default)]
pub struct ProgressInfo {
    pub time: f64,
    pub speed: String,
}
