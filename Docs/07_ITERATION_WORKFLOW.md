# 07 — Iteration Workflow / 迭代工作流

## 1. 目标

工作流服务于两件事：

- Codex 快速实现小而完整的可玩增量。
- 人类在关键内容节点直接试玩，判断是否好玩、好读、好听、想继续。

自动检查负责工程正确性，人工 Gate 负责体验判断，二者不能互相冒充。

M0 已完成并作为强制回归基线。当前里程碑是 M1 Four-Planet Demo。

## 2. 每次会话开始

主 Agent 按顺序：

1. 阅读 `AGENTS.md`。
2. 阅读 `CODEX_GOAL.md`。
3. 阅读 `DEVELOPMENT_TASKS.md`。
4. 阅读 `Docs/M1/00_M1_ROADMAP.md` 与当前任务引用文档。
5. 运行 `git status --short`。
6. 查看近期相关提交和当前实现。
7. 检查是否存在 `In Progress` 或 `Human Check`。
8. 确认依赖全部完成。
9. 只把一个 `Ready` 任务改为 `In Progress`。

开始报告只需说明：

- 当前里程碑和阶段。
- 本轮任务与玩家价值。
- 依赖、范围和明确不做。
- 预计修改文件与验证方式。

不要重复整份设计文档，也不要再次询问已有答案。

## 3. 标准实现循环

```text
读取任务与现状
→ 找到最小可逆实现
→ 修改数据/代码/场景
→ 运行快速检查
→ 启动最短可玩路径
→ 根据真实结果修正
→ 更新测试与必要文档
→ 运行完整适用检查
→ 更新任务与阶段状态
→ 主 Agent 提交
→ 报告并停止
```

一次只做一个任务。即使下一任务已解锁，也不得在同一轮自动继续。

## 4. M1 内容任务的额外入口

新增星球在进入高成本实现前必须已有：

- Planet Packet。
- Main Order Packet。
- Character Packet。
- Route Beat Sheet。
- Art/Audio Package。
- Scope Review。

内容仍为 `PROVISIONAL` 时使用稳定占位 ID，不得把暂名和开放世界观静默写成正史。

共用飞船、HUD、检查点、对话、结算和交接可以抽取；星球自然、人文、人物、货物与独特机制必须定制。

## 5. 检查层级

### Level 0 — 编辑中快速检查

- 编辑器/语言服务器错误。
- 相关单元测试。
- 当前场景直接运行。
- 数据引用验证。

### Level 1 — 仓库检查

完成任务前运行：

```bash
./scripts/check_project.sh
```

预期包含：

- Godot 4.7.1 检查。
- Headless import。
- 测试运行器。
- 场景烟雾。
- `git diff --check`。

### Level 2 — 最短玩法烟雾

按任务选择：

- 存档任务：v1 迁移、v2 保存、坏档/备份和继续游戏。
- 导航任务：已解锁/未解锁、合法/非法目的地和出发交接。
- 内容任务：直接进入相关路线、到达或回访场景。
- 支线任务：接取、超时、失败/放弃、结算与主线隔离。
- 交付任务：成功、偏差、失败与重试。
- 星球任务：从接近到到达的最短完整路径。

### Level 3 — M0 完整回归

任务触及以下系统时必须运行：

- `GameState`、`SaveService`、schema。
- 订单、导航和主线章节。
- 通用对话和模态 UI。
- 飞船、资源、伤害、检查点和路线模板。
- 到达、结算、站点、图鉴和纪念品。

回归路径：

```text
新游戏
→ 大厅教程、接单、配置
→ 驾驶舱旅行
→ 赤砂星失败与重试
→ 着陆、维修场、结算、返站
→ 保存
→ 重建 App
→ 继续游戏
```

### Level 4 — M1 人工 Gate

只在预定节点执行完整试玩：

- Gate E：白噪星垂直切片。
- Gate F：赤砂回访、支线与成长。
- Gate G：穹林星与和平/武装反馈。
- Gate H：跨星球成长整合。
- Gate I：群潮星与 Demo 高潮。
- Gate J：M1 完整 Demo。

细则见 `Docs/M1/05_M1_GATES_AND_TESTING.md`。到达 Gate 后停止扩范围。

## 6. 人工试玩包

