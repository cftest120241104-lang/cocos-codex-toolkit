# Cocos Codex Toolkit

面向 Cocos Creator 2.x 项目的可复用工具仓库。

这个仓库把能力拆成四层：

- `bin/`：命令行入口
- `toolkit/`：实际执行逻辑
- `skills/`：可安装到全局的 Codex skill
- `scripts/`：安装和机器初始化脚本

## Windows 安装

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

安装脚本会做三件事：

- 把 `skills/` 下的 skill 同步到 `%USERPROFILE%\.codex\skills`
- 设置用户环境变量 `COCOS_CODEX_TOOLKIT_HOME`
- 在用户 `PATH` 中补上 `bin\`

安装完成后，重新打开一个终端，就可以直接使用：

```powershell
cocos-toolkit qa --project "E:\path\to\project"
```

## 编码说明

这个仓库默认使用 `UTF-8` 保存文件。  
`README.md` 和 `SKILL.md` 可以写中文，但在部分中文 Windows 环境里，某些 Python 脚本会默认按系统 `gbk` 去读取文本文件。

如果你要在本机校验 skill，优先使用仓库自带的验证脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate-skills.ps1
```

这个脚本会自动以 `PYTHONUTF8=1` 方式调用校验器，避免中文 skill 因编码被误判失败。

## 命令

### 发现一个正在运行的 Creator 实例

```powershell
cocos-toolkit discover --project "E:\path\to\project"
```

### 运行引擎验收

```powershell
cocos-toolkit qa --project "E:\path\to\project"
```

指定验收重放范围：

```powershell
cocos-toolkit qa `
  --project "E:\path\to\project" `
  --scene "db://assets/lobby/main.fire" `
  --prefab "db://assets/AB/game/enemy/Monster1001.prefab"
```

验收会固定产出：

- `raw-<timestamp>.jsonl`
- `summary-<timestamp>.json`
- `report-<timestamp>.md`

### 直接调用一个 cocos-mcp 工具

```powershell
cocos-toolkit mcp-call `
  --project "E:\path\to\project" `
  --tool "get_scene_hierarchy" `
  --args-json '{"depth":2}'
```

## 常用内容制作命令

打开场景：

```powershell
cocos-toolkit scene-open `
  --project "E:\path\to\project" `
  --scene "db://assets/lobby/main.fire"
```

打开预制件：

```powershell
cocos-toolkit prefab-open `
  --project "E:\path\to\project" `
  --prefab "db://assets/prefabs/Test.prefab"
```

把预制件实例化到当前场景：

```powershell
cocos-toolkit prefab-instantiate `
  --project "E:\path\to\project" `
  --prefab "db://assets/prefabs/Test.prefab" `
  --parent-id "parent-uuid"
```

把场景节点保存成预制件：

```powershell
cocos-toolkit prefab-create `
  --project "E:\path\to\project" `
  --node-id "node-uuid" `
  --prefab-name "RewardPopup"
```

读取场景层级：

```powershell
cocos-toolkit scene-hierarchy `
  --project "E:\path\to\project" `
  --depth 3 `
  --details
```

读取节点组件：

```powershell
cocos-toolkit components-get `
  --project "E:\path\to\project" `
  --node-id "node-uuid"
```

创建节点：

```powershell
cocos-toolkit node-create `
  --project "E:\path\to\project" `
  --name "RewardButton" `
  --type button `
  --parent-id "parent-uuid"
```

添加、更新、删除组件：

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

cocos-toolkit component-remove `
  --project "E:\path\to\project" `
  --node-id "node-uuid" `
  --component-id "component-id"
```

重命名节点：

```powershell
cocos-toolkit node-rename `
  --project "E:\path\to\project" `
  --id "node-uuid" `
  --name "NewNodeName"
```

保存场景：

```powershell
cocos-toolkit scene-save --project "E:\path\to\project"
```

查找引用：

```powershell
cocos-toolkit references-find `
  --project "E:\path\to\project" `
  --target-id "uuid" `
  --target-type asset
```

读取控制台：

```powershell
cocos-toolkit console-read `
  --project "E:\path\to\project" `
  --type error `
  --limit 20
```

## 在 Codex 里的使用方式

安装后，Codex 可以直接使用这两个全局 skill：

- `cocos-engine-qa`
- `cocos-editor-builder`

这两个已安装的 skill 会优先通过 `COCOS_CODEX_TOOLKIT_HOME` 回调这个仓库作为执行层。
