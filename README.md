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

## Codex usage

After installation, Codex can use the installed global skills:

- `cocos-engine-qa`
- `cocos-editor-builder`

Those installed skills prefer this repository as the execution layer through `COCOS_CODEX_TOOLKIT_HOME`.
