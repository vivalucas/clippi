# 代码评审记录

<!-- 填写说明：项目基本开发完成后，由不同的人/AI 接力进行多轮独立评审。
每一棒做两件事：① 独立验证上一棒的发现，② 做自己的全量评审。 -->

## 评审流程

```
A 评审（发现） → B 验证 + 修复确认项 + 评审（发现）
→ C 验证 + 修复确认项 + 评审（发现）
→ D ... → 直到无新问题
```

每一步的验证必须独立——不能直接采信上一棒的结论，要自己读代码、跑测试来判断。

确认的 bug 修复后，对应的 `06-dev-log.md` 记录修复内容。

---

## 评审概览

| 棒次 | 评审人 | 日期 | 发现问题数 | 其中被下一棒确认 |
|------|--------|------|-----------|-----------------|
| 1 | A: | | | — |
| 2 | AI 开发助手 | 2026-05-15 | 13 | C 轮全部确认已修复 |
| 3 | cc-mimo | 2026-05-15 | 4 | D 轮确认 3 个成立、1 个不成立 |
| 4 | AI 开发助手 | 2026-05-15 | 0 | — |

## 构建失败复盘 / 下次检查清单

本轮最终通过 GitHub Actions：
- Build macOS: https://github.com/vivalucas/clippi/actions/runs/25876679883
- Build Windows: https://github.com/vivalucas/clippi/actions/runs/25876679842

下次改动前优先检查：

1. Rust 核心库
   - 如果回调需要被多个任务复用，不要用不可克隆的 `Box<dyn Fn>`；优先用 `Arc<dyn Fn + Send + Sync>`。
   - ffmpeg 结构化进度必须显式加 `-progress pipe:1`，并从 stdout 读取；普通 stderr 日志不等价于 progress 格式。
   - 前端传 JSON 到 serde enum 时，要确认大小写和 enum 表示法一致，例如 `mp4` 需要 `#[serde(rename_all = "lowercase")]`。

2. macOS / SwiftUI
   - 新增 Swift 文件后必须确认 `macos/Clippi.xcodeproj/project.pbxproj` 的 PBXSourcesBuildPhase 已包含这些文件；文件存在不代表会被 Xcode 编译。
   - Swift 的 `@convention(c)` 函数指针不能捕获上下文；FFI 回调要使用静态 thunk + 静态存储的 Swift callback。
   - CI 中 Rust 静态库只构建当前 runner 架构时，Xcode 不能同时构建 x86_64 + arm64；否则会出现某个架构找不到 `_clippi_*` 符号。本轮选择 `ONLY_ACTIVE_ARCH=YES`。

3. Windows / WinUI 3
   - 不要把 WPF/UWP 经验直接套到 WinUI 3：`Window` 根节点不支持 `Width/Height/MinWidth/MinHeight`，窗口尺寸应放到 code-behind 的 `AppWindow.Resize`。
   - `Grid` 没有 `CornerRadius`，圆角背景要用 `Border` 包一层。
   - `TextBlock` 没有 `Cursor`；交互手势放在可点击容器或控件上。
   - `x:Bind` 不支持直接写 `Not ViewModel.HasFile` 这类表达式；用 ViewModel 暴露 `HasNoFile`。
   - 拖拽 API 使用 `e.AcceptedOperation = DataPackageOperation.Copy` 和 `e.DragUIOverride.Caption`，不是 `AcceptedDataPackageOperations` / `DragInfo`。
   - C# P/Invoke 不要传空回调指针给 Rust；声明 delegate，保留静态引用，避免被 GC。

4. CI/CD
   - 用户希望“推到 GitHub 后自动构建”时，workflow 不能只监听 tag / workflow_dispatch；需要明确监听 `push.branches: main`。
   - `actions/upload-artifact` 只会把文件放在 Actions run 的 artifact 中，不会出现在 GitHub Releases。需要在 tag 构建时显式创建 Release 并 `gh release upload`。
   - 每次说“发布成功”前必须同时检查 Actions 结果和 `gh release view <tag> --json assets`，确认 Release 页面真的有可下载资产。
   - GitHub 日志里 XamlCompiler 有时只报 MSB3073，需要结合 annotation 或下一轮编译错误逐步定位。
   - 本地缺工具链时，可以先做 `swiftc -typecheck`、`xcodebuild -list`、`git diff --check`，但 Rust/.NET 仍必须以 Actions 结果为准。

