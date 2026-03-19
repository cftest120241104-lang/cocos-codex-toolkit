param(
  [string]$RepoRoot = $(Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$validator = Join-Path $env:USERPROFILE ".codex\skills\.system\skill-creator\scripts\quick_validate.py"
if (-not (Test-Path -LiteralPath $validator)) {
  throw "Validator not found: $validator"
}

$skillsRoot = Join-Path $RepoRoot "skills"
$results = New-Object System.Collections.Generic.List[object]

Get-ChildItem -Path $skillsRoot -Directory | ForEach-Object {
  $skillPath = $_.FullName
  $command = "set PYTHONUTF8=1&& python `"$validator`" `"$skillPath`""
  $output = cmd /c $command 2>&1
  $success = ($LASTEXITCODE -eq 0)
  $results.Add([pscustomobject]@{
    skill = $_.Name
    success = $success
    output = ($output -join [Environment]::NewLine)
  }) | Out-Null
}

$results | ConvertTo-Json -Depth 10
