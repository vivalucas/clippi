# 项目定义

> 状态：已初始化。当前事实以代码、清单、锁文件和发布配置为准。

## 目标与边界

- **产品**：Clippi，一款跨平台原生桌面视频处理工具，以 ffmpeg / ffprobe 为引擎，对普通用户隐藏命令行复杂度，同时保留可诊断的错误详情。
- **用户与场景**：普通用户完成裁剪、格式转换、缩放、音频处理；技术用户通过原生 GUI 加速批量素材方向校正并查看失败详情。
- **成功标准**：常见处理任务无需外部安装 ffmpeg；长任务有进度、取消和明确终态；不覆盖源文件或既有输出；macOS 与 Windows 的信息结构和行为语义一致。
- **明确不做**：云处理、账号与同步、时间线/多轨/特效型视频编辑、AI 内容方向识别、递归文件夹导入、并行运行多个 ffmpeg 任务。Linux 核心库可编译不等于提供 Linux GUI。
- **核心能力**：单文件裁剪/转换/缩放/音频处理，以及多文件旋转与镜像校正；完整功能与验收见 [02](02-function-design.md)。

## 关键术语

- **普通工具**：裁剪、转换、缩放和音频处理，目前以单文件为主。
- **素材校正**：将源方向元数据与用户旋转/镜像烘焙进画面像素，输出不再依赖旋转标签。
- **任务 / 队列**：Rust 核心执行单个 ffmpeg 进程；批量任务预先登记 ID 后串行执行。
- **源文件保护**：永不覆盖或删除源文件；输出冲突由 UI 自动避让，核心仍以 ffmpeg `-n` 做最后防线。

## 技术与平台

| 项目 | 实际选择 | 版本 / 配置依据 | 核对日期 |
| --- | --- | --- | --- |
| 核心库 | Rust 2021，`staticlib` + `cdylib` | `core/Cargo.toml`、`core/Cargo.lock`；当前版本 1.2.0 | 2026-09-22 |
| macOS UI | Swift + SwiftUI + AVKit | Xcode 工程；部署目标 macOS 13.0，Release 构建 arm64 | 2026-09-22 |
| Windows UI | C# + WinUI 3 / .NET 8 | `windows/Clippi/Clippi.csproj`；Windows 10 19041+，正式产物 x64 | 2026-09-22 |
| 媒体引擎 | 随包提供的 ffmpeg / ffprobe | `scripts/download_ffmpeg.*` 与 CI；下载后校验 SHA256 | 2026-09-22 |
| 数据 | 无数据库；少量本地偏好 | UserDefaults / LocalAppData，见 [05](05-data-design.md) | 2026-09-22 |
| 构建发行 | GitHub Actions + GitHub Releases | `.github/workflows/`；tag `v*` 发布 | 2026-09-22 |

## 长期约束

- 继续采用 SwiftUI、WinUI 3 两套原生前端和一个 Rust 核心，不改成 Electron/Tauri/Web UI。
- ffmpeg / ffprobe 二进制不入库，开发和 CI 通过脚本取得，发布产物必须内置。
- 两端共享功能语义、C ABI/JSON 契约、本地化信息结构和品牌资源，不追求控件代码或像素级一致。
- GPL-2.0 许可证保持不变；发布、签名和平台支持边界见 [08](08-deployment.md)。
