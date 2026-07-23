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

所有可步行场景中的对话、观察文字、终端、结算和转场共用场景级优先级协调规则。
`SceneModalCoordinator` 提供最小通用实现；大厅使用
`StationModalCoordinator` 配置玩家与目标条，赤砂星维修场直接配置同一组件，
不创建全局 UI Manager：

- 任一优先级来源打开时隐藏场景交互提示和非必要目标条，并阻止同一交互点重复
  触发。
- 对话、终端、结算和转场属于阻塞模态，冻结世界移动与交互。
- 定时观察文字属于非阻塞观察：保持移动和其他非交互操作，空格/回车可提前
  关闭；输入关闭在下一帧才武装，避免打开内容的同一次按键立即关闭。
- 打开模态的同一次输入不得继续推进该模态内容。
- 多个来源交接时按来源 ID 去重；只要其中一个要求世界锁，阻塞锁就继续生效，
  最后一个来源关闭后才恢复提示与目标条。
- 关闭后重新检测玩家当前交互范围；仍在范围内才恢复提示，同时恢复模态期间更新后的目标内容。
- 定时观察计时结束、手动关闭、结算完成或转场失败后必须显式释放对应来源 ID，
  不能让隐藏提示或输入锁跨场景残留。

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
- 阶段局部的环境音、音乐、警报与临时特效必须在退出树时显式停止，不依赖旧节点
  延迟释放；M0 不因此提前引入全局音频服务。
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

将可序列化的数据与场景节点分开。

### 5.1 `GameProgress`（M0 schema v1）

当前版本化进度：

```text
schema_version
current_order_id
destination_id
cargo_id
ship_configuration  # 固定槽位到稳定模块 ID
story_flags
read_dialogue_ids
completed_order_ids
credits
station_upgrade_ids
departure_confirmed
travel_state
travel_destination_id
order_run_state
settings_reference  # 只引用独立本机设置，不嵌入其内容
```

玩家名、关系值、百科与更多星球解锁属于后续 schema；不要在 M0 为尚未出现的数据
搭建空框架。

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

离开/完成订单后保留必要的订单结果，不把整棵场景树存档。M0 的继续游戏固定回到
快递站稳定状态，不恢复驾驶舱、飞行、抵达或结算场景节点。

### 5.3 `ShipLoadout`

```text
ship_id  # M0 固定一个
power_module_id
defense_module_id
utility_module_ids
computed_stats
```

`computed_stats` 可运行时重算，存档只保存稳定模块 ID。M0 保留 `utility` 作为
激光炮的兼容挂点，并新增 `shield_backup_power` 作为第二功能挂点；旧 v1 存档
缺少后者时按空槽读取，不需要改变 schema。

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
configuration_slot_id  # 同类存在第二物理挂点时使用；否则回退到 slot_type
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
- `flight_resources.gd`：资源变化与统一普通飞行伤害入口。
- `flight_damage_result.gd`：单次事件实际护盾、船体、货物变化及失败标记。
- `flight_collision_resolver.gd`：碰撞分级。
- `flight_style_tracker.gd`：DIVE/GLIDE/BALANCED。
- `flight_tuning.gd` Resource：全部手感参数。

M0 可以先以较少脚本实现，但必须保持运动公式可独立测试。

### 8.3 Flight Lab 输入与诊断层

Flight Lab 的默认键位由 `SettingsService` 统一写入 Input Map；业务脚本只读取 action：

| Action | 默认输入 | 用途 |
|---|---|---|
| `flight_debug_toggle` | H | 显示/隐藏 Full Diagnostics |
| `flight_environment_cycle` | V | 切换深空/大气环境 |
| `flight_assist_cycle` | G | 循环三档重力补偿 |
| `flight_laser_toggle` | L | 安装/卸载调试激光模块 |
| `flight_route_hint` | Tab | 紧凑/展开 Gate B 路线卡 |
| `flight_restart` | R | 重置当前 Flight Lab 检查点 |
| `flight_fire` | F / 鼠标左键 | 共用 held 入口；短按短光柱、按住持续光柱 |
| `flight_controls_help` | C | 显示/隐藏可复用飞行控制帮助 |

