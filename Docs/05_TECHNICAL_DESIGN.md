# 05 — Technical Design / 技术设计

## 1. 技术基线

| 项目 | 决定 |
|---|---|
| Engine | Godot 4.7.1 stable |
| Language | GDScript，默认静态类型 |
| Renderer | Compatibility |
| Project type | 纯 2D |
| Internal viewport | 640×360，16:9 |
| Stretch | viewport + keep + fractional fit；精确倍数尺寸自然为整数比例 |
| Texture filtering | Nearest，像素素材关闭不必要 mipmap |
| Primary platform | macOS / Apple Silicon，本地原型 |
| Primary input | 键盘与鼠标 |
| Target frame rate | 60 FPS |
| External dependencies | 默认 0；引入前记录 |

Godot 版本锁定到 4.7.1，不在开发中自动升级。升级必须单独任务、完整检查并记录 Decision Log。

## 2. 项目设置原则

项目初始化时通过 Godot 编辑器或明确的 `project.godot` 配置完成：

- Base viewport 640×360。
- Stretch mode：`viewport`。
- Stretch aspect：`keep`。
- Stretch scale mode：`fractional`，以便真全屏使用最大 16:9 区域；1280×720 等精确倍数尺寸的实际比例仍为整数。
- Compatibility rendering method。
- 默认纹理过滤 nearest。
- 2D 像素吸附/相机策略由实际运动测试决定，不盲目开启所有 snap 选项。
- 初始窗口可使用 1280×720，方便 2× 预览。
- `toggle_fullscreen` Input Map action 默认绑定 F11，切换实际全屏；保持 16:9，不裁切、不变形。

### 2.1 模态 UI 优先级

大厅中的对话、订单终端、飞船工作台和出发确认共用场景级模态协调规则：

- 任一模态打开时隐藏场景交互提示和非必要目标条，冻结世界移动与交互。
- 打开模态的同一次输入不得继续推进该模态内容。
- 多个模态交接时按来源 ID 去重并保持锁定，最后一个模态关闭后才恢复世界。
- 关闭后重新检测玩家当前交互范围；仍在范围内才恢复提示，同时恢复模态期间更新后的目标内容。

目标条默认不超过 640×360 安全宽度约 40%，最多两行，并避开大厅中央通路与角色/目标聚集区。

不要用 CRT 模糊、色差或全屏噪点掩盖像素不一致。文字必须清晰。

## 3. 推荐目录

```text
project.godot
README.md
AGENTS.md
CODEX_GOAL.md
DEVELOPMENT_TASKS.md
ATTRIBUTION.md

scenes/
  app/
    app.tscn
    main_menu.tscn
  station/
    station_hub.tscn
    station_player.tscn
  cockpit/
    cockpit.tscn
  flight/
    flight_ship.tscn
    flight_level.tscn
    flight_lab.tscn
  arrival/
    red_sand_arrival.tscn
  narrative/
    dialogue_ui.tscn
  ui/
    flight_hud.tscn
    order_terminal.tscn
    ship_loadout.tscn
    settings_menu.tscn

scripts/
  app/
  core/
  data/
  station/
  cockpit/
  flight/
  narrative/
  ui/
  tools/
  check_project.sh

data/
  planets/
  orders/
  cargo/
  modules/
  characters/
  dialogue/
  localization/
  tuning/

assets/
  art/
    characters/
    ships/
    station/
    planets/
    ui/
    vfx/
  audio/
    music/
    ambience/
    sfx/
    voice_placeholder/
  fonts/

tests/
  test_runner.gd
  unit/
  smoke/
  fixtures/

Docs/
Prompts/
```

目录按职责组织，不为每个单节点建立深层目录。场景与脚本可相邻或按上述方式分开，但一旦 T-002 锁定，不频繁重排。

## 4. 应用场景架构

### 4.1 App Shell

`app.tscn` 作为持久根节点：

```text
App
├── SceneContainer
├── PersistentUI
├── TransitionLayer
└── DebugLayer
```

`SceneRouter` 将以下阶段场景装入 `SceneContainer`：

- Main Menu
- Station
- Cockpit
- Flight
- Arrival
- Results

切换规则：

