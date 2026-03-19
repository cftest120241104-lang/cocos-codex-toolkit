# Cocos Codex Toolkit

Reusable toolkit for Cocos Creator 2.x projects.

This repository separates:

- `bin/` command-line entrypoints
- `toolkit/` executable logic
- `skills/` installable global Codex skills
- `scripts/` machine setup helpers

## Install on Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

The install script:

- copies the skills in `skills/` into `%USERPROFILE%\.codex\skills`
- sets the user environment variable `COCOS_CODEX_TOOLKIT_HOME`
- adds `bin\` to the user `PATH` when missing

After opening a new shell, you can run:

```powershell
cocos-toolkit qa --project "E:\path\to\project"
```

## Commands

### Discover one running Creator instance

```powershell
cocos-toolkit discover --project "E:\path\to\project"
```

### Run engine QA

```powershell
cocos-toolkit qa --project "E:\path\to\project"
```

With explicit replay scope:

```powershell
cocos-toolkit qa `
  --project "E:\path\to\project" `
  --scene "db://assets/lobby/main.fire" `
  --prefab "db://assets/AB/game/enemy/Monster1001.prefab"
```

The QA command writes:

- `raw-<timestamp>.jsonl`
- `summary-<timestamp>.json`
- `report-<timestamp>.md`

### Call one cocos-mcp tool directly

```powershell
cocos-toolkit mcp-call `
  --project "E:\path\to\project" `
  --tool "get_scene_hierarchy" `
  --args-json '{"depth":2}'
```

### Common editor builder commands

Open a scene:

```powershell
cocos-toolkit scene-open `
  --project "E:\path\to\project" `
  --scene "db://assets/lobby/main.fire"
```

Open a prefab:

```powershell
cocos-toolkit prefab-open `
  --project "E:\path\to\project" `
  --prefab "db://assets/prefabs/Test.prefab"
```

Read scene hierarchy:

```powershell
cocos-toolkit scene-hierarchy `
  --project "E:\path\to\project" `
  --depth 3 `
  --details
```

Read node components:

```powershell
cocos-toolkit components-get `
  --project "E:\path\to\project" `
  --node-id "node-uuid"
```

Create a node:

```powershell
cocos-toolkit node-create `
  --project "E:\path\to\project" `
  --name "RewardButton" `
  --type button `
  --parent-id "parent-uuid"
```

Add or update a component:

```powershell
cocos-toolkit component-add `
  --project "E:\path\to\project" `
  --node-id "node-uuid" `
  --component-type "cc.Widget"

cocos-toolkit component-update `
  --project "E:\path\to\project" `
  --node-id "node-uuid" `
  --component-id "component-id" `
  --properties-json '{"top":16,"right":16}'
```

Save the scene:

```powershell
cocos-toolkit scene-save --project "E:\path\to\project"
```

## Codex usage

After installation, Codex can use the installed global skills:

- `cocos-engine-qa`
- `cocos-editor-builder`

Those installed skills prefer this repository as the execution layer through `COCOS_CODEX_TOOLKIT_HOME`.