旧存档若仍是精确的 F3–F6 默认绑定，由 `SettingsService` 一次性迁移到 H/V/G/L；自定义绑定不应被无条件覆盖。玩家可见文本不再提示 F3–F6。

飞行测试 HUD 分为两层：

- Essential Flight HUD 默认显示，保留方向速度、垂直速度、俯仰、环境、重力补偿名称、燃料/Boost、三项完整度与当前 Gate 目标。
- Full Diagnostics 默认隐藏，由 H 独立开关，保留角速度、重力/阻力、终端下降、资源速率、碰撞、检查点、激光和进入风格等内部遥测。
- Gate B 路线卡默认只显示进度、当前名称和一行提示，Tab 才展开五项清单；隐藏节点不得残留鼠标拦截区域。
- 正式星球路线复用同一分层契约：Essential 常驻显示带单位的距着陆点、速度和高度，Full Diagnostics 由 H 独立开关并保留内部 `px/s`、环境、资源、雷达和检查点遥测；两层使用独立节点，不能再把两行简略面板冒充完整诊断。

`FlightLabShip` 持有最小 held-fire 状态：按下 `flight_fire` 只启动一次
`FlightLaserWeapon` Beam，按住期间保持 active，松开时停止。武器每物理帧更新
连续视觉，同时用独立 `beam_damage_tick_seconds` 结算伤害；短按也复用同一状态，
不生成脉冲弹丸。重置、失败、暂停、窗口失焦、卸载模块或离场会清除 held、
Beam 和循环音，不增加第二套武器节点。

有限倒车仍由显式速度积分完成。进入阈值、反推倍率、倒车速度比例和制动力倍率统一位于 `FlightTuning` Resource；倒车输入或负本地前向速度会在资源结算前门控 Boost，避免消耗燃料或 Boost 能量。俯仰与相机不因倒车切换另一套方向或限制。

`FlightResources.apply_flight_damage()` 是碰撞、擦碰、雷暴和雷达脉冲的统一
普通伤害入口。它先以护盾吸收基础伤害，再把溢出应用到船体，并按溢出占基础
伤害的比例缩放该危险配置的完全穿透货损。调用方只消费返回的
`FlightDamageResult`，HUD 与公司警告显示其中的真实变化，不再按危险名猜测
固定扣值。高速致命碰撞可在统一结算后强制失败；着陆/配送结果的货损保持独立。

`FlightResources.step_shield_regeneration()` 消费已解析的备用电源能力、有效 Boost
状态、有限倒车状态和 `FlightTuning` 的 `2.5/s` 速率。`FlightLabShip` 在当帧
运动积分后调用它，因此 HUD 读取的护盾值与实际恢复一致；模块未装、护盾已满、
Boost 或倒车时恢复率均为 `0`。正式路线和 Flight Lab 都从同一
`ship_configuration + GameDataRegistry.modules` 解析能力。

### 8.4 环境分区

- `Area2D` 提供当前环境阶段和参数目标。
- `EnvironmentDirector` 处理多个 Area 重叠的优先级与平滑过渡。
- 地形使用 TileMapLayer、StaticBody2D、CollisionPolygon2D 等组合。
- 雷达使用固定 `Area2D` 扇区与统一 AGL 高度的显式状态机，不做地形遮挡潜行
  或完整 AI 感知。
- 检查点只保存稳定运行状态，不复制场景实例。

### 8.5 赤砂星灰盒路线

T-040 的标准 `FLIGHT` 场景使用 `FlightRouteDefinition` 与连续的
`FlightRouteSegment` 数据描述八个阶段。阶段边界只切换环境目标、记录当前
飞船检查点并更新灰盒反馈，不改写飞船位置、速度或姿态；环境数值继续由
`FlightLabShip` 平滑逼近。路线目标时长、总距离、星球视觉尺度、地表高度和
允许倒车距离均集中在 Resource 中。独立 Flight Lab 通过 debug 场景覆盖继续
保留，不与正式赤砂星路线共享 Gate B 任务状态。

