# Clippi

[简体中文](README.md) | [English](README.en.md) | [日本語](README.ja.md)

Clippi is a cross-platform native desktop video processing tool. It uses ffmpeg / ffprobe as the processing engine, with a SwiftUI interface on macOS and a WinUI 3 interface on Windows, so common video tasks no longer require command-line ffmpeg usage.

## Features

- Drag or choose one or more media files, or import the current level of a folder
- Read resolution, duration, codec, frame rate, and bitrate automatically
- Video trimming: fast mode (stream copy) and precise mode (re-encode)
- Format conversion: MP4 / MKV / MOV / WebM
- Resolution scaling: 4K / 1080p / 720p / 480p
- Audio tools: extract MP3 / AAC / WAV, or remove audio tracks
- GPU encoder detection: macOS VideoToolbox, Windows NVENC / QSV
- Material correction: preview and batch rotate 90°/180°, flip horizontally, or flip vertically
- Import multiple files or one folder level, then adjust items individually or apply one correction to a selection
- Normalize common video containers to high-quality MP4: H.264 for SDR and HEVC for detected 10-bit/HDR media
- Generate a fallback preview frame with the bundled ffmpeg when the native player cannot decode a source
- Progress, speed, completion, failure, and cancellation status callbacks
- Output path conflict avoidance, overwrite checks, and write-permission checks before processing
- Interface localization: 简体中文, English, 日本語

> ffmpeg and ffprobe are bundled with releases; users do not need to install or configure them.

## Downloads

Official builds are distributed through GitHub Releases:

- macOS: `Clippi-macos.dmg`
- Windows: `Clippi-Setup-x64.exe` (installer, recommended)
- Windows: `Clippi-Portable-x64.exe` (portable, single exe that extracts once to any folder)
- Windows: `Clippi-windows.zip` (plain archive, for advanced users)

> WinUI 3 apps cannot be compiled into a true single-file executable; the portable build is a self-extractor that unpacks once, after which you run `Clippi.exe` from the chosen folder.

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
│   ├── Clippi.xcodeproj/
│   └── Clippi/
│       ├── ClippiApp.swift        # App entry
│       ├── ClippiCore.h           # Swift bridging header
│       ├── FFI/ClippiFFI.swift    # Swift FFI wrapper
│       ├── Localization.swift     # macOS localization helper
│       ├── *.lproj/               # zh-Hans / en / ja localized resources
│       ├── ViewModels/
│       └── Views/
├── windows/                       # Windows WinUI 3 project
│   └── Clippi/
│       ├── App.xaml/cs
│       ├── MainWindow.xaml/cs
│       ├── Localization.cs        # Windows localization helper
│       ├── Strings/               # zh-CN / en-US / ja-JP .resw resources
│       ├── ViewModels/
│       └── ClippiCore.cs          # C# P/Invoke wrapper
├── scripts/
│   ├── download_ffmpeg.sh
│   ├── download_ffmpeg.ps1
│   ├── build-core.sh
│   └── build-core.ps1
├── installer/
│   ├── Clippi.iss                 # Inno Setup script (installer + portable)
│   └── ChineseSimplified.isl      # Simplified Chinese installer language
├── .github/workflows/
│   ├── build-macos.yml
│   └── build-windows.yml
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

- Material correction supports batch processing; trim and the other tools remain primarily single-file workflows
- Windows builds are not code-signed; SmartScreen may show a "Windows protected your PC" prompt on first run — choose "Run anyway"
- macOS builds are unsigned, so first launch may require allowing the app through system prompts
- Output size estimation, disk-space warnings, advanced ffmpeg parameter editing, command previews, expandable logs, and advanced queue history/retry controls are still planned

## License

GPL-2.0
