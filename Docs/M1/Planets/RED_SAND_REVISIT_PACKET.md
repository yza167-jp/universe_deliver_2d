# Planet Packet — Red Sand Revisit / 赤砂星回访

## Canon status

- 星球、伊娅、首单与低空管制规则：M0 已锁定基线。
- M1 回访订单与具体材料名：PROVISIONAL。

## One-sentence identity

首单改善了居民维修场，却也让公司注意到一批“不在配额内”的设备；玩家回访赤砂星，在伊娅与老皮帮助下把旧中继铭牌的结构变成飞船的特高压电屏蔽罩。

## Narrative role

- 证明订单会改变地点和人物。
- 让伊娅成为持续角色。
- 为白噪星提供确定的模块获取路径。
- 让旧中继铭牌从收藏物变为主线线索，但不解释终极秘密。

## Natural environment

沿用赤砂星：沙漠、尘暴、峡谷、低水资源。回访时可见变化：

- 冷却/净水设备开始运行。
- 维修场增加管线、蒸汽和居民活动痕迹。
- 路线使用较短、变化后的后半段或新的安全航道。

## Civilization

- 居民维修场继续在公司配额外维持基础设施。
- 公司对首单产生的“额外需求”保持警惕。
- 伊娅获得少量工作空间，但没有因此变成权力人物。

## Local conflict

屏蔽罩改造所需材料被公司归类为非标准用途。伊娅可以完成改造，但需要玩家送达材料，并决定是否把技术记录上传公司系统。

## Flight identity

- 不做第二条同规模完整星球路线。
- 复用赤砂路线的短变化段、不同检查点或安全航道。
- 展示首单后的设施变化。
- 不重复 Gate C 的全部危险组合。

### T-110 Working route contract

- 路线变化 ID：`route_red_sand_revisit_service_lane`。
- 入口检查点：`checkpoint_red_sand_revisit_service_lane`。
- 复用 `route_red_sand_m0` 的 `26000–38000 m` 窗口。
- 名义距离：`12000 m`；名义时长：`48 s`。
- 这些数值用于 T-112 的短回访实现与调参，不代表已开放正式可玩路线。

## Main order

Stable ID：`order_m1_red_sand_shielding_retrofit`

作用：送达屏蔽层材料/校准组件，完成特高压电屏蔽罩改造。

候选订单标题：

1. **推荐：**《旧铭牌的新外壳》
2. 《配额外改装许可》
3. 《耐压层临时补件》

候选货物显示名：

1. **推荐：** 中继纹路屏蔽层
2. 高压隔离编织片
3. 非标电磁层压组件

Stable cargo ID：`cargo_relay_pattern_shielding_materials`

T-110 前置与状态合同：

- 必须完成 `order_red_sand_m0`，并持有 `story_red_sand_order_completed`。
- 回访状态按 `revisit_red_sand_available` →
  `revisit_red_sand_materials_pending` → `revisit_red_sand_completed` 推进。
- 订单仍为 `REGISTERED_ONLY`；T-112 才能开放接取、路线和实际交付。

## Required/recommended loadout

- 必须：M0 基础大气防护。
- 推荐：护盾备用电源。
- 激光炮不影响主线资格，但伊娅可以评论玩家配置。

## Delivery method

着陆。

## Characters

- 伊娅：既有角色，状态更新。
- 老皮：参与校准与异常信号反馈。
- 公司远程审核员：只通过终端/文本出现，不新增现场 NPC。

## Arrival scene

- 更新后的维修场。
- 伊娅检查材料与旧铭牌。
- 玩家可查看首单设备运行状态。
- 改装完成后飞船获得可见屏蔽节点。
- 玩家选择是否上传完整改装记录；只影响公司/伊娅关系和图鉴文本。

T-110 使用以下稳定选择标记：

- `story_m1_red_sand_retrofit_records_uploaded_full`
- `story_m1_red_sand_retrofit_records_kept_local`

两条分支在同一段老皮信号反馈与白噪线索处汇合。完成合同确定发放免费且唯一的
`module_high_voltage_shielding` 所有权、档案终端状态、白噪章节和赤砂回访完成
状态；模块实际能力/外观与可玩结算分别由 T-111、T-112 落地。

## Revisit seed

未来可回访查看：

- 居民区是否继续扩展。
- 公司是否追查非标屏蔽技术。
- Stretch 支线“配额之外的滤芯”。

## Art package

- 复用赤砂色板。
- 新增运行中的冷却管线、蒸汽、灯光和居民生活道具。
- 屏蔽罩模块图标和飞船小型外观节点。

## Audio package

- 维修设备运行环境音。
- 屏蔽校准短音效。
- 旧铭牌产生的低频异常噪声。

## Scope budget

- 短回访流程 15–30 分钟。
- 路线复用/变化，不做第二套完整赤砂背景资产。
- 主对话约 15–30 行。
- 1 个站点变化：档案终端解锁。
