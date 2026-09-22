# 架构约定

> 适用状态：启用。Clippi 是双原生前端共享 Rust 核心的 monorepo。

## 系统边界

```text
macOS SwiftUI ── C ABI / UTF-8 JSON ─┐
                                     ├─ Rust core ── child process ── ffmpeg / ffprobe
Windows WinUI 3 ─ C ABI / UTF-8 JSON ┘
```

| 模块 / 目录 | 职责 | 依赖方向 | 不承担什么 |
| --- | --- | --- | --- |
| `core/` | 探测、GPU、命令构建、执行、进度、取消、串行队列、C ABI | 只依赖媒体二进制和 Rust crates | 不维护 UI、用户偏好或平台文件选择器 |
| `macos/` | SwiftUI 界面、AVKit 预览、UserDefaults、Swift FFI 封装 | 调用 core C ABI | 不独立重写 ffmpeg 业务规则 |
| `windows/` | WinUI 3 界面、MediaPlayerElement、LocalAppData、C# P/Invoke | 调用 core C ABI | 不独立维护另一套任务引擎 |
| `scripts/` | 下载媒体二进制、构建核心、回归脚本 | 供开发和 CI 调用 | 不作为运行时业务模块 |
| `.github/workflows/` / `installer/` | 双平台构建、打包、Release 上传 | 依赖各平台工具链 | 不代表生产服务器部署 |

## Rust 核心分工

- `types.rs`：FileInfo、TaskConfig、Operation、Progress 和队列句柄，是 JSON 契约源头。
- `probe.rs`：调用 ffprobe，20 秒超时，解析媒体流、帧率、方向和 HDR 标记。
- `gpu.rs`：按平台探测编码器，单次编码器测试 8 秒超时。
- `task.rs`：校验配置、构建参数、启动/取消 ffmpeg、解析 `-progress pipe:1`。
- `queue.rs`：预注册任务 ID 与取消通道，在单一后台线程串行准备和执行。
- `preview.rs`：原生播放器失败时生成最大 1280×720 的首帧 JPEG。
- `binaries.rs`：`CLIPPI_FFMPEG_DIR` → 应用内置/开发目录 → PATH 的解析顺序。
- `ffi.rs`：C ABI、UTF-8 字符串所有权、任务注册表和回调桥接。

## 关键路径

1. UI 导入路径并异步调用 `clippi_probe_file`；只接受最新请求结果。
2. UI 根据媒体能力构造 TaskConfig JSON；Rust 校验路径、操作、尺寸/时间和输出冲突。
3. 单任务立即返回 task ID，队列一次返回全部 ID；准备与 ffmpeg 执行在后台进行。
4. Rust 将带 task ID 的 JSON 进度回调给 Swift/C#；UI 以 `state` 驱动终态并隔离旧回调。
5. 取消通过全局任务注册表发送信号；核心杀死并等待子进程，回调 cancelled，随后清理句柄。

## 公共约束

- C ABI 回调必须是稳定静态 thunk，Swift/C# 用 task ID 字典分发，不能用会互相覆盖的单一全局闭包。
- Windows 与 macOS 的业务规则变化应先落在 Rust 或共享契约；平台层只处理原生 UI、文件系统和播放器差异。
- 可生成的目录树、完整字段与依赖版本不在本文手抄；以代码、清单和锁文件为准。