- 使用淡入淡出/加载提示，但 M0 不追求无加载无缝。
- 旧阶段场景完全释放。
- 运行时数据先写入 `GameState`，不通过保留旧场景节点传递。
- Scene Router 不包含订单、剧情或飞行规则。

### 4.2 最小 Autoload

建议仅使用：

1. `SceneRouter`：阶段场景切换。
2. `GameState`：当前会话与进度的运行时模型。
3. `SaveService`：存档读写、版本与备份。
4. `SettingsService`：本机设置与辅助选项。
5. `AudioService`：音乐/环境跨场景过渡；仅在确有需要时加入。

不要创建全局 EventBus 作为默认通信方式。优先使用局部信号、节点引用和明确服务接口。

## 5. 运行时状态模型

建议将可序列化的数据与场景节点分开。

### 5.1 `GameProgress`

长期进度：

```text
schema_version
player_name
story_flags
completed_order_ids
unlocked_planet_ids
credits
owned_module_ids
station_upgrade_ids
relationship_values
codex_entries
read_dialogue_ids
```

### 5.2 `OrderRunState`

当前订单临时状态：

```text
order_id
cargo_integrity
hull
shield
fuel
boost_energy
active_checkpoint_id
entry_style
collision_count
elapsed_time
optional_trigger_ids
result_tags
```

离开/完成订单后转成结算结果，不把整棵场景树存档。

### 5.3 `ShipLoadout`

```text
ship_id  # M0 固定一个
power_module_id
defense_module_id
utility_module_ids
computed_stats
```

`computed_stats` 可运行时重算，存档只保存稳定模块 ID。

## 6. 数据定义

使用自定义 Resource（`.tres`）作为 M0 首选，因为：

- 可在 Inspector 中编辑。
- 文本格式可版本控制。
- 类型与资源引用清楚。
- 不需要外部数据库。

### 6.1 `PlanetDefinition`

核心字段：

```text
id: StringName
display_name_key: StringName
description_key: StringName
gravity_scale: float
flight_environment_profile: FlightEnvironmentProfile
required_story_flags: Array[StringName]
scene_paths / route ids
art_palette_id: StringName
music_theme_id: StringName
```

### 6.2 `OrderDefinition`

```text
id
order_type  # MAIN / SIDE
sender_character_id
recipient_character_id
destination_planet_id
cargo_id
reward_credits
required_module_ids
recommended_module_ids
delivery_method
customer_history_keys
story_requirements
completion_flags
```

### 6.3 `CargoDefinition`

```text
id
name_key
company_description_key
story_description_key
icon
boost_policy
impact_tolerance
risk_tags
required_delivery_method
```

### 6.4 `ShipModuleDefinition`

```text
id
slot_type
name_key
description_key
stat_modifiers
capability_tags
cost
story_unlock_flags
```

### 6.5 ID 规则

- 使用稳定英文 `snake_case`，例如 `planet_red_sand`。
- 显示名改变不改变 ID。
- 引用必须由测试验证。
- 删除已进入存档的 ID 前必须提供迁移或兼容映射。

## 7. 叙事与本地化

### 7.1 本地化

- 玩家文本全部使用 Key。
- 中文为源语言。
- 英文列可先为占位，但 Key 必须稳定。
- UI 数值使用格式化模板，不拼接不可翻译语序。
- 测试检查缺失 Key。

### 7.2 对话数据

M0 使用自有轻量结构，不引入大型插件。

建议：

```text
DialogueSequence
  id
  lines[]

DialogueLine
  speaker_id
  text_key
  portrait_expression
  conditions[]
  effects[]
  choices[]
```

条件和效果限制为白名单，例如：

- 检查剧情标记。
- 检查装备模块。
- 检查进入风格。
- 设置剧情标记。
- 调整关系值。
- 发出流程事件。

不要在对话数据中执行任意脚本字符串。

## 8. 飞行架构

### 8.1 场景组合

```text
FlightLevel
├── ParallaxBackground / BackgroundLayers
├── EnvironmentDirector
├── RouteGeometry
├── HazardContainer
├── CheckpointContainer
├── DeliveryTarget
├── FlightShip
├── CameraRig
├── FlightHUD
└── AudioLayers
```

### 8.2 `FlightShip`

