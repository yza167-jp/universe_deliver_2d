# 06 — Content Pipeline / 内容生产流程

## 1. 目标

内容生产必须同时满足：

- 星球具有自然与文明双重差异。
- 订单、货物、飞行机制和剧情互相解释。
- Codex 能根据明确数据与模板实现，而不擅自扩写正史。
- 生成式占位素材可以快速进入游戏，但来源、尺寸和风格可追踪。
- 内容可逐步替换为人工美术，不要求重写系统。

## 2. 内容状态

所有内容条目标记：

- `concept`：概念草案，不进入游戏。
- `approved_placeholder`：可用于当前原型的占位内容。
- `production`：已进入制作，修改需记录影响。
- `review`：等待叙事/美术/玩法检查。
- `locked_for_milestone`：当前里程碑冻结，只修错误。
- `final_candidate`：可能用于发布，但仍需最终许可与一致性检查。

“生成出来了”不等于“已批准”。

## 3. 星球内容包

每颗主线星球先建立一份 Planet Packet，再创建关卡。

### Planet Packet 模板

```markdown
# Planet: <name>

## Canon status
Locked / Provisional

## One-sentence identity
一句话说明自然、文明与冲突。

## Narrative role
它在主线中揭示什么？玩家关系如何变化？

## Natural environment
- 重力
- 大气
- 天气
- 地形
- 生态
- 昼夜/光照

## Civilization
- 主要聚落与建筑
- 交通/物流方式
- 社会制度与劳动
- 技术与审美
- 对银河外卖公司的态度

## Local conflict
当前具体冲突，不写空泛历史。

## Flight identity
- 星系接近
- 大气层危险
- 地表路线
- 独特机制
- 俯冲与缓降差异

## Main order
- 货物
- 发件人/收件人
- 公司描述
- 实际意义
- 必须/推荐模块
- 交付方式

## Characters
核心 NPC 及回访变化。

## Arrival scene
场景式对话与小型步行区域。

## Revisit seed
玩家以后为何回来？看见什么变化？

## Art package
色彩、背景层、建筑轮廓、UI/图标、角色需求。

## Audio package
环境音、主题动机、危险层变化。

## Scope budget
本里程碑制作上限。
```

未完成 Planet Packet，不开始高成本最终资产。

## 4. 订单内容包

每份主线订单必须通过三个问题：

1. 为什么这件东西需要跨星际配送？
2. 为什么它必须由玩家亲自完成最后一程？
3. 它如何让玩家认识收件人或当地冲突？

### Order Packet

```markdown
# Order: <id>

## Role
Main / Side

## Visible brief
玩家接单前能看到的信息。

## Customer history
最多 3–5 条有意义记录。

## Cargo identity
名称、用途、物理/信号特性。

## Company description vs reality
是否存在差异，差异为何有意义。

## Flight constraints
Boost、碰撞、扫描、环境、时间。

## Required/recommended loadout
主线必须配置必须有确定获取路径。

## Route beats
每个阶段发生什么。

## Delivery method
着陆/空投/检查门/对接。

## Arrival story
收件人目标、冲突、玩家局部选择。

## Failure and partial success
主线如何保底；支线如何减报酬。

## Rewards
信用点、许可、关系、模块、纪念品、图鉴。

## Revisit consequences
后续可见变化。
```

## 5. 角色内容包

### Character Packet

```markdown
# Character: <id>

## Canon status

## Role in story

## Species / origin

## Current concrete goal

## Daily-life detail

## Relationship to local civilization

## Relationship to company/logistics

## First impression vs deeper trait

## Speech pattern
- 句长
- 正式程度
- 幽默方式
- 禁用表达

## Visual silhouette

## Key expressions/poses

## First meeting

## Revisit state

## Story flags read/written
```

每个主要 NPC 至少有一个当前目标、一个日常细节、一个立场和一个回访变化。

## 6. 对话生产

### 6.1 写作顺序

1. 写场景目的：玩家进入前知道什么，离开后知道/感受什么。
2. 写角色各自目标。
3. 写 5–10 行最短可用版本。
4. 加入必要选择与条件反馈。
5. 在游戏真实分辨率中测试节奏和换行。
6. 才补充可选内容、表情和环境动作。

不要先写数百行再做系统。

### 6.2 单场景预算

M0 建议：

- 老皮教程：分成多个短段，每段 4–10 行。
- 驾驶舱必触发对话：约 8–16 行。
- 可选驾驶舱互动：每个 3–8 行。
- 赤砂星主要交付：约 20–40 行，按节奏拆段。
- 可选环境对话：3–10 行。

这是工作预算，不是硬上限。避免一屏连续长篇说明。

### 6.3 选择

- 常规 2–3 个。
- 主要表达态度或局部立场。
- 选择后至少有一行明确回应。
- 仅在真正改变后续内容时设置剧情标记。
- 不为虚假分支创建大量重复文本。

### 6.4 文本检查

- 是否符合角色语气。
- 是否在玩家需要操作时过长。
- 是否把玩法信息埋在笑话里。
- 是否重复解释同一世界观。
- 是否使用未锁定正史。
- 中文 UI 是否溢出。
- 英文本地化 Key 是否存在。

