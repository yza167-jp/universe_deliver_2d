# 09 — Dependency Log / 依赖日志

## 当前状态

**第三方代码/插件依赖：无。**

项目初始使用 Godot 4.7.1 内置能力、GDScript 和自有轻量测试/对话系统。

## 引入规则

任何插件、SDK、命令行工具运行时依赖或会影响项目格式的外部库，在安装/提交前必须填写条目。

免费美术、字体和音频属于资产来源，也必须记录到根目录 `ATTRIBUTION.md`。若其导入需要插件，则同时属于本日志。

## 评估模板

```markdown
## DEP-XXX — <name>

**Status:** Proposed / Approved / Rejected / Active / Removed
**Requested by task:** T-XXX
**Version:**
**License:**
**Source:**

### Problem
不用该依赖时遇到的具体问题。

### Alternatives considered
- Godot built-in:
- Small in-house implementation:
- Other dependency:

### Why selected

### Scope of use
哪些目录/系统可以引用，哪些不允许。

### Risks
- Maintenance:
- Engine compatibility:
- Save/data lock-in:
- Platform:
- Security/privacy:

### Removal plan
如何移除，数据如何迁移。

### Verification
安装后运行的测试。
```

## 依赖表

| ID | Name | Version | Status | License | Used by | Notes |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | — |

## 默认拒绝情形

- 只为了省少量简单代码。
- 最近版本不支持 Godot 4.7。
- 许可证不清楚或不适合未来发布。
- 要求把核心剧情/存档转换成难以迁移的私有格式。
- 大量隐式 Autoload、编辑器注入或全局状态。
- 需要常驻网络服务才能本地运行。
- 无明确维护者且替换成本高。

## 可能的未来候选（未批准）

以下只是类别，不代表允许安装：

- 字体：选择支持中文的 OFL 字体，记录具体版本与署名。
- 音频工具：仅生产环节工具，不应成为游戏运行时依赖。
- 测试插件：当前不需要；自有 runner 不足时重新评估。
- 对话插件：当前不需要；M1 内容规模证明自有结构不足后再评估。
- Steam/平台 SDK：Demo 发布决策后再评估。
