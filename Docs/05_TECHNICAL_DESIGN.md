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

### 5.1 `GameProgress`（M1 schema v2）

当前版本化进度：

```text
schema_version
# M0 保留字段
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

# M1 v2 字段
main_story_chapter
unlocked_planet_ids
planet_relation_values
planet_permission_ids
codex_entry_ids
souvenir_ids
completed_side_order_ids
failed_side_order_ids
order_states              # 非 AVAILABLE 的订单状态名
reward_applied_order_ids  # 已原子结算奖励的订单 ID
station_state_level
ship_upgrade_ids
revisit_state
demo_ending_flags
last_stable_station_state
```

集合字段在解析和写回时去重；关系、回访、订单状态与结尾字典验证键和值类型。
`order_states` 只允许 `ACCEPTED / COMPLETED / FAILED / ABANDONED / ARCHIVED`，
且最多一个 `ACCEPTED` 并与 `current_order_id` 相同。每个完成订单都必须有
`reward_applied_order_ids` 账本记录；旧 v2 档缺少新增字段时从既有
current/completed/failed 记录补齐，不重新发奖。设置内容、场景节点、`NodePath`
和运行时节点引用不进入剧情存档。

M0 首单完成订单也是教程完成与赤砂回访前置标记的兼容性权威事实。v1→v2 迁移
及较早 schema v2 的读取都会幂等补齐这两个标记；稳定站点因此显示“接取赤砂星
屏蔽改装回访”，但不会借兼容步骤发放模块、关系、信用点或白噪星资格。

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

`elapsed_time` 只由 active 加急订单累计；对话、帮助面板和系统暂停时冻结，检查点
重试和存档恢复保留当前值。离开/完成订单后保留必要的订单结果，不把整棵场景树
存档。M0 的继续游戏固定回到快递站稳定状态，不恢复驾驶舱、飞行、抵达或结算
场景节点。

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

T-111 起，模块“所有权”和“已安装”是两个独立状态：

- 公司基础配发模块由 `ShipLoadoutRules.BASE_OWNED_MODULE_IDS` 集中声明。
- 剧情模块所有权只读取 schema v2 的 `ship_upgrade_ids`；未获得模块不能通过
  `GameStateModel.equip_ship_module()` 写入配置。
- `ship_configuration` 只保存槽位到稳定模块 ID；配置变更继续使既有出发确认失效。
- 站点工作台在打开时从 M1 订单终端注册表解析当前 active order，不再固定展示
  M0 赤砂订单；没有 active order 时保留 M0 配置作为安全回退。

`FlightElectromagneticProtectionModel` 是无状态能力读取层。它从已安装模块的
`capability_high_voltage_shielding` 找到唯一生效模块，再读取
`high_voltage_damage_multiplier` 与
`electromagnetic_interference_multiplier`。未安装或目录缺失时均返回 `1.0`。
`FlightLabShip.apply_high_voltage_damage()` 只缩放对应危险，再调用既有普通
护盾/船体/货物伤害入口；普通碰撞和普通环境伤害不读取这两个乘数。

飞船脚本用一圈轻量青色像素轮廓表现已安装状态，配置预览使用同一安装真相。
Flight Lab 和赤砂路线只负责把当前配置及模块目录注入飞船；未来白噪危险组件
消费上述纯逻辑接口，不在关卡脚本复制模块 ID 或数值。

### 5.4 M1 多星球进度运行时合同

`GameStateModel` 是章节、解锁、关系、许可、图鉴、纪念品和回访状态的唯一运行时
入口；这些字段直接对应 schema v2，不建立第二份 Progress Manager 或存档副本。
场景/UI 只能调用公开查询与变更方法，不能直接编辑存档 Dictionary。

`M1ProgressRules` 只保存稳定 ID、章节顺序、关系范围和星球准入白名单，不持有玩家
状态。主线按
`M0 完成 → 赤砂回访 → 白噪 → 穹林 → 群潮 → Demo epilogue`
逐个推进；跳级、倒退和未知 ID 均返回稳定原因 Key。星球规则统一读取当前章节、
前序解锁、已取得或已安装模块、许可、剧情标记、已完成订单和可选白名单上下文。
当前白噪星要求章节已到 `chapter_m1_white_noise`、赤砂星已解锁且拥有或安装
`module_high_voltage_shielding`；穹林和群潮还要求各自前一颗星球已解锁。

