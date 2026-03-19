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

function Send-Cdp {
  param(
    [System.Net.WebSockets.ClientWebSocket]$Socket,
    [System.Text.Encoding]$Encoding,
    [string]$Json
  )

  $bytes = $Encoding.GetBytes($Json)
  $segment = [ArraySegment[byte]]::new($bytes)
  $Socket.SendAsync(
    $segment,
    [System.Net.WebSockets.WebSocketMessageType]::Text,
    $true,
    [Threading.CancellationToken]::None
  ).GetAwaiter().GetResult() | Out-Null
}

function Receive-Cdp {
  param(
    [System.Net.WebSockets.ClientWebSocket]$Socket,
    [System.Text.Encoding]$Encoding,
    [int]$Seconds
  )

  $end = (Get-Date).AddSeconds($Seconds)
  $items = New-Object System.Collections.Generic.List[string]

  while ((Get-Date) -lt $end -and $Socket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
    $buffer = New-Object byte[] 65536
    $segment = [ArraySegment[byte]]::new($buffer)
    $stream = New-Object System.IO.MemoryStream
    try {
      $task = $Socket.ReceiveAsync($segment, [Threading.CancellationToken]::None)
    } catch {
      $stream.Dispose()
      break
    }

    $remainingMs = [Math]::Max(1, [int](($end - (Get-Date)).TotalMilliseconds))
    $waitMs = [Math]::Min(1000, $remainingMs)
    try {
      $completed = $task.Wait($waitMs)
    } catch {
      $stream.Dispose()
      break
    }

    if (-not $completed) {
      $stream.Dispose()
      break
    }

    try {
      $result = $task.Result
    } catch {
      $stream.Dispose()
      break
    }
    if ($result.Count -gt 0) {
      $stream.Write($buffer, 0, $result.Count)
    }

    while (-not $result.EndOfMessage -and $Socket.State -eq [System.Net.WebSockets.WebSocketState]::Open) {
      try {
        $task = $Socket.ReceiveAsync($segment, [Threading.CancellationToken]::None)
        $task.Wait() | Out-Null
        $result = $task.Result
      } catch {
        break
      }
      if ($result.Count -gt 0) {
        $stream.Write($buffer, 0, $result.Count)
      }
    }

    if ($stream.Length -gt 0) {
      $items.Add($Encoding.GetString($stream.ToArray()))
    }

    $stream.Dispose()
  }

  return $items
}

function Invoke-McpCall {
  param(
    [int]$Port,
    [string]$ToolName,
    [hashtable]$Arguments
  )

  $body = @{
    name = $ToolName
    arguments = $Arguments
  } | ConvertTo-Json -Depth 10

  Invoke-RestMethod -Uri "http://127.0.0.1:$Port/call-tool" -Method Post -ContentType "application/json" -Body $body | Out-Null
}

function Simplify-CdpMessage {
  param([string]$Raw)

  try {
    $message = $Raw | ConvertFrom-Json -Depth 30
  } catch {
    return $null
  }

  if ($message.method -eq "Runtime.consoleAPICalled") {
    $parts = @()
    foreach ($arg in $message.params.args) {
      if ($null -ne $arg.value) {
        $parts += [string]$arg.value
      } elseif ($null -ne $arg.description) {
        $parts += [string]$arg.description
      } else {
        $parts += [string]$arg.type
      }
    }

    return [pscustomobject]@{
      method = $message.method
      level = $message.params.type
      source = "runtime"
      text = ($parts -join " | ")
    }
  }

  if ($message.method -eq "Console.messageAdded") {
    return [pscustomobject]@{
      method = $message.method
      level = $message.params.message.level
      source = $message.params.message.source
      text = $message.params.message.text
    }
  }

  if ($message.method -eq "Runtime.exceptionThrown") {
    $text = $message.params.exceptionDetails.text
    if ($message.params.exceptionDetails.exception -and $message.params.exceptionDetails.exception.description) {
      $text = $message.params.exceptionDetails.exception.description
    }

    return [pscustomobject]@{
      method = $message.method
      level = "exception"
      source = "runtime"
      text = $text
    }
  }

  if ($message.method -eq "Log.entryAdded") {
    return [pscustomobject]@{
      method = $message.method
      level = $message.params.entry.level
      source = $message.params.entry.source
      text = $message.params.entry.text
    }
  }

  return $null
}

