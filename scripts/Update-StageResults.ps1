param(
  [string]$DataPath = "assets/data.js",
  [int[]]$Stages,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Normalize-Name {
  param([string]$Value)

  if (-not $Value) { return "" }
  $normalized = $Value.Normalize([Text.NormalizationForm]::FormD)
  $builder = [Text.StringBuilder]::new()

  foreach ($char in $normalized.ToCharArray()) {
    if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($char) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
      [void]$builder.Append($char)
    }
  }

  return ($builder.ToString().ToLowerInvariant() -replace "[^a-z0-9]+", " " -replace "\s+", " ").Trim()
}

function Read-TdfData {
  param([string]$Path)

  $raw = Get-Content -Raw -Encoding UTF8 -Path $Path
  $json = $raw -replace '^\s*window\.TDF_DATA\s*=\s*', ''
  $json = $json -replace ';\s*$', ''
  return $json | ConvertFrom-Json
}

function Write-TdfData {
  param(
    [string]$Path,
    [object]$Data
  )

  $json = $Data | ConvertTo-Json -Depth 30
  $content = "window.TDF_DATA = $json;`n"
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText((Resolve-Path $Path), $content, $utf8NoBom)
}

function New-RiderResolver {
  param([object[]]$Riders)

  $map = @{}
  foreach ($rider in $Riders) {
    @($rider.name) + @($rider.aliases) | Where-Object { $_ } | ForEach-Object {
      $key = Normalize-Name $_
      if ($key -and -not $map.ContainsKey($key)) {
        $map[$key] = $rider
      }
    }
  }

  return $map
}

function Resolve-Rider {
  param(
    [hashtable]$Resolver,
    [string]$Name
  )

  $key = Normalize-Name $Name
  if ($Resolver.ContainsKey($key)) { return $Resolver[$key] }
  return $null
}

function Convert-HtmlText {
  param([string]$Html)

  if (-not $Html) { return "" }
  $text = [System.Net.WebUtility]::HtmlDecode($Html)
  $text = $text -replace '<[^>]+>', ' '
  return ($text -replace '\s+', ' ').Trim()
}

function Convert-RiderDisplayName {
  param([string]$Name)

  if (-not $Name) { return "" }
  return (Get-Culture).TextInfo.ToTitleCase($Name.ToLowerInvariant())
}

function Parse-StageTop3 {
  param(
    [string]$Html,
    [hashtable]$Resolver,
    [System.Collections.ArrayList]$Unresolved,
    [int]$Stage
  )

  $rows = [regex]::Matches($Html, '<tr[^>]*class="[^"]*rankingTables__row[^"]*"[^>]*>(.*?)</tr>', 'Singleline')
  $top3 = @()

  foreach ($rowMatch in $rows) {
    $row = $rowMatch.Groups[1].Value
    $rankMatch = [regex]::Match($row, '<td[^>]*is-alignCenter[^>]*>\s*<span>(\d+)</span>', 'Singleline')
    if (-not $rankMatch.Success) { continue }

    $rank = [int]$rankMatch.Groups[1].Value
    if ($rank -lt 1 -or $rank -gt 3) { continue }

    $fullNameMatch = [regex]::Match($row, 'alt="([^"]+)"', 'Singleline')
    $shortNameMatch = [regex]::Match($row, 'rankingTables__row__profile--name[^>]*>\s*(.*?)\s*</a>', 'Singleline')
    $teamMatch = [regex]::Match($row, '<td class="break-line team">\s*<a[^>]*>\s*(.*?)\s*</a>', 'Singleline')
    $timeMatches = [regex]::Matches($row, '<td class="is-alignCenter time">\s*(.*?)\s*</td>', 'Singleline')

    $rawName = if ($fullNameMatch.Success) { Convert-HtmlText $fullNameMatch.Groups[1].Value } else { Convert-HtmlText $shortNameMatch.Groups[1].Value }
    $displayName = if ($shortNameMatch.Success) { Convert-HtmlText $shortNameMatch.Groups[1].Value } else { $rawName }
    $team = if ($teamMatch.Success) { Convert-HtmlText $teamMatch.Groups[1].Value } else { "" }
    $time = if ($timeMatches.Count -ge 1) { Convert-HtmlText $timeMatches[0].Groups[1].Value } else { "" }
    $gap = if ($timeMatches.Count -ge 2) { Convert-HtmlText $timeMatches[1].Groups[1].Value } else { "" }
    $resolved = Resolve-Rider -Resolver $Resolver -Name $rawName

    if (-not $resolved) {
      $null = $Unresolved.Add([pscustomobject]@{ name = Convert-RiderDisplayName $rawName; context = "stage $Stage top3 rank $rank" })
    }

    $top3 += [pscustomobject]@{
      rank = $rank
      riderId = if ($resolved) { $resolved.id } else { $null }
      name = if ($resolved) { $resolved.name } else { Convert-RiderDisplayName $rawName }
      team = $team
      time = $time
      gap = $gap
    }
  }

  return $top3 | Sort-Object rank
}

