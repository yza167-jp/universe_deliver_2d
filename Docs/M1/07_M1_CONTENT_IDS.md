# M1 Content IDs / M1 内容技术 ID

本文记录 T-104 落地的技术 ID 与占位数值。稳定 ID 可供代码、存档和引用使用；
显示名、货物名、角色名、纪念品名与具体描述仍是 `PROVISIONAL` 工作候选，不因此
升级为正式正史。

## 注册表边界

- M0 入口：`data/m0_data_registry.tres`，保持原有 1 星球、1 实际订单、1 货物、
  4 模块和 3 角色。
- M1 内容源：`data/m1_data_registry.tres`，使用
  `registry_id = m1_four_planet_demo`，复用 M0 Resource 再增加 M1 Packet。
- `order_red_sand_cooling_core` 是历史/完成记录 alias，只解析到唯一实际订单
  `order_red_sand_m0`。
- Stretch `side_red_sand_unlisted_filters` 与 `cargo_red_sand_water_filters` 不进入
  必做注册表。
- M0 首单、赤砂回访、T-125 白噪主单与 T-126 白噪返件支线为 `PLAYABLE`。
  穹林、群潮主线及其 2 份必做支线仍为 `REGISTERED_ONLY`：可供目录、依赖和
  内容开发引用，但在对应正式订单流程完成前不能接取或出发。隔离白噪路线夹具
  不改变正式 Resource；内容落地任务必须显式将对应订单与星球切换为
  `PLAYABLE`。

## 星球与环境占位

| Planet ID | Gravity scale | Environment profile | Readiness |
|---|---:|---|---|
| `planet_red_sand` | 1.00 | 既有赤砂环境 | `PLAYABLE` |
| `planet_white_noise` | 1.28 | `environment_white_noise_placeholder` | `PLAYABLE` |
| `planet_canopy_world` | 0.83 | `environment_canopy_world_placeholder` | `REGISTERED_ONLY` |
| `planet_tidal_archipelago` | 0.98 | `environment_tidal_archipelago_placeholder` | `REGISTERED_ONLY` |

表中的白噪 profile 仍是 production placeholder，但正式星球已指向
`res://scenes/flight/white_noise_flight.tscn`。穹林和群潮环境只提供保守参数，
且两个 Resource 均没有 `flight_scene_path`。

### 白噪路线 T-120 灰盒合同

- 路线：`route_white_noise_archive_core`，总长 `34000 m`。
- 六段：
  `white_noise_orbital_approach`、
  `white_noise_open_icefield`、
  `white_noise_ice_rift_split`、
  `white_noise_aurora_blizzard`、
  `white_noise_archive_descent`、
  `white_noise_landing_approach`。
- 环境：
  `environment_white_noise_orbit`、
  `environment_white_noise_icefield`、
  `environment_white_noise_ice_rift`、
  `environment_white_noise_aurora_placeholder`、
  `environment_white_noise_archive`、
  `environment_white_noise_landing`。
- 三条局部分流：
  `white_noise_fast`、
  `white_noise_balanced`、
  `white_noise_scenic`；统一从 `10000 m` 分开，在 `17000 m` 汇合。
- 独立调试订单：`debug_m1_white_noise_route`，只由
  `--m1-debug=white_noise_route` 在内存中建立，不进入正式注册表。
- 路线 profile 以基准 `200 px/s² × planet_white_noise.gravity_scale 1.28`
  得到统一 `256 px/s²` 重力；T-121 再接入电磁干扰与屏蔽差异。

## 新模块

| Module ID | Slot | Capability | 获取标记 |
|---|---|---|---|
| `module_high_voltage_shielding` | Defense | `capability_high_voltage_shielding` | `story_m1_red_sand_shielding_retrofit_completed` |
| `module_biosignal_isolation` | Utility | `capability_biosignal_isolation` | `story_m1_biosignal_isolation_available` |
| `module_crosswind_stabilizer` | Utility | `capability_crosswind_stabilization` | `story_m1_crosswind_stabilizer_available` |

T-111 已实现屏蔽罩能力读取：安装时
`high_voltage_damage_multiplier = 0.60`、
`electromagnetic_interference_multiplier = 0.45`；未安装时两项均回退为 `1.00`。
这是可调工作基线，不是额外护盾资源。隔离舱与横风稳定器在对应主线仍只作为
推荐模块，其具体关卡效果留给各自行星任务。

## 角色

现场角色：

- `character_white_noise_archivist`
- `character_white_noise_memory_owner`
- `character_canopy_route_keeper`
- `character_canopy_canopy_clinic_worker`
- `character_tidal_weather_keeper`
- `character_tidal_city_representative`

