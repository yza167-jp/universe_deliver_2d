# 11 — M1 Technical Delta / M1 技术增量

本文件只描述 M1 相对 M0 已验收技术基线的新增合同。未明确改变的内容继续以 `Docs/05_TECHNICAL_DESIGN.md` 和 `Docs/03_FLIGHT_MODEL.md` 为准。

## 1. 原则

- M0 是回归基线，不通过大重构“顺便泛化”。
- 先建立共享数据与小型接口，再制作白噪星。
- 新星球复用场景流、飞船、HUD、检查点、存档和交付结果，但独特机制保留星球局部组件。
- 不建立万能 Planet Manager、全局 EventBus 或可执行任意脚本的内容系统。
- 所有新状态必须可迁移、可验证、可保存。

## 2. 存档 schema v2

### 2.1 新增字段

`GameProgress` 建议增加：

```text
schema_version = 2
current_chapter_id
unlocked_planet_ids[]
visited_planet_ids[]
revisit_state_by_planet
completed_side_order_ids[]
failed_or_abandoned_side_order_ids[]
relationship_values_by_character
permit_ids[]
codex_entry_ids[]
souvenir_ids[]
module_inventory_ids[]
station_state_id
station_feature_ids[]
demo_ending_flags[]
world_state_flags[]
```

继续保留 M0 字段：

```text
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
```

### 2.2 迁移规则

- v1 → v2 使用明确迁移函数。
- 赤砂星首单完成档应默认：
  - 解锁赤砂星回访入口的前置状态；
  - 保留信用点、模块、旧中继铭牌和首单站点变化；
  - 白噪星显示为下一主线目的地，但仍受屏蔽罩门槛控制。
- 缺失新增字段使用明确默认值。
- 高于当前版本、类型错误、非法负数或矛盾章节状态继续拒绝。
- 迁移失败不得覆盖主档或备份。
- 设置仍位于独立 `settings.cfg`。

### 2.3 自动测试

至少覆盖：

- 全字段 v1 样本迁移。
- 缺字段 v1 样本迁移。
- M0 首单完成状态保持。
- 新字段默认值。
- 重复迁移幂等性。
- 坏档、备份和高版本拒绝。

## 3. 多星球章节与导航

### 3.1 章节模型

新增稳定 ID：

```text
chapter_red_sand_first_delivery
chapter_white_noise
chapter_red_sand_revisit
chapter_canopy_world
chapter_tidal_archipelago
chapter_m1_epilogue
```

章节负责：

- 主线顺序。
- 解锁条件。
- 当前主要订单。
- 可用支线。
- 可回访星球。
- 章节完成效果。

章节数据不执行任意脚本；条件和效果使用白名单。

### 3.2 导航状态

导航屏显示：

- 已解锁且当前订单允许的目的地。
- 已发现但未解锁的星球轮廓。
- 锁定原因：剧情、许可、模块或订单。
- 可回访状态。
- 当前风险与环境摘要。

导航确认仍只允许当前订单合法目的地，不能变成自由星图沙盒。

## 4. Planet Route 合同

### 4.1 可复用层

新星球路线可复用：

- `FlightShip` 与 `FlightTuning`。
- `FlightHUD`、Full Diagnostics 与控制帮助。
- 环境阶段插值。
- 检查点和资源快照。
- 失败、重试和场景交接。
- 进入风格记录。
- 统一普通伤害入口。
- 着陆/投放结果提交接口。

### 4.2 星球局部层

每颗星球独立提供：

- `PlanetRouteDefinition`。
- 环境 Profile。
- 背景与视差控制器。
- 地形/高度合同。
- 独特危险组件。
- 路线触发和景观事件。
- 到达交付目标。
- 视听层。

不得把赤砂星的八段命名、canonical 地表偏移、低空雷达或平台尾缘逻辑强制成为所有星球模板。

### 4.3 最小接口

建议：

```text
PlanetRouteDefinition
  id
  planet_id
  segment_definitions[]
  environment_profile
  checkpoint_definitions[]
  nominal_time_profiles
  delivery_method
  route_scene_path
  arrival_scene_path
  unique_mechanic_tags[]
```

```text
PlanetRouteRuntime
  start(order_run_state)
  get_current_segment_id()
  create_checkpoint_snapshot()
  restore_checkpoint(snapshot)
  complete_delivery(result)
  abort_route(reason)
```

## 5. 订单与支线

### 5.1 OrderDefinition 增量

```text
chapter_id
order_type              # MAIN / SIDE
urgency_policy          # NONE / SOFT_DEADLINE
soft_deadline_seconds
partial_reward_policy
relationship_effects
permit_rewards[]
codex_rewards[]
souvenir_rewards[]
station_effects[]
revisit_effects[]
```

### 5.2 支线状态

支线允许：

- 接取。
- 放弃。
- 失败。
- 重试。
- 超时减报酬。
- 部分成功。

支线失败不能：

- 扣除阻塞主线的维修费。
- 删除必需主线模块。
- 破坏主线章节状态。