function Merge-ParsedTop3WithExisting {
  param(
    [object[]]$ParsedTop3,
    [object[]]$ExistingTop3
  )

  if (-not $ExistingTop3) { return $ParsedTop3 }

  return @($ParsedTop3 | ForEach-Object {
    $parsed = $_
    $existing = @($ExistingTop3 | Where-Object {
      [int]$_.rank -eq [int]$parsed.rank -and
      $_.name -eq $parsed.name -and
      $_.time -eq $parsed.time -and
      $_.gap -eq $parsed.gap -and
      [string]$_.team -ieq [string]$parsed.team
    })[0]

    if ($existing) { $existing } else { $parsed }
  })
}

function Get-RankingPageUrl {
  param([int]$Stage)

  return "https://www.letour.fr/en/rankings/stage-$Stage"
}

function Get-LatestCompletedStageNumber {
  param([object]$Data)

  $latest = @($Data.stageResults.PSObject.Properties |
    ForEach-Object { $_.Value } |
    Where-Object { $_.status -in @("preliminary", "official") } |
    ForEach-Object { [int]$_.stage } |
    Sort-Object -Descending |
    Select-Object -First 1)

  if (-not $latest.Count) { return $null }
  return [int]$latest[0]
}

function Get-GeneralClassificationAjaxUrl {
  param(
    [string]$Html,
    [string]$BaseUrl = "https://www.letour.fr"
  )

  $match = [regex]::Match($Html, '&quot;itg&quot;:&quot;([^&]+)&quot;')
  if (-not $match.Success) { return $null }

  $path = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value).Replace('\/', '/')
  if ($path -match '^https?://') { return $path }
  return "$BaseUrl$path"
}

