# M1 Main Order Packets

本文件给出 M1 五份主线订单的稳定 ID、作用与候选显示名。更详细的自然、文明与路线信息见对应 Planet Packet。

## 1. M0 赤砂星首单

```text
order_id: order_red_sand_cooling_core
status: LOCKED / implemented in M0
cargo_id: cargo_deep_cooling_pump_core
delivery_method: LANDING
```

作用：建立玩家、老皮、伊娅、公司档案矛盾和旧中继铭牌。

## 2. 赤砂星回访：屏蔽改装

```text
order_id: order_m1_red_sand_shielding_retrofit
role: MAIN / REVISIT
cargo_id: cargo_relay_pattern_shielding_materials
destination: planet_red_sand
delivery_method: LANDING
required_modules: M0 baseline atmospheric protection
reward: module_high_voltage_shielding + archive terminal unlock
```

候选标题：

1. **推荐工作候选：**《旧铭牌的新外壳》
2. 《配额外改装许可》
3. 《耐压层临时补件》

玩家可见简报：

- 伊娅请求一批非标准屏蔽材料。
- 公司系统将其标记为“设备兼容性复核”。
- 实际目标是根据旧中继铭牌结构改造玩家飞船。

成功结果：

- 获得特高压电屏蔽罩。
- 解锁白噪星资格。
- 伊娅关系与公司记录根据“是否上传完整改装记录”变化。

失败保底：

- 主线货物严重损坏时从检查点重试。
- 不允许永久失去屏蔽罩获取路径。

## 3. 白噪星主线

```text
order_id: order_m1_white_noise_archive_core
role: MAIN
cargo_id: cargo_white_noise_archive_core
destination: planet_white_noise
delivery_method: LANDING
required_modules: module_high_voltage_shielding
reward: archive permission + codex entries + White Noise relation
```

候选标题：

1. **推荐工作候选：**《白噪中的索引》
2. 《请勿永久保存》
3. 《档案层恢复件》

候选货物：

1. 记忆索引冷核。
2. 档案层相位校准器。
3. 静默库解冻密钥。

Visible brief：恢复一层失效档案索引。

Company description vs reality：公司称其为标准服务恢复，组件实际上可能授予批量索引访问权。

Flight constraints：较强重力、电磁暴雪、低能见度；屏蔽罩降低干扰。

Arrival choice：最小公开索引、保持封存、交由当地共同保管。

失败保底：主线检查点重试；差结果影响关系与报酬，不阻塞穹林主线。

T-125 实现状态：

- 正式订单、白噪星与独立 `34000 m` 航路已在完整接单至继续游戏闭环通过后
  升级为 `PLAYABLE`。
- 三项选择共享同一返航和结算出口。固定奖励为白噪关系 `+1`、档案许可、
  白噪基础图鉴、霜纹索引纪念品、白噪回访种子及穹林章节/导航；封存或当地
  共同保管当前额外关系 `+1`，仍为 Gate F 可调工作值。
- 每次只写入本次选择对应的一条异常图鉴和一个 `ending_archive_choice` 值；
  `0%` 货物完整度仍完成主线，重复结算或读档不会重复发奖。

## 4. 穹林星主线

```text
order_id: order_m1_canopy_ecology_cargo
role: MAIN
cargo_id: cargo_canopy_ecology_sample
destination: planet_canopy_world
delivery_method: LANDING
recommended_modules: module_biosignal_isolation
reward: Canopy relation + ecology corner + biosignal module path
```

候选标题：

1. **推荐工作候选：**《迁徙季的陌生气味》
2. 《请封存武器后入冠》
3. 《树冠隔离航线》

候选货物：

1. 菌根迁徙样本舱。
2. 授粉季生态信标。
3. 幼林免疫孢囊。

Visible brief：将生态样本送达核心树冠隔离区。

Company description vs reality：公司称为普通研究样本；实际关系到幼林病害与迁徙窗口。

Flight constraints：信号/气味吸引飞行生物；隔离舱降低风险。

Weapon choice：封存激光进入核心路线，或保留激光走外缘路线。

失败保底：货损可影响当地释放方式，但不阻塞群潮主线。

## 5. 群潮星主线

```text
order_id: order_m1_tidal_weather_core
role: MAIN
cargo_id: cargo_tidal_weather_control_core
destination: planet_tidal_archipelago
delivery_method: FLOATING_PLATFORM_LANDING
recommended_modules: module_crosswind_stabilizer
reward: station relay observatory + M1 ending flags
```

候选标题：

1. **推荐工作候选：**《把风交给谁》
2. 《天气塔临时托管件》
3. 《风暴航路仲裁核心》

候选货物：

1. 天气塔共识钥。
2. 潮汐控制分配器。
3. 风暴航路仲裁核心。

Visible brief：恢复天气塔网络与跨城邦航路。

Company description vs reality：公司称为服务恢复；组件授权模式决定控制权和数据访问。

Flight constraints：横风、天气塔影响区、浮动平台；稳定器降低扰动。

Arrival choice：单一城邦、城邦联盟公开接口、公司临时托管。

Climax：所有选择都激活中继节点，揭示网络早于公司并显示星图外坐标。

## 主线状态规则

- 每次只允许一份 active order。
- 主线不能被误放弃。
- 必须模块有确定路径。
- 差结果可以减少奖励、关系或便利，但不能造成章节死档。
- 订单完成效果必须幂等，重复进入结算不重复发奖。
- 主线选择只写入局部关系、图鉴与结尾变量，不分裂完整章节。