## 6. 交付方式接口

### 6.1 当前类型

```text
LANDING
DROP
```

未来保留：

```text
CHECK_GATE
DOCKING
MOVING_TARGET
RESCUE
```

### 6.2 通用结果

```text
DeliveryAttempt
  order_id
  method
  position_error
  speed
  altitude
  attitude
  cargo_integrity
  elapsed_time
  result_tags[]
```

```text
DeliveryResult
  outcome             # SUCCESS / PARTIAL / RETRY / FAILED
  reward_multiplier
  cargo_result
  story_effects[]
  relationship_effects[]
```

### 6.3 DROP

投放至少验证：

- 目标区。
- 高度窗口。
- 速度窗口。
- 释放时机。
- 货物完整度。

M1 不模拟复杂货箱刚体。投放物可使用短时可控轨迹、图标或简化 Sprite，并由数据化结果判定。

## 7. 关系、许可、图鉴与纪念品

### 7.1 关系

- 使用稳定 `character_id`。
- M1 可使用小范围整数或枚举层级。
- 关系改变必须有来源 ID，避免重复结算。
- 关系优先影响对白、支线、信息和便利，不直接锁死主线。

### 7.2 通行许可

- 许可是非消耗进度。
- 可来自剧情、角色或任务。
- 导航与订单可检查许可。
- 主线许可必须有确定获取路径。

### 7.3 图鉴与纪念品

- 图鉴使用稳定条目 ID。
- 支持未发现、已发现和隐藏说明。
- 纪念品与快递站场景状态关联。
- 解锁操作幂等。

## 8. 模块库存与站点状态

### 8.1 模块库存

M0 只保存装备 ID；M1 增加：

- 已拥有模块。
- 可购买模块。
- 剧情模块。
- 价格与解锁来源。
- 兼容槽位与能力标签。

仍然只有一艘长期飞船。

### 8.2 站点状态

建议：

```text
station_state_m0_returned
station_state_white_noise_returned
station_state_red_sand_revisit
station_state_pre_tidal
station_state_m1_epilogue
```

场景读取稳定状态并显示差异，不为每个状态复制完整大厅场景。

## 9. 内容数据与验证

### 9.1 数据注册表

注册：

- 星球。
- 章节。
- 订单。
- 货物。
- 模块。
- 角色。
- 许可。
- 图鉴。
- 纪念品。
- 站点状态。

### 9.2 验证

检查：

- ID 唯一且非空。
- 引用存在。
- 主线必需模块有确定获取来源。
- 订单目的地与章节合法。
- 文本 Key 存在。
- 路线和到达场景存在。
- 奖励不会重复。
- PROVISIONAL 内容没有被误标为 LOCKED。

## 10. UI 增量

M1 新增：

- 多星球导航列表。
- 支线/主线区分。
- 加急与部分报酬说明。
- 模块库存与购买。
- 关系/许可反馈。
- 图鉴与纪念品详情。
- 投放交付提示。

继续遵守：

- 640×360 中文可读。
- 信息分层。
- 模态界面隐藏场景提示并协调输入。
- 不建设默认全局 UI Manager。
- 开发诊断不进入玩家常驻 HUD。

## 11. 音频与场景生命周期

- 每颗星球拥有本地环境层和主题动机。
- 场景退出显式停止局部循环与临时效果。
- 同一音乐不得由多个场景重复启动。
- 正式长音乐引入时再评估是否需要最小跨场景 `AudioService`。
- 外部音频必须记录许可证。

## 12. 测试矩阵

### 每次共享系统修改

- M0 完整闭环。
- 新游戏。
- M0 v1 迁移。
- 当前 M1 稳定章节。
- 保存、重建 App、继续游戏。

### 每颗新星球

- 数据与本地化。
- 订单接取和配置门槛。
- 驾驶舱旅行。
- 路线场景实例化。
- 检查点、失败和重试。
- 独特危险状态。
- 到达、结算、返站。
- 存档恢复。
- M0 赤砂星回归。

### M1 最终

- 新档完整主线。
- M0 迁移档完整主线。
- 至少一次支线失败/放弃。
- 低空投放成功、部分成功和重试。
- 赤砂回访状态。
- 武装/和平反馈。
- 四星加载与内存。
- 本地可分享构建。

## 13. 性能与范围

- 目标仍为 60 FPS，开发主机 M1 Max。
- 新星球按阶段启用/停用内容。
- 粒子、生物、天气和移动平台有数量上限。
- 不提前实现复杂对象池，先用 profiler 证明需求。
- 每颗星球路线目标仍以约 1–3 分钟为基准，不通过空白距离拉长 Demo。

## 14. 迁移完成条件

M1 共享基础只有在以下条件满足后才允许开始白噪星正式路线：

- M0 完整回归通过。
- schema v1 → v2 迁移通过。
- 多星球导航和章节状态通过。
- 路线模板不改变赤砂星行为。
- 关系、许可、图鉴、升级、支线和投放基础可被测试 fixture 驱动。
- `./scripts/check_project.sh` 通过。