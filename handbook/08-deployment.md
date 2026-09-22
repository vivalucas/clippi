# 部署、发行与恢复

> 适用状态：启用。Clippi 是桌面应用，通过 GitHub Actions 和 GitHub Releases 发行，没有服务器部署。

## 触发关系

- push 到 `main`：macOS 与 Windows workflow 构建 artifact，用于主分支验证，不创建新版本。
- push `v*` tag：构建相同平台产物，创建或复用 GitHub Release 并上传资产。
- 普通提交、推送、改版本、打 tag 和发布 Release 是不同授权；不得由“同步代码”推导出版本发布。

## 产物与构建

| 平台 | 构建路径 | Release 资产 | 当前边界 |
| --- | --- | --- | --- |
| macOS arm64 | Rust release → Xcode Release → 内置 ffmpeg/ffprobe → DMG | `Clippi-macos.dmg` | 未签名/未公证，部署目标 13.0 |
| Windows x64 | Rust DLL → `dotnet publish` self-contained → 内置 ffmpeg/ffprobe → zip/Inno | Setup、Portable、zip | 未代码签名，SmartScreen 可能提示 |

Windows Portable 是自解压包装，不是真正单文件 WinUI 应用；第一次运行先解压，再从目标目录启动 `Clippi.exe`。

## 发布流程

1. 确认工作区、当前分支、upstream 和用户发布授权。
2. 从 `core/Cargo.toml`、Cargo.lock、Xcode `MARKETING_VERSION`、Windows csproj/manifest、Inno Setup 核对同一版本。
3. 运行与改动匹配的本地测试，检查下载脚本、包内资源路径和 `git diff --check`。
4. 提交并推送当前分支；重新核对远端提交。
5. 创建同一提交的 `vX.Y.Z` tag 并推送。
6. 等待两个 tag workflow 完成；检查 Release 非 draft/prerelease，四项预期资产存在且体积合理。
7. 能访问目标系统时安装或解压运行，验证 ffmpeg/ffprobe 无外部环境也可被找到。

## 回滚与恢复

- 用户可从 GitHub Releases 安装旧版本；应用无数据库迁移，回滚主要风险是本地偏好格式兼容。
- 不建议删除并复用已经公开的 tag/Release。发布错误时优先修复并发布新补丁版本；确需撤回必须由用户明确授权。
- “有 Release 资产”不等于安装和运行已验证；结果需在 [01](01-current-status.md) 明确区分 CI、安装包检查和实机验收。

## 当前发行基线

`v1.2.0`（提交 `47e5b9f`）已在 2026-09-12 完成双平台 main/tag Actions 并发布四项资产。最新 Windows 交互与复杂真实素材仍在 [01](01-current-status.md) 的验收缺口中。
