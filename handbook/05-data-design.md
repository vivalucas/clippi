# 数据约定

> 适用状态：启用，但项目没有数据库。本文记录内存状态和少量本地偏好，防止后续误引入重复持久层。

## 当前依据

- **数据库 / 迁移**：不适用；没有 SQLite、服务端或 schema 迁移。
- **任务状态**：Rust 任务注册表与两端 ViewModel 内存；应用退出后不保留队列或处理历史。
- **macOS 偏好**：UserDefaults 的 `appearance`、`defaultOutputDirectory`。
- **Windows 偏好**：`%LOCALAPPDATA%/Clippi/appearance.txt` 和 `default-output.txt`。
- **测试隔离**：macOS 模型回归使用独立 UserDefaults suite，完成后清除，不能修改用户配置。

## 状态地图

| 概念 | 存储 | 生命周期与唯一性 | 权威来源 |
| --- | --- | --- | --- |
| 当前普通工具素材与参数 | 两端 ViewModel | 当前进程；单一当前素材 | 两端 `MainViewModel` |
| 校正素材条目 | 两端 ViewModel | 当前进程；按规范化路径去重 | 两端 `MainViewModel` |
| task ID / 取消通道 | Rust `TASK_REGISTRY` | 任务终态后清理 | `core/src/ffi.rs`、`queue.rs` |
| 外观 | 平台偏好存储 | 用户级，允许 system/light/dark | MainView / MainWindow |
| 默认输出目录 | 平台偏好存储 | 用户级；空值表示源目录策略 | 两端 `MainViewModel` |
| 媒体与输出文件 | 用户文件系统 | 源文件只读；输出名避让 | 用户选择 + 任务规划 |

## 语义与限制

- 路径是本地绝对路径，只通过 UTF-8 JSON 进入 Rust；文档和测试不得固化个人设备路径。
- 时间单位是秒，使用有限浮点数；码率为整数；旋转标准化为 0/90/180/270。
- task ID 为进程内 `u64`，只用于回调与取消，不跨启动持久化。
- 删除媒体条目、清空列表或退出应用不删除源文件；临时预览图由 UI 在切换素材或退出时清理。
- 引入 SQLite 只有在确认需要持久任务历史、恢复队列或可查询记录时才重评；用户偏好本身不足以成为引库理由。
