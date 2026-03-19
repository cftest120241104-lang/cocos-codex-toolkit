param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Arguments
)

$ErrorActionPreference = "Stop"

function Show-Usage {
  @'
Usage:
  cocos-toolkit qa --project <path> [--scene <db-url>]... [--prefab <db-url>]... [--output-dir <path>] [--wait-seconds <n>] [--no-smoke]
  cocos-toolkit discover --project <path> [--active-projects-path <path>]
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