公司远程身份：

- `character_company_archive_service`
- `character_company_weather_custodian`

当前本地化使用角色候选文档中的推荐工作候选或部门职务，并使用
`*_PROVISIONAL` Key。

## 货物占位数值

| Cargo ID | Boost | Collision tolerance | Risk tags |
|---|---|---:|---|
| `cargo_relay_pattern_shielding_materials` | Limited | 0.65 | electromagnetic signature, nonstandard company record |
| `cargo_white_noise_archive_core` | Limited | 0.55 | electromagnetic interference, archive access |
| `cargo_canopy_ecology_sample` | Limited | 0.60 | biosignal attraction, ecological contamination |
| `cargo_tidal_weather_control_core` | Limited | 0.65 | crosswind instability, control access |
| `cargo_returned_memory_case` | Limited | 0.50 | impact sensitive, private archive |
| `cargo_canopy_spore_stabilizer` | Limited | 0.55 | biosignal attraction, drop window |
| `cargo_tidal_beacon_cells` | Allowed | 0.70 | electrical discharge, time sensitive |

## 订单与暂定数值

| Order ID | Type / Delivery | Credit | Route | Risk | Module rule | Readiness |
|---|---|---:|---:|---:|---|---|
| `order_m1_red_sand_shielding_retrofit` | Revisit / Landing | 140 | 12000 m | 2 | M0 drive + atmosphere required | `PLAYABLE` |
| `order_m1_white_noise_archive_core` | Main / Landing | 180 | 34000 m | 4 | high-voltage shielding required | `PLAYABLE` |
| `order_m1_canopy_ecology_cargo` | Main / Landing | 200 | 1.15 | 3 | biosignal isolation recommended | `REGISTERED_ONLY` |
| `order_m1_tidal_weather_core` | Main / Landing | 240 | 1.30 | 4 | crosswind stabilizer recommended | `REGISTERED_ONLY` |
| `side_white_noise_returned_memory` | Side / Landing | 80 | 17000 m | 2 | archive permission + completed White Noise main required | `PLAYABLE` |
| `side_canopy_spore_drop` | Side / Low-altitude drop | 90 | 0.55 | 3 | biosignal isolation recommended | `REGISTERED_ONLY` |
| `side_tidal_beacon_before_eye` | Side / Landing / Express | 120 | 0.70 | 4 | crosswind stabilizer recommended | `REGISTERED_ONLY` |

群潮支线的暂定加急参数为：目标 `120 s`、宽限 `60 s`、最低信用点比例 `0.50`、
准时关系加成 `+1`。其余六单为非加急。全部 M1 主线、回访与三份必做支线均为
`UNIQUE`。

### 赤砂回访 T-110 合同

- 前置完成订单：`order_red_sand_m0`。
- 前置剧情标记：`story_red_sand_order_completed`。
- 路线变化 ID：`route_red_sand_revisit_service_lane`。
- 入口检查点：`checkpoint_red_sand_revisit_service_lane`。
- 复用 `route_red_sand_m0` 的 `26000–38000 m` 窗口；名义距离
  `12000 m`，名义时长 `48 s`。
- 回访状态依次为 `revisit_red_sand_available`、
  `revisit_red_sand_materials_pending`、`revisit_red_sand_completed`。
- 记录选择标记为
  `story_m1_red_sand_retrofit_records_uploaded_full` 或
  `story_m1_red_sand_retrofit_records_kept_local`；二者不创建主线分叉。
- 完成奖励为 `140` 信用点、赤砂关系 `+1`、
  `codex_cargo_relay_pattern_shielding_materials`、
  `module_high_voltage_shielding`、`station_state_archive_terminal`、
  `planet_white_noise` 导航节点、`chapter_m1_white_noise` 与赤砂回访完成状态。

上述赤砂路线值已由 T-112 的实际场景、路线、交付与结算闭环落实。T-114
解锁白噪导航节点和订单预览，T-120 增加独立灰盒调试场景；T-125 完成正式
白噪闭环后，`planet_white_noise` 与 `order_m1_white_noise_archive_core`
升级为 `PLAYABLE`，正式星球固定使用独立白噪 `flight_scene_path`。

### 白噪主单 T-125 结算合同

- 合同 ID：`white_noise_settlement_contract`。
- 精确路线：`res://scenes/flight/white_noise_flight.tscn`。
- 精确目的地：`res://scenes/arrival/white_noise_arrival.tscn`。
- 结算剧情标记：
  `story_m1_white_noise_choice_settled`、
  `story_m1_white_noise_archive_terminal_updated`、
  `story_m1_canopy_precursor_discovered`。
