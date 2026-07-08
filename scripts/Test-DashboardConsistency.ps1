param(
  [string]$DataPath = "assets/data.js",
  [datetime]$ReferenceDate = (Get-Date)
)

$ErrorActionPreference = "Stop"

function Read-TdfData {
  param([string]$Path)

  $raw = Get-Content -Raw -Encoding UTF8 -Path $Path
  $json = $raw -replace '^\s*window\.TDF_DATA\s*=\s*', ''
  $json = $json -replace ';\s*$', ''
  return $json | ConvertFrom-Json
}

function Get-StageResultsList {
  param([object]$Data)

  if ($Data.stageResults -is [array]) { return @($Data.stageResults) }
  if ($Data.stageResults) { return @($Data.stageResults.PSObject.Properties | ForEach-Object { $_.Value }) }
  return @()
}

function Get-StageResult {
  param(
    [object]$Data,
    [int]$StageNumber
  )

  if ($Data.stageResults -and $Data.stageResults.PSObject.Properties[[string]$StageNumber]) {
    return $Data.stageResults.PSObject.Properties[[string]$StageNumber].Value
  }

  return @(Get-StageResultsList -Data $Data | Where-Object { [int]$_.stage -eq $StageNumber })[0]
}

function Test-PlaceholderValue {
  param([string]$Value)

  if (-not $Value) { return $true }
  return $Value -notmatch '\d'
}

function Get-LatestCompletedResult {
  param([object]$Data)

  return @(Get-StageResultsList -Data $Data |
    Where-Object { $_.status -in @("preliminary", "official") } |
    Sort-Object { [int]$_.stage })[-1]
}

function Get-ExpectedLatestCompletedStage {
  param(
    [object]$Data,
    [datetime]$Today
  )

  $todayKey = $Today.ToString("yyyy-MM-dd")
  $completed = @($Data.stages | Where-Object { $_.date -lt $todayKey } | Sort-Object { [int]$_.number })
  if (-not $completed.Count) { return $null }
  return [int]$completed[-1].number
}

function Get-SelectedStage {
  param(
    [object]$Data,
    [datetime]$Today
  )

  $todayKey = $Today.ToString("yyyy-MM-dd")
  $latestCompleted = Get-LatestCompletedResult -Data $Data
  $exact = @($Data.stages | Where-Object { $_.date -eq $todayKey })[0]

  if ($exact) {
    $exactResult = Get-StageResult -Data $Data -StageNumber ([int]$exact.number)
    if ($exactResult -and $exactResult.status -in @("preliminary", "official")) { return $exact }
    if ($latestCompleted) {
      return @($Data.stages | Where-Object { [int]$_.number -eq [int]$latestCompleted.stage })[0]
    }
    return $exact
  }

  $upcoming = @($Data.stages | Where-Object { $_.date -gt $todayKey } | Sort-Object date)[0]
  if ($upcoming) { return $upcoming }

  if ($latestCompleted) {
    return @($Data.stages | Where-Object { [int]$_.number -eq [int]$latestCompleted.stage })[0]
  }

  return @($Data.stages)[-1]
}

$data = Read-TdfData -Path $DataPath
$errors = [System.Collections.Generic.List[string]]::new()
$latestCompleted = Get-LatestCompletedResult -Data $data
$expectedLatestStage = Get-ExpectedLatestCompletedStage -Data $data -Today $ReferenceDate
$selectedStage = Get-SelectedStage -Data $data -Today $ReferenceDate