所有变更返回 `ProgressChangeResult(success, changed, reason_key, previous_value,
current_value)`。只有 `changed = true` 时才发出一次 `persistent_state_changed`；
重复章节、重复解锁、重复许可、重复收藏和重复回访状态均为成功但无变化的幂等
结果。关系限定为 `-2…+3`，生产调用必须提供唯一事件 ID；已应用事件以
`m1_relation_event/<planet>/<event>` 写入既有 `story_flags`，保证保存、加载后也
不能重复增加。加载由 `GameProgressData.apply_to()` 直接恢复已验证字段，只发出
`runtime_state_restored`，不重放奖励或持久化变更。

### 5.5 M1 一次一单运行时合同

`GameStateModel` 持有唯一 active order 槽位，并以
`AVAILABLE → ACCEPTED → COMPLETED / FAILED / ABANDONED` 为主要状态流；
`ARCHIVED_ONLY` 条目可由可用、失败或放弃态进入 `ARCHIVED`，但不能接取。完成、
失败、放弃和归档都必须经公开方法执行，UI 与场景不能直接写 `order_states`。

主线与 `REVISIT` 订单固定使用 `UNIQUE`，不能放弃；飞行失败时保持
`ACCEPTED`，继续使用既有检查点重试。支线失败/放弃会释放 active 槽位，但只有
`REPEATABLE` 允许再次接取。完成是永久终态；所有重复策略都不能把
`COMPLETED` 变回 `ACCEPTED`。

订单完成入口先验证整份奖励，再一次性应用信用点、关系、许可、图鉴、纪念品、
飞船模块所有权、站点状态、章节、回访状态、完成标记和兼容站点升级，最后写入
`reward_applied_order_ids` 并清理 active 上下文。章节奖励必须是当前章节的下一
合法节点或已达到节点；重复完成、重复加载、非法跳级或结算重入在任何奖励变更前
返回错误。

`M1OrderRules` 是无状态规则层：复用 T-102 的章节、星球、许可和模块准入，统一
加急计时暂停、准时判断和报酬比例。超时在宽限窗口中线性从 `1.0` 降至配置的
`minimum_reward_ratio`，不把超时直接解释为硬失败。
`required_completed_order_ids` 是独立的真实完成门槛；章节和剧情标记不能替代
对应 `completed_order_ids` 记录。

`ExpressOrderHUD` 位于 `App/PersistentUI`，同时承担唯一轻量计时适配器和两行
玩家反馈。它只解析当前 `ACCEPTED + is_express` 订单，并通过
`GameStateModel.advance_active_order_time()` 修改 `OrderRunState.elapsed_time`；
场景脚本、飞行 HUD 和结算 UI 不拥有第二个累计循环。组内按实例 ID 选出唯一
权威驱动，误实例化的副本不会提交同帧第二份 delta。驱动使用
`PROCESS_MODE_ALWAYS`，分别检查持久 `DialogueUI`、`FlightControlsHelp` 与
`SceneTree.paused`；冻结时继续提供状态而不累计。对话与帮助模态打开时，紧凑
HUD 隐藏并由模态内部的本地化暂停提示接管；单纯系统暂停仍在原 HUD 显示冻结
状态。场景切换、检查点和 `R` 重试不触碰 elapsed time，存档只恢复保存值，不
依据 `last_saved_at_unix` 补算离线时间。

结算的信用点权威顺序为：`base_reward` → `cargo_adjusted_reward` →
`time_adjustment` → `total_reward`。`OrderSettlementCalculator` 同时记录
`elapsed_time / target_seconds / timing_status / reward_ratio /
earned_on_time_relation_bonus / on_time_relation_bonus`；
`GameStateModel.settle_current_order()` 校验该结果后把
`total_reward` 当作最终值提交，不能再乘一次时间倍率。准时关系奖励在同一完成
事务内计算，`reward_applied_order_ids` 在信用点或关系变化前拦截结算重入和读档
后的重复调用。