---

## A — 第一轮评审

**评审人**：
**日期**：YYYY-MM-DD
**范围**：全量代码 / 指定模块

### 发现的问题

#### 问题 1：简要标题

- **类型**：Bug / 性能 / 安全 / 代码质量
- **严重程度**：高 / 中 / 低
- **状态**：待验证 / 已确认 / 已修复 / 不成立
- **位置**：`文件路径:行号`
- **描述**：
- **复现步骤**：
- **建议修复**：

#### 问题 2：简要标题

<!-- 同上格式，继续编号 -->

---

## B — 验证 + 第二轮评审

**评审人**：AI 开发助手
**日期**：2026-05-15

### 对 A 的发现逐条验证

| A 的问题 | 确认 | 说明 |
|----------|------|------|
| 无已记录问题 | — | A 轮模板未填写，因此本轮直接做独立全量评审 |

### B 的独立评审发现

#### 问题 1：Rust 队列回调类型无法编译

- **类型**：Bug
- **严重程度**：高
- **状态**：已修复
- **位置**：`core/src/queue.rs`
- **描述**：`ProgressFn` 原为 `Box<dyn Fn>`，队列中调用 `callback.clone()` 会直接编译失败。
- **复现步骤**：运行 `cargo check`。
- **建议修复**：将回调类型改为可克隆的 `Arc<dyn Fn...>`。

#### 问题 2：ffmpeg 进度永远不会上报

- **类型**：Bug
- **严重程度**：高
- **状态**：已修复
- **位置**：`core/src/task.rs`
- **描述**：代码从 stderr 查找 `out_time_us=`，但命令没有传 `-progress pipe:1`；同时 `duration` 永远为 0。
- **复现步骤**：启动任意任务，UI 进度保持 0。
- **建议修复**：传 `-progress pipe:1`，读取 stdout，并通过裁剪区间或 ffprobe 得到总时长。

#### 问题 3：macOS 新 UI 未加入 Xcode target

- **类型**：Bug
- **严重程度**：高
- **状态**：已修复
- **位置**：`macos/Clippi.xcodeproj/project.pbxproj`
- **描述**：工程只编译旧 `ContentView.swift`，不会编译实际实现的 `MainView.swift`、`MainViewModel.swift` 和 FFI 封装。
- **复现步骤**：运行 `xcodebuild -list` 后检查 target sources。
- **建议修复**：将实际源文件加入 PBXSourcesBuildPhase，配置桥接头和 Rust 静态库链接。

#### 问题 4：Swift 捕获型闭包不能作为 C 函数指针

- **类型**：Bug
- **严重程度**：高
- **状态**：已修复
- **位置**：`macos/Clippi/FFI/ClippiFFI.swift`
- **描述**：`@convention(c)` 闭包捕获了 Swift callback 参数，Swift 类型检查会失败。
- **复现步骤**：运行 Swift 类型检查。
- **建议修复**：使用静态 C thunk 和静态 Swift callback 存储。

#### 问题 5：Windows P/Invoke 传空回调指针

- **类型**：Bug
- **严重程度**：高
- **状态**：已修复
- **位置**：`windows/Clippi/ClippiCore.cs`
- **描述**：`RunTask` 向 Rust 传 `IntPtr.Zero`，Rust 侧按函数指针调用时会崩溃。
- **复现步骤**：Windows 启动任务并等待进度回调。
- **建议修复**：声明 native delegate，传稳定的静态回调并保留托管引用。

#### 问题 6：Windows XAML 存在明显无效属性 / 绑定

- **类型**：Bug
- **严重程度**：中
- **状态**：已修复
- **位置**：`windows/Clippi/MainWindow.xaml`
- **描述**：`Window.DataContext`、`Not ViewModel.HasFile`、`Grid CornerRadius`、`TextBlock Cursor` 等写法容易导致 XAML 编译失败。
- **复现步骤**：运行 `dotnet build windows/Clippi/Clippi.csproj`。
- **建议修复**：改用 x:Bind 可解析属性、Border 承载圆角、移除无效 Cursor。

#### 问题 7：Rust enum JSON 与前端小写格式不兼容

