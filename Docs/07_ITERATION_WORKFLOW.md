# 07 — Iteration Workflow / 迭代工作流

## 1. 目标

工作流服务于：

- Codex 快速实现小而完整的可玩增量。
- 人类在关键节点直接判断星球差异、角色、手感和节奏。
- M1 扩展内容时持续保护 M0 已验收基线。

自动检查负责工程正确性；人工试玩负责体验判断，两者不能互相冒充。

## 2. 每次会话开始

主 Agent 按顺序：

1. 阅读 `AGENTS.md`。
2. 阅读 `CODEX_GOAL.md`。
3. 阅读 `DEVELOPMENT_TASKS.md`。
4. 阅读 `Docs/08_DECISION_LOG.md` 与 `Docs/M1/06_M1_DECISIONS.md`。
5. 阅读当前任务引用文档和 Packet。
6. 运行 `git status --short`。
7. 查看近期相关提交与实现。
8. 确认没有 `In Progress` 或未处理的 `Human Check`。
9. 选择依赖已满足的最早 `Ready` 任务并改为 `In Progress`。

开始报告只说明：任务、玩家价值、范围、明确不做、主要文件与验证方案。

## 3. 标准循环

```text
读取任务、Packet 与现状
→ 确认 M0 回归边界
→ 找到最小可逆实现
→ 修改数据/代码/场景
→ 运行相关快速测试
→ 启动最短可玩路径
→ 根据真实结果修正
→ 更新测试与必要文档
→ 运行完整适用检查与 M0 回归
→ 更新任务和依赖状态
→ 主 Agent 提交
→ 报告并停止
```

一次只完成一个任务，不因上下文充足自动继续第二项。

## 4. 内容任务前置

制作新星球高成本内容前必须存在：

- Planet Packet。
- Main Order Packet。
- 核心角色 stable ID 与候选。
- 独特飞行机制说明。
- 内容预算。
- 依赖与验收任务卡。

未完成 Packet 时，可以研究和补文档，不能直接批量生成关卡和正式资产。

## 5. 检查层级

### Level 0 — 编辑中快速检查

- 语言服务器/解析错误。
- 相关单元测试。
- 当前场景直接运行。
- 数据引用验证。

### Level 1 — 仓库检查

任务完成前：

```bash
./scripts/check_project.sh
git diff --check
git status --short
```

### Level 2 — 当前功能烟雾

按任务选择：

- 存档：v1→v2、主档/备份、继续。
- 导航：章节/模块/许可门槛。
- 订单：接取、放弃、完成、失败和幂等结算。
- 低空投放：成功、部分成功、失败与重试。
- 新星球：直达路线、独特机制、到达与结算。
- 支线：发现、接取、失败/部分成功、保存与主线不阻塞。

### Level 3 — M0 回归

重要系统与每颗星球整合任务至少验证：

```text
M0 新游戏
→ 赤砂首单
→ 失败/重试
→ 目的地剧情
→ 结算返站
→ 保存与继续
```

不要求每次人工重玩完整 M0，但自动回归必须保持。

### M1 基础聚合回归入口

T-109 起可单独运行：

```bash
GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot" \
  ./scripts/check_m1_foundation.sh
```

该脚本按子系统分别报告：类型化 M1 合同、v1→v2 迁移、多星球订单/导航、图鉴/
纪念品/站点、档案终端、低空投放、加急订单、M1 调试场景及 M0 完整闭环。它
同时属于 `./scripts/check_project.sh` 的必跑项，失败时保留具体子系统名称。

开发构建可用以下入口直达内容：

```bash
"$GODOT_BIN" --path . --language zh_CN -- --m1-debug=gate_e
"$GODOT_BIN" --path . --language zh_CN -- --m1-debug=red_sand_revisit
"$GODOT_BIN" --path . --language zh_CN -- --m1-debug=white_noise_catalog
"$GODOT_BIN" --path . --language zh_CN -- --m1-debug=canopy_catalog
"$GODOT_BIN" --path . --language zh_CN -- --m1-debug=tidal_catalog
"$GODOT_BIN" --path . --language zh_CN -- --m1-debug=low_altitude_drop
"$GODOT_BIN" --path . --language zh_CN -- --m1-debug=express_order
```

这些入口不出现在普通菜单，不读写正常剧情存档，不写玩家设置。右侧紧凑状态框
显示当前注入上下文；按 `F6` 将内存快照和目标场景一起重置。`gate_e` 从首单
完成后的隔离大厅开始，让玩家正常接取赤砂回访并走完 Gate E；T-112 起
`red_sand_revisit` 会跳过大厅、直接接取正式回访订单并进入
`26000–38000 m` 短路线。白噪、穹林、群潮目录仍只能查看尚未落地的
`REGISTERED_ONLY` 内容，不能接取或出发。

