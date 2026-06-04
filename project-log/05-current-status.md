# 当前状态

> **最后更新**：2026-06-04
> **最后更新人**：AI 开发助手
> **最近开发日志**：2026-06-04 v1.0.7 全量评审修复、图标更新与体验打磨
> **当前可信度**：本轮代码已更新；本地完成 Swift 类型检查、Xcode 工程解析、脚本语法和 diff 检查；Rust / Windows 完整编译待 GitHub Actions 验证

## 当前版本

<!-- 旧状态（废弃于 2026-06-04，原因：已推进到 v1.0.4 发布修复） -->
~~**V1.0.0** — 正式版发布准备中，已修复第五轮评审发现的发布包、FFI、输出路径和任务生命周期问题。~~

**V1.0.4** — 修复 macOS DMG 生成目录问题，补充输出覆盖保护、启动前校验、FFI 异步任务准备和 ffmpeg 下载校验。

**V1.0.7** — 全量评审后修复输出扩展名继承、异步导入竞态、裁剪超界进度估算、错误详情分层和处理期间参数锁定；更换 macOS AppIcon。

## 当前阶段

核心功能代码完成 v1.0.7 稳定性和体验修复，等待 GitHub Actions 与真实视频样本验证。

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
- v1.0.4 本轮修复：macOS DMG `dist/` 目录缺失、输出文件防覆盖、启动前路径/裁剪校验、任务准备异步化、下载脚本 SHA256 校验
- v1.0.7 本轮修复：输出扩展名按操作选择、导入异步结果防串台、裁剪结束时间超界自动夹取、ffmpeg 原始错误详情分层复制、处理期间锁定参数控件、macOS 图标重绘

## 进行中

- 等待 v1.0.7 GitHub Actions 构建与 Release 资产验证
- 等待真实视频样本端到端验证

## 待处理

### 高优先级

- 编写单元测试
- 使用真实视频样本做端到端处理验证

### 中优先级

- GPU 探测逻辑测试
- ffmpeg 命令构建测试
- 进度解析测试
- probe 帧率异常值测试
- Windows 终态回调流转测试

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

**当前任务**：v1.0.7 全量评审修复、提交发布并等待 CI / Release 验证

**已完成**：阅读 project-log 与全量代码；完成全量评审；修复输出扩展名继承、异步导入竞态、裁剪超界进度估算、错误详情分层和处理期间参数锁定；更换 macOS AppIcon；版本推进到 v1.0.7

**未完成**：真实视频样本端到端验证；本地 Rust/.NET 验证仍因本机无 cargo / dotnet 未运行；v1.0.7 Actions / Release 结果待确认

**下一步建议**：推送 v1.0.7 后检查 macOS / Windows Actions 结果与 Release assets；补真实视频样本验证和 Rust 单元测试

**风险 / 阻塞**：本机缺 Rust 和 .NET；队列串行语义仍需更完整的执行模型测试；macOS 目前 CI 只构建 active architecture；本地缺少 `core/target/release/libclippi_core.a` 阻塞 Xcode 最终链接；`core/Cargo.lock` 仍需在 Rust 环境生成并提交

**相关文件**：`core/src/task.rs`, `macos/Clippi/ViewModels/MainViewModel.swift`, `macos/Clippi/Views/MainView.swift`, `windows/Clippi/ViewModels/MainViewModel.cs`, `windows/Clippi/MainWindow.xaml`, `windows/Clippi/MainWindow.xaml.cs`, `macos/Clippi/Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png`
