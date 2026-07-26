# M1 Side Order Packets

M1 支线的目标是自由探索、人物故事、图鉴和升级资源，不是重复刷取。每次仍只携带一单；支线可放弃、失败或部分成功，但不得造成主线死档。

## 1. 白噪星必做支线：被退回的记忆盒

```text
order_id: side_white_noise_returned_memory
role: SIDE
planet_id: planet_white_noise
cargo_id: cargo_returned_memory_case
delivery_method: LANDING
urgent: false
required_for_main: false
```

候选标题：

1. **推荐工作候选：**《被退回的记忆盒》
2. 《只归还副本》
3. 《未获授权的家庭档案》

### Visible brief

一只因授权记录不完整而被档案层退回的私人记忆盒，需要送还原持有人或其代理。

### Customer history

- 记忆盒来自一户已迁出档案层的家庭。
- 公司曾建议将其转入商业托管。
- 原持有人多次要求“只归还，不建立公开索引”。

### Flight constraints

- 使用白噪主线路线的较短分支。
- 货物怕强烈冲击。
- 不增加新的独特危险。

### Arrival choice

- 保持完全私密。
- 仅建立匿名索引。
- 只归还副本，原件继续由当地保管。

### Results

- 信用点。
- 白噪关系变化。
- 人物/记忆盒图鉴文本变化。
- 不提供主线必需模块。

### Failure and partial success

- 货损减少报酬和关系。
- 放弃/失败不阻塞穹林星。

### T-126 implementation result

- 正式支线复用白噪主航路 `17000–34000 m` 后半段，从极光暴雪段的安全检查点
  开始；不创建第二条路线、第二个目的地区域或新的独特危险。
- 订单终端在接取前明确标注“自愿支线”，并且只在白噪主单完成、档案许可已获得
  后显示为可接取；它不属于穹林主线的完成依赖。
- 抵达继续复用 1.5 屏冰下档案区，但使用独立驾驶舱、旅行和抵达对白。三项
  选择分别写入完全私密、匿名容器索引或“副本归还、原件当地封存”的稳定标记，
  然后汇入同一结算。
- 基础报酬为 `80` 信用点与白噪关系 `+1`。货物完整度低于当前可调阈值 `70%`
  时，信用点沿统一货损公式减少，并以 `-1` 附加修正抵消本单关系奖励；不会
  撤销白噪主单结果、穹林章节、导航或模块。
- 人物与记忆盒图鉴说明会按唯一选择更新；完成、失败与放弃均使用既有订单状态机，
  不增加 T-140 才负责的通用支线管理界面。

---

## 2. 穹林星必做支线：孢子季急投

```text
order_id: side_canopy_spore_drop
role: SIDE
planet_id: planet_canopy_world
cargo_id: cargo_canopy_spore_stabilizer
delivery_method: LOW_ALTITUDE_DROP
urgent: false
required_for_main: false
```

候选标题：

1. **推荐工作候选：**《孢子季急投》
2. 《树冠接收环》
3. 《别让它落到根层》

### Visible brief

一批生态稳定剂/医疗孢囊需要送到无法安全着陆的小型树冠诊疗点。

### Why personal last mile

- 接收点位于狭窄树冠区域。
- 自动货运会干扰迁徙生物和孢子流。
- 玩家需要在正确高度、速度和位置释放。

### Delivery window

- 固定、宽容的树冠接收环。
- 核心区成功；外圈部分成功；完全错过可重试或放弃。
- 参数集中配置并有路线提示。

### Flight constraints

- 货物信号会轻度吸引生物。
- 生物信号隔离舱降低风险。
- 不要求移动目标或复杂弹道。

### Results

- 信用点、穹林关系、诊疗点图鉴。
- 成功后站点生态角增加一件小物件/对白。

### Failure and partial success

- 外圈投放减少报酬，但仍可完成。
- 货物完全损坏或错过可重试/放弃。
- 不影响群潮主线资格。

---

## 3. 群潮星必做支线：风眼前的灯

```text
order_id: side_tidal_beacon_before_eye
role: SIDE
planet_id: planet_tidal_archipelago
cargo_id: cargo_tidal_beacon_cells
delivery_method: LANDING
urgent: true
required_for_main: false
```

候选标题：

1. **推荐工作候选：**《风眼前的灯》
2. 《下一班船之前》
3. 《航标电池加急件》

### Visible brief

天气维护队需要一组导航信标电池，在下一段风墙到来前恢复一条民用航路。

### Customer history

- 维护队的预算优先级长期低于天气塔核心。
- 多次补给被合并进“非紧急基础设施”。
- 该航标服务普通客运和渔业，不直接服务城邦权力中心。

### Flight constraints

- 复用群潮路线分支和横风机制。
- 使用宽松加急目标。
- 不新增硬失败倒计时。

### Timing results

- 按时：完整信用点 + 关系奖励。
- 宽限内：轻微减报酬。
- 超时：保底报酬，关系奖励减少；仍可交付。

### Results

- 天气维护者关系。
- 民用航路图鉴。
- 群潮结尾对白的一处小反馈。

### Failure

- 货物损坏/放弃不阻塞主线高潮。

---

## 4. 赤砂星 Stretch 支线：配额之外的滤芯

```text
order_id: side_red_sand_unlisted_filters
role: SIDE
planet_id: planet_red_sand
cargo_id: cargo_red_sand_water_filters
state: STRETCH
required_for_main: false
```

候选标题：

1. **推荐工作候选：**《配额之外的滤芯》
2. 《没有编号的净水件》
3. 《维修场第二张清单》

### Purpose

- 展示首单与回访之后居民区仍在变化。
- 给赤砂普通居民与维修工作更多生活细节。
- 不承担主线模块、章节或中继揭示。

### Scope control

- 只复用短路线或目的地互动。
- Gate F 后根据预算决定 `Ready` 或 `Deferred`。
- 无论是否制作，都不能阻塞 Gate G/H/I。

---

## 支线共同规则

### 可发现性

- 支线由人物、终端或站点变化解锁，不依赖随机刷新。
- 订单终端明确标记“可选”。
- 不使用紧迫措辞诱导玩家认为不做就会主线失败。

### 报酬

支线可以给予：

- 信用点。
- 关系。
- 图鉴/纪念品。
- 可选模块便利。
- 额外对白和回访状态。

不得给予唯一主线必需模块，除非同时存在确定主线路径。

### 失败

- 玩家可以重试或放弃。
- 失败只影响本单报酬、关系或局部内容。
- 不扣除阻塞继续游戏的维修费。
- 不永久锁死约 95% 隐藏结局所需内容；完整游戏可提供替代获取或回访机会。

### 测试

每份支线至少覆盖：

- 解锁条件。
- 接取/放弃/完成/失败。
- 一次一单约束。
- 报酬与关系计算。
- 保存/加载。
- 不阻塞主线。
- 订单结果幂等。
