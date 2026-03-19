param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Arguments
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Show-Usage {
  @'
Usage:
  cocos-toolkit qa --project <path> [--scene <db-url>]... [--prefab <db-url>]... [--output-dir <path>] [--wait-seconds <n>] [--no-smoke]
  cocos-toolkit discover --project <path> [--active-projects-path <path>]
  cocos-toolkit mcp-call --project <path> --tool <tool-name> [--args-json <json>] [--active-projects-path <path>]
  cocos-toolkit scene-open --project <path> --scene <db-url>
  cocos-toolkit prefab-open --project <path> --prefab <db-url>
  cocos-toolkit prefab-instantiate --project <path> --prefab <db-url> [--parent-id <uuid>]
  cocos-toolkit prefab-create --project <path> --node-id <uuid> --prefab-name <name>
  cocos-toolkit scene-save --project <path>
  cocos-toolkit scene-hierarchy --project <path> [--depth <n>] [--details] [--node-id <uuid>]
  cocos-toolkit components-get --project <path> --node-id <uuid>
  cocos-toolkit component-add --project <path> --node-id <uuid> --component-type <type> [--properties-json <json>]
  cocos-toolkit component-update --project <path> --node-id <uuid> --component-id <id> [--component-type <type>] [--properties-json <json>]
  cocos-toolkit component-remove --project <path> --node-id <uuid> --component-id <id>
  cocos-toolkit node-create --project <path> --name <name> [--type <empty|sprite|button|label>] [--parent-id <uuid>]
  cocos-toolkit node-rename --project <path> --id <uuid> --name <new-name>
  cocos-toolkit node-transform --project <path> --id <uuid> [--x <n>] [--y <n>] [--width <n>] [--height <n>] [--scale-x <n>] [--scale-y <n>] [--rotation <n>] [--opacity <n>] [--color <#RRGGBB>]
  cocos-toolkit references-find --project <path> --target-id <uuid> [--target-type <auto|node|asset>]
  cocos-toolkit console-read --project <path> [--limit <n>] [--type <info|warn|error|success|mcp>]
  cocos-toolkit install
'@
}

if (-not $Arguments -or $Arguments.Count -eq 0) {
  Show-Usage
  exit 1
}

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$command = $Arguments[0]
$remaining = if ($Arguments.Count -gt 1) { $Arguments[1..($Arguments.Count - 1)] } else { @() }

function ConvertTo-NativeValue {
  param([object]$Value)

  if ($null -eq $Value) {
    return $null
  }

  if ($Value -is [pscustomobject]) {
    $hash = @{}
    foreach ($property in $Value.PSObject.Properties) {
      $hash[$property.Name] = ConvertTo-NativeValue -Value $property.Value
    }
    return $hash
  }

  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
    $items = New-Object System.Collections.ArrayList
    foreach ($item in $Value) {
      [void]$items.Add((ConvertTo-NativeValue -Value $item))
    }
    return ,$items.ToArray()
  }

  return $Value
}

function ConvertFrom-JsonCompat {
  param([string]$Json)

  if (-not $Json) {
    return @{}
  }

  $parsed = ConvertFrom-Json -InputObject $Json
  $native = ConvertTo-NativeValue -Value $parsed
  if ($null -eq $native) {
    return @{}
  }
  return $native
}

function Parse-CommonProjectOptions {
  param([string[]]$InputArgs)

  $result = [ordered]@{
    project = $null
    activeProjectsPath = $null
    extras = @()
  }

  for ($i = 0; $i -lt $InputArgs.Count; $i++) {
    switch ($InputArgs[$i]) {
      "--project" {
        $i++
        $result.project = $InputArgs[$i]
      }
      "--active-projects-path" {
        $i++
        $result.activeProjectsPath = $InputArgs[$i]
      }
      default {
        $result.extras += $InputArgs[$i]
      }
    }
  }

  if (-not $result.project) {
    throw "Missing required option: --project"
  }

  return $result
}

function Invoke-ToolkitMcp {
  param(
    [string]$ProjectPath,
    [string]$ToolName,
    [hashtable]$ArgumentsMap,
    [string]$ActiveProjectsPath
  )

  $scriptPath = Join-Path $repoRoot "toolkit\editor\invoke_cocos_mcp.ps1"
  $params = @{
    ProjectPath = $ProjectPath
    ToolName = $ToolName
    ArgsJson = ($ArgumentsMap | ConvertTo-Json -Depth 20 -Compress)
  }
  if ($ActiveProjectsPath) {
    $params.ActiveProjectsPath = $ActiveProjectsPath
  }

  & $scriptPath @params
}

