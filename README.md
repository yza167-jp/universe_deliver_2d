# 《我在宇宙送快递》 / Universe Deliver

> 一款以星际配送为叙事载体的 2D 复古科幻公路游戏。

玩家是一名来自地球、被派往银河边境快递站的人类员工。站点里只有玩家和一名会说话、会直立行走的外星水豚同事——**老皮**。玩家在空间站大厅接单、配置唯一一艘长期陪伴自己的飞船，在可交互驾驶舱中经历宁静的星际旅行，再进入横向侧视飞行关卡，亲手完成从飞入星系、接近星球、穿越大气层到降落交货的全过程。

配送不是重复刷取随机词条的借口，而是认识不同文明、介入当地故事、推动主线并逐步发现宇宙秘密的方式。

## 当前阶段

| 项目 | 当前决定 |
|---|---|
| 已完成里程碑 | **M0：Playable Spine**，2026-07-24 完成，6/6 阶段、35/35 任务及 Gate A–D 全部通过 |
| 当前里程碑 | **M1：Four-Planet Demo** |
| M1 当前状态 | 规划基线已建立；T-100 完成，下一项从 `DEVELOPMENT_TASKS.md` 的最早 `Ready` 任务开始 |
| M1 内容 | 赤砂星回访、白噪星、穹林星、群潮星、3 个必做支线 + 1 个可选扩展支线、飞船/站点成长、图鉴与 Demo 高潮 |
| 对外目标 | 可分享 Demo，首次主线体验约 2–4 小时 |
| 引擎 | Godot 4.7.1 stable |
| 脚本 | 静态类型 GDScript |
| 渲染器 | Compatibility |
| 画面 | 16:9、640×360 内部分辨率；真全屏最大 16:9 fractional fit，像素纹理 nearest |
| 首要平台 | macOS / Apple Silicon；M1 收尾增加 Windows 导出验证 |
| 首要输入 | 键盘与鼠标 |
| 发行方向 | 先完成可分享 Demo；不在 M1 接入 Steam SDK |

## 当前体验结构

```text
2D 俯视快递站大厅
→ 接单、与老皮交谈、查看客户历史、配置飞船
→ 2D 第一人称可交互驾驶舱
→ 宁静的星际旅行、途中对话与目的地设定
→ 横向侧视星球进入与配送
→ 场景式交付对话或小型可步行目的地区域
→ 结算、升级、回访与返回快递站
```

M1 的推荐主线顺序：

```text
赤砂星首单（M0 已完成）
→ 赤砂星短回访与特高压电屏蔽罩
→ 白噪星
→ 穹林星
→ 群潮星与 Demo 高潮
```

## M1 成功标准

M1 不是简单复制赤砂星三次。完成时至少需要：

1. 四颗主线星球在自然、人文、飞行机制、角色和声音上具有明确差异。
2. 赤砂星至少发生一次可见回访变化，伊娅不成为一次性 NPC。
3. 白噪星通过较强重力、电磁暴雪和记忆档案文明验证第二颗完整星球。
4. 穹林星通过武装封存选择、生态压力和低空投放验证玩家方式会被记住。
5. 群潮星通过横风、天气塔与局部控制权选择形成 Demo 高潮。
6. 至少完成 3 个正式支线；支线提供人物、探索、图鉴与升级资源，不成为刷钱劳动。
7. 飞船获得特高压电屏蔽罩、生物信号隔离舱和横风稳定器等确定成长。
8. 快递站至少出现三次可见变化，并建立档案终端、生态角和中继观测室。
9. M0 存档安全迁移到 schema v2，支持多星球解锁、关系、许可、图鉴和回访状态。
10. 从新游戏到群潮星结尾的完整 Demo 可以连续完成并通过 Gate E–I。

## 仓库入口

主 Agent 每次开始工作时按以下顺序阅读：

1. [`AGENTS.md`](AGENTS.md)：当前 M1 的稳定仓库规则。
2. [`CODEX_GOAL.md`](CODEX_GOAL.md)：M1 产品目标与完成定义。
3. [`DEVELOPMENT_TASKS.md`](DEVELOPMENT_TASKS.md)：当前 M1 任务、依赖与状态。
4. [`Docs/08_DECISION_LOG.md`](Docs/08_DECISION_LOG.md)：M0 历史决定。
5. [`Docs/M1/06_M1_DECISIONS.md`](Docs/M1/06_M1_DECISIONS.md)：M1 当前确认决定。
6. 当前任务引用的其他 `Docs/` 文档。

M1 主要文档：

| 文档 | 用途 |
|---|---|
| [`Docs/M1/00_M1_OVERVIEW.md`](Docs/M1/00_M1_OVERVIEW.md) | M1 总体范围、阶段与完成标准 |
| [`Docs/M1/01_M1_NARRATIVE_ARC.md`](Docs/M1/01_M1_NARRATIVE_ARC.md) | 四星主线弧线、揭示边界与回访结构 |
| [`Docs/M1/02_M1_SYSTEMS_DELTA.md`](Docs/M1/02_M1_SYSTEMS_DELTA.md) | 相对 M0 的系统增量与明确非目标 |
| [`Docs/M1/03_M1_SAVE_SCHEMA_V2.md`](Docs/M1/03_M1_SAVE_SCHEMA_V2.md) | v1→v2 存档迁移与数据合同 |
| [`Docs/M1/04_M1_CONTENT_BUDGET.md`](Docs/M1/04_M1_CONTENT_BUDGET.md) | 主线、支线、美术、音频与时间预算 |
| [`Docs/M1/05_M1_HUMAN_CHECKS.md`](Docs/M1/05_M1_HUMAN_CHECKS.md) | Gate E–I 人工验收 |
| [`Docs/M1/Planets/`](Docs/M1/Planets/) | 四颗星球的 Planet Packet |
| [`Docs/M1/Orders/`](Docs/M1/Orders/) | 主线与支线 Order Packet |
| [`Docs/M1/Characters/`](Docs/M1/Characters/) | M1 角色候选与稳定角色 ID |

M0 的最终文档快照入口见 [`Docs/Archive/M0/README.md`](Docs/Archive/M0/README.md)。

## 运行方式

使用 Godot `4.7.1-stable`：

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"

# 打开编辑器
"${GODOT_BIN:-godot}" --editor --path .

# 运行仓库检查
./scripts/check_project.sh

# 启动游戏
"${GODOT_BIN:-godot}" --path .
```

运行中按 `F11` 切换真全屏。画面保持 16:9，不裁切、不拉伸变形。

## 开发原则

- M0 是冻结回归基线；除非当前 M1 任务造成明确回归，不重新打开已通过 Gate。
- 一次只完成一个 `Ready` 任务。
- 先建立共用系统和内容包，再制作新星球关卡。
- 叙事、角色、地点与旅途感优先于系统数量。
- 支线必须提供人物、探索或世界变化，不用于无限刷钱。
- 主线必需模块必须有确定获取路径。
- 不加入完整敌人战斗、多飞船、程序生成、多单配送或复杂贸易。
- 新依赖先记录；仅主 Agent 在测试通过后提交，提交信息优先中文。

---

## English Summary

**Universe Deliver** is a narrative-first 2D retro-futuristic space courier road game. M0, a complete one-order playable spine centered on Red Sand, is finished. The current milestone is **M1: Four-Planet Demo**, expanding the game with a Red Sand revisit, White Noise, Canopy World, Tidal Archipelago, three required side orders, ship and station progression, codex/relationship systems, and a complete 2–4 hour demo arc.