加急 HUD 位于 640×360 左下安全区，最多两行，使用青色与琥珀色区分全额、宽限、
保底和暂停，不使用红色硬失败倒计时。订单终端只在 `is_express` 时显示目标、
宽限、最低比例与非硬失败说明；结算时间面板同样对非加急订单完全隐藏，因此
M0 赤砂首单的数值与布局保持原样。

订单的“数据已登记”和“内容可游玩”是不同合同。`OrderDefinition.content_readiness`
为 `REGISTERED_ONLY` 时，目录可以只读展示开发线索，但
`GameStateModel.get_order_acceptance_error()`、配置确认和旅行开始会再次检查订单、
目的星球与真实场景路径，拒绝接取或出发。UI 禁用按钮只是反馈层，不能代替这些
运行时守卫。

### 5.6 M1 目录与导航投影

`M1CatalogModel` 是无状态查询层，以 `M1DataRegistry` 和 `GameStateModel` 为输入，
生成订单目录与星球目录。订单目录固定分为当前主线、可选支线、下一步线索和历史；
active order 置顶，同一时刻最多一个当前主线，未发现的可选内容不显示真实名称。
`M1CatalogHintResolver` 将章节、星球、许可、模块、内容就绪和航线缺失原因转换为
稳定的本地化提示，玩家界面不直接显示内部 ID。

T-114 的 `M1DestinationPreparationStatus` 是同一查询层生成的只读结果，不是新的
Manager。白噪星资格按精确顺序检查赤砂回访章节、完成标记与完成订单，再检查
`module_high_voltage_shielding` 的所有权和 Defense 槽安装状态，最终区分：

```text
PREVIOUS_MAIN_REQUIRED
MODULE_NOT_OBTAINED
MODULE_NOT_INSTALLED
QUALIFIED_ROUTE_PENDING
READY
```

订单终端、`StationShipLoadoutController` / `ShipLoadoutUI` 和
`CockpitNavigationPanel` 均消费这一个结果。UI 可以显示已解锁导航节点、风险与
配置要求，但不能据此接取订单或开始旅行；正式运行时仍由
`content_readiness`、目的星球就绪状态和真实 `flight_scene_path` 三层守卫拒绝
白噪出发。

订单终端是“左侧紧凑目录 + 右侧单项详情 + 固定操作区”；焦点与鼠标只改变当前
选中项，只有显式接取动作才调用 `GameStateModel.accept_order()`。驾驶舱的
`CockpitNavigationPanel` 使用同一目录投影，只显示当前订单目的地、准入门槛和
唯一权威旅行入口，不建立自由星图或第二份导航状态。正常场景读取
`m1_data_registry.tres`；`m0_data_registry.tres` 仅用于显式回归夹具。

### 5.7 M1 图鉴、纪念品墙与站点状态投影

`CodexCatalogModel` 与 `SouvenirWallModel` 都是无状态查询层。前者将
`GameDataRegistry.codex_entries / souvenirs` 与
`GameStateModel.codex_entry_ids / souvenir_ids` 投影为分类目录；后者始终按
注册表顺序生成纪念品墙槽位。两者只返回玩家可见的本地化 Key，不从 UI 写入
GameState。隐藏锁定条目不进入图鉴，允许出现的锁定位与全部未获得纪念品槽只使用
通用未知文本。对应的图鉴纪念品与物理纪念品通过稳定 ID 关联，在图鉴中去重。

`CodexBrowserUI` 是独立可复用的 640×360 灰盒组件。T-113 通过
`StationArchiveTerminalController` 将其正式挂入快递站：只有精确
`station_state_archive_terminal` 存在时才启用交互，浏览器仍直接读取同一
`GameStateModel` 图鉴集合，不建立第二份档案状态。终端和 `SouvenirWallUI`
都通过 `StationModalCoordinator` 获取世界输入锁；鼠标与键盘共用选择函数，
关闭时恢复打开前焦点、玩家控制和场景提示。状态被移除或运行时重置时，终端会
同步禁用并关闭仍在显示的浏览器。

