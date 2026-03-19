param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [Parameter(Mandatory = $true)]
  [string]$ToolName,

  [string]$ArgsJson = "{}",
  [string]$ActiveProjectsPath
)

$ErrorActionPreference = "Stop"

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

$discoverScript = Join-Path $PSScriptRoot "..\qa\discover_cocos_instance.ps1"
$discoverParams = @{ ProjectPath = $ProjectPath }
if ($ActiveProjectsPath) {
  $discoverParams.ActiveProjectsPath = $ActiveProjectsPath
}

$instance = & $discoverScript @discoverParams | ConvertFrom-Json
if (-not $instance.mcpPort) {
  throw "No MCP port found for project path: $ProjectPath"
}

try {
  $arguments = ConvertTo-NativeValue -Value (ConvertFrom-Json -InputObject $ArgsJson)
} catch {
  throw "Invalid JSON passed to --args-json or properties JSON: $ArgsJson"
}

if (-not $arguments) {
  $arguments = @{}
}

$body = @{
  name = $ToolName
  arguments = $arguments
} | ConvertTo-Json -Depth 20

$response = Invoke-RestMethod -Uri "http://127.0.0.1:$($instance.mcpPort)/call-tool" -Method Post -ContentType "application/json" -Body $body
$response | ConvertTo-Json -Depth 20
