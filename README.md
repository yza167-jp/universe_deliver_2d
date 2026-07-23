# 《我在宇宙送快递》 / Universe Deliver

> 一款以星际配送为叙事载体的 2D 复古科幻公路游戏。

玩家是一名来自地球、被派往银河边境快递站的人类员工。站点里只有玩家和一名会说话、会直立行走的外星水豚同事——**老皮**。玩家在空间站大厅接单、配置唯一一艘长期陪伴自己的飞船，在可交互驾驶舱中经历宁静的星际旅行，再进入横向侧视飞行关卡，亲手完成从飞入星系、接近星球、穿越大气层到降落交货的全过程。

配送不是重复刷取随机词条的借口，而是认识不同文明、介入当地故事、推动主线并逐步发现宇宙秘密的方式。

## 当前阶段

| 项目 | 当前决定 |
|---|---|
| 当前里程碑 | **M0：Playable Spine（首个完整可玩骨架）** |
| M0 核心内容 | 快递站大厅 → 接取订单 → 驾驶舱旅行 → 赤砂星完整飞行 → 落地剧情 → 结算返回 |
| 正式 Demo 目标 | **M1：Four-Planet Demo**，包含赤砂、冰原、巨型森林、海洋岛屿群四颗星球 |
| 引擎 | Godot 4.7.1 stable |
| 脚本语言 | GDScript，默认使用静态类型 |
| 渲染器 | Compatibility |
| 画面 | 16:9、640×360 内部分辨率；精确倍数窗口保持整数比例，真全屏使用最大 16:9 fractional fit，像素纹理 nearest |
| 首要平台 | macOS，本地原型；开发机为 M1 Max 64GB |
| 首要输入 | 键盘与鼠标 |
| 发布目标 | 先完成可试玩 Demo，再决定商业发行和其他平台 |

## 体验结构

```text
2D 俯视快递站大厅
→ 接单、与老皮交谈、查看客户历史、配置飞船
→ 2D 第一人称可交互驾驶舱
→ 宁静的星际旅行、途中对话与目的地设定
→ 横向侧视飞行关卡
→ 飞入星系、穿过陨石、接近星球、进入大气层
→ 俯冲或缓降、穿越地形与当地设施
→ 着陆、空投、检查门或对接等交付方式
→ 场景对话或小型可步行目的地区域
→ 结算、升级、返回快递站
```

游戏的情绪节奏是：

- 快递站与星际旅行：温暖、孤独、宁静、略带黑色幽默。
- 星球进入与地表飞行：壮丽、紧张、可完全操控。
- 目的地剧情：人物、文明与世界观优先。

## M0 成功标准

M0 不是四星 Demo，而是验证完整游戏脊柱的内部可玩版本。完成时必须满足：

1. 新玩家可以从主菜单开始，在快递站中通过老皮的引导接取第一份订单。
2. 玩家能在飞船配置界面确认货物和基础模块。
3. 玩家能在驾驶舱设置赤砂星为目的地，并经历至少一段可交互旅行对话。
4. 横版飞行从星系接近开始，而不是从地表直接开始。
5. 玩家能穿过陨石区、进入大气层、经历雷暴、选择俯冲或缓降，并最终降落。
6. 飞船具备油门、刹车、俯仰、重力、惯性、燃料、Boost、护盾、船体和货物完整度。
7. 可选激光炮只用于轰击陨石；星球地表剧情不包含战斗。
8. 交付后进入一段角色剧情，随后结算并返回快递站。
9. 游戏能够保存关键进度、无报错启动，并通过仓库自动检查。
10. 至少经过三个人工试玩节点：大厅循环、飞行手感、完整订单闭环。

## 仓库入口

主 Agent 每次开始工作时按以下顺序阅读：

1. [`AGENTS.md`](AGENTS.md)：长期稳定、不可违反的仓库规则。
2. [`CODEX_GOAL.md`](CODEX_GOAL.md)：当前产品目标和 M0 完成定义。
3. [`DEVELOPMENT_TASKS.md`](DEVELOPMENT_TASKS.md)：当前可执行任务及状态。
4. 与任务相关的 `Docs/` 文档。

主要文档：

