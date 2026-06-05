# API 设计

> 本项目不提供 REST API 接口，此文件记录 Rust 核心库的 FFI 接口定义。
> 两端 UI（macOS SwiftUI / Windows WinUI 3）均通过 FFI 调用这些函数。

## Rust 核心库 FFI 接口

### 接口概览

| 函数 | 说明 |
|------|------|
| `probe_file(path: &str) -> FileInfo` | 读取文件元信息（分辨率、时长、编码、帧率、码率、音频流状态） |
| `detect_gpu() -> GpuCapability` | 探测当前系统 GPU 硬件加速能力 |
| `run_task(task: TaskConfig, callback: ProgressFn) -> TaskHandle` | 执行单个 ffmpeg 任务 |
| `cancel_task(task_id: u64)` | 取消正在执行的任务 |
| `queue_tasks(tasks: Vec<TaskConfig>) -> QueueHandle` | 批量排队执行多个任务 |

### `probe_file` — 文件信息读取

**输入**：文件路径字符串

**输出**：`FileInfo` 结构体，包含：
- 分辨率（宽 x 高）
- 时长
- 编码格式
- 帧率
- 码率
- 是否包含音频流

**底层实现**：调用 ffprobe 解析文件元信息。

### `detect_gpu` — GPU 探测

**输入**：无

**输出**：`GpuCapability` 结构体，标识可用的硬件编码器

**探测逻辑**：
- Windows：h264_nvenc → h264_qsv → CPU
- macOS：hevc_videotoolbox / h264_videotoolbox → CPU

### `run_task` — 执行任务

**输入**：
- `TaskConfig`：任务配置（输入文件、输出路径、参数等）
- `ProgressFn`：进度回调函数

**输出**：`TaskHandle`，可用于取消任务

**底层实现**：根据 TaskConfig 构建 ffmpeg 命令并执行，通过解析 stderr 上报进度。

### `cancel_task` — 取消任务

**输入**：任务 ID (`u64`)

**行为**：终止对应 ffmpeg 进程

### `queue_tasks` — 批量队列

**输入**：任务列表 `Vec<TaskConfig>`

**输出**：`QueueHandle`

**行为**：串行执行队列中的任务，每个任务独立回调进度。

---

## 变更记录

| 日期 | 变更内容 | 原因 |
|------|----------|------|
| 2026-06-05 | `FileInfo` 增加 `has_audio` 字段 | UI 需要在提取音频前提示无音轨视频 |
| 2025-05-14 | 初始版本，记录 Rust FFI 接口定义 | 项目初始化 |
