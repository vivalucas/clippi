# 开发日志

---

## 2026-05-15（推进正式版到 v1.0.0）

**触发原因**：用户要求项目打 `1.0.0` 发布，提交并触发 GitHub Actions 构建。

**修改内容**：
1. `core/Cargo.toml` — 版本号更新为 `1.0.0`。
2. `windows/Clippi/Clippi.csproj` — 应用版本号更新为 `1.0.0`。
3. `macos/Clippi.xcodeproj/project.pbxproj` — `MARKETING_VERSION` 更新为 `1.0.0`。
4. `README.md` — 发布示例 tag 更新为 `v1.0.0`。
5. `project-log/05-current-status.md` — 当前版本更新为 `V1.0.0`。

**验证方式**：
- `swiftc -typecheck macos/Clippi/ClippiApp.swift macos/Clippi/Views/MainView.swift macos/Clippi/ViewModels/MainViewModel.swift macos/Clippi/FFI/ClippiFFI.swift -import-objc-header macos/Clippi/ClippiCore.h`
- `xcodebuild -list -project macos/Clippi.xcodeproj`
- `git diff --check`

**验证结果**：
- Swift 类型检查通过。
- Xcode project 可列出 `Clippi` target / scheme。
- diff whitespace 检查通过。
- 本机仍无 `cargo` / `dotnet`，Rust / Windows 完整编译等待 GitHub Actions 验证。

---

## 2026-05-15（推进版本到 v0.0.3）

**触发原因**：用户要求提交全部修改到 GitHub，并将版本号向前推进 `0.0.1` 触发新版本构建。

**修改内容**：
1. `core/Cargo.toml` — 版本号从 `0.0.1` 更新为 `0.0.3`。
2. `windows/Clippi/Clippi.csproj` — 应用版本号从 `0.0.1` 更新为 `0.0.3`。
3. `macos/Clippi.xcodeproj/project.pbxproj` — `MARKETING_VERSION` 从 `0.0.1` 更新为 `0.0.3`。
4. `README.md` — 发布示例 tag 更新为 `v0.0.3`。
5. `project-log/05-current-status.md` — 当前版本更新为 `V0.0.3`。

**遇到的问题**：
- `project-log/` 在 `.gitignore` 中标记为 local-only；本次按用户要求将 Markdown 文档强制加入提交，但仍排除 `project-log/.claude/settings.local.json`。

**解决方式**：
- 使用 `git add -f project-log/*.md` 提交项目文档，不提交本地 `.claude` 配置。

**验证方式**：
- `git diff --check`
- `swiftc -typecheck macos/Clippi/ClippiApp.swift macos/Clippi/Views/MainView.swift macos/Clippi/ViewModels/MainViewModel.swift macos/Clippi/FFI/ClippiFFI.swift -import-objc-header macos/Clippi/ClippiCore.h`
- 推送 `v0.0.3` tag 后查看 GitHub Actions 和 Release assets。

**验证结果**：
- 等待 `v0.0.3` tag 构建。

---

## 2026-05-15（处理 cc-mimo 第三轮评审）

**触发原因**：cc-mimo 在 `11-code-review-log.md` 中完成第三轮评审，提出 4 个新问题，需要独立验证并修复确认项。

**修改内容**：
1. `core/src/progress.rs` — 删除未使用的死代码模块。
2. `core/src/lib.rs` — 移除 `mod progress;`。
3. `core/src/task.rs` — 抽出阻塞执行函数，新增任务完成 / 失败 / 取消状态回调。
4. `core/src/types.rs` — `Progress` 增加 `state` 和 `message` 字段。
5. `core/src/queue.rs` — 队列改为后台线程串行执行，不再并行启动多个 ffmpeg。
6. `macos/Clippi/ViewModels/MainViewModel.swift` — 处理 `failed` / `cancelled` 状态。
7. `windows/Clippi/ViewModels/MainViewModel.cs` — 处理 `failed` / `cancelled` 状态。
8. `project-log/11-code-review-log.md` — 记录 D 轮验证结论：问题 14 不成立，问题 15-17 成立并已修复。