```text
FlightShip (CharacterBody2D)
├── VisualRoot
│   ├── ShipSprite
│   ├── EngineVFX
│   └── ShieldVFX
├── CollisionShape2D
├── LaserOrigin
├── Sensors
└── Audio
```

职责拆分：

- `flight_ship_controller.gd`：读取 action、协调组件。
- `flight_motion_model.gd` 或纯函数类：计算力与积分。
- `flight_resources.gd`：资源变化。
- `flight_collision_resolver.gd`：碰撞分级。
- `flight_style_tracker.gd`：DIVE/GLIDE/BALANCED。
- `flight_tuning.gd` Resource：全部手感参数。

M0 可以先以较少脚本实现，但必须保持运动公式可独立测试。

### 8.3 环境分区

- `Area2D` 提供当前环境阶段和参数目标。
- `EnvironmentDirector` 处理多个 Area 重叠的优先级与平滑过渡。
- 地形使用 TileMapLayer、StaticBody2D、CollisionPolygon2D 等组合。
- 雷达使用 Area2D/ShapeCast 与地形遮挡的简化规则，不做完整 AI 感知。
- 检查点只保存稳定运行状态，不复制场景实例。

## 9. 大厅与目的地区域

- 玩家使用 `CharacterBody2D`。
- 通用互动采用小型接口/组件，例如 `get_interaction_prompt()` 与 `interact(actor)`。
- 互动选择使用距离、视线/朝向和明确优先级。
- 老皮 M0 可使用脚本化站位和简单移动，不需要 NavigationAgent。
- 小型目的地区域复用同一玩家与互动系统。

## 10. 驾驶舱

驾驶舱是 Control/Node2D 组合，而不是 3D：

- 背景与仪表分层。
- 交互热点使用大尺寸 Control 区域或 Area2D。
- 支持鼠标 hover、点击和键盘焦点。
- 窗外星空通过低成本视差/粒子播放。
- 旅行由 `TravelSequenceController` 按阶段触发视觉、音频和对话。
- 旅行结束只传递目的地与订单状态到 Scene Router。

## 11. 存档

### 11.1 格式

M0 建议使用 JSON 或 Godot `Variant` 可读格式。优先可检查、可迁移：

```json
{
  "schema_version": 1,
  "game_progress": {},
  "last_saved_at": "...",
  "build_version": "..."
}
```

### 11.2 安全写入

1. 将新内容写入临时文件。
2. 验证能重新解析。
3. 将现有主档复制/移动为备份。
4. 原子替换或尽可能安全地替换主档。
5. 加载失败时尝试备份。

不要因一次写入中断覆盖最后可用档。

### 11.3 迁移

- 每次 schema 变化增加版本。
- 使用逐版本迁移函数。
- 缺字段使用明确默认值。
- 无法迁移时保留坏档并提示，不静默清空。

## 12. 设置存储

设置与剧情存档分开：

- 音量。
- 屏幕震动。
- 文字速度。
- 输入映射。
- 辅助驾驶强度。
- 慢动作、路线提示、高对比地形。

新游戏不重置本机设置。

## 13. 音频架构

Bus 建议：

```text
Master
├── Music
├── Ambience
├── SFX
└── UI
```

若后续有配音再加入 Voice。

- 驾驶舱、空间、大气、地表使用环境层渐变。
- 音乐支持安全/接近/危险的分层或交叉淡化。
- 不从多个场景各自启动同一首音乐导致叠加。
- 关键警告音不与对白提示频繁冲突。

## 14. 测试策略

### 14.1 无第三方测试运行器

`tests/test_runner.gd` 继承 `SceneTree`，发现约定测试并以退出码报告结果。

推荐命令：

```bash
"${GODOT_BIN:-godot}" --headless --path . --import
"${GODOT_BIN:-godot}" --headless --path . --script res://tests/test_runner.gd
```

可对关键独立脚本使用 `--check-only --script`。实际 `scripts/check_project.sh` 以 Godot 4.7.1 验证后的参数为准。

### 14.2 单元测试

覆盖：

- ID 注册与数据引用。
- 订单状态机。
- 报酬计算。
- 飞行力计算、辅助重力、终端速度。
- 碰撞分级。
- 资源消耗。
- 进入风格分类。
- 存档迁移与坏档恢复。

