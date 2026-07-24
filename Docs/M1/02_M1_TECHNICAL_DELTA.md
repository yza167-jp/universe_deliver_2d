# M1 Four-Planet Demo — 技术增量

## 1. 原则

M1 在 M0 已验证架构上增量扩展，不进行“为了多星球而重写整个项目”的大改造。

M0 基线继续成立：

- Godot `4.7.1-stable`、Compatibility、纯 2D。
- 640×360、16:9、nearest、真全屏最大 16:9 fractional fit。
- `SceneRouter`、`GameState`、`SaveService`、`SettingsService` 的职责边界。
- `CharacterBody2D` 与显式飞行积分。
- 自有轻量对话、本地化、Resource 数据和测试运行器。
- 模态 UI、护盾优先伤害、检查点与主线安全网。

新增系统必须证明不能通过小型 Resource、组件或现有服务扩展解决后，才允许引入新的全局服务。

## 2. 存档 schema v2

M0 使用 schema v1。M1 需要迁移到 schema v2，并完整支持 v1 → v2。

### 2.1 新增持久字段

建议加入：

```text
schema_version = 2

unlocked_planet_ids: Array[StringName]
planet_relationships: Dictionary[StringName, int]
planet_permit_ids: Array[StringName]
completed_side_order_ids: Array[StringName]
failed_side_order_ids: Array[StringName]
revisit_state_ids: Array[StringName]
codex_entry_ids: Array[StringName]
collectible_ids: Array[StringName]
module_inventory_ids: Array[StringName]
station_upgrade_stage: int
main_story_chapter_id: StringName
ending_variable_tags: Array[StringName]
```

继续保留并迁移：

- 当前/已完成订单。
- 信用点。
- 飞船配置。
- 已读对话。
- 剧情标记。
- M0 站点升级和旧中继铭牌。

### 2.2 迁移规则

v1 → v2：

- 赤砂星默认为已解锁。
- 完成 M0 首单的存档解锁白噪星主线入口。
- 旧中继铭牌转换为对应 `collectible_id` 与 `codex_entry_id`。
- 现有模块配置转换为模块库存 + 已装备槽位。
- 不凭空增加关系值；缺失关系使用明确中性默认。
- 不删除或重置信用点、订单完成记录和设置引用。

保存策略继续使用主档 + 备份。高于当前版本、类型错误或互相矛盾的状态必须拒绝并保留原文件。

## 3. 多星球进度模型

### 3.1 主线章节

`main_story_chapter_id` 负责线性主线位置，例如：

```text
chapter_red_sand_complete
chapter_white_noise_available
chapter_white_noise_complete
chapter_red_sand_revisit_complete
chapter_canopy_available
chapter_canopy_complete
chapter_tidal_available
chapter_tidal_complete
chapter_m1_epilogue
```

不得只用“完成订单数量”推断主线位置。

### 3.2 解锁与许可

- `unlocked_planet_ids`：导航中可查看/选择的星球。
- `planet_permit_ids`：当地通行、设施或剧情授权。
- `required_module_ids`：订单必须配置。
- 主线必需许可和模块必须有确定获取路径。

### 3.3 关系与回访

关系值用于条件和反馈，不做复杂社交模拟：

```text
planet_relationships[planet_id] -> small integer range
revisit_state_ids -> stable named states
```

关系变化只由白名单效果写入。回访场景读取稳定状态 ID，不根据大量零散 flag 猜测。

## 4. 数据 Resource 增量

### 4.1 `PlanetDefinition`

M1 新增或正式启用：

```text
main_route_id
arrival_scene_id
revisit_scene_ids[]
required_permit_ids[]
codex_entry_ids[]
planet_packet_path
```

### 4.2 `OrderDefinition`

新增：

```text
chapter_id
is_timed
soft_time_limit_seconds
late_reward_multiplier
revisit_state_requirements[]
relationship_requirements
relationship_effects
permit_rewards[]
codex_rewards[]
```

### 4.3 `DeliveryMethodDefinition`

建立小型数据定义：

```text
id
scene_behavior_id
speed_window
altitude_window
position_tolerance
failure_policy
```

M1 正式实现 `landing` 与 `low_altitude_drop`。

### 4.4 `CodexEntryDefinition`

```text
id
category
name_key
body_keys[]
icon
unlock_requirements
related_planet_ids[]
related_character_ids[]
```

### 4.5 `RevisitStateDefinition`

```text
id
planet_id
required_story_flags[]
visual_variant_id
dialogue_sequence_ids[]
available_order_ids[]
interactable_changes[]
```

所有新增引用必须进入注册表验证。

## 5. 多目的地导航

驾驶舱导航从“M0 单一赤砂星”扩展为：

- 只显示已解锁星球。
- 主线订单只允许选择其目标星球。
- 支线订单同样由订单目标约束。
- 未解锁星球可按剧情需要显示轮廓，但不可确认。
- 星球卡显示环境、风险、距离、许可与必要模块摘要。
- 导航不成为自由开放星图；主线顺序仍受章节控制。