主 Agent 提供：

```markdown
## Gate / Commit
<gate 与 commit>

## How to run
<精确命令>

## Start path
<菜单、存档或直接调试入口>

## Expected play time
<大致时长>

## What changed
<本 Gate 的内容>

## Focus questions
1. ...
2. ...
3. ...

## Known limitations
- ...

## Reset / retry
<按键或步骤>

## Regression already checked
- M0 ...
- 存档 ...
```

不要求用户填写庞大证据表。自然语言反馈由主 Agent 整理到当前 Gate 任务与决策文档。

## 7. 任务状态

### `Done`

只有在：

- 范围实现。
- 验收标准满足。
- 自动检查和必要烟雾通过。
- M0 回归在需要时通过。
- 非强制 Gate，或 Gate 已被用户明确接受。

时使用。

### `Human Check`

自动部分已经完成，但必须由用户判断。主 Agent 不能自行改为 Done。

### `Blocked`

明确写出依赖或错误。不要用 Blocked 代替排查。

### 发现额外问题

- 阻塞当前验收：在当前任务或 Gate 返工。
- 非阻塞小问题：记录后续任务。
- M2+ 想法：写入 Scope/Decision，不顺手实现。
- M0 基线回归：当前任务必须修复或保持 In Progress。

## 8. Gate 失败循环

```text
Gate Human Check
→ 用户反馈 Rework required
→ 当前 Gate 任务退回 In Progress
→ 只修复明确阻塞项
→ 自动检查与回归
→ 重新进入 Human Check
→ 用户通过
→ 关闭 Gate、解锁下一阶段
```

不要因为 Gate 失败同时重做已经通过的无关系统。

## 9. Git 工作方式

- 仅主 Agent 提交；子 Agent 不提交。
- 一个提交对应一个完整、可解释的任务或 Gate 返工。
- 提交前检查：

```bash
./scripts/check_project.sh
git diff --check
git status --short
git diff --stat
```

核对：

- 没有 `.godot/`、日志、导出构建和临时文件。
- 没有用户无关修改。
- 外部素材已更新 `ATTRIBUTION.md`。
- 新依赖已更新 `Docs/09_DEPENDENCY_LOG.md`。
- 玩家文本使用本地化 Key。
- 没有把无关重构混入功能提交。

提交信息优先中文、动词开头，避免 `update`、`fix stuff`、`WIP`、`final`。

## 10. 新依赖流程

1. 描述具体问题。
2. 先尝试 Godot 内置能力或小型自有实现。
3. 比较候选依赖。
4. 在 `Docs/09_DEPENDENCY_LOG.md` 记录。
5. 用户或任务明确批准后引入。
6. 限制使用范围并写明移除方式。
7. 运行完整检查与 M0 回归。

不要为了省少量代码引入会控制存档、剧情或项目格式的大型插件。

## 11. 文档维护

- 产品事实改变：更新 Narrative Bible、Game Vision、Scope 与 Decision。
- M1 范围或阶段改变：更新 `CODEX_GOAL.md`、M1 Roadmap、Product Scope 和任务表。
- 技术合同改变：更新 Technical Design、M1 Technical Delta 和 Decision。
- 内容方案改变：更新对应 Packet 和 Content Plan。
- 任务实现细节：由 Git 与任务卡简短结果表达。
- 新外部资产/依赖：更新 Attribution/Dependency Log。

README 保持入口性质，不堆叠完整任务历史。

## 12. 主 Agent 最终报告

```markdown
## 完成内容
- T-XXX ...

## 状态
- 任务：Done / Human Check / In Progress
- 阶段：...

## 关键文件
- `path`: 作用

## 验证
- `command` — 结果
- M0 回归 — 结果/不适用原因

## Git
- Commit: `<hash> <message>`

## 已知问题
- ...

## 下一任务
- T-XXX ... / 尚未解锁

## 人工试玩
- 不需要 / Gate X
```

## 13. 不采用的流程

本项目不建立庞大的人工证据录入、复杂状态生成器或为了验证而验证的工具链。

只保留：

- 一个统一仓库检查入口。
- 有价值的自动测试和 M0 回归。
- 简洁人工试玩包。
- 清楚的 Git 历史。
- 产品、技术和内容决策日志。
