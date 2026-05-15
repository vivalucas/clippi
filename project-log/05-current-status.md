# 当前状态

> **最后更新**：2026-05-15
> **最后更新人**：AI 开发助手
> **最近开发日志**：2026-05-15 修复构建链路与 FFI 回调
> **当前可信度**：GitHub Actions macOS / Windows 构建已通过

## 当前版本

**V0.0.3** — 核心功能开发完成，macOS / Windows CI 构建已通过。

## 当前阶段

核心功能代码已完成构建链路修复。GitHub Actions 已在 `main` push 上自动触发，并通过 macOS / Windows 构建。

## 已完成

- 项目规划文档编写完成
- 技术架构确定（双原生 UI + Rust 核心库）
- 功能设计文档编写完成
- 开发知识库（project-log）搭建完成
- Monorepo 目录结构搭建
- Rust 核心库项目初始化（Cargo.toml + 模块定义）
- Rust 核心库 FFI 接口实现（probe_file、detect_gpu、run_task、cancel_task、queue_tasks）
- ffmpeg 下载脚本编写（download_ffmpeg.sh / download_ffmpeg.ps1）
- GitHub Actions CI/CD 流水线配置
- macOS SwiftUI 完整实现（ViewModel、Views、FFI 封装）
- Windows WinUI 3 完整实现（ViewModel、MainWindow）
- macOS Xcode target 已接入实际 MainView / MainViewModel / FFI 文件
- Swift / C# FFI 进度回调已从空指针或捕获型 C 回调改为稳定桥接
- Rust 进度解析改为使用 `-progress pipe:1`
- GitHub Actions Build macOS 通过：https://github.com/vivalucas/clippi/actions/runs/25906172242
- GitHub Actions Build Windows 通过：https://github.com/vivalucas/clippi/actions/runs/25906172219
- README 编写
- .gitignore 配置
- GPL-2.0 开源协议

## 进行中

- 等待后续功能测试与真实视频样本验证

## 待处理

### 高优先级

- 编写单元测试
- 使用真实视频样本做端到端处理验证

### 中优先级

- GPU 探测逻辑测试
- ffmpeg 命令构建测试
- 进度解析测试

### 低优先级

- 文档完善
- 示例文件添加

## 未解决的问题 / 临时决策

| 问题 | 影响 | 状态 | 备注 |
|------|------|------|------|
| 无 Apple 开发者账号 | macOS 分发需用户手动绕过 Gatekeeper | 临时方案 | README 中提供 xattr -cr 命令 |
| ffmpeg 版本选择 | 需确定具体版本号和下载源 | 待确定 | macOS: evermeet.cx, Windows: BtbN/FFmpeg-Builds |

## 下一步

1. 补 Rust 核心库单元测试，尤其是 ffmpeg 参数构建、进度解析和 JSON FFI 兼容性
2. 用真实视频样本做 macOS / Windows 端到端处理验证
3. 继续打磨前端视觉层级和交互状态
4. 后续如需 universal macOS 包，补 Rust 双架构构建与 `lipo` 合并

## 任务交接

**当前任务**：构建失败排查与修复（已完成）

**已完成**：阅读 project-log 与代码；修复 Rust 进度回调、serde 枚举兼容、macOS Xcode target 文件接入、Swift/C# FFI 回调、Windows XAML / WinUI API 问题、CI 构建参数、cc-mimo 第三轮评审确认项；macOS / Windows Actions 已通过

**未完成**：真实视频样本端到端验证；本地 Rust/.NET 验证仍因本机无 cargo / dotnet 未运行

**下一步建议**：补单元测试和样本验证；如继续 UI 打磨，先对照 `11-code-review-log.md` 的构建失败复盘清单

**风险 / 阻塞**：本机缺 Rust 和 .NET；队列串行语义仍需更完整的执行模型测试；macOS 目前 CI 只构建 active architecture

**相关文件**：`core/src/task.rs`, `core/src/types.rs`, `macos/Clippi.xcodeproj/project.pbxproj`, `macos/Clippi/FFI/ClippiFFI.swift`, `windows/Clippi/ClippiCore.cs`, `windows/Clippi/MainWindow.xaml`
