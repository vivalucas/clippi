# 当前状态

> 更新时间：2026-09-22
>
> 核对依据：`main` / `47e5b9f` / `v1.2.0`，工作区在本轮文档迁移前与 `origin/main` 一致
>
> 阶段：v1.2.0 已发布，常规维护与跨平台扩大验收

## 活跃任务

| 任务 | 执行者 / 当前分支 | 状态 | 已完成与下一步 | 相关文件 |
| --- | --- | --- | --- | --- |
| 暂无活跃开发任务 | — | — | 文档体系已迁移为 handbook；后续按实际需求登记 | [开发导航](README.md) |

## 已发布基线

- `v1.2.0` Release 已于 2026-09-12 发布；同一提交的 macOS、Windows main/tag 四次 Actions 均成功。
- Release 现有资产：`Clippi-macos.dmg`、`Clippi-Setup-x64.exe`、`Clippi-Portable-x64.exe`、`Clippi-windows.zip`。
- 当前仓库版本来源一致：Rust、macOS、Windows manifest/csproj 和安装器均为 1.2.0。

## 阻塞与待决事项

- 无已确认开发阻塞。
- 仍缺扩大验收：Windows v1.2.0 实机交互、NVIDIA NVENC / Intel QSV 真机、真实 HDR/10-bit、多音轨、长视频、异常文件、display matrix 和批量失败重试。
- macOS 与 Windows 发布包均未代码签名；是否引入 Apple/Windows 签名属于产品与发行决策，不能在普通修复中顺带改变。
- 输出大小预估、磁盘空间预警、命令预览/完整日志界面、普通工具批量化和任务历史尚未实现；它们是候选能力，不是当前承诺。

## 最近验证与交接

- 代码基线：`47e5b9f`（v1.2.0）。
- 2026-09-12 本地验证：Rust fmt / Clippy / 20 单测 / Release；11 个真实 FFI 冒烟用例；8 个 macOS 模型回归；macOS Debug/Release 构建与实际 UI 导入、播放、主题、设置、旋转导出。
- 2026-09-12 CI：macOS arm64 与 Windows x64 构建、安装器/便携包生成和 Release 上传成功。
- 尚未证明：v1.2.0 Windows UI 实机行为，以及上述真实复杂素材/硬件编码矩阵。
- 开发和复现入口见 [07](07-environment.md) 与 [10](10-quality.md)。当前没有仅存在于旧 `project-log`、删除后不可恢复的未完成工作。

完成任务在不再影响交接后应从本页移除；稳定能力写 00/02，长期经验写 11，历史提交由 Git 保留。