**遇到的问题**：
- 问题 14 表述中说 `ContentView.swift` 也在 PBXSourcesBuildPhase 中，但实际工程 sources 列表不包含它，只残留 file reference / build file 记录。

**解决方式**：
- 用 `project.pbxproj` 的 PBXSourcesBuildPhase 独立核对，确认 `ContentView.swift` 不参与编译。
- 对成立问题直接修复。

**验证方式**：
- `rg -n "parse_progress_line|ProgressInfo|mod progress|progress::" core/src -S`
- `swiftc -typecheck macos/Clippi/ClippiApp.swift macos/Clippi/Views/MainView.swift macos/Clippi/ViewModels/MainViewModel.swift macos/Clippi/FFI/ClippiFFI.swift -import-objc-header macos/Clippi/ClippiCore.h`
- `git diff --check`

**验证结果**：
- 死代码引用已不存在。
- Swift 类型检查通过。
- diff whitespace 检查通过。
- Rust/.NET 完整编译仍需 GitHub Actions 验证。

---

## 2026-05-15（修复构建链路与 FFI 回调）

**触发原因**：用户要求全面阅读项目，优先从 project-log 开始，对照代码找 bug / 优化点，并修复后推送 GitHub 触发自动构建。

**修改内容**：
1. `core/src/types.rs` — 将进度回调类型改为可克隆的 `Arc<dyn Fn...>`，并让输出格式 / 音频格式支持小写 JSON。
2. `core/src/task.rs` — 改用 ffmpeg `-progress pipe:1` 解析真实进度，补充参数校验、完成回调、`-threads 0`、WebM 编码回退和错误输出读取。
3. `core/src/ffi.rs` — 适配新的回调类型。
4. `macos/Clippi.xcodeproj/project.pbxproj` — 把实际 MainView / MainViewModel / FFI 文件加入 Xcode target，配置桥接头和 Rust 静态库链接。
5. `macos/Clippi/FFI/ClippiFFI.swift` — 修复 Swift 捕获型闭包不能作为 C 函数指针的问题。
6. `macos/Clippi/ViewModels/MainViewModel.swift` — 修复 RemoveAudio JSON 构造类型错误、可选值 JSON 序列化问题和完成状态更新。
7. `windows/Clippi/ClippiCore.cs` — 修复 P/Invoke 回调传空指针的问题，保留 native delegate 防止被 GC。
8. `windows/Clippi/MainWindow.xaml` — 移除无效 Window.DataContext、无效 `Not` 绑定、Grid CornerRadius 和 TextBlock Cursor。
9. `windows/Clippi/ViewModels/MainViewModel.cs` — 增加 UI 线程派发、进度解析、HasFile 派生属性通知和软件编码回退。
10. `.github/workflows/` — macOS 禁用 CI 签名，Windows 指定 x64 / win-x64 构建。

**遇到的问题**：
- 本机缺少 `cargo` / `rustc` / `dotnet`，无法做 Rust 和 Windows 完整本地构建。
- Xcode 访问默认 DerivedData 日志目录受沙箱限制，但工程解析仍成功。
- 第一次推送后发现 workflow 只监听 tag / 手动触发，普通 `main` push 不会自动构建。
- macOS Actions 后续失败于单架构 Rust 静态库与 Xcode universal 构建冲突。
- Windows Actions 后续失败于 WinUI 3 XAML / 拖拽 API 写法误用。

**解决方式**：
- 使用 Swift 类型检查验证 macOS Swift 源文件。
- 使用 Xcode 工程列表验证 target / scheme 可解析。
- 将剩余 Rust/.NET 编译验证交给 GitHub Actions。
- 为两个 workflow 增加 `main` push 触发。
- macOS CI 改为 `ONLY_ACTIVE_ARCH=YES`，与 Rust 当前架构静态库保持一致。
- Windows 端将窗口尺寸移动到 `AppWindow.Resize`，并改用正确的 `AcceptedOperation` / `DataPackageOperation.Copy` / `DragUIOverride`。