if (-not $latestCompleted) {
  $errors.Add("No completed stage result is available in stageResults.")
} else {
  if ($expectedLatestStage -and [int]$latestCompleted.stage -ne $expectedLatestStage) {
    $errors.Add("Latest completed stage is $($latestCompleted.stage), expected $expectedLatestStage for $($ReferenceDate.ToString('yyyy-MM-dd')).")
  }

  if ([int]$data.resultsMeta.latestCompletedStage -ne [int]$latestCompleted.stage) {
    $errors.Add("resultsMeta.latestCompletedStage is $($data.resultsMeta.latestCompletedStage), but latest result is stage $($latestCompleted.stage).")
  }

  foreach ($jersey in @("yellow", "green", "polkaDot", "white")) {
    $entry = $latestCompleted.jerseysAfterStage.$jersey
    if (-not $entry -or -not $entry.name) {
      $errors.Add("Missing $jersey jersey holder after stage $($latestCompleted.stage).")
    }
  }

  if (-not $latestCompleted.winner -or -not $latestCompleted.winner.name) {
    $errors.Add("Missing stage winner for latest completed stage $($latestCompleted.stage).")
  }

  if (@($latestCompleted.top3).Count -lt 3) {
    $errors.Add("Latest completed stage $($latestCompleted.stage) does not have a full top 3.")
  }

  if (-not $latestCompleted.summary) {
    $errors.Add("Latest completed stage $($latestCompleted.stage) has no recap summary.")
  } else {
    if ($latestCompleted.summary.Length -lt 120) {
      $errors.Add("Latest completed stage $($latestCompleted.stage) recap is too short.")
    }
    if ($latestCompleted.summary -notmatch [regex]::Escape($latestCompleted.winner.name)) {
      $errors.Add("Latest completed stage $($latestCompleted.stage) recap does not mention the winner.")
    }
    $yellowHolder = $latestCompleted.jerseysAfterStage.yellow
    if ($yellowHolder -and $yellowHolder.name -and $latestCompleted.summary -notmatch [regex]::Escape($yellowHolder.name)) {
      $errors.Add("Latest completed stage $($latestCompleted.stage) recap does not mention the yellow jersey holder.")
    }
    if (@($latestCompleted.top3).Count -ge 2 -and $latestCompleted.summary -notmatch [regex]::Escape($latestCompleted.top3[1].name)) {
      $errors.Add("Latest completed stage $($latestCompleted.stage) recap does not mention another key rider or event outcome.")
    }
  }
}

if (-not $selectedStage) {
  $errors.Add("Could not determine the dashboard-selected stage.")
} else {
  $selectedResult = Get-StageResult -Data $data -StageNumber ([int]$selectedStage.number)
  if ($latestCompleted -and [int]$selectedStage.number -ne [int]$latestCompleted.stage) {
    $todayKey = $ReferenceDate.ToString("yyyy-MM-dd")
    if ($selectedStage.date -eq $todayKey -and (-not $selectedResult -or $selectedResult.status -notin @("preliminary", "official"))) {
      $errors.Add("Dashboard would select unfinished stage $($selectedStage.number) instead of latest completed stage $($latestCompleted.stage).")
    }
  }

  if ($latestCompleted -and [int]$selectedStage.number -eq [int]$latestCompleted.stage) {
    if (-not $selectedResult -or $selectedResult.status -notin @("preliminary", "official")) {
      $errors.Add("Selected stage $($selectedStage.number) is completed but has no visible result.")
    }

    if (Test-PlaceholderValue -Value $selectedStage.elevation) {
      $errors.Add("Selected completed stage $($selectedStage.number) still has a placeholder elevation.")
    }
    if (Test-PlaceholderValue -Value $selectedStage.startTime) {
      $errors.Add("Selected completed stage $($selectedStage.number) still has a placeholder start time.")
    }
    if (Test-PlaceholderValue -Value $selectedStage.finishWindow) {
      $errors.Add("Selected completed stage $($selectedStage.number) still has a placeholder finish window.")
    }
  }
}

$latestHighlightStage = @($data.highlights | Where-Object { -not $_.isShort } | ForEach-Object { [int]$_.stage } | Sort-Object)[-1]
if ($latestCompleted -and $latestHighlightStage -and $latestHighlightStage -gt [int]$latestCompleted.stage) {
  $errors.Add("Latest highlight stage is $latestHighlightStage, but latest completed race result is stage $($latestCompleted.stage).")
}

if ($data.meta.dataStatus.results -match '^Official' -and $expectedLatestStage -and [int]$data.resultsMeta.latestCompletedStage -lt $expectedLatestStage) {
  $errors.Add("Results data status claims Official while data only reaches stage $($data.resultsMeta.latestCompletedStage) and expected stage is $expectedLatestStage.")
}

if ($errors.Count) {
  Write-Host "Dashboard consistency check failed:"
  $errors | ForEach-Object { Write-Host " - $_" }
  exit 1
}

Write-Host "Dashboard consistency OK."
if ($latestCompleted) {
  Write-Host "Latest completed stage: $($latestCompleted.stage)"
}
if ($selectedStage) {
  Write-Host "Dashboard selected stage: $($selectedStage.number)"
}
