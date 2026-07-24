# 《我在宇宙送快递》 / Universe Deliver

> 一款以星际配送为叙事载体的 2D 复古科幻公路游戏。

玩家是一名来自地球、被派往银河边境快递站的人类员工。站点里只有玩家和一名会说话、会直立行走的外星水豚同事——**老皮**。玩家在空间站大厅接单、配置唯一一艘长期陪伴自己的飞船，在可交互驾驶舱中经历宁静的星际旅行，再进入横向侧视飞行关卡，亲手完成从飞入星系、接近星球、穿越大气层到降落交货的全过程。

配送不是重复刷取随机词条的借口，而是认识不同文明、介入当地故事、推动主线并逐步发现宇宙秘密的方式。

## 当前阶段

| 项目 | 当前决定 |
|---|---|
| 已完成里程碑 | **M0：Playable Spine**，2026-07-24 通过完整人工验收 |
| 当前里程碑 | **M1：Four-Planet Demo** |
| 当前状态 | **规划完成，等待从 T-100 开始实施** |
| M1 核心内容 | 赤砂星基线 + 白噪星 + 穹林星 + 群潮星 + 回访、支线、升级与 Demo 结尾 |
| 引擎 | Godot 4.7.1 stable |
| 脚本语言 | GDScript，新增代码默认使用静态类型 |
| 渲染器 | Compatibility |
| 画面 | 16:9、640×360 内部分辨率；精确倍数窗口自然保持整数比例，真全屏使用最大 16:9 fractional fit，像素纹理 nearest |
| 首要平台 | macOS / Apple Silicon，本地 Demo |
| 首要输入 | 键盘与鼠标 |

## 里程碑状态

### M0 — Playable Spine：Done

M0 已打通并验收以下完整流程：

```text
快递站大厅
→ 老皮教程、接单和飞船配置
→ 第一人称驾驶舱旅行
→ 赤砂星完整横版进入与着陆
→ 居民维修场剧情
→ 结算、返站、纪念物
→ 保存与继续游戏
```

M0 的 `6/6` 阶段、`35/35` 任务与 Gate A–D 均已完成。历史任务记录保留在 [`DEVELOPMENT_TASKS.md`](DEVELOPMENT_TASKS.md)，该文件不再作为当前任务队列。

### M1 — Four-Planet Demo：Planning Ready

M1 要证明游戏能够用不同自然环境、文明、人物和飞行机制组成一条有起承转合的主线，而不是只完成一颗赤砂星。

主线顺序：

```text
赤砂星首单（M0 已完成）
→ 白噪星
→ 赤砂星回访
→ 穹林星
→ 群潮星高潮
```

M1 的目标包括：

- 四颗可进入的主线星球。
- 约 4–6 份主线/章节订单与 4–6 份成本受控的支线订单。
- 至少一次具有可见变化的赤砂星回访。
- 着陆与低空投放两种正式交付方式。
- 飞船模块、信用点、通行许可、关系、图鉴和快递站变化形成初步成长闭环。
- 古老中继网的第一层明确揭示与 Demo 悬念结尾。
- 首次主线体验约 2–4 小时。

M1 仍不加入完整敌人战斗、多飞船购买、程序生成路线、多单同时配送或复杂贸易。

## 当前文档入口

主 Agent 每次开始工作时按以下顺序阅读：

1. [`AGENTS.md`](AGENTS.md)：仓库级长期规则和 M1 范围保护。
2. [`CODEX_GOAL.md`](CODEX_GOAL.md)：M1 产品目标与完成定义。
3. [`M1_DEVELOPMENT_TASKS.md`](M1_DEVELOPMENT_TASKS.md)：当前可执行任务及状态。
4. 当前任务引用的 `Docs/` 与 `Docs/M1/` 文档。
5. `git status`、近期相关提交和当前实现。

主要 M1 文档：

