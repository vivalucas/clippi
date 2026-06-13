# 当前状态

> **最后更新**：2026-06-13
> **最后更新人**：AI 开发助手
> **最近开发日志**：2026-06-13 第七轮代码审查修复
> **当前可信度**：本轮代码已更新；本地 Rust 单测通过；FFI 字典分发重构完成；待真实视频和纯音频样本全覆盖验证。

## 当前版本

<!-- 旧状态（废弃于 2026-06-04，原因：已推进到 v1.0.4 发布修复） -->
~~**V1.0.0** — 正式版发布准备中，已修复第五轮评审发现的发布包、FFI、输出路径和任务生命周期问题。~~

**V1.0.4** — 修复 macOS DMG 生成目录问题，补充输出覆盖保护、启动前校验、FFI 异步任务准备和 ffmpeg 下载校验。

**V1.0.8** — 全量评审后修复输出扩展名继承、异步导入竞态、裁剪超界进度估算、错误详情分层和处理期间参数锁定；更换 macOS AppIcon。

**V1.0.9** — 复核评审项后补充 ffprobe / GPU 探测超时、无音轨提取前置提示、Windows 启动校验状态恢复、Windows 输出目录自动避让，并同步英文 / 日文 README。

<!-- 旧状态（废弃于 2026-06-08，原因：已推进为 v1.0.10 发布） -->
~~**V1.0.9 后续质量修复** — 生成并提交 `core/Cargo.lock`，补 Rust 核心单元测试，忽略 `core/target/`，修复 macOS AppIcon 资产尺寸警告。~~

**V1.0.10** — 质量修复发布：生成并提交 `core/Cargo.lock`，补 Rust 核心单元测试，忽略 `core/target/`，修复 macOS AppIcon 资产尺寸警告，并推进 macOS / Windows / Rust 版本号。

**V1.0.11** (准备中) — 第七轮审查修复：重构 Swift/C# FFI 回调字典隔离并发任务，重构 `queue_tasks` 支持中途取消，取消纯视频文件限制支持音频，消除冗余 `ffprobe`，修复 Scale 音频丢失和 ETA 极值抖动，改进默认 copy 音频策略。

## 当前阶段

<!-- 旧状态（废弃于 2026-06-08，原因：已补齐 Cargo.lock、Rust 单测并完成 macOS Debug 构建验证） -->
~~核心功能代码完成 v1.0.9 复核修复，等待 GitHub Actions 与真实视频样本验证。~~

<!-- 旧状态（废弃于 2026-06-08，原因：已推进版本号并准备发布 v1.0.10） -->
~~核心功能代码完成 v1.0.9 复核修复，并补齐本轮确认的构建可复现性和 Rust 核心测试；等待 Windows GitHub Actions 与真实视频样本验证。~~

核心功能代码完成 v1.0.11 的并发回调重构与体验优化，大幅度解耦了任务分发与格式限制；等待真实媒体文件样本验证。

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
- v1.0.8 本轮修复：输出扩展名按操作选择、导入异步结果防串台、裁剪结束时间超界自动夹取、ffmpeg 原始错误详情分层复制、处理期间锁定参数控件、macOS 图标重绘
- v1.0.9 复核修复：ffprobe / GPU 探测超时、音频提取无音轨前置提示、Windows 启动校验 UI 状态恢复、Windows 输出目录选择自动避让、英文/日文 README 结构同步
- v1.0.10 质量修复：生成 `core/Cargo.lock`；新增 Rust 单元测试覆盖 JSON FFI 契约、ffmpeg 参数构建、帧率解析和 ETA / speed 解析；`.gitignore` 忽略 `core/target/`；修复 macOS AppIcon 资产元数据警告；版本号推进到 `1.0.10`
- v1.0.11 审查修复：重构 C# / Swift 两端的全局回调为字典映射机制以避免并发冲突；开放 `TASK_REGISTRY` 修复批量队列不可取消问题；支持读取并兼容纯音频文件导入；精简 `prepare_task` 内冗余执行的进程外探测；修复缩放时忽视音频编解码器的问题；优化默认 `audio_codec` 为直通策略。

## 进行中

- 等待 v1.0.11 的 GitHub Actions 构建与发布验证
- 等待真实视频及音频样本端到端验证

## 待处理

### 高优先级

<!-- 旧待办（完成于 2026-06-08，原因：已补 Rust 核心单元测试） -->
~~编写单元测试~~
- 使用真实视频样本做端到端处理验证

### 中优先级

- GPU 探测逻辑测试
<!-- 旧待办（完成于 2026-06-08，原因：已补 Rust 单测覆盖命令构建、ETA / speed 解析、帧率异常值） -->
~~ffmpeg 命令构建测试~~
~~进度解析测试~~
~~probe 帧率异常值测试~~
- Windows 终态回调流转测试

### 低优先级

- 文档完善
- 示例文件添加

## 未解决的问题 / 临时决策

| 问题 | 影响 | 状态 | 备注 |
|------|------|------|------|
| 无 Apple 开发者账号 | macOS 分发需用户手动绕过 Gatekeeper | 临时方案 | README 中提供 xattr -cr 命令 |
| ffmpeg 版本选择 | 需保持发布构建可复现 | 已固定，待 CI 持续验证 | macOS: evermeet.cx 7.1.1 zip + SHA256；Windows: BtbN autobuild-2026-06-03-14-37 + SHA256 |

## 下一步

1. 用真实视频/音频样本做 macOS / Windows 端到端处理验证
2. 在 Windows / GitHub Actions 环境验证 publish zip 内 `clippi_core.dll`、`ffmpeg.exe`、`ffprobe.exe` 布局和运行时查找
3. 验证队列 API `queue_tasks` 在未来开放 UI 时的行为
4. 继续打磨前端视觉层级和交互状态
5. 后续如需 universal macOS 包，补 Rust 双架构构建与 `lipo` 合并

## 任务交接

**当前任务**：v1.0.11 修复并发与体验断层已完成，等待真实音视频样本全覆盖验证

**已完成**：...（历史省略）；完成第七轮全量代码审查，修复多任务并发覆盖 FFI 回调漏洞；修复 `queue_tasks` 的取消注册失效；支持纯音频文件探测与处理；移除重复调用 `ffprobe` 的冗余耗时；补充 Scale 的音频编码参数；增加对抖动极低 ETA 的过滤；默认采用音频 `-c:a copy` 直通提升速度；完成各文档日志刷新。

**未完成**：本地 Windows 验证仍受限（无 .NET）；排队 `queue_tasks` 的实测联调暂无 UI 触发路径；`run_with_timeout` 可能存在的微小线程滞留未做根治（影响极小）。

**下一步建议**：通过提供各类音视频样本（尤其带多种音轨的视频和纯音频文件）实际运行界面验证；如一切顺畅则打 Tag 触发 CI 并进入 v1.0.11 发布。

**风险 / 阻塞**：队列并发任务的日志错乱和性能竞争问题由于当前 UI 仅开放单任务执行暂时延后体现；`run_with_timeout` 遗留了较少可能的悬挂线程（低频）。

**相关文件**：`core/src/ffi.rs`, `core/src/queue.rs`, `core/src/probe.rs`, `core/src/task.rs`, `macos/Clippi/FFI/ClippiFFI.swift`, `windows/Clippi/ClippiCore.cs`, `macos/Clippi/ViewModels/MainViewModel.swift`, `windows/Clippi/ViewModels/MainViewModel.cs`