function Parse-GeneralClassificationTop10 {
  param(
    [string]$Html,
    [hashtable]$Resolver
  )

  $rows = [regex]::Matches($Html, '<tr[^>]*class="[^"]*rankingTables__row[^"]*"[^>]*>(.*?)</tr>', 'Singleline')
  $standings = @()

  foreach ($rowMatch in $rows) {
    $row = $rowMatch.Groups[1].Value
    $rankMatch = [regex]::Match($row, 'rankingTables__row__position[^>]*>\s*<span>(\d+)</span>', 'Singleline')
    if (-not $rankMatch.Success) { continue }

    $position = [int]$rankMatch.Groups[1].Value
    if ($position -lt 1 -or $position -gt 10) { continue }

    $fullNameMatch = [regex]::Match($row, 'alt="([^"]+)"', 'Singleline')
    $shortNameMatch = [regex]::Match($row, 'rankingTables__row__profile--name[^>]*>\s*(.*?)\s*</a>', 'Singleline')
    $teamMatch = [regex]::Match($row, '<td class="break-line team">\s*<a[^>]*>\s*(.*?)\s*</a>', 'Singleline')
    $timeMatches = [regex]::Matches($row, '<td class="is-alignCenter time">\s*(.*?)\s*</td>', 'Singleline')

    $rawName = if ($fullNameMatch.Success) { Convert-HtmlText $fullNameMatch.Groups[1].Value } else { Convert-HtmlText $shortNameMatch.Groups[1].Value }
    $resolved = Resolve-Rider -Resolver $Resolver -Name $rawName
    $name = if ($resolved) { $resolved.name } else { Convert-RiderDisplayName $rawName }

    $standings += [pscustomobject]@{
      position = $position
      riderId = if ($resolved) { $resolved.id } else { $null }
      name = $name
      team = if ($teamMatch.Success) { Convert-HtmlText $teamMatch.Groups[1].Value } else { "" }
      totalTime = if ($timeMatches.Count -ge 1) { Convert-HtmlText $timeMatches[0].Groups[1].Value } else { "" }
      gap = if ($timeMatches.Count -ge 2) { Convert-HtmlText $timeMatches[1].Groups[1].Value } else { "" }
      movement = $null
    }
  }

  return $standings | Sort-Object position
}

function Get-GeneralClassification {
  param(
    [int]$Stage,
    [string]$RankingHtml,
    [hashtable]$Resolver
  )

  $ajaxUrl = Get-GeneralClassificationAjaxUrl -Html $RankingHtml
  if (-not $ajaxUrl) {
    Write-Warning "Could not find general classification endpoint for stage $Stage."
    return $null
  }

  Write-Host "Fetching general classification from $ajaxUrl"
  try {
    $gcHtml = (Invoke-WebRequest -Uri $ajaxUrl -UseBasicParsing -TimeoutSec 30).Content
  } catch {
    Write-Warning "Could not fetch general classification for stage $Stage`: $($_.Exception.Message)"
    return $null
  }

  $standings = @(Parse-GeneralClassificationTop10 -Html $gcHtml -Resolver $Resolver)
  if ($standings.Count -lt 10) {
    Write-Warning "General classification top 10 was not available for stage $Stage."
    return $null
  }

  return [pscustomobject]@{
    stage = $Stage
    checkedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    status = "official"
    source = "letour"
    sourceUrl = Get-RankingPageUrl -Stage $Stage
    standings = $standings
  }
}

function New-GeneratedSummary {
  param(
    [int]$Stage,
    [object[]]$Top3
  )

  if ($Top3.Count -lt 3) { return "" }
  return "$($Top3[0].name) won stage $Stage ahead of $($Top3[1].name) and $($Top3[2].name). The result has been imported from the official Tour de France rankings. Add or update the race narrative later if an official stage report is available."
}

function Convert-ComparableJson {
  param([object]$Value)

  return ($Value | ConvertTo-Json -Depth 20 -Compress)
}

$data = Read-TdfData -Path $DataPath
$resolver = New-RiderResolver -Riders @($data.riders)
$unresolved = [System.Collections.ArrayList]::new()
$rankingHtmlByStage = @{}
$changed = $false

if (-not $data.stageResults) {
  $data | Add-Member -NotePropertyName "stageResults" -NotePropertyValue ([pscustomobject]@{})
} elseif ($data.stageResults -is [array]) {
  $resultMap = [pscustomobject]@{}
  @($data.stageResults) | ForEach-Object {
    $stageKey = [string]$_.stage
    $resultMap | Add-Member -NotePropertyName $stageKey -NotePropertyValue $_
  }
  $data.stageResults = $resultMap
}

if (-not $data.resultsMeta) {
  $data | Add-Member -NotePropertyName "resultsMeta" -NotePropertyValue ([pscustomobject]@{
    checkedAt = $null
    sourcePriority = @("letour", "pcs", "manualFallback")
    latestCompletedStage = $null
    status = "partial"
    unresolvedRiders = @()
  })
}

