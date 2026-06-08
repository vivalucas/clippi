# 当前状态

> **最后更新**：2026-06-08
> **最后更新人**：AI 开发助手
> **最近开发日志**：2026-06-08 v1.0.10 发布准备
> **当前可信度**：本轮代码已更新；本地 Rust 单测通过；macOS Debug 构建通过；Windows 完整编译仍待 GitHub Actions / .NET 环境验证

## 当前版本

<!-- 旧状态（废弃于 2026-06-04，原因：已推进到 v1.0.4 发布修复） -->
~~**V1.0.0** — 正式版发布准备中，已修复第五轮评审发现的发布包、FFI、输出路径和任务生命周期问题。~~

**V1.0.4** — 修复 macOS DMG 生成目录问题，补充输出覆盖保护、启动前校验、FFI 异步任务准备和 ffmpeg 下载校验。

**V1.0.8** — 全量评审后修复输出扩展名继承、异步导入竞态、裁剪超界进度估算、错误详情分层和处理期间参数锁定；更换 macOS AppIcon。

**V1.0.9** — 复核评审项后补充 ffprobe / GPU 探测超时、无音轨提取前置提示、Windows 启动校验状态恢复、Windows 输出目录自动避让，并同步英文 / 日文 README。

<!-- 旧状态（废弃于 2026-06-08，原因：已推进为 v1.0.10 发布） -->
~~**V1.0.9 后续质量修复** — 生成并提交 `core/Cargo.lock`，补 Rust 核心单元测试，忽略 `core/target/`，修复 macOS AppIcon 资产尺寸警告。~~

**V1.0.10** — 质量修复发布：生成并提交 `core/Cargo.lock`，补 Rust 核心单元测试，忽略 `core/target/`，修复 macOS AppIcon 资产尺寸警告，并推进 macOS / Windows / Rust 版本号。

## 当前阶段

<!-- 旧状态（废弃于 2026-06-08，原因：已补齐 Cargo.lock、Rust 单测并完成 macOS Debug 构建验证） -->
~~核心功能代码完成 v1.0.9 复核修复，等待 GitHub Actions 与真实视频样本验证。~~

<!-- 旧状态（废弃于 2026-06-08，原因：已推进版本号并准备发布 v1.0.10） -->
~~核心功能代码完成 v1.0.9 复核修复，并补齐本轮确认的构建可复现性和 Rust 核心测试；等待 Windows GitHub Actions 与真实视频样本验证。~~

核心功能代码完成 v1.0.10 质量修复并准备发布；等待 GitHub Actions 构建、Release 资产和真实视频样本验证。

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

## 进行中

- 等待 v1.0.10 GitHub Actions 构建与 Release 资产验证
- 等待真实视频样本端到端验证

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

1. 用真实视频样本做 macOS / Windows 端到端处理验证
2. 在 Windows / GitHub Actions 环境验证 publish zip 内 `clippi_core.dll`、`ffmpeg.exe`、`ffprobe.exe` 布局和运行时查找
3. 继续打磨前端视觉层级和交互状态
4. 后续如需 universal macOS 包，补 Rust 双架构构建与 `lipo` 合并

## 任务交接

**当前任务**：v1.0.10 发布准备已完成，等待 GitHub Actions / Release 验证与真实样本验证

**已完成**：阅读 project-log 与全量代码；完成全量评审；修复输出扩展名继承、异步导入竞态、裁剪超界进度估算、错误详情分层和处理期间参数锁定；更换 macOS AppIcon；复核并修复探测超时、无音轨提取提示、Windows 启动校验状态和输出目录避让；版本推进到 v1.0.9；补齐 `core/Cargo.lock`、Rust 核心单测、`core/target/` 忽略规则和 AppIcon 资产元数据修复；版本推进到 v1.0.10 并准备发布

**未完成**：真实视频样本端到端验证；本地 Windows/.NET 验证仍因本机无 `dotnet` 未运行；v1.0.10 Actions / Release 结果待确认

**下一步建议**：推送后检查 macOS / Windows Actions 结果与 Release assets；补真实视频样本验证；在 Windows 环境验证终态回调和 zip 运行时布局

**风险 / 阻塞**：本机缺 .NET；队列串行语义仍需更完整的执行模型测试；macOS 目前 CI 只构建 active architecture；Windows publish 产物布局仍需 CI / Windows 环境确认

**相关文件**：`core/Cargo.lock`, `core/src/probe.rs`, `core/src/task.rs`, `core/src/types.rs`, `.gitignore`, `macos/Clippi/Assets.xcassets/AppIcon.appiconset/Contents.json`, `windows/Clippi/ViewModels/MainViewModel.cs`, `windows/Clippi/MainWindow.xaml.cs`