| 文档 | 用途 |
|---|---|
| [`Docs/00_GAME_VISION.md`](Docs/00_GAME_VISION.md) | 产品愿景、体验支柱和非目标 |
| [`Docs/01_NARRATIVE_BIBLE.md`](Docs/01_NARRATIVE_BIBLE.md) | 已锁定设定、暂定故事骨架、角色与四星框架 |
| [`Docs/02_CORE_GAMEPLAY.md`](Docs/02_CORE_GAMEPLAY.md) | 完整玩法循环、订单、经济、失败与辅助选项 |
| [`Docs/03_FLIGHT_MODEL.md`](Docs/03_FLIGHT_MODEL.md) | 横版飞行控制、重力、阻力、资源和可调参数 |
| [`Docs/04_DEMO_SCOPE.md`](Docs/04_DEMO_SCOPE.md) | M0、M1 和 Demo 后范围边界 |
| [`Docs/05_TECHNICAL_DESIGN.md`](Docs/05_TECHNICAL_DESIGN.md) | Godot 架构、数据、场景、存档和测试策略 |
| [`Docs/06_CONTENT_PIPELINE.md`](Docs/06_CONTENT_PIPELINE.md) | 星球、订单、角色、剧情、美术与音频生产流程 |
| [`Docs/07_ITERATION_WORKFLOW.md`](Docs/07_ITERATION_WORKFLOW.md) | Codex 开发循环、测试、提交和人工试玩节点 |
| [`Docs/08_DECISION_LOG.md`](Docs/08_DECISION_LOG.md) | 已确认决定和仍开放问题 |
| [`Docs/09_DEPENDENCY_LOG.md`](Docs/09_DEPENDENCY_LOG.md) | 第三方依赖与引入理由记录 |
| [`Docs/10_ART_DIRECTION.md`](Docs/10_ART_DIRECTION.md) | 像素复古科幻视觉规范和四星美术方向 |

给 Codex 主 Agent 使用的启动提示见 [`Prompts/CODEX_M0_START.md`](Prompts/CODEX_M0_START.md)。

## 运行方式

请使用 Godot `4.7.1-stable`。若 Godot 不在 `PATH` 中，可先指定可执行文件：

```bash
export GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
```

随后在仓库根目录运行：

```bash
# 打开编辑器
"${GODOT_BIN:-godot}" --editor --path .

# 运行仓库检查
./scripts/check_project.sh

# 启动当前主场景
"${GODOT_BIN:-godot}" --path .
```

运行中按 `F11` 可切换真全屏；画面保持 16:9，不裁切、不拉伸变形。1280×720 等精确倍数窗口仍为整数比例，其他尺寸与真全屏使用最大可用 16:9 区域。

检查脚本会依次尝试 `GODOT_BIN`、`godot`、`godot4` 和 macOS 默认应用路径，并验证 Godot 版本、headless 导入、全部 GDScript 解析、测试及 Git 空白错误。

## 开发原则

- 先完成一条可玩的完整路径，再扩展星球数量。
- 叙事、角色和世界观优先于系统数量。
- 飞行必须可调、可读、可快速重试；不追求真实模拟。
- 允许占位素材，但从早期就要有基本粒子、音效和氛围。
- 不做随机刷取驱动的 Roguelike 循环。
- 不允许失败造成无法推进主线的经济死档。
- 新依赖必须先记录引入理由、替代方案和移除成本。
- 仅主 Agent 在测试通过后统一提交，提交信息优先使用中文。

---

## English Summary

**Universe Deliver** is a narrative-first 2D retro-futuristic space courier road game. The player is a human courier from Earth, assigned to a remote delivery station shared with Lao Pi, a talking upright alien capybara. The game alternates between a top-down station hub, an interactive first-person cockpit, fully controllable side-view planetary approach and landing sequences, and story-focused destination scenes.

The current target is **M0: Playable Spine**, a complete single-order loop centered on the desert planet Red Sand. The following milestone, **M1: Four-Planet Demo**, adds an ice world, a giant forest world, and an ocean archipelago world. Development uses Godot 4.7.1 stable, typed GDScript, a 640×360 16:9 pixel-art viewport with nearest filtering and largest-fit fullscreen scaling, and keyboard/mouse-first controls.
