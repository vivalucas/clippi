# 项目架构

## 系统架构

采用「双原生 UI + Rust 共用核心库」架构，在保证原生体验和性能的同时，最大化复用核心逻辑代码。

```
┌──────────────────┐     ┌──────────────────┐
│  macOS UI        │     │  Windows UI      │
│  Swift + SwiftUI │     │  C# + WinUI 3    │
└────────┬─────────┘     └────────┬─────────┘
         │   FFI                  │   FFI
         ▼                        ▼
┌──────────────────────────────────────────┐
│         Rust 核心库 (.dylib / .dll)       │
│  probe / gpu / task / queue / progress   │
└────────────────────┬─────────────────────┘
                     │ 进程调用
                     ▼
              ┌──────────────┐
              │   ffmpeg     │
              │ (静态编译)    │
              └──────────────┘
```

### 分层说明

| 层级 | macOS | Windows | 说明 |
|------|-------|---------|------|
| UI 层 | Swift + SwiftUI | C# + WinUI 3 | 完全原生渲染，跟随系统主题 |
| 核心库 | Rust (.dylib) | Rust (.dll) | 逻辑共用，编译为各平台动态库 |
| 处理引擎 | ffmpeg（静态编译） | ffmpeg（静态编译） | 随应用打包，不依赖用户环境 |

## 目录结构

```
clippi/
├── core/                    # Rust 核心库
│    ├── src/
│    │    ├── probe.rs       # ffprobe 文件信息读取
│    │    ├── gpu.rs         # GPU 探测逻辑
│    │    ├── task.rs        # 任务配置与执行
│    │    ├── queue.rs       # 批量队列管理
│    │    └── progress.rs    # ffmpeg stderr 解析
│    └── Cargo.toml
├── macos/                   # Swift + SwiftUI
│    └── Clippi.xcodeproj
├── windows/                 # C# + WinUI 3
│    └── Clippi.sln
├── ffmpeg/                  # 二进制目录（不入库，.gitignore）
│    ├── macos-arm64/
│    └── windows-x64/
├── scripts/
│    ├── download_ffmpeg.sh  # macOS / Linux 下载脚本
│    └── download_ffmpeg.ps1 # Windows 下载脚本
├── docs/                    # 文档
├── project-log/             # 开发知识库
├── .github/
│    └── workflows/
│         ├── build-macos.yml
│         └── build-windows.yml
├── .gitignore
└── README.md
```

## 关键技术决策

### 决策 1：双原生 UI + Rust 核心库

- **选择**：macOS 用 SwiftUI，Windows 用 WinUI 3，共用 Rust 核心库
- **备选方案**：Electron / Tauri（跨平台单 UI 方案）
- **原因**：原生 UI 资源占用更低，体验更好；Rust 核心库最大化复用逻辑代码；AI 可承担两端 UI 的开发成本
- **参考**：详见 `10-planning-log.md` ADR-001

### 决策 2：ffmpeg 作为处理引擎

- **选择**：静态编译 ffmpeg，随应用打包
- **备选方案**：调用系统已安装的 ffmpeg
- **原因**：避免版本不一致问题，用户体验一致，无需用户额外安装
- **参考**：详见 `10-planning-log.md` ADR-002

### 决策 3：Monorepo 管理

- **选择**：单仓库管理 core + macos + windows
- **备选方案**：多仓库分离
- **原因**：保证核心库与两端 UI 版本同步，便于 AI 协作开发时获取完整上下文
- **参考**：详见 `10-planning-log.md` ADR-003

## 依赖关系

| 依赖 | 版本 | 用途 |
|------|------|------|
| ffmpeg | 固定版本（脚本中定义） | 视频处理引擎 |
| Rust | stable | 核心库开发 |
| Swift | Xcode 对应版本 | macOS UI |
| .NET / WinUI 3 | 对应版本 | Windows UI |

## 开发原则

### 性能优先

- 应用 UI 层不做任何重计算，全部交给 Rust 核心库处理
- ffmpeg 任务串行执行，避免多任务并行互相抢占 GPU/CPU 资源
- ffmpeg 参数始终传 `-threads 0`，由 ffmpeg 自动决定最优线程数
- 能用 `-c copy` 的操作绝不触发重编码

### AI 协作开发

- Monorepo 结构确保 AI 每次生成代码时能看到完整项目上下文
- Rust FFI 接口是最容易出错的环节，需人工重点审查
- 每个功能模块独立提交，便于回溯和局部重写
- 核心库接口一旦定稳，两端 UI 可并行由 AI 独立生成

### 用户体验

- 所有操作提供即时反馈，长任务必须有进度指示
- 错误信息分两层：友好提示（普通用户）+ 原始日志（技术用户）
- 普通用户看不到 ffmpeg 命令；技术用户可展开查看完整命令
- 设计语言跟随系统：macOS 遵循 Apple HIG，Windows 遵循 Fluent Design

## 变更记录

| 日期 | 变更内容 | 原因 |
|------|----------|------|
| 2025-05-14 | 初始版本，基于项目规划文档填充 | 项目初始化 |
