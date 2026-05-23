# 环境配置

## 环境要求

### macOS 开发环境

| 项目 | 版本 | 说明 |
|------|------|------|
| macOS | 26 Tahoe+ | 目标运行平台 |
| Xcode | 最新稳定版 | SwiftUI 开发 |
| Rust | stable | 核心库编译 |
| Swift | Xcode 对应版本 | macOS UI |

### Windows 开发环境

| 项目 | 版本 | 说明 |
|------|------|------|
| Windows | 10 / 11 x64 | 目标运行平台 |
| Visual Studio | 2022+ | WinUI 3 开发 |
| .NET | 对应版本 | WinUI 3 依赖 |
| Rust | stable | 核心库编译 |

### ffmpeg

| 项目 | 说明 |
|------|------|
| 来源 (macOS) | evermeet.cx 静态编译版 |
| 来源 (Windows) | BtbN/FFmpeg-Builds |
| 管理方式 | 不入库，通过 scripts/ 脚本下载 |
| 版本 | 固定在下载脚本中，校验 SHA256 |

## 环境变量

本项目为桌面应用，无需 `.env` 文件或环境变量配置。

所有配置通过 Rust 核心库的 TaskConfig 结构体在运行时传入。

## 第三方服务

| 服务 | 用途 | 配置方式 |
|------|------|----------|
| ffmpeg | 视频处理引擎 | 通过 scripts/ 脚本下载，随应用打包 |
| GitHub Actions | CI/CD 构建 | .github/workflows/ 配置 |

## 本地开发配置

```bash
# 1. 克隆项目
git clone <repo-url> clippi
cd clippi

# 2. 下载 ffmpeg（首次 clone 后执行）
# macOS:
bash scripts/download_ffmpeg.sh
# Windows (PowerShell):
# .\scripts\download_ffmpeg.ps1

# 3. 编译 Rust 核心库
cd core
cargo build

# 4. 打开对应平台项目
# macOS: 用 Xcode 打开 macos/Clippi.xcodeproj
# Windows: 用 Visual Studio 打开 windows/Clippi/Clippi.csproj

# 5. 运行
```

## 变更记录

| 日期 | 变更内容 | 原因 |
|------|----------|------|
| 2025-05-14 | 初始版本，基于项目规划文档填充 | 项目初始化 |
