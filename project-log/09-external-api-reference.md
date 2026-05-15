# 外部服务 / API 参考

> 本项目为本地桌面应用，不依赖在线 API。主要外部依赖为 ffmpeg 命令行工具。

---

## 外部服务清单

| 服务 | 用途 | 官方文档 | 备注 |
|------|------|----------|------|
| ffmpeg | 视频处理引擎 | https://ffmpeg.org/documentation.html | 静态编译，随应用打包 |
| ffprobe | 文件元信息读取 | 同上（ffmpeg 套件的一部分） | 用于 probe_file |

---

## 服务一：ffmpeg

### 基本信息

| 项目 | 内容 |
|------|------|
| 文档地址 | https://ffmpeg.org/documentation.html |
| 类型 | 本地命令行工具（非 API） |
| 许可证 | GPL-2.0 |
| macOS 下载源 | evermeet.cx 静态编译版 |
| Windows 下载源 | BtbN/FFmpeg-Builds |
| 管理方式 | 通过 scripts/ 下载脚本管理，版本固定，校验 SHA256 |

### 核心命令

| 命令 | 说明 | 备注 |
|------|------|------|
| `ffmpeg` | 视频处理主程序 | 所有转码、裁剪、格式转换等操作 |
| `ffprobe` | 文件信息读取 | 解析分辨率、时长、编码、帧率、码率 |

### 常用参数参考

| 参数 | 说明 |
|------|------|
| `-i INPUT` | 输入文件 |
| `-ss START` | 起始时间 |
| `-to END` | 结束时间 |
| `-c copy` | 直接复制流（快速模式，不重编码） |
| `-c:v ENCODER` | 指定视频编码器（如 h264_nvenc, hevc_videotoolbox） |
| `-c:a ENCODER` | 指定音频编码器 |
| `-vf scale=W:H` | 分辨率缩放 |
| `-an` | 去除音频 |
| `-vn` | 去除视频 |
| `-hwaccel TYPE` | 启用硬件加速解码 |
| `-threads 0` | 由 ffmpeg 自动决定最优线程数 |
| `-progress pipe:1` | 输出进度信息到 stdout |

### GPU 编码器

| 平台 | 编码器 | 优先级 |
|------|--------|--------|
| Windows (NVIDIA) | h264_nvenc | 1 |
| Windows (Intel) | h264_qsv | 2 |
| macOS | hevc_videotoolbox / h264_videotoolbox | 1 |
| 回退 | libx264 / libx265 | 最低 |

### 进度解析

ffmpeg 使用 `-progress pipe:1` 时输出结构化进度信息，关键字段：

- `out_time_us=` — 已处理时间（微秒）
- `speed=` — 处理速度倍率
- `progress=` — 状态（continue / end）

Rust 核心库的 `progress.rs` 负责解析这些字段，计算百分比和 ETA。

### ffmpeg 管理策略

- ffmpeg 二进制不入库，加入 `.gitignore`
- 开发环境：首次 clone 后运行 `scripts/download_ffmpeg.sh`（macOS）或 `.ps1`（Windows）
- 下载来源：Windows 使用 BtbN/FFmpeg-Builds，macOS 使用 evermeet.cx 静态编译版
- 版本固定在脚本中，校验 SHA256 hash 后解压
- CI/CD 构建时同样自动下载，打包进最终安装包
- ffmpeg 升级随软件版本一起发布，在 CHANGELOG 中注明

### 已知问题 / 踩坑记录

| 日期 | 问题 | 解决方案 |
|------|------|----------|
| — | — | 暂无 |

---

## 变更记录

| 日期 | 变更内容 | 原因 |
|------|----------|------|
| 2025-05-14 | 初始版本，记录 ffmpeg 依赖信息 | 项目初始化 |
