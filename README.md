# 《我在宇宙送快递》 / Universe Deliver

> 一款以星际配送为叙事载体的 2D 复古科幻公路游戏。

玩家是一名来自地球、被派往银河边境快递站的人类员工。站点里只有玩家和一名会说话、会直立行走的外星水豚同事——**老皮**。玩家在空间站大厅接单、配置唯一一艘长期陪伴自己的飞船，在可交互驾驶舱中经历宁静的星际旅行，再进入横向侧视飞行关卡，亲手完成从飞入星系、接近星球、穿越大气层到降落交货的全过程。

配送不是随机刷取的借口，而是认识不同文明、介入当地故事、推动主线并逐步发现宇宙秘密的方式。

## 当前阶段

| 项目 | 当前状态 |
|---|---|
| 已完成里程碑 | **M0：Playable Spine**，6/6 阶段、35/35 任务、Gate A–D 全部通过 |
| 当前里程碑 | **M1：Four-Planet Demo**，规划完成，准备实施 |
| 当前第一任务 | `T-101`：schema v2 与多星球进度模型 |
| M1 核心内容 | 赤砂 → 白噪 → 赤砂回访 → 穹林 → 群潮 → Demo 悬念结尾 |
| 引擎 | Godot 4.7.1 stable |
| 脚本 | 静态类型 GDScript |
| 渲染器 | Compatibility |
| 画面 | 640×360、16:9、nearest；真全屏最大 16:9 fractional fit |
| 首要平台 | macOS / Apple Silicon，本地 Demo |
| 首要输入 | 键盘与鼠标 |

M0 归档见 [`Docs/Archive/M0_MILESTONE.md`](Docs/Archive/M0_MILESTONE.md)。

## M1 目标

M1 要把已经成立的一颗赤砂星完整脊柱扩展为四星 Demo：

```text
赤砂星序章
→ 白噪星：冰原、电磁暴雪、记忆档案文明
→ 赤砂星回访：地点变化、支线、低空投放与成长
→ 穹林星：树冠路线、生态压力、和平/武装反馈
→ 群潮星：横风、海面、天气塔与中继网揭示
→ Demo 悬念结尾
```

M1 计划包含：

- 四颗可进入主线星球。
- 4–6 份主线订单与少量支线。
- 至少一次明确回访。
- 低空投放作为第二种正式交付方式。
- 飞船、快递站、关系/许可、图鉴和纪念品的轻量成长。
- v1 → v2 存档迁移。
- 首次主线体验约 2–4 小时。

仍不加入完整战斗、多飞船、程序生成、多单同时配送或复杂贸易。

## 仓库入口

主 Agent 每次开始工作时按以下顺序阅读：

1. [`AGENTS.md`](AGENTS.md)：长期仓库规则与当前 M1 范围。
2. [`CODEX_GOAL.md`](CODEX_GOAL.md)：M1 产品目标与完成定义。
3. [`DEVELOPMENT_TASKS.md`](DEVELOPMENT_TASKS.md)：M1 当前任务和状态。
4. 当前任务引用的设计文档。

### M1 规划文档

| 文档 | 用途 |
|---|---|
| [`Docs/M1/00_M1_ROADMAP.md`](Docs/M1/00_M1_ROADMAP.md) | 阶段、实施顺序和里程碑保护 |
| [`Docs/M1/01_M1_PRODUCT_SCOPE.md`](Docs/M1/01_M1_PRODUCT_SCOPE.md) | 四星 Demo 产品范围与完成定义 |
| [`Docs/M1/02_M1_TECHNICAL_DELTA.md`](Docs/M1/02_M1_TECHNICAL_DELTA.md) | schema v2、多星球、路线模板和系统增量 |
| [`Docs/M1/03_M1_CONTENT_PLAN.md`](Docs/M1/03_M1_CONTENT_PLAN.md) | 主线、支线、回访、角色与内容预算 |
| [`Docs/M1/04_WHITE_NOISE_PLANET_PACKET.md`](Docs/M1/04_WHITE_NOISE_PLANET_PACKET.md) | 第一颗新增星球的 PROVISIONAL 工作包 |
| [`Docs/M1/05_M1_GATES_AND_TESTING.md`](Docs/M1/05_M1_GATES_AND_TESTING.md) | Gate E–J 与测试策略 |
| [`Docs/M1/06_M1_DECISIONS.md`](Docs/M1/06_M1_DECISIONS.md) | M1 增量决定与开放问题 |

