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

## 星球与环境占位

| Planet ID | Gravity scale | Environment profile | Readiness |
|---|---:|---|---|
| `planet_red_sand` | 1.00 | 既有赤砂环境 | `PLAYABLE` |
| `planet_white_noise` | 1.28 | `environment_white_noise_placeholder` | `REGISTERED_ONLY` |
| `planet_canopy_world` | 0.83 | `environment_canopy_world_placeholder` | `REGISTERED_ONLY` |
| `planet_tidal_archipelago` | 0.98 | `environment_tidal_archipelago_placeholder` | `REGISTERED_ONLY` |

三个新环境只提供保守的重力、密度、阻力与终端下降安全值，不代表对应路线手感已经
完成。它们没有 `flight_scene_path`。

## 新模块

| Module ID | Slot | Capability | 获取标记 |
|---|---|---|---|
| `module_high_voltage_shielding` | Defense | `capability_high_voltage_shielding` | `story_m1_red_sand_shielding_retrofit_completed` |
| `module_biosignal_isolation` | Utility | `capability_biosignal_isolation` | `story_m1_biosignal_isolation_available` |
| `module_crosswind_stabilizer` | Utility | `capability_crosswind_stabilization` | `story_m1_crosswind_stabilizer_available` |

本任务只声明能力标签，不实现关卡效果。屏蔽罩是白噪主线硬门槛；隔离舱与横风
稳定器在对应主线只作为推荐模块。

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

| Order ID | Type / Delivery | Credit | Route | Risk | Module rule |
|---|---|---:|---:|---:|---|
| `order_m1_red_sand_shielding_retrofit` | Revisit / Landing | 140 | 1.00 | 2 | M0 drive + atmosphere required |
| `order_m1_white_noise_archive_core` | Main / Landing | 180 | 1.25 | 4 | high-voltage shielding required |
| `order_m1_canopy_ecology_cargo` | Main / Landing | 200 | 1.15 | 3 | biosignal isolation recommended |
| `order_m1_tidal_weather_core` | Main / Landing | 240 | 1.30 | 4 | crosswind stabilizer recommended |
| `side_white_noise_returned_memory` | Side / Landing | 80 | 0.65 | 2 | archive permission required |
| `side_canopy_spore_drop` | Side / Low-altitude drop | 90 | 0.55 | 3 | biosignal isolation recommended |
| `side_tidal_beacon_before_eye` | Side / Landing / Express | 120 | 0.70 | 4 | crosswind stabilizer recommended |

群潮支线的暂定加急参数为：目标 `120 s`、宽限 `60 s`、最低信用点比例 `0.50`、
准时关系加成 `+1`。其余六单为非加急。全部 M1 主线、回访与三份必做支线均为
`UNIQUE`。

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