T-045 Gate C 返工后，`FlightRouteDefinition` 集中保存名义快速/常规/观景
时长 `82 / 120 / 165 s`，八段边界集中在 `FlightRouteSegment`，当前总长
`38000 px`。各段另保存 `checkpoint_fuel_floor`，重试快照只在现有燃料低于
该值时向上保底。路线 HUD 显示经过时间与常规参考时长，不提供倒计时失败条件。

`RedSandRouteVisuals` 是完整星球圆盘与环境层的唯一阶段控制器，并持有纯逻辑
`RedSandOrbitTransitionModel`。阶段 1–3 仍按路线进度计算天体位置与尺度；从
路线 `11800 m` 到 `15800 m` 的 `4000 m` 连续窗口输出跨阶段的
`orbit_to_atmosphere_visual_progress`。圆盘、曲面地平线、大气辉光、高层云、
星空衰减、环境色调和入层粒子都消费该值；阶段标签仅改变玩法/文案，不直接
触发背景状态。以常规巡航 `316.67 m/s` 计算，名义时长约 `12.63 s`。模型只
接受单调递增的路线距离，因此短距离倒车不会让天体反向弹跳；阶段边界不创建
Tween，也不重设任何变换。

圆盘从过渡起点持续向 `(320, 612)` 移动并放大到 `7.0×`。曲面地平线不再是
固定 Canvas 多边形，而与 `PlanetAnchor` 共用位置、尺度和局部圆弧几何；完整
圆盘自然成为同一边缘的曲率地平线。Alpha 只有在可见弧面自然降到
`112→84 px` 后才淡出并关闭，不能代替几何移动。重开或检查点恢复调用同一
`reset_to_distance()` 精确恢复视觉进度、圆盘、地平线、辉光与星空状态。

`FlightRouteSegment.terrain_surface_enabled` 同时门控该段的 `FloorVisual`、
`FloorEdge` 与 `FloorBody`。赤砂星阶段 1–5 保持关闭，只保留背景和视觉危险；
阶段 6 的低层沙漠设施、阶段 7 准备走廊和阶段 8 着陆段才打开真实地表。
`floor_y` 在前段只用于灰盒几何/诊断，不再直接成为玩家可见高度。后段地表的
阻挡形状只沿可见 `FloorEdge` 生成 `SegmentShape2D`，禁止用向屏幕下方填充的
封闭 `CollisionPolygon2D` 产生不可见分段侧墙；每个阻挡体保存对应可见几何
路径，Full Diagnostics 记录最近碰撞名称、路径、layer/mask 与法线。

由于阶段 1–5 没有物理地表，飞船在重力下累计的世界 Y 不代表距固定地面的
高度。路线局部 `FlightSurfaceFrame` 在 `20000 m` 获取当前船底参考点与虚拟
高度，在第一段真实地表边界 `23000 m` 锁定 `surface_frame_offset_y`。该偏移
同时应用到 `RedSandRouteVisuals` 的阶段 6–8 地表/设施/标签、
`RedSandLowFlightCourse`、`RedSandLandingZone` 和 canonical 剖面；不得改变
飞船位置、速度或姿态。基线保持真实进入轨迹差异，只在预测入口低于
`180 m + downward_speed × 1.25 s` 时继续下移未来地表。偏移锁定后不再随
飞船追踪，检查点恢复沿用同一值；回到 `20000 m` 前的检查点才重置并重新获取。

`FlightAltitudeReferenceProvider` 是 HUD 与低空雷达的唯一高度源。实时入口只
接受 canonical route vertical frame：路线根把船体底部中心
`AltitudeReferencePoint` 转换为路线空间，同时以其实际 X 作为剖面查询距离、
以其 Y 作为 `ship_reference_route_y`，再由
`FlightRouteDefinition.get_ground_route_y(reference_distance, active_segment)` 加上
已锁定的 `surface_frame_offset_y` 查询地表 Y。相机、屏幕位置、视觉最大进度和
切段标签都不能改写这些输入；世界坐标
只用于专用地表层 RayCast。短距离倒车时，查询距离被限制在当前阶段的连续剖面，
不会跳回上一段或冻结在最大进度。