旅行状态流继续使用离站、巡航、接近与场景交接，不为每颗星球复制控制器。

## 6. 星球路线模板

从赤砂星提取可复用合同，而不是直接复制脚本：

```text
PlanetFlightRoute
├── FlightRouteDefinition
├── EnvironmentDirector
├── RouteGeometryProvider
├── HazardContainer
├── CheckpointContainer
├── DeliveryTarget
├── PlanetVisualDirector
├── FlightShip
├── CameraRig
├── EssentialHUD
└── AudioLayers
```

共用：

- 飞船、相机、HUD、资源、伤害、检查点、帮助。
- 路线阶段推进接口。
- 危险预警与结果接口。
- 俯冲/滑翔风格记录。
- 到达与结算交接。

定制：

- 阶段数据与环境曲线。
- 地形/通道和背景视觉。
- 独特危险。
- 交付方式。
- 当地音频与剧情触发。

赤砂星专属的 canonical surface frame、低空雷达和平台尾缘逻辑不得被无条件塞进所有星球基类。只有确实共用的合同进入组件。

## 7. 白噪星技术增量

第一颗新增星球需要：

- 相对赤砂星约 `1.2–1.35` 的工作重力范围。
- 电磁暴雪环境状态。
- 低能见度但可访问的地形轮廓。
- HUD/导航干扰的可读表现，不能隐藏关键安全信息。
- 特高压电屏蔽罩能力门控。
- 冰洞/冰下设施的路线几何。
- 与赤砂星不同的检查点和到达方式节奏。

电磁干扰优先作为可配置状态：

```text
visibility_pressure
navigation_noise
instrument_dropout_window
shield_stress
```

不直接随机禁用玩家输入，也不通过不可读故障制造难度。

## 8. 支线与加急订单

支线复用主线订单状态机，但拥有独立结果：

- `AVAILABLE / ACCEPTED / IN_TRANSIT / COMPLETED / FAILED / ABANDONED`
- 一次仍只携带一单。
- 加急时间只影响报酬，不强制主线失败。
- 支线失败不撤销主线许可和关键模块。
- 不通过重复刷单提供主线必需资源。

时间从实际订单运行开始计，不包括暂停、阻塞对话和加载时间。

## 9. 低空投放

M1 第二种正式交付方式：

- 玩家进入清楚的投放走廊。
- HUD 显示速度、高度、位置三个条件。
- 条件进入宽容窗口后允许释放。
- 释放后货物沿简化轨迹到目标，不模拟复杂绳索或真实箱体物理。
- 偏差影响完整度/对白/报酬；主线可以快速重试。
- 使用 `DeliveryMethodDefinition`，不在具体星球脚本中硬编码全部数值。

## 10. 图鉴、纪念品与站点变化

图鉴与纪念品数据进入 `GameProgress`，展示仍由站点局部场景负责：

- 纪念品墙按稳定槽位 ID 更新。
- 图鉴提供分类与详情，不制作复杂百科搜索。
- 新站点功能通过稳定升级 ID 解锁。
- 站点变体应可由场景状态应用器重建，不能依赖保留旧场景节点。

## 11. 测试增量

M1 每个任务继续运行 M0 全量检查。新增重点：

- v1 → v2 存档迁移与备份恢复。
- 多星球解锁和章节合法转换。
- 订单目标与导航目的地一致性。
- 关系/许可/图鉴引用验证。
- 主线与支线状态隔离。
- 加急时间暂停规则与报酬计算。
- 低空投放速度/高度/位置窗口。
- 星球路线模板的关键场景实例化。
- 每颗星球完整路线烟雾。
- M0 从新游戏到继续游戏完整回归。

测试不得声称验证角色质量、环境差异或飞行手感；这些由 M1 Gate 人工判断。

## 12. 性能与资产

- 保持 60 FPS 目标。
- 新星球按阶段启用/停用内容，不引入开放世界流送系统。
- 正式音频、字体或第三方资产必须先更新依赖/署名记录。
- 生成式占位图进入 `approved_placeholder` 前必须修正伪文字、像素密度和可读碰撞。
- M1 结束前再评估 Git LFS、平台 SDK 和发布打包依赖。

## 13. 迁移完成条件

M1-A 技术基础只有在以下条件满足后才能进入白噪星高成本路线制作：

- [ ] schema v2 与 v1 迁移通过。
- [ ] 多星球解锁、章节、许可、关系和图鉴有稳定数据模型。
- [ ] 导航可显示多个已解锁星球并拒绝非法目的地。
- [ ] 路线模板可以实例化赤砂星回归和白噪星空白路线。
- [ ] M0 完整闭环测试继续通过。
- [ ] 没有新增第三方运行时依赖，或依赖已获记录与批准。