switch ($command) {
  "qa" {
    $project = $null
    $outputDir = $null
    $waitSeconds = 5
    $scenes = New-Object System.Collections.Generic.List[string]
    $prefabs = New-Object System.Collections.Generic.List[string]
    $noSmoke = $false

    for ($i = 0; $i -lt $remaining.Count; $i++) {
      switch ($remaining[$i]) {
        "--project" {
          $i++
          $project = $remaining[$i]
        }
        "--scene" {
          $i++
          $scenes.Add($remaining[$i]) | Out-Null
        }
        "--prefab" {
          $i++
          $prefabs.Add($remaining[$i]) | Out-Null
        }
        "--output-dir" {
          $i++
          $outputDir = $remaining[$i]
        }
        "--wait-seconds" {
          $i++
          $waitSeconds = [int]$remaining[$i]
        }
        "--no-smoke" {
          $noSmoke = $true
        }
        default {
          throw "Unknown option for qa: $($remaining[$i])"
        }
      }
    }

    if (-not $project) {
      throw "Missing required option: --project"
    }

    $params = @{
      ProjectPath = $project
      OpenSceneUrls = $scenes.ToArray()
      OpenPrefabUrls = $prefabs.ToArray()
      ActionWaitSeconds = $waitSeconds
    }
    if ($outputDir) {
      $params.OutputDir = $outputDir
    }
    if ($noSmoke) {
      $params.NoSmoke = $true
    }

    $scriptPath = Join-Path $repoRoot "toolkit\qa\capture_cocos_engine_logs.ps1"
    & $scriptPath @params
    break
  }
  "discover" {
    $project = $null
    $activeProjectsPath = $null

    for ($i = 0; $i -lt $remaining.Count; $i++) {
      switch ($remaining[$i]) {
        "--project" {
          $i++
          $project = $remaining[$i]
        }
        "--active-projects-path" {
          $i++
          $activeProjectsPath = $remaining[$i]
        }
        default {
          throw "Unknown option for discover: $($remaining[$i])"
        }
      }
    }

    if (-not $project) {
      throw "Missing required option: --project"
    }

    $params = @{ ProjectPath = $project }
    if ($activeProjectsPath) {
      $params.ActiveProjectsPath = $activeProjectsPath
    }

    $scriptPath = Join-Path $repoRoot "toolkit\qa\discover_cocos_instance.ps1"
    & $scriptPath @params
    break
  }
  "install" {
    $scriptPath = Join-Path $repoRoot "scripts\install.ps1"
    & $scriptPath
    break
  }
  "mcp-call" {
    $project = $null
    $activeProjectsPath = $null
    $toolName = $null
    $argsJson = "{}"

    for ($i = 0; $i -lt $remaining.Count; $i++) {
      switch ($remaining[$i]) {
        "--project" {
          $i++
          $project = $remaining[$i]
        }
        "--active-projects-path" {
          $i++
          $activeProjectsPath = $remaining[$i]
        }
        "--tool" {
          $i++
          $toolName = $remaining[$i]
        }
        "--args-json" {
          $i++
          $argsJson = $remaining[$i]
        }
        default {
          throw "Unknown option for mcp-call: $($remaining[$i])"
        }
      }
    }

    if (-not $project) {
      throw "Missing required option: --project"
    }
    if (-not $toolName) {
      throw "Missing required option: --tool"
    }

    $scriptPath = Join-Path $repoRoot "toolkit\editor\invoke_cocos_mcp.ps1"
    $params = @{
      ProjectPath = $project
      ToolName = $toolName
      ArgsJson = $argsJson
    }
    if ($activeProjectsPath) {
      $params.ActiveProjectsPath = $activeProjectsPath
    }
    & $scriptPath @params
    break
  }
  "scene-open" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $scene = $null
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--scene" {
          $i++
          $scene = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for scene-open: $($parsed.extras[$i])"
        }
      }
    }
    if (-not $scene) {
      throw "Missing required option: --scene"
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "open_scene" -ArgumentsMap @{ url = $scene } -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "prefab-open" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $prefab = $null
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--prefab" {
          $i++
          $prefab = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for prefab-open: $($parsed.extras[$i])"
        }
      }
    }
    if (-not $prefab) {
      throw "Missing required option: --prefab"
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "open_prefab" -ArgumentsMap @{ url = $prefab } -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "prefab-instantiate" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $prefab = $null
    $parentId = $null
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--prefab" {
          $i++
          $prefab = $parsed.extras[$i]
        }
        "--parent-id" {
          $i++
          $parentId = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for prefab-instantiate: $($parsed.extras[$i])"
        }
      }
    }
    if (-not $prefab) {
      throw "Missing required option: --prefab"
    }
    $argsMap = @{
      action = "instantiate"
      path = $prefab
    }
    if ($parentId) {
      $argsMap.parentId = $parentId
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "prefab_management" -ArgumentsMap $argsMap -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "prefab-create" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $nodeId = $null
    $prefabName = $null
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--node-id" {
          $i++
          $nodeId = $parsed.extras[$i]
        }
        "--prefab-name" {
          $i++
          $prefabName = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for prefab-create: $($parsed.extras[$i])"
        }
      }
    }
    if (-not $nodeId) {
      throw "Missing required option: --node-id"
    }
    if (-not $prefabName) {
      throw "Missing required option: --prefab-name"
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "create_prefab" -ArgumentsMap @{ nodeId = $nodeId; prefabName = $prefabName } -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "scene-save" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    if ($parsed.extras.Count -gt 0) {
      throw "Unknown option for scene-save: $($parsed.extras[0])"
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "save_scene" -ArgumentsMap @{} -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "scene-hierarchy" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $argsMap = @{}
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--depth" {
          $i++
          $argsMap.depth = [int]$parsed.extras[$i]
        }
        "--details" {
          $argsMap.includeDetails = $true
        }
        "--node-id" {
          $i++
          $argsMap.nodeId = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for scene-hierarchy: $($parsed.extras[$i])"
        }
      }
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "get_scene_hierarchy" -ArgumentsMap $argsMap -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "components-get" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $nodeId = $null
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--node-id" {
          $i++
          $nodeId = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for components-get: $($parsed.extras[$i])"
        }
      }
    }
    if (-not $nodeId) {
      throw "Missing required option: --node-id"
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "manage_components" -ArgumentsMap @{ action = "get"; nodeId = $nodeId } -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "component-add" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $nodeId = $null
    $componentType = $null
    $propertiesJson = "{}"
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--node-id" {
          $i++
          $nodeId = $parsed.extras[$i]
        }
        "--component-type" {
          $i++
          $componentType = $parsed.extras[$i]
        }
        "--properties-json" {
          $i++
          $propertiesJson = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for component-add: $($parsed.extras[$i])"
        }
      }
    }
    if (-not $nodeId) {
      throw "Missing required option: --node-id"
    }
    if (-not $componentType) {
      throw "Missing required option: --component-type"
    }
    $argumentsMap = @{
      action = "add"
      nodeId = $nodeId
      componentType = $componentType
    }
    $properties = ConvertFrom-JsonCompat -Json $propertiesJson
    if ($properties.Count -gt 0) {
      $argumentsMap.properties = $properties
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "manage_components" -ArgumentsMap $argumentsMap -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "component-update" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $nodeId = $null
    $componentId = $null
    $componentType = $null
    $propertiesJson = "{}"
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--node-id" {
          $i++
          $nodeId = $parsed.extras[$i]
        }
        "--component-id" {
          $i++
          $componentId = $parsed.extras[$i]
        }
        "--component-type" {
          $i++
          $componentType = $parsed.extras[$i]
        }
        "--properties-json" {
          $i++
          $propertiesJson = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for component-update: $($parsed.extras[$i])"
        }
      }
    }
    if (-not $nodeId) {
      throw "Missing required option: --node-id"
    }
    if (-not $componentId) {
      throw "Missing required option: --component-id"
    }
    $argumentsMap = @{
      action = "update"
      nodeId = $nodeId
      componentId = $componentId
    }
    if ($componentType) {
      $argumentsMap.componentType = $componentType
    }
    $properties = ConvertFrom-JsonCompat -Json $propertiesJson
    if ($properties.Count -gt 0) {
      $argumentsMap.properties = $properties
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "manage_components" -ArgumentsMap $argumentsMap -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "component-remove" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $nodeId = $null
    $componentId = $null
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--node-id" {
          $i++
          $nodeId = $parsed.extras[$i]
        }
        "--component-id" {
          $i++
          $componentId = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for component-remove: $($parsed.extras[$i])"
        }
      }
    }
    if (-not $nodeId) {
      throw "Missing required option: --node-id"
    }
    if (-not $componentId) {
      throw "Missing required option: --component-id"
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "manage_components" -ArgumentsMap @{ action = "remove"; nodeId = $nodeId; componentId = $componentId } -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "node-create" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $name = $null
    $type = "empty"
    $parentId = $null
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--name" {
          $i++
          $name = $parsed.extras[$i]
        }
        "--type" {
          $i++
          $type = $parsed.extras[$i]
        }
        "--parent-id" {
          $i++
          $parentId = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for node-create: $($parsed.extras[$i])"
        }
      }
    }
    if (-not $name) {
      throw "Missing required option: --name"
    }
    $argsMap = @{ name = $name; type = $type }
    if ($parentId) {
      $argsMap.parentId = $parentId
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "create_node" -ArgumentsMap $argsMap -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "node-rename" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $id = $null
    $name = $null
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--id" {
          $i++
          $id = $parsed.extras[$i]
        }
        "--name" {
          $i++
          $name = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for node-rename: $($parsed.extras[$i])"
        }
      }
    }
    if (-not $id) {
      throw "Missing required option: --id"
    }
    if (-not $name) {
      throw "Missing required option: --name"
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "set_node_name" -ArgumentsMap @{ id = $id; newName = $name } -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "node-transform" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $argsMap = @{}
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--id" {
          $i++
          $argsMap.id = $parsed.extras[$i]
        }
        "--x" {
          $i++
          $argsMap.x = [double]$parsed.extras[$i]
        }
        "--y" {
          $i++
          $argsMap.y = [double]$parsed.extras[$i]
        }
        "--width" {
          $i++
          $argsMap.width = [double]$parsed.extras[$i]
        }
        "--height" {
          $i++
          $argsMap.height = [double]$parsed.extras[$i]
        }
        "--scale-x" {
          $i++
          $argsMap.scaleX = [double]$parsed.extras[$i]
        }
        "--scale-y" {
          $i++
          $argsMap.scaleY = [double]$parsed.extras[$i]
        }
        "--rotation" {
          $i++
          $argsMap.rotation = [double]$parsed.extras[$i]
        }
        "--opacity" {
          $i++
          $argsMap.opacity = [int]$parsed.extras[$i]
        }
        "--color" {
          $i++
          $argsMap.color = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for node-transform: $($parsed.extras[$i])"
        }
      }
    }
    if (-not $argsMap.id) {
      throw "Missing required option: --id"
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "update_node_transform" -ArgumentsMap $argsMap -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "references-find" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $targetId = $null
    $targetType = $null
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--target-id" {
          $i++
          $targetId = $parsed.extras[$i]
        }
        "--target-type" {
          $i++
          $targetType = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for references-find: $($parsed.extras[$i])"
        }
      }
    }
    if (-not $targetId) {
      throw "Missing required option: --target-id"
    }
    $argsMap = @{ targetId = $targetId }
    if ($targetType) {
      $argsMap.targetType = $targetType
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "find_references" -ArgumentsMap $argsMap -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "console-read" {
    $parsed = Parse-CommonProjectOptions -InputArgs $remaining
    $argsMap = @{}
    for ($i = 0; $i -lt $parsed.extras.Count; $i++) {
      switch ($parsed.extras[$i]) {
        "--limit" {
          $i++
          $argsMap.limit = [int]$parsed.extras[$i]
        }
        "--type" {
          $i++
          $argsMap.type = $parsed.extras[$i]
        }
        default {
          throw "Unknown option for console-read: $($parsed.extras[$i])"
        }
      }
    }
    Invoke-ToolkitMcp -ProjectPath $parsed.project -ToolName "read_console" -ArgumentsMap $argsMap -ActiveProjectsPath $parsed.activeProjectsPath
    break
  }
  "--help" {
    Show-Usage
    break
  }
  "-h" {
    Show-Usage
    break
  }
  default {
    Show-Usage
    throw "Unknown command: $command"
  }
}
