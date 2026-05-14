# Clippi

Clippi 是一款跨平台、原生图形界面的视频处理工具，以 ffmpeg 为处理引擎，对普通用户隐藏命令行复杂度，同时为技术用户保留完整的控制能力。

## 特性

- 拖拽导入文件，自动读取媒体信息
- 视频裁剪（快速模式 / 精确模式）
- 格式转换（mp4 / mkv / mov / webm）
- 分辨率缩放（4K / 1080p / 720p / 480p）
- 音频处理（提取音频 / 去除音频）
- GPU 硬件加速（VideoToolbox / NVENC / QSV）
- 批量队列处理
- 实时进度显示

## 技术栈

| 层级 | 技术 |
|------|------|
| macOS UI | Swift + SwiftUI |
| Windows UI | C# + WinUI 3 |
| 核心库 | Rust |
| 处理引擎 | ffmpeg |

## 项目结构

```
clippi/
├── core/          # Rust 核心库
├── macos/         # macOS SwiftUI 项目
├── windows/       # Windows WinUI 3 项目
├── scripts/       # 构建脚本
├── project-log/   # 开发知识库
└── docs/          # 文档
```

## 开发

### 环境要求

- Rust (stable)
- ffmpeg (通过脚本下载)
- macOS: Xcode
- Windows: Visual Studio + .NET

### 构建

```bash
# 下载 ffmpeg
./scripts/download_ffmpeg.sh  # macOS/Linux
.\scripts\download_ffmpeg.ps1  # Windows

# 构建 Rust 核心库
cd core
cargo build --release
```

## 许可证

GPL-2.0