- **类型**：Bug
- **严重程度**：中
- **状态**：已修复
- **位置**：`core/src/types.rs`
- **描述**：前端传 `mp4` / `mp3`，Rust serde 默认期望 `Mp4` / `Mp3`。
- **复现步骤**：调用转换或提取音频任务。
- **建议修复**：为 `OutputFormat` 和 `AudioFormat` 增加 `#[serde(rename_all = "lowercase")]`。

#### 问题 8：CI 构建参数与当前工程不匹配

- **类型**：构建配置
- **严重程度**：中
- **状态**：已修复
- **位置**：`.github/workflows/build-macos.yml`, `.github/workflows/build-windows.yml`
- **描述**：macOS CI 可能因签名失败中断；Windows 未显式指定 x64 / win-x64，而 Rust DLL 只按默认 x64 路径复制。
- **复现步骤**：推送 tag 触发 Actions。
- **建议修复**：macOS 禁用 CI 签名，Windows build 指定 `-p:Platform=x64 -r win-x64`。

#### 问题 9：workflow 未监听 main 分支 push

- **类型**：构建配置
- **严重程度**：中
- **状态**：已修复
- **位置**：`.github/workflows/build-macos.yml`, `.github/workflows/build-windows.yml`
- **描述**：用户要求推到 GitHub 后触发自动构建，但 workflow 原来只监听 `v*` tag 和手动触发。
- **复现步骤**：普通 push `main` 后不会触发 Actions。
- **建议修复**：为两个 workflow 增加 `push.branches: main`。

#### 问题 10：macOS universal 构建与单架构 Rust 静态库冲突

- **类型**：构建配置
- **严重程度**：高
- **状态**：已修复
- **位置**：`.github/workflows/build-macos.yml`
- **描述**：`ONLY_ACTIVE_ARCH=NO` 会让 Xcode 同时链接 x86_64 和 arm64，但 Rust CI 只生成当前 runner 架构的 `libclippi_core.a`，导致 x86_64 链接 `_clippi_*` 符号失败。
- **复现步骤**：macOS Actions 构建报 `found architecture 'arm64', required architecture 'x86_64'` 和 `_clippi_*` undefined symbols。
- **建议修复**：MVP 阶段用 `ONLY_ACTIVE_ARCH=YES`；如后续要 universal binary，需要 Rust 分别构建双架构并 `lipo` 合并。

#### 问题 11：WinUI Window / XAML 使用了不支持的属性

- **类型**：Bug
- **严重程度**：中
- **状态**：已修复
- **位置**：`windows/Clippi/MainWindow.xaml`, `windows/Clippi/MainWindow.xaml.cs`
- **描述**：`Window` 根节点配置 `Width/Height/MinWidth/MinHeight`、`Grid CornerRadius`、`TextBlock Cursor` 等写法导致 XamlCompiler 失败。
- **复现步骤**：Windows Actions `Build Windows app` 步骤失败，早期只显示 MSB3073。
- **建议修复**：窗口尺寸移动到 `AppWindow.Resize`，圆角用 `Border`，移除无效 Cursor。

#### 问题 12：WinUI 拖拽事件 API 名称使用错误

- **类型**：Bug
- **严重程度**：中
- **状态**：已修复
- **位置**：`windows/Clippi/MainWindow.xaml.cs`
- **描述**：代码使用了不存在的 `AcceptedDataPackageOperations`、`DataPackageOperations`、`DragInfo`。
- **复现步骤**：Windows Actions 报 `DragEventArgs does not contain a definition for DragInfo` 等错误。
- **建议修复**：改为 `e.AcceptedOperation = DataPackageOperation.Copy` 和 `e.DragUIOverride.Caption`。

#### 问题 13：Actions artifact 被误认为 GitHub Release 资产

- **类型**：发布流程
- **严重程度**：高
- **状态**：已修复
- **位置**：`.github/workflows/build-macos.yml`, `.github/workflows/build-windows.yml`
- **描述**：此前 workflow 只执行 `actions/upload-artifact`，构建产物只存在于 Actions run 页面，GitHub Releases 页面不会显示安装包。
- **复现步骤**：打开 Releases 页面，`v0.0.1` 没有 `.dmg` / `.zip` 资产。
- **建议修复**：tag 构建时授予 `contents: write`，创建 Release，并上传 `Clippi-macos.dmg` / `Clippi-windows.zip`。发布完成后用 `gh release view <tag> --json assets` 验证。

