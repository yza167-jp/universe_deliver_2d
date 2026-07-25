# M1 Save Schema v2

## 1. 目标

- M0 v1 存档可以无损进入 M1。
- 多星球、支线、关系、许可、图鉴、模块和站点变化可以稳定保存。
- 继续保持单一主档、备份恢复和坏档保留。
- 不恢复飞行中的场景节点；继续游戏仍回到稳定快递站节点。

## 2. Schema v2

建议数据：

```text
schema_version = 2

# M0 既有字段
current_order_id
 destination_id
cargo_id
ship_configuration
story_flags
read_dialogue_ids
completed_order_ids
credits
station_upgrade_ids
departure_confirmed
travel_state
travel_destination_id
order_run_state
settings_reference

# M1 新增字段
main_story_chapter
unlocked_planet_ids
planet_relation_values
planet_permission_ids
codex_entry_ids
souvenir_ids
completed_side_order_ids
failed_side_order_ids
station_state_level
ship_upgrade_ids
revisit_state
demo_ending_flags
last_stable_station_state
```

具体类型：

```text
main_story_chapter: StringName
unlocked_planet_ids: Array[StringName]
planet_relation_values: Dictionary[StringName, int]
planet_permission_ids: Array[StringName]
codex_entry_ids: Array[StringName]
souvenir_ids: Array[StringName]
completed_side_order_ids: Array[StringName]
failed_side_order_ids: Array[StringName]
station_state_level: int
ship_upgrade_ids: Array[StringName]
revisit_state: Dictionary[StringName, StringName]
demo_ending_flags: Dictionary[StringName, Variant]
last_stable_station_state: StringName
```

默认值：

- StringName 字段为空 ID。
- Array 与 Dictionary 字段为空集合。
- `station_state_level = 0`。
- `demo_ending_flags` 只接受布尔、整数、有限浮点数或非空稳定 ID。
- 集合读取和写回均去重；字典键和值必须通过类型验证。

## 3. 稳定 ID

### 章节

```text
chapter_m0_red_sand_complete
chapter_m1_red_sand_revisit
chapter_m1_white_noise
chapter_m1_canopy_world
chapter_m1_tidal_archipelago
chapter_m1_demo_epilogue
```

### 星球

```text
planet_red_sand
planet_white_noise
planet_canopy_world
planet_tidal_archipelago
```

### 模块

```text
module_asteroid_laser
module_shield_backup_power
module_high_voltage_shielding
module_biosignal_isolation
module_crosswind_stabilizer
```

### 站点状态

```text
station_state_m0_first_delivery
station_state_archive_terminal
station_state_ecology_corner
station_state_relay_observatory
```

### M0 兼容与既有图鉴

```text
order_red_sand_m0                    # M0 运行时历史 ID，必须保留
order_red_sand_cooling_core          # M1 Packet canonical 完成别名
codex_planet_red_sand
codex_character_iya
codex_souvenir_old_relay_plaque
souvenir_old_relay_plaque
station_after_first_delivery         # 首单后的稳定返站恢复 ID
```

v1 完成档迁移时保留 `order_red_sand_m0`，同时补入
`order_red_sand_cooling_core`，避免旧 M0 场景重新开放订单，并让后续 M1 Packet
读取 canonical ID。不得以迁移为由重命名或删除已经进入玩家存档的 M0 ID。

## 4. v1 → v2 迁移

### 已完成赤砂首单的 v1 存档

迁移后：

```text
main_story_chapter = chapter_m1_red_sand_revisit
unlocked_planet_ids includes planet_red_sand
completed_order_ids preserves order_red_sand_cooling_core
codex_entry_ids includes existing Red Sand / Iya / relay plaque entries when corresponding flags exist
souvenir_ids includes souvenir_old_relay_plaque when station upgrade exists
station_state_level >= 1
last_stable_station_state = station_after_first_delivery
```

白噪星不能因迁移直接解锁；必须完成赤砂回访并取得屏蔽罩。

### 未完成赤砂首单的 v1 存档

- 保留原 M0 进度。
- 当前 M0 没有已锁定的“首单前”章节 ID，因此 `main_story_chapter` 保持空 ID，
  继续由既有订单、剧情和站点字段决定进度。
- 新集合字段使用空集合或明确默认值。
- 不发放 M1 模块、关系或奖励。

### Schema 0 / 缺版本字段

继续沿用现有 0→1 迁移，再执行 1→2；不得跳过既有验证。

## 5. 迁移不变量

- 信用点不减少、不重复发放。
- 已完成订单不丢失。
- 飞船已有模块不丢失。
- 旧中继铭牌和站点变化不丢失。
- 设置文件不被迁移覆盖。
- 迁移成功后下一次稳定保存才写入 v2 主档。
- 读取和“继续游戏”本身不改写 v1；下一次稳定保存时，原有效 v1 由现有备份
  轮换机制保留。
- 迁移失败时保留原文件并提示，不写入部分状态。

## 6. 支线状态

一次仍只有一个 `current_order_id`。支线历史存入：

```text
completed_side_order_ids
failed_side_order_ids
story_flags
planet_relation_values
codex_entry_ids
```

放弃支线：

- 清除 active order。
- 可写入非永久冷却/可重接状态，具体由 OrderDefinition 决定。
- 不加入 `failed_side_order_ids`，除非订单设计明确将放弃视为失败。

部分成功：

- 订单可标记完成。
- `result_tags` 记录迟到、货损、偏差投放等。
- 报酬、关系和图鉴文本由结果计算。

## 7. 关系与许可

关系值建议 M1 使用小整数范围，例如 `-2…+3`，不作为可无限刷取条。

许可使用稳定 ID：

```text
permission_white_noise_archive_access
permission_canopy_core_route
permission_tidal_weather_tower
```

主线必须许可必须有确定获取路径；关系值不足可以改变便利和对白，但不能造成无法修复的主线死档。

运行时关系范围固定为 `-2…+3`。正常关系变化必须通过 `GameStateModel` 的唯一
事件接口；事件消费标记使用
`m1_relation_event/<planet>/<event>` 存入既有 `story_flags`，因此存档恢复不会
重新发奖。章节、星球和许可读取时验证本文件列出的稳定白名单；图鉴、纪念品和
回访状态只接受非空稳定英文 ID。

## 8. Demo 结尾变量

```text
ending_tidal_control_choice
ending_weapon_tendency
ending_archive_choice
ending_side_orders_completed
ending_relay_signal_detected
```

这些变量只用于 M1 结尾对白、图鉴和未来 M2 起点，不在 M1 创建多套结局关卡。

## 9. 自动测试

至少覆盖：

1. v1 完成档迁移。
2. v1 未完成档迁移。
3. schema 0→1→2 链式迁移。
4. v2 正常保存/加载。
5. 缺字段默认值。
6. 类型错误和非法负数拒绝。
7. 主档损坏时备份恢复。
8. 高于当前 schema 拒绝。
9. 迁移不重复发奖。
10. 多星球、关系、许可、图鉴、纪念品、支线和结尾变量往返一致。
11. 设置独立。
12. M0 新游戏/继续回归。

## 10. 明确不做

- 多存档槽。
- 云同步。
- 跨平台同步。
- 飞行中精确场景恢复。
- 回滚任意历史章节。
- 存档编辑器。
