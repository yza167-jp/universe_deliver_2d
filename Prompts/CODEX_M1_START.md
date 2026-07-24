# Codex 主 Agent — M1 启动提示

将下面内容作为 M1 第一次开发会话的 Goal/Prompt 使用。

---

你是《我在宇宙送快递》Godot 2D 项目的主开发 Agent。M0 Playable Spine 已完成人工验收；当前目标是按仓库任务计划开发 **M1：Four-Planet Demo**。

开始前完整阅读：

1. `AGENTS.md`
2. `CODEX_GOAL.md`
3. `M1_DEVELOPMENT_TASKS.md`
4. `Docs/M1/README.md`
5. `Docs/M1/00_M1_ROADMAP.md`
6. `Docs/11_M1_TECHNICAL_DELTA.md`
7. `Docs/12_M1_ITERATION_GATES.md`
8. 当前任务引用的其他文档

然后检查：

- `git status`
- 当前分支和最近提交
- 当前所有 `In Progress`、`Human Check` 与 `Ready` 任务
- 用户未提交和未跟踪文件

当前任务队列是 `M1_DEVELOPMENT_TASKS.md`。根目录 `DEVELOPMENT_TASKS.md` 是已完成的 M0 历史记录，不从其中领取任务。

当前 M1 顺序为：

```text
共享系统与 M0 回归保护
→ 白噪星垂直切片
→ 成长、支线、低空投放与赤砂回访
→ 穹林星
→ 群潮星高潮
→ 四星 Demo 整合
```

工作规则：

1. 若存在 `In Progress` 或 `Human Check`，不要领取新任务，先报告当前应处理事项。
2. 否则选择依赖已满足、状态为 `Ready`、顺序最靠前的一项任务。
3. 一次只做一个任务；完成后停止，不自动继续第二项。
4. 开始时将任务改为 `In Progress`，完成后按真实结果改为 `Done` 或 `Human Check`。
5. 严格遵守任务卡的范围、明确不做和依赖。
6. M0 是受保护基线；修改共享状态、飞行、UI、存档、场景流或数据注册表时必须运行完整 M0 回归。
7. 不提前制作白噪星关卡：T-100 至 T-109 未完成前只建立 M1 共享基础。
8. 新星球必须先依据 Planet/Order/Character Packet 创建数据，再投入关卡与资产。
9. 不自行把 PROVISIONAL 或 OPEN 世界观升级为 LOCKED 正史。
10. 使用 Godot 4.7.1、静态类型 GDScript、Compatibility renderer 和现有 640×360 显示合同。
11. 玩家可见文本使用本地化 Key；代码、文件和稳定 ID 使用英文。
12. 新依赖必须先记录到 `Docs/09_DEPENDENCY_LOG.md`；没有充分理由不引入依赖。
13. 不覆盖用户未提交修改，不使用破坏性 Git 命令。
14. 仅主 Agent 在适用检查通过后创建聚焦的中文提交。
15. 到 Gate E–I 时停止扩展，提供试玩包并等待用户结论。

修改代码前先报告：

- 本轮任务编号与标题；
- 玩家价值；
- 依赖；
- 实现范围；
- 明确不做；
- 预计修改文件；
- 自动测试、M0 回归和烟雾测试方案。

完成前至少执行：

- 当前任务专项测试；
- `./scripts/check_project.sh`；
- 受影响场景烟雾；
- 必要的 M0 完整闭环回归；
- `git diff --check`；
- `git status` 和最终 diff 检查。

最终报告必须包含：

- 完成任务与最终状态；
- 实现内容和关键文件；
- 全部测试结果；
- M0 回归结果；
- commit hash 与信息；
- 已知问题；
- 下一项可能解锁的任务；
- 是否需要人工试玩。

本轮应从 `T-100 — 冻结 M0 回归基线并建立 M1 检查合同` 开始。不要在同一轮开始 T-101。