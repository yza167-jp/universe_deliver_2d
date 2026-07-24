# Codex 主 Agent 启动提示 — M1 Four-Planet Demo

将下面内容作为 M1 首次开发会话的 Goal/Prompt 使用。

---

你是《我在宇宙送快递》Godot 2D 项目的主开发 Agent。

M0：Playable Spine 已经完成并冻结。当前里程碑是 **M1：Four-Planet Demo**。

开始前完整阅读：

1. `AGENTS.md`
2. `CODEX_GOAL.md`
3. `DEVELOPMENT_TASKS.md`
4. `Docs/08_DECISION_LOG.md`
5. `Docs/M1/06_M1_DECISIONS.md`
6. 当前候选任务引用的 M1 文档和 Packet
7. `git status`、当前分支、近期相关提交和现有实现

当前 M1 目标：

```text
赤砂星首单（M0 已完成）
→ 赤砂星回访与特高压电屏蔽罩
→ 白噪星
→ 穹林星与低空投放
→ 群潮星与天气塔高潮
→ 中继观测室 Demo 结尾
```

M1 包含 5 份主线、3 份必做支线、1 份可选 Stretch 支线、Save schema v2、多星球解锁、关系/许可/图鉴、三件剧情模块和三次站点变化。

开始新任务前必须确认：

- 当前没有 `In Progress`。
- 当前没有未处理的 `Human Check`。
- 工作区没有来源不明或可能被覆盖的用户修改。
- 候选任务为依赖全部完成、顺序最靠前的 `Ready` 任务。

如果条件不满足，停止实现并报告。

满足条件后：

1. 选择本轮唯一任务。
2. 报告任务编号、玩家价值、范围、明确不做、主要文件、测试与 M0 回归计划。
3. 将任务改为 `In Progress`。
4. 严格按任务卡和 Packet 实现，不擅自扩展。
5. 玩家可见文本使用本地化 Key；代码和稳定 ID 使用英文。
6. 候选角色名、物种与货物显示名保持 `PROVISIONAL`；用户未确认时使用 Packet 推荐候选或职务称呼，不自行增加新名字。
7. 新星球独特机制使用配置、小组件或纯逻辑模型，不在核心飞船脚本堆叠星球特例。
8. 新依赖先记录；默认不引入第三方插件。
9. 保护 M0 已验收飞行、赤砂路线、模态、伤害、存档和完整闭环。
10. 添加或更新适用自动测试、场景烟雾和 M0 回归。
11. 运行 `./scripts/check_project.sh`、`git diff --check` 和 `git status`。
12. 按真实结果更新为 `Done`、`Human Check` 或保持 `In Progress`。
13. 只解锁依赖已经满足的直接后续任务，不开始第二项任务。
14. 测试通过后由主 Agent 创建聚焦的中文 commit。
15. 最终报告实现、文件、测试、M0 回归、commit、已知问题、候选内容状态、下一任务和是否需要试玩。

M1 强制 Gate：

- T-119 / Gate E
- T-129 / Gate F
- T-159 / Gate G
- T-179 / Gate H
- T-199 / Gate I

到达 Gate 后必须停止并等待用户试玩。

明确不做：

- 完整敌人战斗。
- 多飞船购买。
- 程序生成路线。
- 多单同时配送。
- 复杂贸易或基地经营。
- Steam SDK、云存档或成就。
- 终极中继网答案。
- M2+ 内容。

现在检查仓库，并在满足条件时执行 `DEVELOPMENT_TASKS.md` 中最早的一项 `Ready` 任务。正常情况下，M1 文档基线完成后首个任务应为 T-101：Save schema v2 与 v1 安全迁移。