function Normalize-Issue {
  param(
    [pscustomobject]$Event,
    [string]$CurrentAsset
  )

  $assetPattern = 'The Asset used by component "([^"]+)" in (scene|prefab) "([^"]+)" is missing\.\s*Detailed information:\s*Node path: "([^"]+)"\s*Asset url: "([^"]+)"\s*Missing uuid: "([^"]+)"'
  $match = [regex]::Match($Event.text, $assetPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if ($match.Success) {
    return [pscustomobject]@{
      type = "asset-missing"
      currentAsset = $CurrentAsset
      component = $match.Groups[1].Value
      ownerType = $match.Groups[2].Value
      ownerName = $match.Groups[3].Value
      nodePath = $match.Groups[4].Value
      assetUrl = $match.Groups[5].Value
      missingUuid = $match.Groups[6].Value
      message = $Event.text
    }
  }

  if ($Event.text -match "object already destroyed") {
    return [pscustomobject]@{
      type = "destroyed-object"
      currentAsset = $CurrentAsset
      message = $Event.text
    }
  }

  if ($Event.text -match "TypeError|ReferenceError|SyntaxError|load script .* failed|Cannot set property") {
    return [pscustomobject]@{
      type = "exception"
      currentAsset = $CurrentAsset
      message = $Event.text
    }
  }

  return $null
}

$discoverScript = Join-Path $PSScriptRoot "discover_cocos_instance.ps1"
$instance = & $discoverScript -ProjectPath $ProjectPath | ConvertFrom-Json

if (-not $instance.mcpPort) {
  throw "No MCP port found for project path: $ProjectPath"
}

if (-not $OutputDir) {
  $OutputDir = Join-Path $ProjectPath "qa-logs"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$existingIndexes = @(
  Get-ChildItem -Path $OutputDir -File -ErrorAction SilentlyContinue |
    ForEach-Object {
      $m = [regex]::Match($_.Name, '^log(\d+)-')
      if ($m.Success) { [int]$m.Groups[1].Value }
    } |
    Where-Object { $_ -is [int] }
)
$nextIndex = if ($existingIndexes.Count -gt 0) {
  (($existingIndexes | Measure-Object -Maximum).Maximum + 1)
} else {
  1
}
$logPrefix = "log$nextIndex"
$rawPath = Join-Path $OutputDir "$logPrefix-raw-$stamp.jsonl"
$summaryPath = Join-Path $OutputDir "$logPrefix-summary-$stamp.json"
$reportPath = Join-Path $OutputDir "$logPrefix-report-$stamp.md"

$cdpList = Invoke-RestMethod -Uri "http://127.0.0.1:$($instance.cdpPort)/json/list"
$page = $cdpList | Where-Object { $_.type -eq "page" } | Select-Object -First 1
if (-not $page) {
  throw "No CDP page found on port $($instance.cdpPort)"
}

$socket = [System.Net.WebSockets.ClientWebSocket]::new()
$socket.ConnectAsync([Uri]$page.webSocketDebuggerUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult() | Out-Null
$encoding = [System.Text.Encoding]::UTF8

Send-Cdp -Socket $socket -Encoding $encoding -Json '{"id":1,"method":"Runtime.enable","params":{}}'
Send-Cdp -Socket $socket -Encoding $encoding -Json '{"id":2,"method":"Console.enable","params":{}}'
Send-Cdp -Socket $socket -Encoding $encoding -Json '{"id":3,"method":"Log.enable","params":{}}'

$script:rawMessages = New-Object System.Collections.Generic.List[string]

function Capture-Scope {
  param(
    [string]$CurrentAsset,
    [int]$Seconds
  )

  $captured = Receive-Cdp -Socket $socket -Encoding $encoding -Seconds $Seconds
  foreach ($raw in $captured) {
    $wrapped = [pscustomobject]@{
      scope = $CurrentAsset
      raw = $raw
    } | ConvertTo-Json -Compress -Depth 10
    $script:rawMessages.Add($wrapped)
  }
}

Capture-Scope -CurrentAsset "startup" -Seconds 1

if (-not $NoSmoke) {
  Send-Cdp -Socket $socket -Encoding $encoding -Json '{"id":4,"method":"Runtime.evaluate","params":{"expression":"console.warn(\"codex-cdp-smoke-test\")"}}'
  Capture-Scope -CurrentAsset "startup" -Seconds 2
}

foreach ($sceneUrl in $OpenSceneUrls) {
  Invoke-McpCall -Port ([int]$instance.mcpPort) -ToolName "open_scene" -Arguments @{ url = $sceneUrl }
  Capture-Scope -CurrentAsset $sceneUrl -Seconds $ActionWaitSeconds
}

foreach ($prefabUrl in $OpenPrefabUrls) {
  Invoke-McpCall -Port ([int]$instance.mcpPort) -ToolName "open_prefab" -Arguments @{ url = $prefabUrl }
  Capture-Scope -CurrentAsset $prefabUrl -Seconds $ActionWaitSeconds
}

try {
  $socket.Abort()
} catch {}

$script:rawMessages | Set-Content -LiteralPath $rawPath -Encoding UTF8

$summaryScript = Join-Path $PSScriptRoot "summarize_cdp_log.py"
$normalized = python $summaryScript $rawPath
if ($LASTEXITCODE -ne 0) {
  throw "Failed to summarize raw CDP log: $rawPath"
}
$normalizedSummary = $normalized | ConvertFrom-Json

$summary = [pscustomobject]@{
  projectPath = $ProjectPath
  projectName = $instance.projectName
  pid = $instance.pid
  editorVersion = $instance.editorVersion
  mcpPort = $instance.mcpPort
  cdpPort = $instance.cdpPort
  replayedScenes = $OpenSceneUrls
  replayedPrefabs = $OpenPrefabUrls
  rawLogPath = $rawPath
  summaryPath = $summaryPath
  reportPath = $reportPath
  capturedEventCount = $normalizedSummary.capturedEventCount
  ignoredEventCount = $normalizedSummary.ignoredEventCount
  rawIssueCount = $normalizedSummary.rawIssueCount
  issueCount = $normalizedSummary.issueCount
  issueTypeCounts = $normalizedSummary.issueTypeCounts
  ignoredMessages = $normalizedSummary.ignoredMessages
  verdict = $normalizedSummary.verdict
  issues = $normalizedSummary.issues
}

$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$reportLines = New-Object System.Collections.Generic.List[string]
$reportLines.Add("# Cocos Engine QA Report")
$reportLines.Add("")
$reportLines.Add("Verdict: $($summary.verdict)")
$reportLines.Add("Project: $($summary.projectPath)")
$reportLines.Add("Captured events: $($summary.capturedEventCount)")
$reportLines.Add("Ignored events: $($summary.ignoredEventCount)")
$reportLines.Add("Matched issue events: $($summary.rawIssueCount)")
$reportLines.Add("Unique issues: $($summary.issueCount)")
$reportLines.Add("")

if ($summary.replayedScenes.Count -gt 0) {
  $reportLines.Add("Scenes:")
  foreach ($scene in $summary.replayedScenes) {
    $reportLines.Add("- $scene")
  }
  $reportLines.Add("")
}

if ($summary.replayedPrefabs.Count -gt 0) {
  $reportLines.Add("Prefabs:")
  foreach ($prefab in $summary.replayedPrefabs) {
    $reportLines.Add("- $prefab")
  }
  $reportLines.Add("")
}

if ($summary.ignoredMessages.Count -gt 0) {
  $reportLines.Add("Ignored noise:")
  foreach ($item in $summary.ignoredMessages) {
    $reportLines.Add("- $($item.message) ($($item.occurrences))")
  }
  $reportLines.Add("")
}

if ($summary.issueTypeCounts.PSObject.Properties.Count -gt 0) {
  $reportLines.Add("Issue types:")
  foreach ($property in $summary.issueTypeCounts.PSObject.Properties) {
    $reportLines.Add("- $($property.Name): $($property.Value)")
  }
  $reportLines.Add("")
}

$reportLines.Add("Issues:")
if ($summary.issues.Count -eq 0) {
  $reportLines.Add("- none")
} else {
  foreach ($issue in $summary.issues) {
    if ($issue.type -eq "asset-missing") {
      $reportLines.Add("- [$($issue.type)] $($issue.ownerType) $($issue.ownerName) :: $($issue.component) :: uuid=$($issue.missingUuid) :: node=$($issue.nodePath) :: occurrences=$($issue.occurrences) :: scopes=$([string]::Join(', ', $issue.scopes))")
    } else {
      $reportLines.Add("- [$($issue.type)] $($issue.summary) :: occurrences=$($issue.occurrences) :: scopes=$([string]::Join(', ', $issue.scopes))")
    }
  }
}
$reportLines.Add("")
$reportLines.Add("Raw log: $rawPath")
$reportLines.Add("Summary: $summaryPath")

$reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8
$summary | ConvertTo-Json -Depth 20
