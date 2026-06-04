# Clippi

Clippi 是一款跨平台原生桌面视频处理工具。它以 ffmpeg / ffprobe 为处理引擎，用 macOS SwiftUI 和 Windows WinUI 3 提供图形界面，让常见视频处理任务不再依赖命令行。

## 当前功能

- 拖拽或选择单个媒体文件
- 自动读取分辨率、时长、编码、帧率和码率
- 视频裁剪：快速模式（复制流）和精确模式（重编码）
- 格式转换：MP4 / MKV / MOV / WebM
- 分辨率缩放：4K / 1080p / 720p / 480p
- 音频处理：提取 MP3 / AAC / WAV，或移除音轨
- GPU 编码探测：macOS VideoToolbox，Windows NVENC / QSV
- 处理进度、速度、完成、失败和取消状态回传
- 输出路径自动避让已有文件，处理前检查覆盖和写入权限

> 批量队列和更完整的高级 ffmpeg 参数控制仍在后续规划中；当前桌面 UI 以单文件处理为主。

## 下载与分发

正式版本通过 GitHub Releases 分发：

- macOS：`Clippi-macos.dmg`
- Windows：`Clippi-windows.zip`

Release 构建会把 ffmpeg / ffprobe 一起打包进应用产物；用户不需要额外安装 ffmpeg。开发环境也可以通过 `scripts/download_ffmpeg.*` 下载本地二进制，Rust 核心库会优先查找应用内置路径，其次查找 `CLIPPI_FFMPEG_DIR`，最后回退到系统 `PATH`。

## 技术栈

| 层级 | 技术 |
|------|------|
| macOS UI | Swift + SwiftUI |
| Windows UI | C# + WinUI 3 |
| 核心库 | Rust |
| 处理引擎 | ffmpeg / ffprobe |

## 项目结构

```
clippi/
├── core/                          # Rust 核心库
│   ├── src/
│   │   ├── lib.rs                 # 模块定义
│   │   ├── ffi.rs                 # C FFI 接口
│   │   ├── probe.rs               # ffprobe 文件信息读取
│   │   ├── gpu.rs                 # GPU 探测
│   │   ├── task.rs                # ffmpeg 任务执行
│   │   ├── queue.rs               # 串行队列基础能力
│   │   ├── binaries.rs            # ffmpeg / ffprobe 路径解析
│   │   ├── types.rs               # 数据类型定义
│   │   └── error.rs               # 错误类型
│   └── Cargo.toml
├── macos/                         # macOS SwiftUI 项目
│   ├── Clippi.xcodeproj/
│   └── Clippi/
│       ├── ClippiApp.swift        # App 入口
│       ├── ClippiCore.h           # Swift 桥接头
│       ├── FFI/ClippiFFI.swift    # Swift FFI 封装
│       ├── ViewModels/
│       └── Views/
├── windows/                       # Windows WinUI 3 项目
│   └── Clippi/
│       ├── App.xaml/cs
│       ├── MainWindow.xaml/cs
│       ├── ViewModels/
│       └── ClippiCore.cs          # C# P/Invoke 封装
├── scripts/
│   ├── download_ffmpeg.sh
│   ├── download_ffmpeg.ps1
│   ├── build-core.sh
│   └── build-core.ps1
├── .github/workflows/
│   ├── build-macos.yml
│   └── build-windows.yml
├── LICENSE
└── README.md
```

## 本地开发

### 环境要求

- Rust stable
- macOS：Xcode 15+
- Windows：Visual Studio 2022 + .NET 8 SDK
- ffmpeg / ffprobe：可通过脚本下载，或放入 `CLIPPI_FFMPEG_DIR`

### 构建步骤

```bash
# 1. 下载 ffmpeg / ffprobe
./scripts/download_ffmpeg.sh      # macOS
.\scripts\download_ffmpeg.ps1     # Windows

# 2. 构建 Rust 核心库
./scripts/build-core.sh           # macOS
.\scripts\build-core.ps1          # Windows

# 3. 打开原生项目
# macOS: macos/Clippi.xcodeproj
# Windows: windows/Clippi/Clippi.csproj
```

## CI/CD

GitHub Actions 会在以下场景自动构建：

- 推送到 `main`：构建 macOS / Windows artifact，用于验证主分支
- 推送 `v*` tag：构建并上传 Release 资产

发布示例：

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 当前限制

- 桌面 UI 当前只开放单文件处理
- Windows 产物目前是 zip 包，不是安装器
- macOS 产物未签名，首次运行可能需要按系统提示允许打开
- 输出文件大小预估、磁盘空间预警、高级 ffmpeg 参数编辑、命令预览、日志展开和批量任务管理仍待完善

## 许可证

GPL-2.0
