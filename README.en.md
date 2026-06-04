# Clippi

[简体中文](README.md) | [English](README.en.md) | [日本語](README.ja.md)

Clippi is a cross-platform native desktop video processing tool. It uses ffmpeg / ffprobe as the processing engine, with a SwiftUI interface on macOS and a WinUI 3 interface on Windows, so common video tasks no longer require command-line ffmpeg usage.

## Features

- Drag or choose a single media file
- Read resolution, duration, codec, frame rate, and bitrate automatically
- Video trimming: fast mode (stream copy) and precise mode (re-encode)
- Format conversion: MP4 / MKV / MOV / WebM
- Resolution scaling: 4K / 1080p / 720p / 480p
- Audio tools: extract MP3 / AAC / WAV, or remove audio tracks
- GPU encoder detection: macOS VideoToolbox, Windows NVENC / QSV
- Progress, speed, completion, failure, and cancellation status callbacks
- Output path conflict avoidance, overwrite checks, and write-permission checks before processing
- Interface localization: 简体中文, English, 日本語

> Batch queues and more complete advanced ffmpeg parameter controls are planned later. The current desktop UI focuses on single-file processing.

## Downloads

Official builds are distributed through GitHub Releases:

- macOS: `Clippi-macos.dmg`
- Windows: `Clippi-windows.zip`

Release builds bundle ffmpeg / ffprobe with the app, so users do not need to install ffmpeg separately. Development environments can also download local binaries through `scripts/download_ffmpeg.*`. The Rust core library searches bundled app paths first, then `CLIPPI_FFMPEG_DIR`, and finally the system `PATH`.

## Tech Stack

| Layer | Technology |
|------|------|
| macOS UI | Swift + SwiftUI |
| Windows UI | C# + WinUI 3 |
| Core library | Rust |
| Processing engine | ffmpeg / ffprobe |
| Localization | macOS `.lproj` / Windows `.resw` |

## Project Structure

```text
clippi/
├── core/                          # Rust core library
│   ├── src/
│   │   ├── lib.rs                 # Module definitions
│   │   ├── ffi.rs                 # C FFI interface
│   │   ├── probe.rs               # ffprobe file metadata reading
│   │   ├── gpu.rs                 # GPU detection
│   │   ├── task.rs                # ffmpeg task execution
│   │   ├── queue.rs               # Serial queue foundation
│   │   ├── binaries.rs            # ffmpeg / ffprobe path resolution
│   │   ├── types.rs               # Data types
│   │   └── error.rs               # Error types
│   └── Cargo.toml
├── macos/                         # macOS SwiftUI project
│   └── Clippi/
│       ├── Localization.swift     # macOS localization helper
│       └── *.lproj/               # zh-Hans / en / ja localized resources
├── windows/                       # Windows WinUI 3 project
│   └── Clippi/
│       ├── Localization.cs        # Windows localization helper
│       └── Strings/               # zh-CN / en-US / ja-JP .resw resources
├── scripts/
├── LICENSE
├── README.md                      # 简体中文
├── README.en.md                   # English
└── README.ja.md                   # 日本語
```

## Local Development

### Requirements

- Rust stable
- macOS: Xcode 15+
- Windows: Visual Studio 2022 + .NET 8 SDK
- ffmpeg / ffprobe: download with the scripts, or place them in `CLIPPI_FFMPEG_DIR`

### Build Steps

```bash
# 1. Download ffmpeg / ffprobe
./scripts/download_ffmpeg.sh      # macOS
.\scripts\download_ffmpeg.ps1     # Windows

# 2. Build the Rust core library
./scripts/build-core.sh           # macOS
.\scripts\build-core.ps1          # Windows

# 3. Open the native project
# macOS: macos/Clippi.xcodeproj
# Windows: windows/Clippi/Clippi.csproj
```

## CI/CD

GitHub Actions builds automatically in these scenarios:

- Push to `main`: build macOS / Windows artifacts to validate the main branch
- Push a `v*` tag: build and upload release assets

Release example:

```bash
git tag v1.0.0
git push origin v1.0.0
```

## Current Limitations

- The desktop UI currently exposes single-file processing only
- Windows builds are distributed as zip archives, not installers
- macOS builds are unsigned, so first launch may require allowing the app through system prompts
- Output size estimation, disk-space warnings, advanced ffmpeg parameter editing, command previews, expandable logs, and batch task management are still planned

## License

GPL-2.0
