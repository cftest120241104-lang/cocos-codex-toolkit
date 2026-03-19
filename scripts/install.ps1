param(
  [string]$RepoRoot = $(Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

$skillsSource = Join-Path $RepoRoot "skills"
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }
$skillsTarget = Join-Path $codexHome "skills"
$binPath = Join-Path $RepoRoot "bin"

New-Item -ItemType Directory -Force -Path $skillsTarget | Out-Null

Get-ChildItem -Path $skillsSource -Directory | ForEach-Object {
  $target = Join-Path $skillsTarget $_.Name
  if (Test-Path -LiteralPath $target) {
    Remove-Item -LiteralPath $target -Recurse -Force
  }
  Copy-Item -LiteralPath $_.FullName -Destination $target -Recurse -Force
  Set-Content -LiteralPath (Join-Path $target "toolkit-root.txt") -Value $RepoRoot -Encoding UTF8
}

[Environment]::SetEnvironmentVariable("COCOS_CODEX_TOOLKIT_HOME", $RepoRoot, "User")

$currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$normalizedEntries = @()
if ($currentUserPath) {
  $normalizedEntries = $currentUserPath.Split(';') | Where-Object { $_ }
}
if ($normalizedEntries -notcontains $binPath) {
  $newPath = if ($currentUserPath) { "$currentUserPath;$binPath" } else { $binPath }
  [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
}

[pscustomobject]@{
  repoRoot = $RepoRoot
  codexHome = $codexHome
  installedSkills = Get-ChildItem -Path $skillsSource -Directory | Select-Object -ExpandProperty Name
  toolkitHomeEnv = $RepoRoot
  binPath = $binPath
  note = "Open a new shell before using cocos-toolkit from PATH."
} | ConvertTo-Json -Depth 10