$stageNumbers = if ($Stages) {
  $Stages
} else {
  @($data.stages | Where-Object { [datetime]$_.date -le (Get-Date).Date } | ForEach-Object { [int]$_.number })
}

foreach ($stageNumber in $stageNumbers) {
  $stage = @($data.stages | Where-Object { [int]$_.number -eq $stageNumber })[0]
  if (-not $stage) { continue }

  $url = Get-RankingPageUrl -Stage $stageNumber
  Write-Host "Fetching stage $stageNumber results from $url"

  try {
    $html = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30).Content
  } catch {
    Write-Warning "Could not fetch stage $stageNumber results: $($_.Exception.Message)"
    continue
  }
  $rankingHtmlByStage[$stageNumber] = $html

  $top3 = @(Parse-StageTop3 -Html $html -Resolver $resolver -Unresolved $unresolved -Stage $stageNumber)
  if ($top3.Count -lt 3) {
    Write-Warning "Stage $stageNumber top 3 was not available."
    continue
  }

  $stageKey = [string]$stageNumber
  $stageResultProperty = $data.stageResults.PSObject.Properties[$stageKey]
  $existing = if ($stageResultProperty) { $stageResultProperty.Value } else { $null }
  $result = if ($existing) { $existing } else { [pscustomobject]@{ stage = $stageNumber } }

  $mergedTop3 = if ($existing) { @(Merge-ParsedTop3WithExisting -ParsedTop3 $top3 -ExistingTop3 @($existing.top3)) } else { $top3 }

  $updatedResult = [pscustomobject]@{
    stage = $stageNumber
    status = "official"
    flags = if ($result.PSObject.Properties["flags"] -and $result.flags) { @($result.flags) } else { @() }
    source = "letour"
    sourceUrl = if ($result.sourceUrl) { $result.sourceUrl } else { $url }
    checkedAt = if ($result.checkedAt) { $result.checkedAt } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz") }
    distanceActual = $stage.distance
    winner = [pscustomobject]@{
    riderId = $mergedTop3[0].riderId
    name = $mergedTop3[0].name
    team = $mergedTop3[0].team
    }
    top3 = $mergedTop3
    winningTime = $mergedTop3[0].time
    summary = if ($result.summary) { $result.summary } else { New-GeneratedSummary -Stage $stageNumber -Top3 $mergedTop3 }
    summarySourceUrl = if ($result.summarySourceUrl) { $result.summarySourceUrl } else { $url }
    jerseysAfterStage = if ($result.jerseysAfterStage) { $result.jerseysAfterStage } else { [pscustomobject]@{
      yellow = $null
      green = $null
      polkaDot = $null
      white = $null
    } }
    decisions = if ($result.PSObject.Properties["decisions"] -and $result.decisions) { @($result.decisions) } else { @() }
  }

  $oldComparable = if ($existing) {
    Convert-ComparableJson ([pscustomobject]@{
      stage = $existing.stage
      status = $existing.status
      flags = @($existing.flags)
      source = $existing.source
      sourceUrl = $existing.sourceUrl
      distanceActual = $existing.distanceActual
      winner = $existing.winner
      top3 = $existing.top3
      winningTime = $existing.winningTime
      summary = $existing.summary
      summarySourceUrl = $existing.summarySourceUrl
      jerseysAfterStage = $existing.jerseysAfterStage
      decisions = @($existing.decisions)
    })
  } else {
    $null
  }

  $newComparable = Convert-ComparableJson ([pscustomobject]@{
    stage = $updatedResult.stage
    status = $updatedResult.status
    flags = @($updatedResult.flags)
    source = $updatedResult.source
    sourceUrl = $updatedResult.sourceUrl
    distanceActual = $updatedResult.distanceActual
    winner = $updatedResult.winner
    top3 = $updatedResult.top3
    winningTime = $updatedResult.winningTime
    summary = $updatedResult.summary
    summarySourceUrl = $updatedResult.summarySourceUrl
    jerseysAfterStage = $updatedResult.jerseysAfterStage
    decisions = @($updatedResult.decisions)
  })

  if ($oldComparable -eq $newComparable) {
    continue
  }

  $updatedResult.checkedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

  if ($stageResultProperty) {
    $stageResultProperty.Value = $updatedResult
  } else {
    $data.stageResults | Add-Member -NotePropertyName $stageKey -NotePropertyValue $updatedResult
  }
  $changed = $true
}