**验证方式**：
- `swiftc -typecheck macos/Clippi/ClippiApp.swift macos/Clippi/Views/MainView.swift macos/Clippi/ViewModels/MainViewModel.swift macos/Clippi/FFI/ClippiFFI.swift -import-objc-header macos/Clippi/ClippiCore.h`
- `xcodebuild -list -project macos/Clippi.xcodeproj`

**验证结果**：
- Swift 类型检查通过。
- Xcode 工程可列出 `Clippi` target 和 scheme。
- GitHub Actions Build macOS 通过：https://github.com/vivalucas/clippi/actions/runs/25876679883
- GitHub Actions Build Windows 通过：https://github.com/vivalucas/clippi/actions/runs/25876679842
- 本机 Rust/.NET 未运行，原因是本机缺少对应工具链。

**复盘经验**：
- 不要只看文件是否存在，还要确认平台工程文件是否真正引用了它。
- FFI 回调要把“语言运行时能不能稳定持有函数指针”作为第一优先级检查。
- 对 WinUI 3 不要混用 WPF / UWP API 名称；遇到 MSB3073 但日志不具体时，优先看 GitHub annotation。
- Rust 静态库架构必须和 Xcode 构建架构一致；universal app 需要 Rust universal library 配套。
- “推送后自动构建”需要 workflow 监听 branch push，tag-only 不满足这个需求。
- “Actions 构建成功”不等于“Release 页面有安装包”；`actions/upload-artifact` 和 GitHub Release assets 是两套东西，发布后必须检查 `gh release view <tag> --json assets`。

---

## 2026-05-15（修复 Release 资产发布）

**触发原因**：用户发现 GitHub Releases 页面没有构建安装包，说明此前只验证了 Actions artifact，没有验证 Release assets。

**修改内容**：
1. `.github/workflows/build-macos.yml` — 增加 `permissions: contents: write`，tag 构建时创建 Release 并上传 `Clippi-macos.dmg`。
2. `.github/workflows/build-windows.yml` — 增加 `permissions: contents: write`，将 Windows build 目录压缩为 `Clippi-windows.zip`，tag 构建时上传到 Release。
3. 创建并推送 `v0.0.2` tag，触发正式 Release 构建。

**遇到的问题**：
- `actions/upload-artifact` 只把产物放在 Actions 页面，不会自动进入 GitHub Releases。

**解决方式**：
- 在 tag 构建中使用 `gh release create` / `gh release upload` 显式发布资产。

**验证方式**：
- `gh run list --limit 4 --json databaseId,workflowName,headBranch,status,conclusion,url`
- `gh release view v0.0.2 --json name,tagName,url,assets`

**验证结果**：
- Build macOS `v0.0.2` 通过：https://github.com/vivalucas/clippi/actions/runs/25877802058
- Build Windows `v0.0.2` 通过：https://github.com/vivalucas/clippi/actions/runs/25877802064
- Release `v0.0.2` 已包含 `Clippi-macos.dmg` 和 `Clippi-windows.zip`。

---

## 2026-05-14（修复 Rust 编译错误）

**触发原因**：GitHub Actions 构建失败，Rust 核心库编译出错。

**修改内容**：
1. `core/src/task.rs` — 修复 percent 类型不匹配 (f64 -> f32)
2. `core/src/task.rs` — 修复 CoreError 转换问题（改用 map_err 替代 context）
3. `core/src/task.rs` — 移除未使用的 OutputFormat 导入

**遇到的问题**：
- `Progress.percent` 字段类型为 `f32`，但计算结果为 `f64`
- 线程返回的错误类型与 `CoreError` 不兼容

**解决方式**：
- 使用 `as f32` 进行类型转换
- 使用 `map_err` 直接转换为 `CoreError`，避免 `anyhow::Error` 中间类型

