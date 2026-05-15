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
├── core/                          # Rust 核心库
│   ├── src/
│   │   ├── lib.rs                 # 模块定义
│   │   ├── ffi.rs                 # C FFI 接口
│   │   ├── probe.rs               # ffprobe 文件信息读取
│   │   ├── gpu.rs                 # GPU 探测
│   │   ├── task.rs                # 任务执行
│   │   ├── queue.rs               # 队列管理
│   │   ├── types.rs               # 数据类型定义
│   │   └── error.rs               # 错误类型
│   └── Cargo.toml
├── macos/                         # macOS SwiftUI 项目
│   ├── Clippi.xcodeproj/
│   └── Clippi/
│       ├── ClippiApp.swift        # App 入口
│       ├── FFI/ClippiFFI.swift    # Swift FFI 封装
│       ├── ViewModels/            # ViewModel 层
│       └── Views/                 # View 层
├── windows/                       # Windows WinUI 3 项目
│   └── Clippi/
│       ├── App.xaml/cs            # App 入口
│       ├── MainWindow.xaml/cs     # 主窗口
│       ├── ViewModels/            # ViewModel 层
│       └── ClippiCore.cs          # C# P/Invoke 封装
├── scripts/                       # 构建脚本
│   ├── download_ffmpeg.sh         # macOS/Linux ffmpeg 下载
│   ├── download_ffmpeg.ps1        # Windows ffmpeg 下载
│   ├── build-core.sh              # Rust 核心库构建 (macOS/Linux)
│   └── build-core.ps1             # Rust 核心库构建 (Windows)
├── .github/workflows/             # CI/CD
│   ├── build-macos.yml
│   └── build-windows.yml
├── LICENSE                        # GPL-2.0
└── README.md
```

## 构建

项目使用 GitHub Actions 自动构建。推送 `v*` 格式的 tag 会触发构建流程。

### 本地开发

#### 环境要求

- Rust (stable)
- ffmpeg (通过脚本下载)
- macOS: Xcode 15+
- Windows: Visual Studio 2022 + .NET 8 SDK

#### 构建步骤

```bash
# 1. 下载 ffmpeg
./scripts/download_ffmpeg.sh      # macOS/Linux
.\scripts\download_ffmpeg.ps1     # Windows

# 2. 构建 Rust 核心库
./scripts/build-core.sh           # macOS/Linux
.\scripts\build-core.ps1          # Windows

# 3. 打开 IDE 项目
# macOS: 打开 macos/Clippi.xcodeproj
# Windows: 打开 windows/Clippi/Clippi.csproj
```

### 发布

```bash
# 创建版本 tag 并推送，触发 CI/CD 构建
git tag v1.0.0
git push origin v1.0.0
```

构建完成后，可以在 GitHub Releases 页面下载对应平台的安装包。

## 许可证

GPL-2.0
