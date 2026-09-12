# 视频工具界面重构与回归检查

## 设计

- macOS 与 Windows 改为常驻工具侧栏：裁剪、转换格式、缩放、提取音频、去除音频直接可见；旋转与镜像位于辅助位置。
- macOS 统一系统材质侧栏、选中态、留白、圆角参数卡和底部导出栏。视频素材提供预览，支持更换素材，裁剪增加范围滑块，导出完成可在访达中定位实际结果。
- Windows 同步侧栏、素材预览与信息卡布局，保留各处理工具和批量校正能力。
- 新增界面文本覆盖简中、英文、日文。

## 修复

- 两端更换素材后裁剪起点未重置。
- macOS 将 ffprobe 的错误 JSON 误当成有效素材。
- 取消后的旧回调影响后续任务；批量任务过早完成时提前结束整批状态。
- 缩放强制拉伸画面，现按目标范围等比缩放并保证偶数像素尺寸。
- WebM 缩放、精确裁剪使用不兼容编码，现统一选择 VP9 / Opus。
- 输出文件存在时当前 ffmpeg 可能零退出并被误判成功，核心增加输出存在检查。
- 预览任务随 SwiftUI 状态刷新反复加载；取消预览后临时图未清理。
- 导出后更改输出位置时，访达定位应使用已完成文件的实际路径。

## 验证

- `cargo test --manifest-path core/Cargo.toml`：20 项通过。
- `cargo build --release --manifest-path core/Cargo.toml`：通过。
- `python3 scripts/test-core-smoke.py`：11 项真实 FFI / ffmpeg 案例通过，包含横竖比例、裁剪时长、流类型、WebM、无效来源与防覆盖。
- `scripts/test-macos-model.swift`：真实核心下检查替换素材、错误探测、立即取消后重新导出、三素材批量校正。
- macOS Xcode Debug 构建通过。
- Windows XAML / 三语资源 XML 解析与键唯一性检查通过。

复现 macOS 模型测试：先准备一个 2 秒以上 MP4，然后运行：

```sh
swiftc -parse-as-library -import-objc-header macos/Clippi/ClippiCore.h \
  macos/Clippi/ViewModels/MainViewModel.swift macos/Clippi/Localization.swift \
  macos/Clippi/FFI/ClippiFFI.swift scripts/test-macos-model.swift \
  core/target/release/libclippi_core.a -o /tmp/clippi-model-tests
/tmp/clippi-model-tests /absolute/path/to/sample.mp4
```

## 未完成的环境验收

~~Mac 锁屏，电脑操作工具无法截图或点击验证。~~（后续本轮已解锁并完成 macOS 界面验证，见 13。）当前环境没有 Windows / .NET SDK，未编译运行 WinUI。上述静态验证不等于 Windows 运行验收；也不代表项目不存在其他 bug。


## 第二轮：功能层级、主题与交互审查

- 工具统一为裁剪、格式转换、缩放、旋转与镜像、音频处理。删除旋转前的分隔，音频操作在工具内切换。
- 两端提供跟随系统 / 浅色 / 深色，分别通过 UserDefaults 和本地用户配置文件保存。
- 空状态隐藏不可用参数，增加可通过键盘操作的选择按钮；已加载素材区域也支持拖入替换。
- 缩放明确说明保持比例，素材元数据简化；没有音轨或画面时提前提示并禁用对应导出。
- 切换工具保留当前素材，切换格式保留自选输出位置和文件名。
- Windows 内容区可滚动，输出、反馈和操作区固定在底部；读取素材期间锁定操作，防止使用旧素材启动任务。
- 实际导入复现 macOS 播放器崩溃。日志显示 VideoPlayerView 无法加载 AVPlayerView，产物缺少 AVKit 直接链接；补上 Debug / Release 的 AVKit 链接后实际导入成功。

本轮验证：macOS 编译通过；6 项模型回归通过（新增跨工具素材选择、保存位置保留）；实际窗口验证浅色、深色和重开后的主题记忆、导入视频、音频子选项、旋转工具素材衔接。Windows XAML 与三语资源静态检查通过，但依然未在 Windows 中编译运行。


## 第三轮：独立设置页面

两端新增侧栏底部的设置入口，外观从侧栏移入专用页面。设置包含跟随系统 / 浅色 / 深色、持久化默认导出位置，以及本地处理说明。当前素材的处理参数和单次输出路径仍留在工具页。默认导出位置用于后续导入及未单独指定位置的批量导出，修改设置不会覆盖当前输出路径。macOS 支持 Command+, 打开设置。

macOS 构建与既有模型回归通过，实际窗口确认设置页面显示；Windows XAML 和三语资源静态检查通过，仍待 Windows 运行验收。


## 本轮综合自查收尾

最新结论、修复、测试数量和环境边界以 [13 综合自查](13-ui-redesign-review.md) 为准；本文件保留按时间追加的过程记录。