### 长期设计文档

| 文档 | 用途 |
|---|---|
| [`Docs/00_GAME_VISION.md`](Docs/00_GAME_VISION.md) | 产品愿景、支柱和非目标 |
| [`Docs/01_NARRATIVE_BIBLE.md`](Docs/01_NARRATIVE_BIBLE.md) | 正史、暂定故事、角色与四星框架 |
| [`Docs/02_CORE_GAMEPLAY.md`](Docs/02_CORE_GAMEPLAY.md) | 核心循环、订单、成长、失败与辅助 |
| [`Docs/03_FLIGHT_MODEL.md`](Docs/03_FLIGHT_MODEL.md) | 飞行、资源、危险和参数基线 |
| [`Docs/04_DEMO_SCOPE.md`](Docs/04_DEMO_SCOPE.md) | M0、M1、M2+ 范围边界 |
| [`Docs/05_TECHNICAL_DESIGN.md`](Docs/05_TECHNICAL_DESIGN.md) | Godot 架构、数据、存档和测试 |
| [`Docs/06_CONTENT_PIPELINE.md`](Docs/06_CONTENT_PIPELINE.md) | Planet/Order/Character Packet 与资产流程 |
| [`Docs/07_ITERATION_WORKFLOW.md`](Docs/07_ITERATION_WORKFLOW.md) | 单任务循环、Gate 和 Git 规则 |
| [`Docs/08_DECISION_LOG.md`](Docs/08_DECISION_LOG.md) | 全项目长期决定与人工验收历史 |
| [`Docs/09_DEPENDENCY_LOG.md`](Docs/09_DEPENDENCY_LOG.md) | 第三方依赖记录 |
| [`Docs/10_ART_DIRECTION.md`](Docs/10_ART_DIRECTION.md) | 像素复古科幻视觉规范 |

M1 首次启动提示：[`Prompts/CODEX_M1_START.md`](Prompts/CODEX_M1_START.md)。

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

## 当前已完成的 M0 内容

- 快递站大厅、老皮教程、订单终端和飞船配置。
- 第一人称驾驶舱、导航、旅行和老皮互动。
- 赤砂星从星系外缘到着陆的完整路线。
- 飞船推力、刹车、俯仰、重力、阻力、Boost、有限倒车和辅助驾驶。
- 护盾、船体、燃料、Boost、货物完整度与统一伤害顺序。
- 持续激光 Beam，只打明确环境目标。
- 赤砂星维修场、伊娅、结算、信用点、纪念物和返站变化。
- 版本化存档、备份恢复、新游戏和继续游戏。
- 50 套测试与完整 M0 闭环烟雾基线。

## 开发原则

- M0 是回归基线，不因 M1 内容扩展无理由重写。
- 新星球先完成内容包与灰盒，再制作专属美术。
- 星球差异必须同时包含自然、人文、角色、货物与飞行。
- 主线必需模块和许可必须有确定获取路径。
- 支线提供角色、探索、图鉴与替代路径，不成为刷取劳动。
- 玩家可见文本使用本地化 Key；新增脚本默认静态类型。
- 新依赖先记录原因、许可证、替代方案和移除成本。
- 仅主 Agent 在测试通过后创建聚焦中文提交。

---

## English Summary

**Universe Deliver** is a narrative-first 2D retro-futuristic space courier road game. M0, a complete single-order vertical slice centered on Red Sand, is finished. The current milestone is **M1: Four-Planet Demo**, adding White Noise, Canopy World, and Tidal Archipelago, plus revisits, side orders, low-altitude drops, light ship/station progression, relationships, permits, codex entries, and a first clear reveal of the ancient Relay Lattice.
