param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectPath,

  [string[]]$OpenSceneUrls = @(),
  [string[]]$OpenPrefabUrls = @(),
  [string]$OutputDir,
  [int]$ActionWaitSeconds = 5,
  [switch]$NoSmoke
)

$ErrorActionPreference = "Stop"

function Resolve-ToolkitRoot {
  $candidates = New-Object System.Collections.Generic.List[string]

  if ($env:COCOS_CODEX_TOOLKIT_HOME) {
    $candidates.Add($env:COCOS_CODEX_TOOLKIT_HOME) | Out-Null
  }

  $markerPath = Join-Path $PSScriptRoot "..\toolkit-root.txt"
  if (Test-Path -LiteralPath $markerPath) {
    $markedRoot = (Get-Content -LiteralPath $markerPath -Raw).Trim()
    if ($markedRoot) {
      $candidates.Add($markedRoot) | Out-Null
    }
  }

  $repoCandidate = Join-Path $PSScriptRoot "..\..\.."
  $candidates.Add($repoCandidate) | Out-Null

  foreach ($candidate in $candidates) {
    try {
      $full = (Resolve-Path -LiteralPath $candidate).Path
    } catch {
      continue
    }

    $scriptPath = Join-Path $full "toolkit\qa\capture_cocos_engine_logs.ps1"
    if (Test-Path -LiteralPath $scriptPath) {
      return $full
    }
  }

  throw "Unable to locate cocos-codex-toolkit. Run scripts\\install.ps1 from the toolkit repo or set COCOS_CODEX_TOOLKIT_HOME."
}

$toolkitRoot = Resolve-ToolkitRoot
$scriptPath = Join-Path $toolkitRoot "toolkit\qa\capture_cocos_engine_logs.ps1"
$params = @{
  ProjectPath = $ProjectPath
  OpenSceneUrls = $OpenSceneUrls
  OpenPrefabUrls = $OpenPrefabUrls
  ActionWaitSeconds = $ActionWaitSeconds
}
if ($OutputDir) {
  $params.OutputDir = $OutputDir
}
if ($NoSmoke) {
  $params.NoSmoke = $true
}

& $scriptPath @params
