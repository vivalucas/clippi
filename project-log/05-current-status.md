# 当前状态

> **最后更新**：2026-09-05
> **最后更新人**：AI 开发助手
> **最近开发日志**：2026-09-05 v1.1.0 素材校正工作区
> **当前可信度**：Rust 核心严格静态检查、测试和 Release 构建通过；Windows x64 Debug/Release 构建及隐藏启动冒烟通过；含 display matrix 的合成视频变换验证通过；待 macOS 26 arm64 CI 与真实素材双端验收。

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

**V1.1.0** (发布中) — 新增素材校正工作区：多文件/当前层文件夹导入、视频预览、逐条与批量旋转镜像、串行队列、安全输出，以及 macOS 26 arm64 明确构建目标。发布标签 `v1.1.0` 触发双平台构建。

## 当前阶段

<!-- 旧状态（废弃于 2026-06-08，原因：已补齐 Cargo.lock、Rust 单测并完成 macOS Debug 构建验证） -->
~~核心功能代码完成 v1.0.9 复核修复，等待 GitHub Actions 与真实视频样本验证。~~

<!-- 旧状态（废弃于 2026-06-08，原因：已推进版本号并准备发布 v1.0.10） -->
~~核心功能代码完成 v1.0.9 复核修复，并补齐本轮确认的构建可复现性和 Rust 核心测试；等待 Windows GitHub Actions 与真实视频样本验证。~~

<!-- 旧状态（废弃于 2026-09-05，原因：已进入 v1.1.0 素材校正开发） -->
~~核心功能代码完成 v1.0.11 的并发回调重构与体验优化，大幅度解耦了任务分发与格式限制；等待真实媒体文件样本验证。~~

v1.1.0 素材校正核心、Windows/macOS 页面和发布配置已实现并进入标签发布；当前等待双平台 CI 产物与真实素材端到端验收。

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
- v1.1.0 素材校正：双端统一工作区、AVKit/MediaPlayerElement 播放预览、五种方向操作、逐条/勾选/全部应用、队列进度和安全输出。
- Rust 核心新增方向元数据探测与可组合 `Transform` 操作，输出清理旋转标签。
- `Transform` 对 WebM 输出统一回退到容器兼容编码，避免双端各自维护格式特例。
- macOS CI 固定 `macos-26` arm64，并校验随包 ffmpeg/ffprobe 包含 arm64。
- 全面复核修复：队列任务 ID 即时返回且准备阶段可取消、完成项不重复执行、导入防并发、处理期间界面锁定、失败详情可查看、Windows 页签入口与最小尺寸统一。
- 统一素材校正输出策略：MP4 容器；SDR 使用 H.264，HDR 使用 HEVC；映射全部音轨并转 AAC 192 kbps；原生播放器失败时使用内置 ffmpeg 首帧兜底。
- 带 90° display matrix 的合成 MP4 已验证标准化方向并清除方向标签；补充组合变换样本验证为 320×240、两个 AAC 音轨均保留，兜底 JPEG 可生成；Rust 18 项测试、严格 Clippy、Release 构建及 Windows x64 Debug/Release 均通过。
- Windows 应用已完成隐藏启动冒烟测试，进程稳定运行后由测试脚本正常结束。

## 进行中

- 等待 `v1.1.0` 标签触发的 Windows 与 macOS 26 arm64 GitHub Actions 构建验证
- 等待真实手机素材在 Windows 与 macOS 上完成预览、组合变换和队列取消验收

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

1. 在 GitHub Actions 运行 macOS 26 arm64 构建，修正可能出现的 Swift/Xcode 编译问题。
2. 用真实手机 MOV/MP4 和不同音轨素材做双端端到端验收（合成 display matrix 样本已通过核心链路）。
3. 用交互式人工测试验证双端队列停止全部、单项失败继续、统一输出目录同名避让和预览视觉一致性。
4. 验证 Windows/macOS 安装产物均内置 ffmpeg/ffprobe，干净机器无需外部环境。

## 任务交接

<!-- 旧交接（废弃于 2026-09-05，原因：任务已推进到 v1.1.0） -->
~~**当前任务**：v1.0.11 修复并发与体验断层已完成，等待真实音视频样本全覆盖验证~~

**当前任务**：v1.1.0 素材校正工作区及全面复核修复已完成本地实现和 Windows 验证，等待 macOS CI 与真实素材验收。

**已完成**：...（历史省略）；完成第七轮全量代码审查，修复多任务并发覆盖 FFI 回调漏洞；修复 `queue_tasks` 的取消注册失效；支持纯音频文件探测与处理；移除重复调用 `ffprobe` 的冗余耗时；补充 Scale 的音频编码参数；增加对抖动极低 ETA 的过滤；默认采用音频 `-c:a copy` 直通提升速度；完成各文档日志刷新。

**未完成**：当前机器无法运行 Xcode；当前可用自动化接口不支持 Windows 原生应用视觉检查，未取得真实窗口截图；尚未使用用户实际素材验证。

**下一步建议**：先跑 macOS 26 arm64 CI，再以真实 MP4/MOV 覆盖 90°/180°、双向镜像、组合操作和批量取消。

**风险 / 阻塞**：队列并发任务的日志错乱和性能竞争问题由于当前 UI 仅开放单任务执行暂时延后体现；`run_with_timeout` 遗留了较少可能的悬挂线程（低频）。

**相关文件**：`project-log/12-material-correction-design.md`, `core/src/types.rs`, `core/src/probe.rs`, `core/src/task.rs`, `macos/Clippi/Views/MainView.swift`, `macos/Clippi/ViewModels/MainViewModel.swift`, `windows/Clippi/MainWindow.xaml`, `windows/Clippi/ViewModels/MainViewModel.cs`