Provider 按阶段输出 `ORBITAL / ATMOSPHERE_ENTRY / AGL` 以及明确的
`source / is_valid / Final AGL / raw ray / raw profile / last valid /
invalid duration / failure reason`。阶段 1–3 返回无数值的高空状态；阶段 4–5
使用 `1800→1200→1050 m` 的虚拟剖面，并从阶段 5 的 `40%` 进度开始把同一
带偏移 canonical 地表剖面平滑混入，因此阶段 6 不替换飞船参考点，也不强制
重置高度或速度。

阶段 6–8 以路线剖面为确定性 Final AGL，向下射线验证物理表面；两源差异超过
`4 m` 即标记 `RAY_PROFILE_MISMATCH`。负 AGL、无剖面或不一致是无效状态，
真实 `0 m`/`1 m` 仍是合法高度，禁止用数值哨兵掩盖错误。瞬时无效最多以
`HOLD_LAST_VALID` 保持 `0.20 s`，随后进入 `INVALID` 并输出诊断；低空雷达仅在
当前源有效时评估阈值，HUD 与雷达逐帧读取同一个 Final AGL。平台顶面通过
`RedSandLandingZone` 覆盖同一参考点 X 的地表查询，而不是另建高度坐标；因此
船体俯仰导致船体中心先越过平台边缘时，RayCast 与剖面也不会分采两个表面。
Full Diagnostics
同时显示实际路线距离、飞船/地表 route Y、AGL 路线单位、剖面段、阶段 5→6
混合值、无效持续时间、射线路径及射线/剖面差值。Debug 路线还以 `0.45 s`
运动窗口检测“坐标预期变化但 Final AGL 固定”的不变量并输出完整快照。
移动 `StaticBody2D` 后，PhysicsServer2D 可能晚于脚本帧更新查询变换；最多四次
Provider 更新以剖面为权威并暂缓射线一致性验证，随后必须恢复 RayCast 交叉
验证。该窗口只处理服务器同步，不能吞掉负 AGL 或长期双源不一致。

### 8.6 赤砂星固定危险与环境反馈

T-041 的陨石和雷击均由场景中的固定节点编排，不使用随机天气：陨石复用
`DestructibleAsteroid` 的碰撞层、耐久与检查点重置；`FlightLightningStrike`
以路线距离触发后进入 `IDLE / TRACKING / LOCKED / STRIKE / COOLDOWN` 状态机。
追踪阶段以当前速度预测 `0.65 s` 锁定窗口结束时的位置，并把目标限制在相机
安全区；切入锁定的当帧会跳过追踪平滑、重算一次最终预测点，再冻结目标
`0.65 s`，只有短暂 `STRIKE` 状态可命中。当前几何保证真实 `W` 全油门、
无 Boost 的普通最大前速继续进入命中区，锁定后 Boost 可冲到前方，明显刹车进入倒车可落到
后方，小幅俯仰仍在垂直命中范围内；不按输入状态赋予无敌或强制命中。
`RedSandHazardDirector` 只在雷暴段施加由 `FlightHazardModel` 计算的确定性
风力，辅助驾驶按现有强度降低风力压力。
慢动作辅助只在追踪/锁定预警窗口临时调整时间倍率，命中范围、伤害、路线状态
和叙事结果保持相同，并在命中、重开、离开雷暴或释放场景时恢复原倍率。
各阶段的屏幕色调、环境循环和危险音乐强度由局部反馈组件切换，不引入全局
音频 Manager。T-044 在该组件内加入五层视差、速度/入大气/雷暴/着陆粒子，
并由 `FlightLabShip` 的可选本地节点提供推进、Boost 与碰撞反馈；这些占位声音
均在运行时合成，不依赖外部素材，也不改变飞行数值。

