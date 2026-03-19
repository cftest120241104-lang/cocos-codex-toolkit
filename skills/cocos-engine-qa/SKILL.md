---
name: cocos-engine-qa
description: Final acceptance gate for Cocos Creator 2.x projects. Bind the correct editor instance, replay scene and prefab opens through cocos-mcp, collect raw engine/editor logs through CDP, apply a small allowlist for known editor noise, and return a strict PASS or FAIL result. Use when the goal is to decide whether a Cocos project can run cleanly in Creator with no acceptance-scope exceptions or missing-asset warnings.
---

# Cocos Engine QA

Treat this skill as an acceptance gate, not a repair workflow. Use CDP as the source of truth for engine logs. Use MCP only to drive the editor.

Prefer the installed toolkit CLI when available:
`cocos-toolkit qa --project <abs-project-path>`

The bundled `scripts/` in this skill are thin wrappers. They resolve `COCOS_CODEX_TOOLKIT_HOME` and delegate to the shared toolkit repository so the workflow stays the same across machines.

## Workflow

1. Bind the correct editor instance.
   Do not trust the currently selected `cocos-mcp` project when multiple Creator windows are open.
   Run `scripts/discover_cocos_instance.ps1 -ProjectPath <abs-project-path>` first.
   If the project is not running, use `cocos-cc-manager` to start or reuse the correct instance, then run discovery again.

2. Capture raw engine logs through CDP.
   Use `scripts/capture_cocos_engine_logs.ps1` with the same project path.
   CDP events are the acceptance source of truth:
   `Runtime.consoleAPICalled`
   `Console.messageAdded`
   `Runtime.exceptionThrown`
   `Log.entryAdded`

3. Replay scenes and prefabs through MCP.
   Pass known failing `db://` scene or prefab paths when the user gives them.
   If the user only says "验收这个项目", start with all scenes, then the highest-risk prefabs.
   Treat `open_scene` and `open_prefab` as reproduction steps only. Do not infer pass/fail from MCP success text.

4. Normalize issues from CDP logs.
   Parse and group:
   missing asset warnings with component, node path, asset url, missing uuid
   script exceptions such as `TypeError`, `ReferenceError`, import-time failures
   editor/runtime noise such as `object already destroyed`
   Use `references/log-patterns.md` for triage rules.

5. Return a strict acceptance result.
   `PASS` only when the replay scope finishes with no non-allowlisted CDP issues.
   `FAIL` when any missing asset warning, script exception, or editor/runtime exception remains after allowlist filtering.
   Report the failing asset scope, component, node path, missing uuid, or exception text.

6. Escalate to specialized skills when needed.
   Use `cocos-uuid-debug` when the issue is a missing or malformed UUID.
   Use `cocos-decompile-qa` when the issue looks like a `.fire`, `.prefab`, `.meta`, Spine, or JsonAsset schema mismatch.
   Use `cocos-regression-test` when the user says a previous output worked and you need baseline comparison.

## Scripts

`scripts/discover_cocos_instance.ps1`
Find the Creator process, MCP port, and CDP port for one project path. Use this before any acceptance run.

`scripts/capture_cocos_engine_logs.ps1`
Connect to the project's CDP endpoint, optionally replay scene/prefab opens through MCP, and write raw plus normalized logs to disk.
The normalized summary should be the final gate artifact and include:
`verdict`
`capturedEventCount`
`ignoredEventCount`
`rawIssueCount`
`issueCount`
`issueTypeCounts`
`issues`

Typical usage:

```powershell
cocos-toolkit discover `
  --project "E:\path\to\project"

cocos-toolkit qa `
  --project "E:\path\to\project" `
  --scene "db://assets/lobby/main.fire" `
  --prefab "db://assets/AB/game/enemy/Monster1001.prefab"
```

## Reporting

Write acceptance results from CDP, not from memory.

Keep three artifacts when possible:
raw JSONL event stream
normalized JSON summary
short human report listing failing scene/prefab, component, node path, and missing uuid or exception

Name them consistently when possible:
`raw-<timestamp>.jsonl`
`summary-<timestamp>.json`
`report-<timestamp>.md`

If a run finds no issues, say that explicitly, mention the replay scope, and return `PASS`.
If any non-allowlisted issue remains, return `FAIL` before discussing repair paths.