| 文档 | 用途 |
|---|---|
| [`Docs/M1/README.md`](Docs/M1/README.md) | M1 文档索引与阅读顺序 |
| [`Docs/M1/00_M1_ROADMAP.md`](Docs/M1/00_M1_ROADMAP.md) | 阶段、内容预算、交付顺序和成功标准 |
| [`Docs/M1/01_M1_STORY_BEATS.md`](Docs/M1/01_M1_STORY_BEATS.md) | M1 暂定主线节拍、角色与中继网揭示边界 |
| [`Docs/M1/02_M1_DECISIONS.md`](Docs/M1/02_M1_DECISIONS.md) | M1 已锁定工作决定与开放问题 |
| [`Docs/11_M1_TECHNICAL_DELTA.md`](Docs/11_M1_TECHNICAL_DELTA.md) | 相对 M0 的存档、路线、订单、升级和测试增量 |
| [`Docs/12_M1_ITERATION_GATES.md`](Docs/12_M1_ITERATION_GATES.md) | M1 的 Gate E–I 人工试玩节点 |
| [`Docs/M1/PLANET_WHITE_NOISE.md`](Docs/M1/PLANET_WHITE_NOISE.md) | 白噪星 Planet Packet |
| [`Docs/M1/PLANET_RED_SAND_REVISIT.md`](Docs/M1/PLANET_RED_SAND_REVISIT.md) | 赤砂星回访、成长中场与投放候选 |
| [`Docs/M1/PLANET_CANOPY_WORLD.md`](Docs/M1/PLANET_CANOPY_WORLD.md) | 穹林星 Planet Packet |
| [`Docs/M1/PLANET_TIDAL_ARCHIPELAGO.md`](Docs/M1/PLANET_TIDAL_ARCHIPELAGO.md) | 群潮星 Planet Packet |
| [`Prompts/CODEX_M1_START.md`](Prompts/CODEX_M1_START.md) | M1 首次 Codex 开发会话启动 Goal |

长期基础文档继续有效：

- [`Docs/00_GAME_VISION.md`](Docs/00_GAME_VISION.md)
- [`Docs/01_NARRATIVE_BIBLE.md`](Docs/01_NARRATIVE_BIBLE.md)
- [`Docs/02_CORE_GAMEPLAY.md`](Docs/02_CORE_GAMEPLAY.md)
- [`Docs/03_FLIGHT_MODEL.md`](Docs/03_FLIGHT_MODEL.md)
- [`Docs/04_DEMO_SCOPE.md`](Docs/04_DEMO_SCOPE.md)
- [`Docs/05_TECHNICAL_DESIGN.md`](Docs/05_TECHNICAL_DESIGN.md)
- [`Docs/06_CONTENT_PIPELINE.md`](Docs/06_CONTENT_PIPELINE.md)
- [`Docs/07_ITERATION_WORKFLOW.md`](Docs/07_ITERATION_WORKFLOW.md)
- [`Docs/08_DECISION_LOG.md`](Docs/08_DECISION_LOG.md)
- [`Docs/09_DEPENDENCY_LOG.md`](Docs/09_DEPENDENCY_LOG.md)
- [`Docs/10_ART_DIRECTION.md`](Docs/10_ART_DIRECTION.md)

若旧文档中的 M0 暂定描述与 `Docs/M1/` 中的当前 M1 工作方案冲突，以更具体、更新的 M1 文档和最新 Decision Log 为准；不得因此静默改写 LOCKED 正史。

## 运行方式

请使用 Godot `4.7.1-stable`：

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"

# 打开编辑器
"${GODOT_BIN:-godot}" --editor --path .

# 运行仓库检查
./scripts/check_project.sh

# 启动当前主场景
"${GODOT_BIN:-godot}" --path .
```

运行中按 `F11` 可切换真全屏。画面保持 16:9，不裁切、不拉伸变形。

## 开发原则

- M0 是已验收回归基线，不因制作新星球而随意拆改。
- M1 先建立共享数据、存档迁移和内容模板，再制作白噪星。
- 每颗星球必须同时改变自然环境、文明冲突、货物意义、飞行机制、人物和声音/视觉。
- 先完成 Planet Packet、Order Packet 和 Character Packet，再投入高成本关卡与资产。
- 一次只完成一个 Ready 任务；到达人工 Gate 后停止扩展。
- 主线失败不得造成经济死档。
- 玩家可见文本使用本地化 Key；新依赖必须先记录。
- 仅主 Agent 在适用检查通过后统一提交，提交信息优先中文。

---

## English Summary

**Universe Deliver** is a narrative-first 2D retro-futuristic space courier road game. M0, the complete Red Sand single-order playable spine, is finished and human-approved. The project is now entering **M1: Four-Planet Demo**, which adds White Noise, Canopy World, Tidal Archipelago, a Red Sand revisit, side deliveries, progression, codex/collectibles, a second delivery method, and a story climax that clearly reveals the ancient relay network for the first time.

M1 planning is complete; implementation should begin from `T-100` in `M1_DEVELOPMENT_TASKS.md`.