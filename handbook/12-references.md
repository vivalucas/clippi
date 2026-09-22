# 外部服务与参考资料

> 适用状态：启用。Clippi 不依赖在线业务 API，外部依赖是媒体工具、平台框架和发行服务。

## 来源索引

| 服务 / 资料 | 官方来源或原件位置 | 本项目用途 | 版本 / 核对方式 | 实现入口 |
| --- | --- | --- | --- | --- |
| FFmpeg / ffprobe | <https://ffmpeg.org/documentation.html> | 探测、转码、滤镜、进度 | 实际二进制由下载脚本决定 | `core/src/`、`scripts/download_ffmpeg.*` |
| eugeneware ffmpeg-static | GitHub Releases | macOS arm64 二进制 | 脚本固定 6.1.1 + SHA256 | `scripts/download_ffmpeg.sh` |
| evermeet | <https://evermeet.cx/ffmpeg/> | macOS x64 二进制 | 脚本固定 7.1.1 + SHA256 | `scripts/download_ffmpeg.sh` |
| BtbN FFmpeg Builds | GitHub Releases | Windows x64 GPL 构建 | rolling latest + 官方 checksum | `scripts/download_ffmpeg.ps1` |
| Apple SwiftUI / AVKit | Apple Developer Documentation | macOS UI 和播放器 | 随 Xcode / 部署目标 | `macos/` |
| Windows App SDK / WinUI 3 | Microsoft Learn / NuGet | Windows UI 和播放器 | csproj 固定包版本 | `windows/` |
| GitHub Actions / Releases | workflow 与仓库 Release | 构建、artifact、正式资产 | 以 workflow 和实际 run 为准 | `.github/workflows/` |

## 采用边界

- FFmpeg 参数和容器兼容规则只在核心实现维护；本文不复制完整命令手册。
- 下载源、版本、checksum 和归档布局变化时先更新脚本并验证，再更新本索引；缓存文档不代表上游最新状态。
- 不把 GitHub、Apple 或 Microsoft 账号凭据写入仓库。引入签名时只记录证书/secret 变量名和配置位置，不记录真实材料。