---

## C — 验证 + 第三轮评审

**评审人**：cc-mimo
**日期**：2026-05-15
**范围**：全量代码（Rust 核心库、macOS SwiftUI、Windows WinUI 3、CI/CD）

### 对 B 的发现逐条验证

| B 的问题 | 确认 | 说明 |
|----------|------|------|
| 问题 1：Rust 队列回调类型无法编译 | ✅ 已修复 | `types.rs:76` 已改为 `Arc<dyn Fn(Progress) + Send + Sync + 'static>`，可克隆 |
| 问题 2：ffmpeg 进度永远不会上报 | ✅ 已修复 | `task.rs:108-109` 已加 `-progress pipe:1`，从 stdout 读取 `out_time_us=` |
| 问题 3：macOS 新 UI 未加入 Xcode target | ✅ 已修复 | `project.pbxproj` 已包含 `MainView.swift`、`MainViewModel.swift`、`ClippiFFI.swift` |
| 问题 4：Swift 捕获型闭包不能作为 C 函数指针 | ✅ 已修复 | `ClippiFFI.swift:6` 使用静态 `progressThunk` + 静态 `progressCallback` 存储 |
| 问题 5：Windows P/Invoke 传空回调指针 | ✅ 已修复 | `ClippiCore.cs:11` 声明了 `_nativeProgressCallback` 静态委托引用 |
| 问题 6：Windows XAML 存在明显无效属性 / 绑定 | ✅ 已修复 | `MainWindow.xaml` 使用 `Border` 承载圆角、`x:Bind` 可解析表达式、无 `Cursor` |
| 问题 7：Rust enum JSON 与前端小写格式不兼容 | ✅ 已修复 | `types.rs:50,60` 已加 `#[serde(rename_all = "lowercase")]` |
| 问题 8：CI 构建参数与当前工程不匹配 | ✅ 已修复 | macOS `ONLY_ACTIVE_ARCH=YES`，Windows `-p:Platform=x64 -r win-x64` |
| 问题 9：workflow 未监听 main 分支 push | ✅ 已修复 | 两个 workflow 均配置 `push.branches: main` |
| 问题 10：macOS universal 构建与单架构 Rust 静态库冲突 | ✅ 已修复 | `build-macos.yml:57` 已设 `ONLY_ACTIVE_ARCH=YES` |
| 问题 11：WinUI Window / XAML 使用了不支持的属性 | ✅ 已修复 | 窗口尺寸在 `MainWindow.xaml.cs:22` 的 `AppWindow.Resize` 中设置 |
| 问题 12：WinUI 拖拽事件 API 名称使用错误 | ✅ 已修复 | 使用 `DataPackageOperation.Copy` 和 `e.DragUIOverride.Caption` |
| 问题 13：Actions artifact 被误认为 GitHub Release 资产 | ✅ 已修复 | 两个 workflow 均有 `gh release upload --clobber` |

B 轮 13 个问题全部确认已修复。

### C 的独立评审发现

#### 问题 14：macOS `DropAreaView` 重复定义导致编译失败

- **类型**：Bug
- **严重程度**：高
- **状态**：不成立
- **位置**：`macos/Clippi/ContentView.swift:37` 与 `macos/Clippi/Views/MainView.swift:118`
- **描述**：两个文件都定义了 `struct DropAreaView: View`，且都在 `project.pbxproj` 的 PBXSourcesBuildPhase 中。Swift 同模块内不允许同名 struct，会导致编译错误 `Invalid redeclaration of 'DropAreaView'`。
- **复现步骤**：运行 `xcodebuild`，编译阶段报重复类型定义。
- **建议修复**：`ContentView.swift` 是死代码（`ClippiApp.swift` 只引用 `MainView`），应从 Xcode 项目中移除该文件，或将其从编译源中删除。
- **D 轮验证**：不成立。`ContentView.swift` 仍有 PBXFileReference 和旧 PBXBuildFile 记录，但不在 PBXSourcesBuildPhase 的 `files` 列表里；当前 Sources 只包含 `ClippiApp.swift`、`MainView.swift`、`MainViewModel.swift`、`ClippiFFI.swift`。macOS CI 已通过。

