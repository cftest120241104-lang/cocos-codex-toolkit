param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [Parameter(Mandatory = $true)]
  [string]$ToolName,

  [string]$ArgsJson = "{}",
  [string]$ActiveProjectsPath
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

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

function Repair-MojibakeString {
  param([string]$Value)

  if ([string]::IsNullOrEmpty($Value)) {
    return $Value
  }

  if ($Value -notmatch '[ÃÂâæåäöï¼]') {
    return $Value
  }

  try {
    $bytes = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetBytes($Value)
    $decoded = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($decoded -and $decoded -ne $Value) {
      return $decoded
    }
  } catch {
  }

  return $Value
}

function Normalize-ResponseValue {
  param([object]$Value)

  if ($null -eq $Value) {
    return $null
  }

  if ($Value -is [string]) {
    return Repair-MojibakeString -Value $Value
  }

  if ($Value -is [pscustomobject]) {
    $hash = [ordered]@{}
    foreach ($property in $Value.PSObject.Properties) {
      $hash[$property.Name] = Normalize-ResponseValue -Value $property.Value
    }
    return [pscustomobject]$hash
  }

  if ($Value -is [System.Collections.IDictionary]) {
    $hash = [ordered]@{}
    foreach ($key in $Value.Keys) {
      $hash[$key] = Normalize-ResponseValue -Value $Value[$key]
    }
    return $hash
  }

  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
    $items = New-Object System.Collections.ArrayList
    foreach ($item in $Value) {
      [void]$items.Add((Normalize-ResponseValue -Value $item))
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

$webResponse = Invoke-WebRequest -Uri "http://127.0.0.1:$($instance.mcpPort)/call-tool" -Method Post -ContentType "application/json" -Body $body -UseBasicParsing
$memory = New-Object System.IO.MemoryStream
$webResponse.RawContentStream.Position = 0
$webResponse.RawContentStream.CopyTo($memory)
$jsonText = [System.Text.Encoding]::UTF8.GetString($memory.ToArray())
$response = ConvertFrom-Json -InputObject $jsonText
$normalizedResponse = Normalize-ResponseValue -Value $response
$normalizedResponse | ConvertTo-Json -Depth 20
