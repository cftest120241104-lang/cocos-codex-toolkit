---
name: cocos-engine-qa
description: Cocos Creator 2.x 项目的最终引擎验收 skill。绑定正确的编辑器实例，通过 cocos-mcp 重放场景和预制件打开流程，通过 CDP 抓取原始引擎日志，应用少量白名单噪音过滤，并输出严格的 PASS 或 FAIL。适用于判断一个 Cocos 项目是否能在 Creator 中无缺失资源告警、无脚本异常地正常打开和运行。
---

# Cocos 引擎验收

把这个 skill 当成最终验收闸门，而不是修复流程。引擎日志以 CDP 为唯一真相源，MCP 只负责驱动编辑器执行动作。

优先使用已经安装的 toolkit CLI：
`cocos-toolkit qa --project <abs-project-path>`

这个 skill 目录下的 `scripts/` 只是薄包装。它们会解析 `COCOS_CODEX_TOOLKIT_HOME`，再回调共享的 toolkit 仓库，这样跨机器时工作流保持一致。

## 工作流

1. 绑定正确的编辑器实例。
   多开 Creator 窗口时，不要直接相信当前选中的 `cocos-mcp` 项目。
   先运行 `scripts/discover_cocos_instance.ps1 -ProjectPath <abs-project-path>`。
   如果项目还没启动，先用 `cocos-cc-manager` 启动或复用正确实例，再重新发现一次。

2. 通过 CDP 抓原始引擎日志。
   对同一个项目路径运行 `scripts/capture_cocos_engine_logs.ps1`。
   验收以这些 CDP 事件为准：
   `Runtime.consoleAPICalled`
   `Console.messageAdded`
   `Runtime.exceptionThrown`
   `Log.entryAdded`

3. 通过 MCP 重放场景和预制件。
   如果用户给了明确的失败资源，就优先传入对应的 `db://` 场景或预制件路径。
   如果用户只说“验收这个项目”，先从全场景开始，再覆盖高风险预制件。
   `open_scene` 和 `open_prefab` 只是复现步骤，不要根据 MCP 的成功文本直接判定通过。

4. 对 CDP 日志做归一化。
   重点解析和归类：
   缺失资源告警：组件名、节点路径、资源 URL、缺失 UUID
   脚本异常：`TypeError`、`ReferenceError`、导入阶段失败等
   编辑器或运行时异常：例如 `object already destroyed`
   归类规则参考 `references/log-patterns.md`。

5. 返回严格的验收结果。
   只有当重放范围内没有任何非白名单 CDP 问题时，才返回 `PASS`。
   只要白名单过滤后仍然存在缺失资源、脚本异常或编辑器/运行时异常，就返回 `FAIL`。
   报告里要明确写出失败资源范围、组件、节点路径、缺失 UUID 或异常文本。

6. 必要时分流到专项 skill。
   缺失或格式异常的 UUID 问题，交给 `cocos-uuid-debug`。
   如果看起来是 `.fire`、`.prefab`、`.meta`、Spine、JsonAsset 等结构问题，交给 `cocos-decompile-qa`。
   如果用户说明“以前是好的”，需要做基线回归对比时，交给 `cocos-regression-test`。

## 脚本

`scripts/discover_cocos_instance.ps1`
根据一个项目路径找到对应的 Creator 进程、MCP 端口和 CDP 端口。所有验收动作前先跑这个。

`scripts/capture_cocos_engine_logs.ps1`
连接项目对应的 CDP 端点，可选地通过 MCP 重放场景或预制件打开，并把原始日志和归一化结果落盘。
归一化 summary 应该作为最终验收产物，至少包括：
`verdict`
`capturedEventCount`
`ignoredEventCount`
`rawIssueCount`
`issueCount`
`issueTypeCounts`
`issues`

典型用法：

```powershell
cocos-toolkit discover `
  --project "E:\path\to\project"

cocos-toolkit qa `
  --project "E:\path\to\project" `
  --scene "db://assets/lobby/main.fire" `
  --prefab "db://assets/AB/game/enemy/Monster1001.prefab"
```

## 报告要求

验收结果必须来自 CDP，不要凭记忆或人工观察下结论。

尽量保留三类产物：
原始 JSONL 事件流
归一化 JSON summary
简短的人类可读报告，列出失败场景或预制件、组件、节点路径、缺失 UUID 或异常

命名尽量统一：
`raw-<timestamp>.jsonl`
`summary-<timestamp>.json`
`report-<timestamp>.md`

如果一次重放没有发现问题，要明确写出来，说明重放范围，并返回 `PASS`。
如果白名单过滤后仍有任何问题，先返回 `FAIL`，再讨论修复路线。
