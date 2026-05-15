# 项目概述

## 项目名称

Clippi — 图形化视频处理工具

## 项目背景

Clippi 是一款跨平台、原生图形界面的视频处理工具，以 ffmpeg 为处理引擎，对普通用户隐藏命令行复杂度，同时为技术用户保留完整的控制能力。

核心目标：
- 让普通用户无需了解 ffmpeg 即可完成常见视频处理任务
- 让技术用户通过 GUI 快速构建 ffmpeg 命令，并可查看原始日志
- 最大化利用硬件资源（GPU 硬件加速、多核 CPU）
- 应用本身轻量，内存与 CPU 占用极低

## 用户 / 使用场景

- 普通用户：需要裁剪视频、转换格式、提取音频等常见操作，不想学习命令行
- 技术用户：熟悉 ffmpeg，希望通过 GUI 加速工作流，同时保留查看原始命令和日志的能力

## 产品定位

| 维度 | 定位 |
|------|------|
| 目标用户 | 技术用户 + 普通用户（兼顾） |
| 竞品参考 | HandBrake（功能参考）、Permute（体验参考） |
| 设计风格 | 简洁优雅，工具感强，避免臃肿 |
| 开源协议 | GPL-2.0（与 ffmpeg 兼容） |
| 初始版本 | 0.0.1 |

## 平台支持

### 主力支持平台

| 平台 | 架构 | 系统版本 | UI 框架 | GPU 加速 |
|------|------|----------|---------|----------|
| macOS | Apple Silicon (ARM64) | macOS 26 Tahoe+ | Swift + SwiftUI | VideoToolbox |
| Windows | x86_64 | Windows 11 / 10 | C# + WinUI 3 | NVENC / QSV |

### 兼容支持平台（低额外成本）

| 平台 | 额外开发成本 | 说明 |
|------|-------------|------|
| Windows 10 x64 | 几乎零成本 | 与 Win11 同一套代码，API 全兼容 |
| macOS Intel (x86_64) | 极低 | 额外打一个 x86_64 构建包即可 |
| Linux x64 | 低 | Rust 核心库原生支持，UI 需适配 |

## 核心功能

1. 文件导入（拖拽/选择，自动读取媒体信息）
2. 视频裁剪（快速模式 -c copy / 精确模式重编码）
3. 格式转换（mp4 / mkv / mov / webm）
4. 分辨率缩放（预设 + 自定义）
5. 音频处理（提取音频 / 去除音频）
6. GPU 硬件加速（自动探测，优先使用）
7. 批量队列处理
8. 实时进度显示

详细功能设计见 `01-function-design.md`。

## 核心概念

不适用，原因：暂无特殊领域概念。项目围绕 ffmpeg 命令构建，核心概念即 ffmpeg 的编解码参数。

## 技术选型依据

| 决策项 | 选择 | 原因 |
|--------|------|------|
| macOS UI | SwiftUI | Apple 现代框架，AI 代码生成质量高，声明式语法 |
| Windows UI | WinUI 3 + Fluent Design | Win11 原生风格，微软主推方向 |
| 核心逻辑 | Rust | 零运行时开销，内存安全，跨平台编译 |
| 不选 Tauri/Electron | — | 原生 UI 资源占用更低，体验更好，AI 可承担开发成本 |

## 技术栈

| 层级 | 技术 | 说明 |
|------|------|------|
| macOS UI | Swift + SwiftUI | Apple 原生框架，macOS 26 Tahoe+ |
| Windows UI | C# + WinUI 3 | Windows 11 原生风格，Fluent Design |
| 核心库 | Rust | 跨平台共用逻辑，编译为 .dylib / .dll |
| 处理引擎 | ffmpeg（静态编译） | 随应用打包，不依赖用户环境 |
| GPU 加速 | VideoToolbox (macOS) / NVENC + QSV (Windows) | 启动时自动探测 |
| 构建 | GitHub Actions | tag 触发自动构建双平台 |
| 分发 | GitHub Releases | .dmg (macOS) / .exe (Windows) |

## 项目边界

- 不包含：在线视频处理（纯本地桌面应用）
- 不包含：视频编辑功能（时间线、特效、多轨等，定位是处理工具而非编辑器）
- 不包含：Linux GUI 支持（初期仅 macOS + Windows，Linux 后期低成本兼容）
- 不包含：用户账号系统、云同步等在线功能

## 项目约束

- 采用「双原生 UI + Rust 共用核心库」架构，不做 Electron / Tauri
- ffmpeg 二进制不入库，随应用打包分发
- GPL-2.0 协议，与 ffmpeg 兼容
- macOS 暂无 Apple 开发者账号，需用户手动绕过 Gatekeeper
- ffmpeg 任务串行执行，避免多任务并行抢占 GPU/CPU 资源