临时特效按坐标职责归属：推进、Boost、Beam 与船体碰撞反馈必须属于飞船局部
节点；着陆尘埃属于 `RedSandLandingZone` 的世界空间节点，只在真实接触坐标
一次性触发；CanvasLayer 只保留确实属于屏幕空间的闪光、色调和 HUD 压力。
静止、松开操作、重试、切段、路线完成及场景退出必须停止相应 emitter，并清除
旧粒子，禁止用透明或移出视口掩盖失去来源的效果。

`FlightLaserWeapon` 的持续 Beam 使用射线只查询
`FlightWeaponRules.LASER_TARGET_MASK`，每帧绘制炮口到命中点/最大射程的
`Line2D`，每 `0.10 s` 独立结算一次陨石伤害。视觉最短保持和释放淡出与伤害
Tick 分离，循环音在 Beam 开始时开启一次、停止时关闭；重试统一调用 reset，
避免残留光柱或音频。

### 8.7 赤砂星低空管制雷达与最后三阶段

阶段 6（`23000–30500 m`）把原低层沙漠与设施雷达内容合并到局部
`RedSandLowFlightCourse`。场景继续使用手工固定的峡谷/设施 `StaticBody2D`
和三个 `FlightRadarSector`，但不再创建 `FlightRadarCover`，也不再用贴地或
遮挡作为安全条件。所有阈值集中在课程组件：最低安全高度 `300 m`、警告
`1.0 s`、锁定 `0.45 s`、脉冲 `0.12 s`、冷却 `1.8 s`，资源后果为
`12` 点基础伤害和完全穿透时 `2` 点货损；护盾优先吸收，部分穿透按比例结算
船体与货物变化。

状态流为 `CLEAR → LOW_ALTITUDE_WARNING → LOCKED → PULSE → COOLDOWN`。
高于安全线保持 `CLEAR`；低于安全线才启动扫描。进入 `PULSE` 时通过现有资源
接口、HUD 数值变化、屏幕短促静电/闪烁、本地合成雷达脉冲音与系统警告共同
表达原因，冷却期间不会每帧重复扣除。离开阶段 6 会清空全部计时、扇区、锁定、
脉冲和声音状态。

阶段 7（`30500–33000 m`）是独立、无雷达的着陆准备走廊：降低场景遮挡，
提供抬升、稳定、减速和观察远处信标的空间。阶段 8（`33000–38000 m`）才是
从高位下降的最终进场，不重新加入雷达或低飞要求。路线提示和高对比度地形
开关继续只影响可视辅助并保持输入穿透。

### 8.8 赤砂星着陆、重试与抵达交接

T-043 使用局部 `RedSandLandingZone` 组合大型可读 `StaticBody2D` 着陆台、
进场提示和安全检查点；飞过路线末端本身不再视为交付完成。接地品质由纯逻辑
`FlightLandingModel` 根据水平速度、下降速度、接触强度和俯仰角分类为平稳、
勉强或失败，全部阈值、勉强着陆货损和抵达延时集中在 `FlightTuning` Resource，
不引入起落架刚体或精确对接物理。

最终进场配置集中在路线 Resource 与 `RedSandLandingZone`：阶段 7 长
`2500 m`，阶段 8 从 `33000 m` 开始；着陆中心为 `37000 m`、平台宽仍为
`2400 m`，所以阶段 8 开始时距中心 `4000 m`、距平台前缘 `2800 m`。推荐
进入高度为 `600 m`，正常 `220 m/s` 进场到中心名义约 `18.18 s`。平台碰撞
只在路线 `35000 m`（距中心 `2000 m`、距可见前缘 `800 m`）后启用，不会在
远处尚不可辨识时阻挡推荐路线。平台尾缘保持在 `38200 m`；船底高度参考点越过
该有限边界而尚未完成接地时，`RedSandLandingZone` 使用本地化原因触发既有
失败/自动重试流。失败冻结期间不再更新 AGL，不允许进入路线尾部后再切换到
普通地表剖面；这不是加长平台或放宽成功区。

