# 环境、换机与运维

> 适用状态：启用。所有命令从项目根目录执行；安装和发布不因阅读本文自动获得授权。

## 环境矩阵

| 环境 | 工具链依据 | 安装与启动入口 | 已验证范围 |
| --- | --- | --- | --- |
| macOS | Rust stable、Xcode 15+；工程部署目标 13.0 | `scripts/download_ffmpeg.sh`、`scripts/build-core.sh`、`macos/Clippi.xcodeproj` | v1.2.0 arm64 CI；2026-09-12 本地构建/UI |
| Windows | Rust stable、VS 2022、.NET 8、Windows SDK/WinUI 3 | PowerShell 脚本、`windows/Clippi/Clippi.csproj` | v1.2.0 x64 CI；最新 UI 实机仍待扩大验收 |
| Linux | 无 GUI 交付 | 仅 Rust core 可按需构建 | 未声明产品支持 |

## 首次安装

```bash
# macOS
./scripts/download_ffmpeg.sh
./scripts/build-core.sh
# 然后用 Xcode 打开 macos/Clippi.xcodeproj
```

```powershell
# Windows PowerShell
.\scripts\download_ffmpeg.ps1
.\scripts\build-core.ps1
# 然后用 Visual Studio 打开 windows/Clippi/Clippi.csproj
```

Rust 核心也可直接运行 `cargo build --manifest-path core/Cargo.toml`。不要复制另一台机器的 `core/target`、`bin/obj`、DerivedData 或已下载二进制来代替本机初始化。

## 配置

| 变量 / 配置项 | 用途 | 是否必需 | 安全示例 / 位置 |
| --- | --- | --- | --- |
| `CLIPPI_FFMPEG_DIR` | 指定包含 ffmpeg 与 ffprobe 的开发目录 | 否 | `/path/to/ffmpeg-bin` |
| UserDefaults / LocalAppData | 外观与默认导出目录 | 运行后可选 | 由应用管理，不进 Git |

媒体二进制解析顺序为：`CLIPPI_FFMPEG_DIR` → 应用包/可执行文件附近的内置目录 → 当前开发目录的 `ffmpeg/<platform>` → PATH。项目不使用 `.env`，也不需要在线 API 凭据。

## 下载与版本事实

- macOS arm64 脚本当前使用 `ffmpeg-static` 6.1.1 单二进制；x64 使用 evermeet 7.1.1 zip，各自固定 SHA256。
- Windows 脚本使用 BtbN 的 rolling `master-latest` GPL x64 包，并从同一 Release 的 checksum 文件验证下载。它不是永久固定版本；媒体行为变化时应记录实际构建来源并重跑核心冒烟。
- 版本与 URL 只以 `scripts/download_ffmpeg.*` 为准，文档不复制完整 hash。

## 换机检查

拉取当前分支后安装对应工具链，运行下载/构建脚本和 [10](10-quality.md) 的最小测试。macOS 通过不能写成 Windows 通过，CI 构建成功也不能替代目标机器的播放器、GPU 和文件选择器交互测试。