### Level 4 — M1 Human Gate

- Gate E / T-119。
- Gate F / T-129。
- Gate G / T-159。
- Gate H / T-179。
- Gate I / T-199。

到达 Gate 后停止扩范围。

## 6. Planet Packet 实现循环

每颗新增星球按以下顺序：

1. 确认 Packet 与候选状态。
2. 用灰盒定义路线阶段、距离、检查点和独特机制。
3. 在独立/直达入口验证飞行。
4. 接入主线货物、驾驶舱和订单。
5. 制作目的地区域、角色和局部选择。
6. 加入 production placeholder 美术、VFX 和音频。
7. 接入结算、关系、图鉴、站点变化和存档。
8. 添加支线或回访。
9. 运行星球完整烟雾和 M0 回归。
10. 到对应 Gate 请求人工试玩。

不要先写大量剧情或最终资产再测试路线。

## 7. 支线开发规则

支线任务必须回答：

1. 玩家为什么愿意做，而不只是为了钱？
2. 它展示了主线没展示的人物/地点哪一面？
3. 它复用了什么，新增了什么？
4. 失败如何影响本单而不阻塞主线？

支线优先：

- 复用主线路线分支或短变化段。
- 使用不同货物限制、交付方式或角色意义。
- 给关系、图鉴、纪念品或可见变化。

禁止：

- 随机刷新。
- 无限刷钱。
- 简单反向跑完整主路线。
- 为一个支线搭建新的大型系统。

## 8. 候选内容处理

- Stable ID 可以实现。
- 显示名/物种/标题未确认时使用 Packet 候选或职务称呼。
- 正式对白任务前应向用户请求选择对应候选。
- 不阻塞共用系统、灰盒和数据合同任务。
- 不允许 Agent 自动把“推荐候选”升级为 LOCKED。

## 9. Human Check 试玩包

```markdown
## Build / Commit
<hash>

## How to run
<command>

## Save / Start state
<v1 migration / chapter / debug route>

## Expected play time
<range>

## Steps
1. ...

## Focus questions
1. ...
2. ...
3. ...

## M0 regression checked
- ...

## Known limitations
- ...

## Reset / retry
- ...
```

反馈可以是自然语言，主 Agent负责整理进任务与决定文档。

## 10. 任务状态

### Done

只有在：

- 范围完成。
- 验收满足。
- 自动检查通过。
- 必要 M0 回归通过。
- 非 Gate 或 Gate 已获用户明确接受。

### Human Check

自动部分已完成，但必须由用户判断。不得自行改为 Done。

### Blocked

写明真实依赖/错误，不用它代替排查。

### Stretch

不阻塞里程碑和 Gate。只有必做内容稳定且预算允许时转为 Ready；否则 Deferred。

## 11. 发现额外问题

- 阻塞当前验收：当前任务返工。
- 非阻塞小问题：记录后续任务或已知限制。
- 另一个阶段必要：写入对应任务并保持依赖。
- M2+ 想法：写入 Demo Scope/Decision，不顺手实现。

## 12. Git 工作方式

- 仅主 Agent 提交。
- 一个任务/可解释增量一个聚焦提交。
- 提交前检查测试、diff、状态和无关用户修改。
- 不提交 `.godot/`、缓存、导出或本机存档。
- 外部素材同步更新 Attribution；新依赖同步更新 Dependency Log。
- 提交信息优先中文、动词开头。

## 13. 文档维护

- 产品/正史改变：Narrative Bible、M1 Arc、M1 Decisions。
- M1 范围改变：CODEX_GOAL、Demo Scope、任务表和内容预算。
- 架构改变：Technical Design 或 M1 Systems Delta。
- 存档改变：M1 Save Schema v2。
- 星球内容改变：对应 Planet/Order/Character Packet。
- 普通实现日志：任务结果和 Git，不堆入长期文档。

README 保持入口性质。

## 14. M1 最终报告模板

```markdown
## 完成内容
- T-XXX ...

## 关键文件
- `path`: 作用

## 验证
- `command` — 结果
- M0 regression — 结果

## Git
- Commit: `<hash> <message>`

## 内容状态
- Stable IDs:
- Candidate names touched:
- Canon changes: none / ...

## 已知问题
- ...

## 下一任务
- T-XXX ...

## 人工试玩
- 不需要 / Gate X
```