进入最终阶段时，`FlightLabShip` 以固定安全位置和速度替换重试快照，但保留
当时的环境、辅助驾驶和资源状态。重试位置为中心前 `4000 m`、推荐高度
`600 m`、前向速度 `110 m/s`，仍有 `2800 m` 才接触平台前缘；失败沿用现有
`flight_restart` 与快速自动重试，只回到着陆进场。成功后飞船停止受控运动，
勉强着陆只扣除少量货物完整度，结果写入当前 `OrderRunState`，再由
`SceneRouterService` 从 `FLIGHT` 切换到 `ARRIVAL`。抵达场景只读取已保存结果
提供最低限度反馈，正式目的地剧情仍属于 T-050。

### 8.9 飞行控制帮助与暂停边界

`FlightControlsHelp` 是局部、可复用的模态 `Control`，由路线 HUD 实例化，
不创建全局 UI Manager。赤砂星路线首次 `_ready()` 后延迟打开帮助，先记录原
`SceneTree.paused`，再暂停飞船、危险和路线计时；路线根与帮助本身使用
`PROCESS_MODE_ALWAYS` 接收关闭输入，飞船使用 `PROCESS_MODE_PAUSABLE`。

`C`、`Escape`、`E` 或 `Enter` 关闭后恢复进入前暂停状态，并把同一输入标记为
已处理，避免顺带开火、重试或推进。检查点重试不强制重复弹出；`C` 可随时复开。
帮助从本地化表读取核心操作和“仅测试模式”分组，并由当前 `ShipLoadout` / 直达
测试工具刷新激光“已安装/未安装”状态。`L` 只在 Debug 的
`--red-sand-route` 入口切换模块，正式流程继续读取出发前配置。

T-053 起，`FlightControlsHelp` 还绑定场景传入的 `SettingsService`，提供键盘可
聚焦的路线提示与高对比度地形开关，并在按钮文本中明确显示“已开启/已关闭”。
设置继续保存到 `user://settings.cfg`；`assist_option_changed` 只通知既有路线
视觉、低空管制和着陆区局部消费方，不增加全局 UI Manager。路线提示开关控制
灰盒引导线/信标，高对比开关同时提高可碰撞地表上缘的宽度与明度。

公司货损警告由 `RedSandRouteHUD` 的独立计时槽显示：警告面板与 `RoutePanel`
使用同一右上矩形，显示期间隐藏路线卡，结束后恢复；底部 `StatusPanel` 保持
独立，因此雷击、碰撞、雷达和重试反馈不会覆盖公司警告。标题的文字等级和符号
保证严重度不依赖边框颜色。

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

M0 使用可检查、可迁移的 JSON。当前文件为 `user://savegame.json`，格式为：

```json
{
  "schema_version": 1,
  "game_progress": {},
  "last_saved_at_unix": 0,
  "build_version": "...",
  "settings_reference": "local_settings"
}
```

`game_progress` 只保存稳定 ID、数值和布尔状态；不保存 `Node`、场景实例、资源对象
或可运行脚本。

### 11.2 安全写入

1. 将新内容写入临时文件。
2. 验证能重新解析。
3. 将现有主档复制/移动为备份。
4. 原子替换或尽可能安全地替换主档。
5. 加载失败时尝试备份。

不要因一次写入中断覆盖最后可用档。

当前路径为：

- 临时档：`user://savegame.tmp`
- 上一份有效档：`user://savegame.backup.json`
- 新写入前发现的非法主档副本：`user://savegame.invalid.json`

只有新内容和备份都能重新解析为有效 schema 后才替换主档。主档损坏但备份有效时，
主菜单保持“继续游戏”可用并明确提示将从备份恢复；两份都无效时禁用继续，但保留
“新游戏”以及原文件，不静默清空。

### 11.3 迁移