### 14.3 烟雾测试

- Main 场景实例化。
- Station/Cockpit/Flight/Arrival 场景实例化。
- 场景切换顺序。
- 最小订单从接取到完成的状态模拟。

自动测试不声称验证手感、美术和剧情质量。

## 15. `check_project.sh` 预期

脚本应：

1. 定位 Godot 可执行文件：优先 `GODOT_BIN`，其次 `godot`/`godot4`。
2. 验证版本符合 4.7.1；不一致时至少警告，重大版本不一致应失败。
3. 执行 headless import。
4. 运行测试运行器。
5. 检查 `git diff --check`。
6. 汇总清晰结果并返回正确退出码。

不在脚本中自动安装 Godot、插件或系统依赖。

## 16. 性能预算

M0 目标：M1 Max 本地运行稳定 60 FPS，并保留未来低配优化余量。

工作预算：

- 避免每帧创建大量临时对象。
- 粒子和陨石数量有上限。
- 长关卡按段启用/停用内容，不需要大型开放世界流送系统。
- 背景使用适量 Parallax2D/CanvasLayer，避免巨幅无压缩纹理。
- 音频预加载和流式播放按资源长度选择。
- 不因预想性能问题提前实现复杂对象池；实际 profiler 证明后再做。

人工路线试玩记录：

- 明显卡顿位置。
- 场景切换等待。
- 大量粒子/雷暴时帧率。
- 内存增长和场景释放。

## 17. 调试工具

开发构建允许：

- 直接进入任一 M0 阶段。
- 选择测试订单。
- 切换飞行环境层。
- 调整飞行参数。
- 补满/降低资源。
- 跳到检查点。
- 显示碰撞层和交互热点。
- 显示剧情标记与订单状态。

调试入口不得默认出现在普通玩家界面，也不得成为主流程必需条件。

## 18. 依赖策略

初始第三方依赖为 0。

引入前必须回答：

- Godot 内置功能为什么不足？
- 依赖是否维护到 Godot 4.7？
- 许可证是否允许目标发布？
- 是否会污染核心存档/数据格式？
- 能否在 1–2 个提交内移除？
- 谁负责后续升级？

记录到 `09_DEPENDENCY_LOG.md` 后再引入。

## 19. Git 与二进制资产

- 提交 `.tscn`、`.tres`、脚本和源素材。
- 忽略 `.godot/`、日志、临时文件和导出产物。
- 大型音频/源图明显增长后再评估 Git LFS，不从第一天强制。
- 外部资产必须同步更新 `ATTRIBUTION.md`。
- 主 Agent 在测试通过后统一提交。

## 20. 已知技术风险

| 风险 | 缓解 |
|---|---|
| 横版飞行手感反复 | Flight Lab、集中 FlightTuning、早期人工 Gate |
| 640×360 中文 UI 拥挤 | 早期真实中文测试、分层信息、较高分辨率像素字 |
| 长关卡尺度失控 | 电影化压缩、阶段式环境、6–10 分钟 M0 上限 |
| 对话系统过度开发 | 白名单条件/效果、无可视化编辑器、M0 只做必要功能 |
| Autoload 膨胀 | 只保留跨场景服务，业务逻辑留在系统/数据对象 |
| AI 生成资产风格不一 | Art Bible、尺寸模板、统一调色与人工审查 |
| 主线门槛形成刷取 | 确定获取路径、无随机关键模块、经济安全网 |
| Godot 升级破坏 | 锁定 4.7.1，升级单独任务和完整回归 |

## 21. 官方技术依据

项目创建时参考 Godot 官方文档：

- Godot release archive：确认锁定的稳定版本。
- Multiple resolutions：640×360、viewport stretch 与 integer/fractional scaling 的取舍；当前项目契约以第 2 节为准。
- CharacterBody2D：脚本控制的 2D 角色/载具运动基础。
- Command line tutorial：headless、`--path`、`--import`、`--script` 与退出码检查。
- Static typing in GDScript：新增脚本的类型策略。

实际配置以 Godot 4.7.1 编辑器生成和验证的设置名为准，不盲拷贝旧版本示例。