完成赤砂回访后，档案投影已知的白噪星和旧铭牌异常回波；“玩家已知”和“导航已
解锁”仍由不同字段表达。赤砂回访的同一原子结算通过
`planet_unlock_rewards` 写入白噪导航节点。老皮的一次性档案简报由独立
`DialogueSequence` 和完成标记驱动，取消对话不会伪造完成。为兼容 T-114 之前
已经完成回访的 schema v2 存档，读取时只有在精确回访完成订单、剧情标记、白噪
章节和屏蔽罩所有权同时存在时，才幂等补齐白噪导航节点；存档 schema 仍保持 v2。

`StationStateRules` 只登记三个精确 `station_state_*` ID 及其摘要等级。
`GameStateModel.unlock_station_state()` 是唯一普通写入口：非法 ID 拒绝、重复 ID
成功但无变化，实际变化只发出一次持久化通知与站点解锁事件。
`StationStatePresenter` 只按 `station_upgrade_ids` 切换三个隐藏根节点，不读取
`station_state_level` 推断内容。等级只向上汇总，存档加载只恢复并刷新，不重放
升级事件。

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
content_readiness: REGISTERED_ONLY / PLAYABLE
required_story_flags: Array[StringName]
flight_scene_path
art_palette_id: StringName
music_theme_id: StringName
```

`data/m0_data_registry.tres` 继续是冻结的 M0 运行时入口。
`data/m1_data_registry.tres` 以 `registry_id = m1_four_planet_demo` 标识完整 Packet
内容源，并从 T-105 起成为正常订单终端与驾驶舱导航的数据源。冻结的 M0 注册表
只保留为显式测试/兼容夹具。未制作路线的星球必须显式使用 `REGISTERED_ONLY` 且
不声明 `flight_scene_path`；只有 `PLAYABLE` 星球可以引用存在的场景。

### 6.2 `OrderDefinition`

```text
id
display_name_key
order_type          # MAIN / SIDE / REVISIT
required_chapter
unlock_conditions   # PLANET_UNLOCKED / PERMISSION_GRANTED / MODULE_AVAILABLE
required_completed_order_ids
sender
recipient
destination_planet
planet_id
destination_id
cargo_id
delivery_type       # LANDING / LOW_ALTITUDE_DROP
content_readiness   # REGISTERED_ONLY / PLAYABLE
credit_reward
relation_rewards
permission_rewards
codex_rewards
souvenir_rewards
ship_upgrade_rewards
planet_unlock_rewards
station_state_rewards
chapter_reward
revisit_state_rewards
repeat_policy       # UNIQUE / REPEATABLE / ARCHIVED_ONLY
is_express
target_seconds
grace_seconds
minimum_reward_ratio
relation_bonus_on_time
required_module_ids
recommended_module_ids
customer_history_keys
story_requirements
completion_flags
```

主线与回访订单只能使用 `UNIQUE`。注册表验证重复订单 ID、已知章节/星球/角色/
货物/模块、目的地一致性、交付类型、解锁条件、所有奖励引用及加急参数。
M0 历史中使用的 `order_red_sand_cooling_core` 只通过注册表 alias 解析到实际
`order_red_sand_m0`，不创建第二份可接订单 Resource。

M0 首单必须为 `PLAYABLE`；尚未落地剧情或路线的 M1 订单必须显式为
`REGISTERED_ONLY`。注册表验证该数据合同，运行时仍独立检查目的星球和场景路径，
避免错误数据把占位内容变成可接或可出发订单。

`RedSandRevisitContract` 是正式短回访的数据合同，不是第二个运行时路线系统。
它引用正式回访订单、主/可选抵达对白和既有 `route_red_sand_m0`，集中声明短路线
变化 ID、入口检查点、`26000–38000 m` 路线窗口、`48 s` 名义时长、三个本地
HUD 阶段、变化设施位置、回访状态、记录选择标记和自动安装奖励。T-112 完成
路线—抵达—结算—返站—存档闭环后，正式回访订单为 `PLAYABLE`。

`RedSandFlight` 只在当前 active order 精确匹配回访合同时启用该变体：从
`26000 m` 专用检查点进入，提前锁定已有 surface frame，使用同一 canonical AGL，
将 HUD 重新映射为本地 `1/3–3/3` 和 `0–100%`，并禁用原
`RedSandLowFlightCourse` 的雷达、碰撞障碍和提示。新增的
`RedSandRevisitRouteLandmark` 仅绘制 `28600 m` 处的设备/居民变化且无碰撞；
M0 从 `0 m` 开始的完整路线不走这些分支。

抵达对白完成标记与二选一标记共同构成交付就绪条件，取消或在选择处退出不能提前
结算。`OrderResults` 从 M1 注册表按 active order 解析正式订单，并通过
`GameStateModel.settle_current_order()` 一次提交基础奖励、分支附加关系和需要
自动安装的剧情模块；所有附加参数在任何 mutation 前验证，避免信用点、模块、
章节、回访或站点状态部分写入。

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

### 6.5 图鉴、纪念品与注册表

`GameDataRegistry` 使用 `Array[CodexEntryDefinition]` 与
`Array[SouvenirDefinition]` 作为奖励引用的唯一内容目录，不再维护平行的手写 ID
数组。两类 Resource 均保存稳定 ID、本地化 Key、关联星球和锁定前隐藏规则；
`CodexEntryDefinition` 额外声明星球、人物、货物、异常或纪念品类别。验证器同时
检查跨类型重复 ID、关联星球、奖励引用和中英文文本。

M0 首单 Resource 与 `m0_data_registry.tres` 保持冻结的信用点奖励合同；当前首单
结算通过 `GameStateModel` 的 M0 兼容步骤，在同一次持久化提交中补齐赤砂星、
伊娅、旧中继铭牌图鉴与物理铭牌。v1→v2 迁移使用同一组稳定 ID，并以集合去重保证
不会出现第二份奖励。

### 6.6 ID 规则

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
运动窗口检测“坐标预期变化但 Final AGL 的窗口内范围近似固定”的不变量并
输出完整快照。检测器记录窗口内 Final AGL 的最小值与最大值，不用首尾净变化
代替响应幅度；因此下降后拉起的正常平滑反转不会被误报，真正冻结的输出仍会
触发诊断。
移动 `StaticBody2D` 后，PhysicsServer2D 可能晚于脚本帧更新查询变换；最多四次
Provider 更新以剖面为权威并暂缓射线一致性验证，随后必须恢复 RayCast 交叉
验证。该窗口只处理服务器同步，不能吞掉负 AGL 或长期双源不一致。

### 8.6 白噪星独立路线灰盒

T-120 使用独立 `WhiteNoiseFlight` 场景，不实例化、继承或改名赤砂正式路线。
`WhiteNoiseRouteDefinition` 在通用 `FlightRouteDefinition` 上只增加局部
`WhiteNoiseRouteBranch` 数组；主路线仍由连续 `FlightRouteSegment`、环境
Resource 与安全检查点驱动。六段边界为：

```text
0–4500       轨道/高空接近
4500–9500    开阔冰原
9500–17000   冰裂谷与三路分流
17000–23000  极光和确定性电磁暴雪
23000–28500  地下档案入口
28500–34000  最终进场与有限着陆台
```

整段名义快速/常规/观景时长为 `88 / 118 / 154 s`。冰裂谷在 `10000 m`
按船体实际路线 Y 选择 `white_noise_fast / white_noise_balanced /
white_noise_scenic`，三路共享 `17000 m` 汇合点；通道使用两条可见冰层分隔
碰撞和各自的安全重试 Y，不复制三份完整路线。路线重开恢复第一段确定起点，
阶段重试恢复当前环境、资源下限、速度和对应安全通道。

`WhiteNoiseRouteVisuals` 生成冰原上缘、冰洞顶面、局部分流障碍、极光/风雪
灰盒线、竖向档案门框、下降信标和有限着陆台。着陆段从 `28500 m` 开始，
平台可碰撞前缘为 `32750 m`，接触目标为 `33700 m`，因此最终阶段提供
`5200 m` 观察、减速和下降距离；路线完成只停在灰盒完成状态，不误入赤砂抵达。

飞船继续使用 M0 `FlightLabShip`、`FlightTuning`、三档重力补偿、伤害、
Boost/倒车、检查点和 `FlightDebugHUD`。白噪六个 profile 都把
`planet_white_noise.gravity_scale = 1.28` 映射为 `256 px/s²`，仅按区域改变
混合、密度、阻力和终端下降保护。`WhiteNoiseRouteHUD` 只提供白噪段名、进度、
分流/汇合与紧凑帮助；H 继续控制共用 Full Diagnostics，C/G/R 继续使用既有
Input Map action。

集中调试入口 `--m1-debug=white_noise_route` 由
`M1DebugScenarioCatalog/Controller` 构建当前进程内的
`debug_m1_white_noise_route` 夹具。它深拷贝正式白噪订单与星球并只在夹具上
临时设为可玩、指向独立场景；正式 Resource 继续 `REGISTERED_ONLY` 且没有
`flight_scene_path`。F6 重建同一内存快照，SaveService 与 SettingsService
保持既有隔离合同。

T-121 使用三层局部职责，不把白噪特例塞入核心飞船：

- `WhiteNoiseStormProfile` Resource 集中保存 `17000 / 17700 / 22000 /
  23000 m` 距离门槛，`2.4 / 12.0 / 2.8 s` 最短时长、`0.86` 干扰、
  `18 / 3` 高压与货损请求、`4.0 s` 脉冲间隔和 `0.78` 可见度压力。
- `WhiteNoiseInterferenceModel` 只处理确定性的
  `CLEAR / WARNING / ACTIVE / RECOVERY`、单调路线距离和脉冲序号；它不访问
  SceneTree、Input 或玩家存档。
- 场景内 `WhiteNoiseStormController` 消费模型，调用
  `FlightLabShip.apply_high_voltage_damage()`，同步 HUD、有限屏幕线条与
  `WhiteNoiseRouteVisuals`。核心资源和危险文字始终在高层 CanvasLayer 上可读。

已安装屏蔽罩时，控制器只从 `FlightLabShip` 已配置的模块能力取得干扰
`0.45`；高压结算则由飞船继续读取同一模块 Resource 的 `0.60`。路线提示和
高对比通过现有 SettingsService 驱动世界航标，慢动作只在 WARNING 临时使用
`0.55` 时间倍率。帮助/系统暂停不调用危险 advance；检查点、F6、离开窗口和
场景退出都会重建或清理模型、脉冲反馈与时间倍率。

`--m1-debug=white_noise_route` 保持安装屏蔽罩的正常对照；
`--m1-debug=white_noise_route_unshielded` 复用同一深拷贝订单夹具、但让 Defense
槽恢复默认模块。两者都不修改正式白噪订单或星球的 `REGISTERED_ONLY` 状态。

### 8.7 赤砂星固定危险与环境反馈

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

### 8.8 赤砂星低空管制雷达与最后三阶段

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

### 8.9 赤砂星着陆、重试与抵达交接

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

### 8.10 飞行控制帮助与暂停边界

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

### 8.11 M1 低空投放与 Delivery Lab

低空投放拆成三个职责：

- `LowAltitudeDropProfile`：唯一参数源，保存高度/水平速度窗口、核心/外圈半宽、
  固定下降速度、水平速度继承和部分成功质量/报酬比例，并提供结构验证。
- `LowAltitudeDropModel`：纯逻辑状态门闩。它以高度除以下降速度得到下落时间，
  再以释放 X、水平速度和继承比例得到预计落点；输出 `PENDING /
  CORE_SUCCESS / OUTER_PARTIAL / MISSED / INVALID_RELEASE`。
- `DeliveryLab`：独立场景适配层，读取 `FlightLabShip` 的世界 X、水平速度和
  局部地表高度，驱动预测线、货物灰盒轨迹、HUD、本地化原因与检查点重试。

窗口非法时模型不消费货物；首次合法释放后立即锁定唯一货物，场景只能播放和展示
该次已确定结果。重复输入不实例化节点、不覆盖结果、不写奖励。`R` 先恢复
`FlightLabShip` 的稳定检查点，再重置模型和货物视觉，因而飞船、货物和结果处于
同一重试边界。

`delivery_drop` 由 `SettingsService` 注册，默认 `E / 鼠标右键` 共用同一 action；
业务脚本不直接判断设备按键。开发构建通过 `--delivery-lab` 让
`SceneRouterService` 以 FLIGHT 场景覆盖打开；`SaveService` 将该参数列为直接
调试入口，不自动写玩家存档。

该原型复用 M0 `FlightLabShip`、`FlightTuning` 和穹林占位环境，但不引用或修改
活动订单，不调用结算器，也不把穹林订单/星球从 `REGISTERED_ONLY` 提升为可玩。
货物轨迹是确定性线性视觉，不使用 `RigidBody2D`、随机风场或复杂碰撞弹道。

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

T-122 在通用驾驶舱外增加订单级 `WhiteNoiseMainOrderContent` Resource，保存
白噪主单的手动老皮对白、必播旅行对白、收音机/货舱对白、四段状态 Key、设备
备注和独立完成标记。`Cockpit` 只依据当前活动订单稳定 ID 选择该 Resource，
`TravelSequenceController` 仍只负责通用阶段推进；对白已读继续由
`DialogueRuntime` 使用 sequence/line ID 写入 v2 状态，不另建白噪 Manager。
订单终端以 `CargoDefinition.company_description_key` 和
`story_description_key` 为同一货物的两份权威文本，分别标成公司记录与实际
用途，避免 UI 自行推断文明冲突。

## 11. 存档

### 11.1 格式

M1 继续使用可检查、可迁移的 JSON。当前文件为 `user://savegame.json`，格式为：