- 每次 schema 变化增加版本。
- 使用逐版本迁移函数。
- 缺字段使用明确默认值。
- 无法迁移时保留坏档并提示，不静默清空。

schema `0`（没有版本字段）的已知 M0 字段会迁移到 v1；v1 缺字段使用明确默认值；
高于当前版本、类型错误、负数资源或不一致订单状态会被拒绝，不把部分数据写进
`GameState`。成功继续旧版存档并进入稳定节点后，下一次安全写入会生成 v1 主档。

### 11.4 自动保存与继续入口

`SaveService` 监听 `GameState.persistent_state_changed`，并在 `STATION`、`RESULTS`
两个稳定阶段合并同帧重复变更后写入。进入这两个阶段也会触发保存，保证结算场景
在 `_ready()` 中提交奖励后仍能落盘。测试、headless、导入和直接调试路线默认关闭
正常自动保存，避免污染玩家档案。

“新游戏”重置 `GameState` 并立即创建有效主档；“继续游戏”只在主档或备份有效时
启用，加载完成后从主菜单进入 `STATION`。M0 不做多槽位、云同步、跨平台同步或
飞行中场景恢复。

## 12. 设置存储

设置与剧情存档分开：

- 音量。
- 屏幕震动。
- 文字速度。
- 输入映射。
- 辅助驾驶强度。
- 慢动作、路线提示、高对比地形。

新游戏不重置本机设置。

当前设置继续由 `SettingsService` 写入 `user://settings.cfg`；剧情存档只保存
`settings_reference = "local_settings"`。存档恢复、备份回退和新游戏都不得复制、
覆盖或回滚玩家的音量、键位和辅助选项。

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

M0 赤砂星路线暂由场景局部 `AudioStreamPlayer` 播放程序合成的短循环与音效，
音乐按阶段及雷达压力在 `-30 dB` 至 `-17 dB` 间平滑变化；环境循环与音乐峰值
都至少为雷击预警保留 `6 dB` 余量。后续引入正式长音乐时再接入上述 Bus 分层，
不为当前占位音频提前增加全局服务。

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
- 资源消耗，以及护盾充足、部分破盾和无护盾时的统一碰撞/环境伤害顺序。
- 进入风格分类。
- 存档迁移与坏档恢复。
- canonical 高度的阶段 5→6 边界连续性、合法 `0/1 m`、负 AGL 与双源不一致
  的显式失败、无效宽限和 HUD/雷达同值约束。
- 从阶段 1 真实推进到阶段 6 的累计重力路径、地表帧获取/锁定、所有地表消费方
  的统一偏移，以及阶段 6–8 检查点和阶段 8 `4.0 km / 600 m` 重试。
- 高/中/低、上升/下降、零速、Boost/无 Boost、短倒车、检查点/重开的
  `11 × 30/60/120 FPS` 矩阵，连续重复至少 `20` 次，并包含真实 Input Map
  上升、俯冲和 Boost 轨迹。

### 14.3 烟雾测试

- Main 场景实例化。
- Station/Cockpit/Flight/Arrival 场景实例化。
- 场景切换顺序。
- 最小订单从接取到完成的状态模拟。
- 使用同一 App、`GameState` 与测试存档实际贯穿新游戏、教程接单、驾驶舱旅行、
  飞行失败重试、着陆剧情、结算返站、重建 App 和继续游戏；同时断言暂停、局部
  音频、持久对话层和单一活动场景的生命周期边界。
- 大厅、赤砂星维修场与返航纪念品的阻塞模态输入锁，以及非阻塞观察的提示隐藏、
  移动保留、空格/回车关闭、重复触发阻止和最终来源关闭后的恢复。
- 雷暴真实积分路线固定覆盖 `W` 普通最大前速且无 Boost 时命中、锁定后 Boost 前冲躲开、急刹进入
  倒车后落在命中区后方，以及小幅俯仰仍命中；测试不得使用输入无敌或强制命中。

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
| 长关卡尺度失控 | 电影化压缩、阶段式环境、单颗主线约 1–3 分钟 |
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
