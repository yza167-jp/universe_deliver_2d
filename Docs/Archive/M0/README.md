# M0 Archive / M0 归档入口

M0：Playable Spine 已于 **2026-07-24** 完成。

- 里程碑提交：`bb4cd4be7e30f4587b23f96e64cc8fc1fbeecc17`
- 提交信息：`确认 M0 已具备进入四星 Demo 规划的资格`
- 完成结果：`6/6` 阶段、`35/35` 任务、Gate A–D 全部通过。
- 自动基线：Godot 4.7.1、50/50 测试、全部专项烟雾与完整 M0 闭环通过。

## 精确快照

M0 的最终根目录文件可在上述 commit 中查看：

- `CODEX_GOAL.md`
- `DEVELOPMENT_TASKS.md`
- `Prompts/CODEX_M0_START.md`
- `Docs/04_DEMO_SCOPE.md`
- `Docs/08_DECISION_LOG.md`

GitHub 路径示例：

```text
https://github.com/yza167-jp/universe_deliver_2d/blob/bb4cd4be7e30f4587b23f96e64cc8fc1fbeecc17/CODEX_GOAL.md
https://github.com/yza167-jp/universe_deliver_2d/blob/bb4cd4be7e30f4587b23f96e64cc8fc1fbeecc17/DEVELOPMENT_TASKS.md
```

根目录现在始终代表**当前里程碑 M1**。不要把本目录中的 M0 链接或历史任务重新复制回根目录，也不要在 M1 开发中修改 M0 commit。

## M0 回归合同

M1 的每个重要系统任务都应保护以下基线：

```text
新游戏
→ 大厅与老皮教程
→ 赤砂星接单与配置
→ 驾驶舱旅行
→ 赤砂星完整飞行与重试
→ 维修场剧情
→ 结算返站
→ 保存与继续游戏
```

若 M1 改动造成回归，在当前 M1 任务中修复并补充测试；不要重新打开 M0 的旧任务状态。