```json
{
  "schema_version": 2,
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

schema `0`（没有版本字段）的已知 M0 字段先迁移到 v1，并通过完整 v1 一致性验证，
再执行 v1→v2；不得跳过中间版本。v1 完成赤砂首单的档案在内存中补齐赤砂回访
章节、赤砂星解锁、已有图鉴/纪念品和首单站点状态，但不解锁白噪星或发放屏蔽罩。
未完成档继续由既有 M0 字段决定进度，新增字段使用空集合、空 ID、空字典和等级 0。

高于当前版本、类型错误、负数资源或不一致订单状态会被拒绝，不把部分数据写进
`GameState`。schema v2 还验证章节、星球、许可为当前稳定白名单，关系只使用已知
星球且位于 `-2…+3`，图鉴、纪念品与回访状态使用稳定英文 ID。读取旧档只执行
内存迁移；成功继续并进入下一稳定节点后，安全写入才生成 v2 主档，同时由现有
轮换流程保留原有效 v1 备份。

站点状态额外验证所有 `station_state_*` 候选必须属于
`StationStateRules.STATE_IDS`。读取时允许由 `station_upgrade_ids` 将
`station_state_level` 向上归一化，但绝不由等级补发设施 ID；因此粗粒度摘要不能
成为第二份功能真相。

### 11.4 自动保存与继续入口

`SaveService` 监听 `GameState.persistent_state_changed`，并在 `STATION`、`RESULTS`
两个稳定阶段合并同帧重复变更后写入。进入这两个阶段也会触发保存，保证结算场景
在 `_ready()` 中提交奖励后仍能落盘。测试、headless、导入和直接调试路线默认关闭
正常自动保存，避免污染玩家档案。

“新游戏”重置 `GameState` 并立即创建有效 v2 主档；“继续游戏”只在主档或备份有效时
启用，加载完成后从主菜单进入 `STATION`。M1 不做多槽位、云同步、跨平台同步或
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
- 一次一单、主线重试安全、支线失败/放弃与显式重接。
- 加急计时暂停、超时报酬下限与准时关系奖励。
- 完成奖励原子性、幂等账本及 active/completed 存档往返。
- 飞行力计算、辅助重力、终端速度。
- 碰撞分级。
- 资源消耗，以及护盾充足、部分破盾和无护盾时的统一碰撞/环境伤害顺序。
- 低空投放高度/速度/接收区边界、落点公式、部分成功比例和单货物门闩。
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
- 大厅正式面板、返航纪念品详情与赤砂星维修场的阻塞模态输入锁，以及其他非阻塞
  观察文字的提示隐藏、移动保留、手动关闭、重复触发阻止和最终来源关闭后的恢复。
- 图鉴分类与锁定去剧透、多槽纪念品顺序、鼠标/键盘同一路径、站点精确 ID 根节点、
  `station_state_level` 单调摘要及加载不重放事件。
- 档案终端的精确状态启用、已知记录投影、640×360 模态布局、键鼠分类切换、老皮
  白噪简报、焦点恢复，以及旧 schema v2 回访存档的新增记录兼容。
- Delivery Lab 的键鼠共用 action、核心/外圈/漏投可见反馈、重复输入防重、
  检查点恢复飞船与货物，以及不改写活动订单/信用点。
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

### 17.1 M1 隔离调试场景

T-109 在既有 Lab 与赤砂直达参数之外增加统一入口：

```text
--m1-debug=<scenario_id>
```

`M1DebugScenarioCatalog` 集中声明 scenario 的章节、已解锁星球、目录焦点、
可用/已安装模块、许可、关系、目标 Stage、目标场景和预览限制，并在应用前验证
稳定 ID、章节对应的星球前缀、订单/星球引用、模块槽位和隔离夹具组合。
`M1DebugScenarioController` 只通过通过校验的 `GameProgressData` 内存快照恢复基础
状态；加急场景从正式 `REGISTERED_ONLY` 订单深拷贝一个独立的
`debug_m1_express_order`，再通过 `GameStateModel.accept_order()` 接取。正式注册表
及其订单、星球就绪状态始终不变。

赤砂回访场景定义的基础快照声明 `revisit_red_sand_available`。生成的快照必须
已完成 `order_red_sand_m0`、持有首单完成标记且尚未取得
`module_high_voltage_shielding`；T-112 随后接取正式回访订单，将状态推进为
`revisit_red_sand_materials_pending`，并打开正式短路线。其他调试场景继续遵守
各自的目录预览或隔离夹具边界。

目录场景复用 `OrderTerminalUI` 并聚焦指定订单；低空投放和加急场景分别复用
Delivery Lab 与 Flight Lab。持久 UI 只显示 scenario、章节、订单、星球和
“自动存档已关闭”，不建立玩家可见调试菜单。`F6 / m1_debug_reset` 重新应用初始
快照并重载目标场景，使运行时数据和场景夹具同时回到确定状态。

带 `--m1-debug` 的进程在 `MainMenu` 第一次查询继续游戏前即进入隔离模式：

- `SaveService` 关闭自动保存，并在任何正常存档读取、写入、新游戏或继续游戏操作
  到达文件层前拒绝请求；
- `SettingsService` 可以读取现有本机设置用于一致的显示/输入，但禁止写回、首次
  创建或旧绑定迁移写入；
- 调试状态只存在于当前进程，不使用第二个玩家存档，也不带入下次普通启动。

保存迁移等验证继续使用测试专用临时路径。`scripts/check_m1_foundation.sh` 作为
可独立运行的聚合入口，逐项标记 v2 迁移、多星球系统、目录导航、收藏与站点、
低空投放、加急订单、赤砂回访闭环、档案终端、白噪资格准备、白噪路线、暴雪
机制与九个 M1 调试启动和
M0 完整闭环；该入口由 `scripts/check_project.sh` 调用。

Gate E 入口 `--m1-debug=gate_e` 使用同一隔离合同，从首单完成后的
`STATION` 状态开始，保留赤砂、伊娅、旧中继铭牌、首单信用点与回访资格，但不
预接订单、不发放屏蔽罩，也不解锁白噪星。玩家因此可以按正式订单终端、配置、
驾驶舱、短路线、抵达、结算和返站顺序试玩；该入口仍不接触玩家主档。

T-120 新增的 `--m1-debug=white_noise_route` 使用已经获得且安装特高压电屏蔽罩、
白噪章节与导航资格的确定快照，接取独立调试订单并直接打开白噪灰盒场景。
T-121 的 `--m1-debug=white_noise_route_unshielded` 只提供同一暴雪序列的未安装
隔离对照。两者共同验证路线、重力、分流、碰撞、检查点、着陆与屏蔽差异，不代表
正式白噪主线已经开放。

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
