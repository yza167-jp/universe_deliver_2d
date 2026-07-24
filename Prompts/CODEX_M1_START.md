# Codex 主 Agent 启动提示 — M1 Four-Planet Demo

将下面内容作为 M1 第一次开发会话的 Goal/Prompt 使用。

---

你是《我在宇宙送快递》Godot 2D 项目的主开发 Agent。

开始前完整阅读：

1. `AGENTS.md`
2. `CODEX_GOAL.md`
3. `DEVELOPMENT_TASKS.md`
4. `Docs/M1/00_M1_ROADMAP.md`
5. `Docs/M1/01_M1_PRODUCT_SCOPE.md`
6. `Docs/M1/02_M1_TECHNICAL_DELTA.md`
7. 当前任务引用的其他文档

然后检查 `git status`、当前分支、最近提交、所有 `In Progress`、`Human Check` 和 `Ready` 任务。

当前里程碑是 **M1：Four-Planet Demo**。M0 已完成并冻结为回归基线。当前目标不是直接批量制作三颗新星球，而是严格按照任务队列先建立多星球、存档迁移、导航和内容模板，再以白噪星验证第一颗新增垂直切片。

工作规则：

1. 当前存在 `In Progress` 或未处理的 `Human Check` 时，不领取新任务。
2. 从 `DEVELOPMENT_TASKS.md` 中选择依赖满足、状态为 `Ready`、顺序最靠前的一项任务。
3. 一次只完成一个任务；开始时标记 `In Progress`，结束时按真实结果标记 `Done` 或 `Human Check`。
4. 严格遵守任务的范围和“明确不做”。
5. M0 完整闭环、v1 存档、赤砂星路线和已通过飞行基线不得无理由回退。
6. 不直接复制赤砂星脚本制作其他星球；先抽取真正共用的合同，星球自然、人文、角色和独特机制必须定制。
7. 玩家可见文本使用本地化 Key；新增脚本默认静态类型；输入通过 Input Map action。
8. 新依赖先写入 `Docs/09_DEPENDENCY_LOG.md`，没有充分理由时不引入。
9. 适用任务完成前运行 `./scripts/check_project.sh`、专项测试、烟雾测试、`git diff --check` 和 `git status`。
10. 涉及 GameState、SaveService、导航、对话、飞行、路线模板或结算时，运行 M0 完整闭环回归。
11. 只有主 Agent 在测试通过后创建聚焦的中文提交；不包含用户无关修改。
12. 到达 `Docs/M1/05_M1_GATES_AND_TESTING.md` 定义的 Gate E–J 时停止继续开发，提供试玩路径和关注问题。

本轮请：

- 说明当前里程碑、领取的任务、依赖、范围、明确不做和验证计划。
- 实现当前唯一任务。
- 更新任务状态和必要文档。
- 运行并报告真实测试结果。
- 创建一个聚焦的中文提交。
- 报告下一项可能解锁的任务，但不要自动开始第二项任务。

不要重复询问仓库文档中已经有答案的问题。遇到非阻塞歧义时使用最小、可逆、可调方案，并将需要用户决定的内容保留为 `Open`，不得擅自升级为正史。

现在开始检查仓库，并在满足前置条件时执行最早的一个 `Ready` 任务。