$latestCompletedStage = Get-LatestCompletedStageNumber -Data $data

if ($latestCompletedStage) {
  $latestRankingHtml = $rankingHtmlByStage[$latestCompletedStage]
  if (-not $latestRankingHtml) {
    $latestUrl = Get-RankingPageUrl -Stage $latestCompletedStage
    Write-Host "Fetching stage $latestCompletedStage rankings for general classification from $latestUrl"
    try {
      $latestRankingHtml = (Invoke-WebRequest -Uri $latestUrl -UseBasicParsing -TimeoutSec 30).Content
    } catch {
      Write-Warning "Could not fetch stage $latestCompletedStage rankings for general classification: $($_.Exception.Message)"
    }
  }

  if ($latestRankingHtml) {
    $generalClassification = Get-GeneralClassification -Stage $latestCompletedStage -RankingHtml $latestRankingHtml -Resolver $resolver
    if ($generalClassification) {
      $oldGcComparable = if ($data.PSObject.Properties["generalClassification"]) {
        Convert-ComparableJson ([pscustomobject]@{
          stage = $data.generalClassification.stage
          status = $data.generalClassification.status
          source = $data.generalClassification.source
          sourceUrl = $data.generalClassification.sourceUrl
          standings = $data.generalClassification.standings
        })
      } else {
        $null
      }

      $newGcComparable = Convert-ComparableJson ([pscustomobject]@{
        stage = $generalClassification.stage
        status = $generalClassification.status
        source = $generalClassification.source
        sourceUrl = $generalClassification.sourceUrl
        standings = $generalClassification.standings
      })

      if ($oldGcComparable -ne $newGcComparable) {
        if ($data.PSObject.Properties["generalClassification"]) {
          $data.generalClassification = $generalClassification
        } else {
          $data | Add-Member -NotePropertyName "generalClassification" -NotePropertyValue $generalClassification
        }
        $changed = $true
      }
    }
  }
}

if ($changed) {
  $data.resultsMeta.checkedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
  $data.resultsMeta.latestCompletedStage = Get-LatestCompletedStageNumber -Data $data
  $data.resultsMeta.unresolvedRiders = @($unresolved)
  $data.resultsMeta.status = if ($unresolved.Count) { "needs_review" } else { "ok" }
  $data.meta.dataStatus.results = if ($unresolved.Count) { "Official / needs review" } else { "Official" }
  $data.meta.updatedAt = (Get-Date).ToString("yyyy-MM-dd")
}

Write-Host "Unresolved riders: $($unresolved.Count)"
@($unresolved) | ForEach-Object { Write-Host " - $($_.name) [$($_.context)]" }

if ($DryRun) {
  if (-not $changed) { Write-Host "No changes detected." }
  Write-Host "Dry run complete. Data file was not changed."
  exit 0
}

if (-not $changed) {
  Write-Host "No changes detected."
  exit 0
}

$before = Get-Content -Raw -Encoding UTF8 -Path $DataPath
$tempJson = $data | ConvertTo-Json -Depth 30
$after = "window.TDF_DATA = $tempJson;`n"

if ($before -eq $after) {
  Write-Host "No changes detected."
  exit 0
}

Write-TdfData -Path $DataPath -Data $data
Write-Host "Updated $DataPath"
