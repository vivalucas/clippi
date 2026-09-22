# 接口约定

> 适用状态：启用。项目没有 HTTP API；唯一跨语言接口是 Rust C ABI，载荷为 UTF-8 JSON。

## 契约入口

- Rust 导出：`core/src/ffi.rs`；数据结构：`core/src/types.rs`。
- C 头：`macos/Clippi/ClippiCore.h`。
- Swift 封装：`macos/Clippi/FFI/ClippiFFI.swift`。
- C# P/Invoke：`windows/Clippi/ClippiCore.cs`。
- JSON enum：Operation 使用 serde 外部标签；OutputFormat / AudioFormat 使用小写字符串。

| 能力 / C ABI | 输入与返回 | 调用方 | 当前状态 |
| --- | --- | --- | --- |
| `clippi_probe_file` | UTF-8 路径 → FileInfo JSON / error JSON | Swift、C# | 启用 |
| `clippi_detect_gpu` | 无 → GpuCapability JSON | Swift、C# | 启用 |
| `clippi_generate_preview_image` | 源路径、JPEG 路径 → 状态 | Swift、C# | 启用 |
| `clippi_run_task` | TaskConfig JSON + callback → task ID | Swift、C# | 启用 |
| `clippi_cancel_task` | task ID → 0/1 | Swift、C# | 启用 |
| `clippi_queue_tasks` | TaskConfig 数组 + callback → task ID 数组 JSON | 校正工作区 | 启用，串行 |
| `clippi_free_string` | Rust 分配的 C 字符串 | Swift、C# | 必须调用 |

## 核心数据语义

- FileInfo：宽高、时长、编码、帧率、码率、是否有音频、像素格式、色彩传递、HDR 标记、标准化方向。
- TaskConfig：输入/输出路径、Operation、可选 video/audio codec 与 hw_accel。
- Progress：`task_id`、0–100 百分比、speed、可选 ETA、`state`、可选 message。
- 终态只有 `completed`、`failed`、`cancelled`；前端不能用 percent == 100 替代终态。
- Rust 字符串由 Rust 分配并用 `clippi_free_string` 回收；Windows 必须显式 UTF-8 marshalling，Swift 的 C 回调不能捕获上下文。

## 兼容与变更

- 增加字段时给读取方兼容默认值；重命名 enum、改变大小写或表示法属于破坏性变更，必须同步 Rust 单测、Swift、C# 与真实 FFI 冒烟。
- task ID 回调映射须在调用队列后立即登记返回 ID，并处理回调早于前端登记的情况。
- 新增 UI 不自动意味着新增 C ABI；能用现有 TaskConfig 表达时优先复用。
- 没有认证、分页或网络版本号。契约测试入口见 [10](10-quality.md)。
