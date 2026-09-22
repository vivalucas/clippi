# 测试、评审与质量

> 适用状态：启用。维护可重复验证入口、当前缺口和高风险回归点，不记录每次通过的流水账。

## 验证入口

| 范围 | 命令 / 手动检查 | 通过条件 | 限制 |
| --- | --- | --- | --- |
| Rust 格式 | `cargo fmt --manifest-path core/Cargo.toml -- --check` | 无 diff | 跨平台通用 |
| Rust 静态检查 | `cargo clippy --manifest-path core/Cargo.toml --all-targets -- -D warnings` | 0 warning/error | 需 Rust 工具链 |
| Rust 单测 | `cargo test --manifest-path core/Cargo.toml` | 全部通过 | 覆盖契约、参数、队列校验、解析 |
| Rust Release | `cargo build --release --manifest-path core/Cargo.toml` | 生成目标库 | 不等于 UI 通过 |
| 真实 FFI 冒烟 | `python3 scripts/test-core-smoke.py` | 11 个生成媒体用例通过 | 先 build release；PATH 有 ffmpeg/ffprobe；Windows 脚本当前不适用 |
| macOS 模型回归 | 编译并运行 `scripts/test-macos-model.swift` | 8 项状态/队列/偏好/裁剪回归通过 | 需至少 2 秒 MP4 和已构建静态库 |
| macOS App | `xcodebuild` Debug/Release + 实际窗口 | 构建并验证主路径、主题、预览、导出 | 只代表 macOS |
| Windows App | `dotnet build/publish` + 实机窗口 | x64 构建、启动并验证文件选择/播放器/主题/导出 | CI 构建不替代实机交互 |
| 文档 | `python3 handbook/tools/check_docs.py --strict-init` | 0 error | 不验证业务事实 |

## 高风险回归矩阵

- C ABI JSON：Operation 外部标签、格式小写、UTF-8 路径、Rust 字符串释放、task ID 回调隔离。
- 任务生命周期：极快完成的早到回调、取消后立即重启、准备中取消、队列部分注册失败、失败后续跑。
- 媒体规则：WebM VP9/Opus、缩放比例与偶数尺寸、快速/精确裁剪、无音轨/无视频轨、已存在输出不变。
- 校正：0/90/180/270 源方向、水平/垂直镜像与组合、预览/输出一致、清理旋转标签、多音轨保留。
- UI：设置往返不重置素材、格式切换保留目录/文件名、导入结果不串台、处理时参数锁定、友好错误与原始详情分层。
- 发行：产物内含 Rust 库与 ffmpeg/ffprobe，安装器不为空包，Release 资产实际存在。

## 当前质量缺口

| 编号 | 确认程度 / 优先级 | 触发条件、位置、影响及证据 | 处理状态 |
| --- | --- | --- | --- |
| Q-001 | 待验证 / 中 | v1.2.0 Windows 实机：XAML 绑定、文件夹选择、主题持久化、播放器定位、设置返回 | 待 Windows x64 验收 |
| Q-002 | 待验证 / 中 | VideoToolbox / NVENC / QSV 真实素材兼容性 | 待对应 GPU 真机 |
| Q-003 | 待验证 / 中 | HDR/10-bit、多音轨、长视频、异常文件、方向元数据与队列失败重试 | 合成短素材已覆盖核心路径，仍需真实样本 |
| Q-004 | 已知低频风险 / 低 | ffprobe 超时强杀依赖管道随子进程关闭，极端孙进程场景可能残留读取线程 | 当前以 kill + wait 缓解；复现后再重构进程组管理 |

历史 50 余项评审发现均已修复、判定不成立或被当前缺口取代，不再保留逐条流水。关键防复发约定已收敛到 [11](11-decisions.md) 和上述矩阵；完整修复历史由 Git 保存。

## 评审规则

全面评审默认只读，写明日期、执行者、代码基线、覆盖和未覆盖；确认问题与待验证风险分开，同一 AI 自查不能称为独立评审。较长且仍有交接价值的报告才建立 14+ 专题。