## 7. 数据落地

- 概念文档存于 `Docs/` 或专用 content 文档。
- 进入游戏的定义使用 `.tres` Resource。
- 玩家可见文本进入本地化表。
- 场景只引用稳定 ID/Resource，不复制长文本。
- 每次新增数据运行引用验证。
- 不把 Excel/Notion 等外部平台作为唯一真源；当前仓库必须可独立构建。

## 8. 美术生产阶段

### 8.1 Graybox

- 几何图形、纯色块、简单 Tile。
- 目标是尺寸、碰撞、镜头和流程。

### 8.2 Generated Placeholder

由图像生成工具或现有免费素材快速提供：

- 角色概念。
- 背景层。
- 飞船轮廓。
- UI 装饰。
- 星球景观候选。

处理要求：

- 统一裁切到规定尺寸。
- 关闭平滑，按像素网格处理。
- 必要时降色、重描轮廓和修正透视。
- 记录为 `AI-generated placeholder`。

### 8.3 Style Pass

- 统一调色板。
- 统一轮廓粗细和像素密度。
- 修复生成式图像中的伪文字、畸形结构和不连续像素。
- 拆分可动画部件。
- 验证碰撞可读性。

### 8.4 Production Candidate

- 人工重绘或深度修正。
- 完成必要动画。
- 适配所有 UI/游戏场景。
- 许可和 Attribution 完整。
- 通过真实游戏截图审查，而不是只看单张图。

## 9. 资产清单与命名

命名示例：

```text
chr_lao_pi_station_idle.png
chr_lao_pi_cockpit_talk.png
ship_player_side_base.png
bg_red_sand_approach_far.png
bg_red_sand_clouds_mid.png
tile_red_sand_canyon_01.png
ui_order_terminal_frame.png
vfx_ship_boost_01.png
sfx_ship_engine_loop_01.ogg
mus_red_sand_approach_01.ogg
```

规则：

- 全英文小写 `snake_case`。
- 前缀表示类型：`chr_`、`ship_`、`bg_`、`tile_`、`ui_`、`vfx_`、`sfx_`、`mus_`。
- 不使用连续的 `final`、`new` 等无意义版本后缀。
- 迭代版本通过 Git 管理；仅同时保留确有用途的变体。

## 10. 像素资产尺寸建议

| 资产 | 工作尺寸 |
|---|---:|
| 大厅玩家 | 32×48 或 32×64 |
| 老皮大厅 Sprite | 40×48 或 48×64，保持水豚轮廓 |
| 飞船侧视 | 96–128 px 宽，约 40–64 px 高 |
| NPC 对话头像 | 96×96 或 128×128 |
| 重要角色半身立绘 | 192–256 px 高 |
| 物品/货物图标 | 32×32 或 48×48 |
| 模块图标 | 32×32 |
| UI 9-slice 边框 | 8/16 px 网格 |
| 小型环境道具 | 16–64 px 网格 |

尺寸可因视觉测试调整，但同类资产保持统一像素密度。

## 11. 关卡内容生产

### 11.1 先节奏、后美术

每条飞行路线先用灰盒定义：

- 阶段长度。
- 速度范围。
- 检查点。
- 危险预警距离。
- 俯冲/滑翔路线。
- 主要景观镜头。
- 对话/广播触发窗口。

玩家试玩确认后再制作专属背景和道具。

### 11.2 手工为主

M0/M1 采用手工路线和固定危险。可以写辅助脚本快速摆放重复道具，但不建立程序生成游戏系统。

### 11.3 复用规则

可复用：

- 飞行阶段框架。
- 危险组件。
- 相机、HUD、检查点、交付基类。
- 云、星空、通用粒子基础。

必须定制：

- 星球的地形节奏。
- 关键景观。
- 文明建筑轮廓。
- 主线货物和角色。
- 独特飞行机制。

## 12. 音频生产

### 音频层级

- 音乐：合成器浪潮、氛围电子、星球主题。
- 环境：站点机械、星际静噪、大气风、雷暴、当地生态/城市。
- 飞船：引擎、制动、Boost、护盾、碰撞、警报、激光。
- UI：终端、接单、导航、结算。
- 角色：可先使用文本提示音或非常轻量非语言声，不做配音承诺。

### 动态音乐

优先使用层或交叉淡化：

```text
safe / cruise
→ approach
→ danger / storm
→ landing resolution
```

不要为每个小状态切换整首音乐造成跳变。

外部音频必须记录来源、许可证和修改方式。

## 13. 内容评审清单

每个星球/订单进入里程碑冻结前检查：

- [ ] 自然、人文和冲突三者都存在。
- [ ] 货物限制有世界内解释。
- [ ] 飞行机制不是换皮。
- [ ] NPC 有具体目标和回访变化。
- [ ] 公司不是唯一信息来源。
- [ ] 主线失败不会死档。
- [ ] 辅助选项不破坏流程。
- [ ] 生成式资产已修正伪文字和风格问题。
- [ ] 所有第三方素材已记录。
- [ ] 中文文本在 640×360 实机测试。
- [ ] 内容状态已标记。
