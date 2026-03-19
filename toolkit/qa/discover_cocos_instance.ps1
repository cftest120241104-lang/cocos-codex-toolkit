param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [string]$ActiveProjectsPath
)

$ErrorActionPreference = "Stop"

if (-not $ActiveProjectsPath) {
  $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
  $ActiveProjectsPath = Join-Path $codexHome "cocos-mcp\active-projects.json"
}

function Normalize-PathValue {
  param([string]$Value)
  return (($Value -replace "\\", "/").TrimEnd("/")).ToLowerInvariant()
}

function Get-McpPortFromProjectLog {
  param([string]$TargetProjectPath)

  $logPath = Join-Path $TargetProjectPath "settings\cocos-mcp.log"
  if (-not (Test-Path -LiteralPath $logPath)) {
    return $null
  }

  $matches = Select-String -Path $logPath -Pattern "MCP Server running at http://127\.0\.0\.1:(\d+)" -ErrorAction SilentlyContinue
  if (-not $matches) {
    return $null
  }

  for ($i = $matches.Count - 1; $i -ge 0; $i--) {
    $line = $matches[$i].Line
    $match = [regex]::Match($line, "MCP Server running at http://127\.0\.0\.1:(\d+)")
    if ($match.Success) {
      return [int]$match.Groups[1].Value
    }
  }

  return $null
}

function Get-ActiveProjectInfo {
  param(
    [string]$TargetProjectPath,
    [string]$RegistryPath
  )

  if (-not (Test-Path -LiteralPath $RegistryPath)) {
    return $null
  }

  try {
    $activeProjects = Get-Content -LiteralPath $RegistryPath -Raw | ConvertFrom-Json
  } catch {
    return $null
  }

  $normalizedTarget = Normalize-PathValue $TargetProjectPath
  return $activeProjects | Where-Object {
    $_.projectPath -and (Normalize-PathValue $_.projectPath) -eq $normalizedTarget
  } | Select-Object -First 1
}

$project = Get-ActiveProjectInfo -TargetProjectPath $ProjectPath -RegistryPath $ActiveProjectsPath

$process = Get-CimInstance Win32_Process -Filter "name = 'CocosCreator.exe'" | Where-Object {
  $_.CommandLine -and $_.CommandLine.IndexOf($ProjectPath, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
} | Select-Object -First 1

if (-not $project -and -not $process) {
  throw "No running Cocos Creator instance found for project path: $ProjectPath"
}

$cdpPort = 9222
$commandLine = $null
$procId = $null
if ($process) {
  $commandLine = $process.CommandLine
  $procId = $process.ProcessId
  $match = [regex]::Match($commandLine, "--remote-debugging-port=(\d+)")
  if ($match.Success) {
    $cdpPort = [int]$match.Groups[1].Value
  }
}

$mcpPort = $null
if ($project -and $project.port) {
  $mcpPort = [int]$project.port
}
if (-not $mcpPort) {
  $mcpPort = Get-McpPortFromProjectLog -TargetProjectPath $ProjectPath
}

[pscustomobject]@{
  projectName = if ($project -and $project.projectName) { $project.projectName } else { Split-Path -Leaf $ProjectPath }
  projectPath = $ProjectPath
  assetsPath = if ($project -and $project.assetsPath) { $project.assetsPath } else { Join-Path $ProjectPath "assets" }
  pid = if ($project -and $project.pid) { $project.pid } else { $procId }
  editorVersion = if ($project -and $project.editorVersion) { $project.editorVersion } else { $null }
  mcpPort = $mcpPort
  cdpPort = $cdpPort
  commandLine = $commandLine
} | ConvertTo-Json -Depth 10
