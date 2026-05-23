# 部署

> Clippi 是桌面应用，通过 GitHub Releases 分发。无服务器部署。

## 部署环境

| 环境 | 用途 | 说明 |
|------|------|------|
| 本地开发 | 开发调试 | 各平台本地构建运行 |
| GitHub Release | 正式分发 | 推送 tag 触发自动构建并发布 |

## 构建与发布流程

### 触发方式

推送 git tag（格式 `v*.*.*`）自动触发 GitHub Actions 构建流水线，同时构建 macOS 和 Windows 两个平台。

### 构建流程

| 步骤 | macOS | Windows |
|------|-------|---------|
| 1 | checkout 代码 | checkout 代码 |
| 2 | 运行 `download_ffmpeg.sh` | 运行 `download_ffmpeg.ps1` |
| 3 | 编译 Rust 核心库 (.dylib) | 编译 Rust 核心库 (.dll) |
| 4 | xcodebuild 打包 | MSBuild 打包 |
| 5 | 生成 .dmg | 生成 .exe 安装包 |
| 6 | 上传到 GitHub Release | 上传到 GitHub Release |

### CI/CD

- GitHub Actions 配置文件：`.github/workflows/build-macos.yml` 和 `.github/workflows/build-windows.yml`
- 推送 `v*.*.*` 格式的 tag 自动触发

### 分发方式

| 平台 | 格式 | 分发渠道 | 备注 |
|------|------|----------|------|
| macOS | .dmg | GitHub Releases | README 提供绕过 Gatekeeper 的命令 |
| Windows | .exe | GitHub Releases + Microsoft Store（后期） | Store 版需额外签名配置 |

### macOS Gatekeeper 说明

由于暂无 Apple 开发者账号，用户下载后需在终端执行以下命令以绕过 Gatekeeper 限制：

```bash
xattr -cr /Applications/Clippi.app
```

该命令已写入 README 安装说明中。

### 回滚方案

- GitHub Releases 保留所有历史版本，用户可手动下载旧版本安装
- 如需回滚发布：删除对应 tag 和 Release，修复后重新发布

## 版本路线图

| 版本 | 里程碑 | 主要内容 |
|------|--------|----------|
| 0.0.1 | 项目骨架 | 仓库结构、Rust 核心库接口定义、CI/CD 流水线搭建 |
| 0.0.2 | 核心链路 | 拖入文件 → 调用 ffmpeg → 输出，GPU 探测，进度条 |
| 0.0.3 | 基础功能 | 裁剪、格式转换、分辨率缩放、提取/去除音频 |
| 0.0.4 | 批量队列 | 多文件排队处理，任务管理 UI |
| 0.0.5 | 体验打磨 | 错误提示、预估文件大小、中英文切换 |
| 0.1.0 | MVP 完整版 | 全部 MVP 功能稳定，发布第一个对外版本 |
| 0.2.0 | 二期启动 | 时间轴预览、GIF 转换、字幕水印 |
| 0.5.0 | 功能完整 | 二期全部功能，Windows 商店上架准备 |
| 1.0.0 | 正式版 | 三期功能，全平台稳定 |

## 变更记录

| 日期 | 变更内容 | 原因 |
|------|----------|------|
| 2025-05-14 | 初始版本，基于项目规划文档填充 | 项目初始化 |