#### 问题 15：`progress.rs` 模块为死代码

- **类型**：代码质量
- **严重程度**：低
- **状态**：已修复
- **位置**：`core/src/progress.rs`、`core/src/lib.rs:10`
- **描述**：`mod progress` 在 `lib.rs` 中声明，但 `parse_progress_line` 和 `ProgressInfo` 既无 `pub use` 导出，也未在任何其他模块中被调用。`task.rs` 中的进度解析是直接在循环中手动实现的（解析 `out_time_us=`），与 `progress.rs` 的解析逻辑完全无关。
- **复现步骤**：`grep -r "parse_progress_line\|ProgressInfo" core/src/` 仅在 `progress.rs` 内部出现。
- **建议修复**：删除 `progress.rs` 和 `lib.rs` 中的 `mod progress;` 声明。
- **D 轮验证**：确认成立，已删除 `core/src/progress.rs`，并移除 `core/src/lib.rs` 的 `mod progress;`。

#### 问题 16：队列函数注释"串行执行"但实际并行启动

- **类型**：Bug / 设计缺陷
- **严重程度**：中
- **状态**：已修复
- **位置**：`core/src/queue.rs:5-15`
- **描述**：`queue_tasks` 注释为 `Queue multiple tasks for serial execution`，但循环中对每个 task 调用 `run_task`，而 `run_task` 内部是 `std::thread::spawn`，所有任务同时并行启动。用户排队 N 个任务时，N 个 ffmpeg 进程会同时运行，争抢 CPU 和磁盘 I/O，进度回调也会混乱交叉。
- **复现步骤**：调用 `clippi_queue_tasks` 传入多个任务，观察系统进程列表。
- **建议修复**：二选一：① 若意图是串行，则在前一个任务完成后再启动下一个（需要 `run_task` 返回 join handle）；② 若意图是并行，则修正注释和文档。当前行为与声明不符。
- **D 轮验证**：确认成立，已将 `queue_tasks` 改为先准备所有任务，再启动一个后台队列线程按顺序调用阻塞执行函数，避免同时启动多个 ffmpeg 进程。

#### 问题 17：`run_task` 线程内错误静默丢失

- **类型**：Bug
- **严重程度**：中
- **状态**：已修复
- **位置**：`core/src/task.rs:19-90`
- **描述**：`std::thread::spawn` 的闭包返回 `Result<(), CoreError>`，但返回的 `JoinHandle` 被直接丢弃。`TaskHandle` 只包含 `id` 和 `cancel_tx`，没有 `join_handle`。如果 ffmpeg 启动失败、解析失败或被取消，调用方无法得知任务结果。FFI 层 `clippi_run_task` 返回 task id 后，无法查询任务是否成功完成。
- **复现步骤**：传入不存在的输入文件路径，`clippi_run_task` 返回有效 task id（非 0），但 ffmpeg 实际已失败。
- **建议修复**：在 `TaskHandle` 中增加 `join_handle`，或增加任务完成/错误回调机制，让调用方能感知任务结果。
- **D 轮验证**：确认成立，已通过完成/错误回调修复。`Progress` JSON 新增 `state` 和 `message` 字段，任务完成、失败、取消都会回传给 UI；macOS / Windows ViewModel 已处理 `failed` / `cancelled` 状态。

---

## D — 验证 + 第四轮评审

**评审人**：AI 开发助手
**日期**：2026-05-15

### 对 C 的发现逐条验证

| C 的问题 | 确认 | 说明 |
|----------|------|------|
| 问题 14 | ❌ 不成立 | `ContentView.swift` 不在 PBXSourcesBuildPhase，重复 `DropAreaView` 不参与编译 |
| 问题 15 | ✅ 成立并修复 | 删除 `progress.rs` 和 `mod progress;` |
| 问题 16 | ✅ 成立并修复 | 队列改为单后台线程串行执行 |
| 问题 17 | ✅ 成立并修复 | 通过 `Progress.state/message` 回传完成、失败、取消状态 |

### D 的独立评审发现

暂无新增问题。剩余风险：本机仍无 Rust / .NET 工具链，Rust/Windows 完整编译以 GitHub Actions 为准。

---

<!-- 后续棒次复制「X — 验证 + 第 N 轮评审」结构继续追加 -->