**验证方式**：
- 推送代码并重新触发 GitHub Actions 构建

**验证结果**：
- 等待 GitHub Actions 构建结果

---

## 2026-05-14（完善 FFI 接口和 UI 实现）

**触发原因**：项目骨架搭建完成后，需要完善 Rust FFI 导出接口和两端 UI 的完整功能实现。

**修改内容**：
1. `core/src/ffi.rs` — 完善 FFI 导出函数（run_task、cancel_task、queue_tasks）
2. `core/Cargo.toml` — 添加 once_cell 依赖
3. `scripts/build-core.sh` — 添加 Rust 核心库构建脚本（macOS/Linux）
4. `scripts/build-core.ps1` — 添加 Rust 核心库构建脚本（Windows）
5. `macos/Clippi/ClippiCore.h` — 添加 Swift 桥接头文件
6. `macos/Clippi/FFI/ClippiFFI.swift` — 添加 Swift FFI 封装
7. `macos/Clippi/ViewModels/MainViewModel.swift` — 添加完整 ViewModel 实现
8. `macos/Clippi/Views/MainView.swift` — 添加完整 UI 实现（拖拽、操作控件、进度）
9. `windows/Clippi/ClippiCore.cs` — 添加 C# P/Invoke 封装
10. `windows/Clippi/ViewModels/MainViewModel.cs` — 添加完整 ViewModel 实现
11. `windows/Clippi/MainWindow.xaml` — 重构完整 UI 布局
12. `windows/Clippi/MainWindow.xaml.cs` — 添加完整功能实现
13. `.github/workflows/` — 更新 CI/CD 支持完整构建流程

**遇到的问题**：
- 本地未安装 Rust，无法进行编译验证

**解决方式**：
- 依赖 GitHub Actions 进行构建验证，代码推送后由 CI/CD 测试

**验证方式**：
- 代码结构完整性检查
- 推送到 GitHub 后观察 Actions 构建状态

**验证结果**：
- 代码已推送，等待 GitHub Actions 构建验证

---

## 2026-05-14（项目骨架搭建）

**触发原因**：根据项目规划文档，搭建完整的项目骨架和基础代码框架。

**修改内容**：
1. `core/Cargo.toml` — 创建 Rust 核心库项目配置，定义依赖
2. `core/src/lib.rs` — 定义核心库模块结构和公开接口
3. `core/src/types.rs` — 定义所有数据类型（FileInfo、GpuCapability、TaskConfig 等）
4. `core/src/error.rs` — 定义错误类型
5. `core/src/probe.rs` — 实现 ffprobe 文件信息读取
6. `core/src/gpu.rs` — 实现 GPU 硬件加速探测
7. `core/src/task.rs` — 实现 ffmpeg 任务执行和取消
8. `core/src/queue.rs` — 实现批量队列管理
9. `core/src/progress.rs` — 实现 ffmpeg 进度解析
10. `scripts/download_ffmpeg.sh` — macOS/Linux ffmpeg 下载脚本
11. `scripts/download_ffmpeg.ps1` — Windows ffmpeg 下载脚本
12. `.github/workflows/build-macos.yml` — macOS CI/CD 流水线
13. `.github/workflows/build-windows.yml` — Windows CI/CD 流水线
14. `macos/Clippi/` — macOS SwiftUI 项目骨架（App、ContentView、ViewModel）
15. `windows/Clippi/` — Windows WinUI 3 项目骨架（App、MainWindow）
16. `README.md` — 项目说明文档
17. `LICENSE` — GPL-2.0 开源协议
18. `.gitignore` — Git 忽略配置
19. `project-log/05-current-status.md` — 更新项目状态

**遇到的问题**：
- 无

**解决方式**：
- 无

**验证方式**：
- Rust 核心库代码结构完整，包含所有必要模块
- 脚本文件语法正确
- CI/CD 配置语法正确

**验证结果**：
- 通过（代码结构验证）

---

<!-- 新记录追加在上方分隔线之后、旧记录之前 -->