- 回访状态：
  `revisit_white_noise_memory_followup_available`。
- 结尾键：`ending_archive_choice`；合法值为
  `archive_minimum_index`、`archive_keep_sealed`、
  `archive_local_custody`。
- 选择专属图鉴：
  `codex_anomaly_white_noise_minimum_index`、
  `codex_anomaly_white_noise_sealed_index`、
  `codex_anomaly_white_noise_shared_custody`。
- 固定奖励包括白噪关系 `+1`、档案许可、白噪基础图鉴、霜纹索引纪念品、
  穹林章节/导航与白噪回访种子；封存/共同保管当前各有可调额外关系 `+1`。

### 白噪返件支线 T-126 合同

- 合同 ID：`white_noise_returned_memory_contract`。
- 复用路线：`res://scenes/flight/white_noise_flight.tscn` 的
  `17000–34000 m` 窗口；起始段索引 `3`，名义距离 `17000 m`。
- 复用目的地：`res://scenes/arrival/white_noise_arrival.tscn`，但使用独立
  驾驶舱和抵达对白 ID。
- 前置完成订单：`order_m1_white_noise_archive_core`；支线没有章节奖励或
  星球解锁奖励，不作为穹林前置。
- 选择标记：
  `story_side_white_noise_choice_keep_private`、
  `story_side_white_noise_choice_anonymous_index`、
  `story_side_white_noise_choice_local_original`。
- 结尾键：`ending_white_noise_memory_return`；合法值为
  `memory_return_keep_private`、`memory_return_anonymous_index`、
  `memory_return_local_original`。
- 基础奖励为 `80` 信用点、白噪关系 `+1` 和人物/货物图鉴；货物完整度低于
  当前 `70%` 工作阈值时额外关系修正 `-1`。

新增目的地 ID：

- `destination_red_sand_repair_yard`
- `destination_white_noise_archive_platform`
- `destination_white_noise_memory_return`
- `destination_canopy_core_platform`
- `destination_canopy_clinic_drop_ring`
- `destination_tidal_weather_tower`
- `destination_tidal_beacon_station`

## 图鉴与纪念品

保留 M0：

- `codex_planet_red_sand`
- `codex_character_iya`
- `codex_souvenir_old_relay_plaque`
- `souvenir_old_relay_plaque`

白噪：

- `codex_planet_white_noise`
- `codex_character_white_noise_archivist`
- `codex_cargo_white_noise_archive_core`
- `codex_character_white_noise_memory_owner`
- `codex_cargo_returned_memory_case`
- `codex_anomaly_white_noise_minimum_index`
- `codex_anomaly_white_noise_sealed_index`
- `codex_anomaly_white_noise_shared_custody`
- `souvenir_white_noise_frost_index`

穹林：

- `codex_planet_canopy_world`
- `codex_character_canopy_route_keeper`
- `codex_cargo_canopy_ecology_sample`
- `codex_character_canopy_clinic_worker`
- `codex_cargo_canopy_spore_stabilizer`
- `souvenir_canopy_route_chime`

群潮：

- `codex_planet_tidal_archipelago`
- `codex_character_tidal_weather_keeper`
- `codex_character_tidal_city_representative`
- `codex_cargo_tidal_weather_control_core`
- `codex_cargo_tidal_beacon_cells`
- `souvenir_tidal_weather_vane`

赤砂回访另登记 `codex_cargo_relay_pattern_shielding_materials`。所有新增条目默认在
未解锁时隐藏。

T-106 查询约定：

- 图鉴纪念品 ID `codex_souvenir_old_relay_plaque` 与物理纪念品
  `souvenir_old_relay_plaque` 在浏览器中只生成一条可读记录。
- 纪念品墙按本节四个 `souvenir_*` 在注册表中的顺序生成四个槽位；未获得槽位
  不显示候选名称或说明。
- M0 首单当前结算与 v1→v2 迁移都补齐旧中继铭牌，但去重后始终只有一份。

## 站点状态

设施状态使用以下精确稳定 ID：

- `station_state_archive_terminal`
- `station_state_ecology_corner`
- `station_state_relay_observatory`

M0 既有 `station_upgrade_first_delivery_display` 继续只代表首单纪念品展示，不重命名
为新的 M1 设施状态。`station_upgrade_ids` 决定各设施根节点是否启用；
`station_state_level` 只记录最高摘要等级。
