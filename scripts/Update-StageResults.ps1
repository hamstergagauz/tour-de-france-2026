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

function Convert-ToSlug {
  param([string]$Value)

  $normalized = Normalize-Name $Value
  if (-not $normalized) { return "unknown-rider" }
  return ($normalized -replace "\s+", "-")
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

  $json = $Data | ConvertTo-Json -Depth 40
  $content = "window.TDF_DATA = $json;`n"
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText((Resolve-Path $Path), $content, $utf8NoBom)
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

function Convert-ComparableJson {
  param([object]$Value)

  return ($Value | ConvertTo-Json -Depth 30 -Compress)
}

function New-StringArray {
  param([object]$Values)

  $items = [System.Collections.Generic.List[string]]::new()
  foreach ($value in @($Values)) {
    if (-not $value) { continue }
    $text = [string]$value
    if (-not $items.Contains($text)) {
      $items.Add($text)
    }
  }
  return ,@($items)
}

function New-IntArray {
  param([object]$Values)

  $items = [System.Collections.Generic.List[int]]::new()
  foreach ($value in @($Values)) {
    if ($null -eq $value -or $value -eq "") { continue }
    if ($value -is [System.Management.Automation.PSCustomObject] -or $value -is [hashtable]) { continue }
    $number = [int]$value
    if (-not $items.Contains($number)) {
      $items.Add($number)
    }
  }
  return ,@($items | Sort-Object)
}

function New-JerseyHistory {
  param([object]$Existing)

  return [pscustomobject]@{
    yellow = New-IntArray @($Existing.yellow)
    green = New-IntArray @($Existing.green)
    polkaDot = New-IntArray @($Existing.polkaDot)
    white = New-IntArray @($Existing.white)
  }
}

function New-InclusionState {
  param([object]$Existing)

  return [pscustomobject]@{
    editorial = [bool]($Existing.editorial)
    stageWinner = [bool]($Existing.stageWinner)
    jerseyHolder = [bool]($Existing.jerseyHolder)
  }
}

function New-OfficialIds {
  param([object]$Existing)

  return [pscustomobject]@{
    letour = if ($Existing -and $Existing.letour) { [string]$Existing.letour } else { $null }
  }
}

function Ensure-RiderRegistryShape {
  param([object]$Data)

  $curatedOrder = 0

  foreach ($rider in @($Data.riders)) {
    if (-not $rider.id) {
      throw "Every rider must have a canonical id before registry shaping."
    }

    if (-not $rider.PSObject.Properties["aliases"]) {
      $rider | Add-Member -NotePropertyName "aliases" -NotePropertyValue @()
    }
    $rider.aliases = New-StringArray (@($rider.aliases) + @($rider.name))

    $entryType = if ($rider.PSObject.Properties["entryType"]) { [string]$rider.entryType } else { "" }
    if (-not $entryType) {
      $rider | Add-Member -NotePropertyName "entryType" -NotePropertyValue "curated" -Force
      $entryType = "curated"
    }
    if ($entryType -eq "curated") {
      $curatedOrder++
    }

    $rider | Add-Member -NotePropertyName "officialIds" -NotePropertyValue (New-OfficialIds $rider.officialIds) -Force
    $rider | Add-Member -NotePropertyName "reviewNeeded" -NotePropertyValue ([bool]$rider.reviewNeeded) -Force
    $rider | Add-Member -NotePropertyName "inclusion" -NotePropertyValue (New-InclusionState $rider.inclusion) -Force
    $rider | Add-Member -NotePropertyName "stageWinnerStages" -NotePropertyValue (New-IntArray @($rider.stageWinnerStages)) -Force
    $rider | Add-Member -NotePropertyName "jerseyHistory" -NotePropertyValue (New-JerseyHistory $rider.jerseyHistory) -Force
    $rider | Add-Member -NotePropertyName "latestQualifyingStage" -NotePropertyValue $(if ($rider.latestQualifyingStage) { [int]$rider.latestQualifyingStage } else { $null }) -Force
    $rider | Add-Member -NotePropertyName "editorialOrder" -NotePropertyValue $(if ($entryType -eq "curated") { $curatedOrder } else { $null }) -Force
    $rider | Add-Member -NotePropertyName "derivedFrom" -NotePropertyValue $(if ($rider.PSObject.Properties["derivedFrom"]) { $rider.derivedFrom } else { $null }) -Force

    if ($entryType -eq "curated") {
      $rider.inclusion.editorial = $true
    }
  }
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

function Parse-LetourRiderIdentity {
  param([string]$RowHtml)

  $match = [regex]::Match($RowHtml, 'href="/en/rider/(\d+)/[^"]+/([^"/?#]+)"', 'IgnoreCase')
  if (-not $match.Success) {
    return [pscustomobject]@{
      letourId = $null
      slug = $null
    }
  }

  return [pscustomobject]@{
    letourId = [string]$match.Groups[1].Value
    slug = [string]$match.Groups[2].Value
  }
}

function New-RankingEntry {
  param(
    [string]$RowHtml,
    [string]$RawName,
    [string]$DisplayName,
    [string]$Team
  )

  $identity = Parse-LetourRiderIdentity -RowHtml $RowHtml
  return [pscustomobject]@{
    officialIds = [pscustomobject]@{
      letour = $identity.letourId
    }
    letourSlug = $identity.slug
    name = if ($DisplayName) { $DisplayName } else { Convert-RiderDisplayName $RawName }
    rawName = $RawName
    normalizedName = Normalize-Name $RawName
    team = $Team
  }
}

function Parse-StageTop3 {
  param([string]$Html)

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
    $displayName = if ($shortNameMatch.Success) { Convert-HtmlText $shortNameMatch.Groups[1].Value } else { Convert-RiderDisplayName $rawName }
    $team = if ($teamMatch.Success) { Convert-HtmlText $teamMatch.Groups[1].Value } else { "" }
    $entry = New-RankingEntry -RowHtml $row -RawName $rawName -DisplayName $displayName -Team $team

    $top3 += [pscustomobject]@{
      rank = $rank
      riderId = $null
      officialIds = $entry.officialIds
      letourSlug = $entry.letourSlug
      name = $entry.name
      rawName = $entry.rawName
      team = $team
      time = if ($timeMatches.Count -ge 1) { Convert-HtmlText $timeMatches[0].Groups[1].Value } else { "" }
      gap = if ($timeMatches.Count -ge 2) { Convert-HtmlText $timeMatches[1].Groups[1].Value } else { "" }
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

    if ($existing) {
      if (-not $existing.PSObject.Properties["officialIds"]) {
        $existing | Add-Member -NotePropertyName "officialIds" -NotePropertyValue $parsed.officialIds -Force
      } else {
        $existing.officialIds = $parsed.officialIds
      }
      if (-not $existing.PSObject.Properties["letourSlug"]) {
        $existing | Add-Member -NotePropertyName "letourSlug" -NotePropertyValue $parsed.letourSlug -Force
      } else {
        $existing.letourSlug = $parsed.letourSlug
      }
      $existing
    } else {
      $parsed
    }
  })
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
  param([string]$Html)

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
    $displayName = if ($shortNameMatch.Success) { Convert-HtmlText $shortNameMatch.Groups[1].Value } else { Convert-RiderDisplayName $rawName }
    $team = if ($teamMatch.Success) { Convert-HtmlText $teamMatch.Groups[1].Value } else { "" }
    $entry = New-RankingEntry -RowHtml $row -RawName $rawName -DisplayName $displayName -Team $team

    $standings += [pscustomobject]@{
      position = $position
      riderId = $null
      officialIds = $entry.officialIds
      letourSlug = $entry.letourSlug
      name = $entry.name
      rawName = $entry.rawName
      team = $team
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
    [string]$RankingHtml
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

  $standings = @(Parse-GeneralClassificationTop10 -Html $gcHtml)
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

function New-RiderRegistryContext {
  param([object[]]$Riders)

  $byId = @{}
  $byLetourId = @{}
  $aliasMap = @{}

  foreach ($rider in @($Riders)) {
    $byId[$rider.id] = $rider

    $letourId = [string]$rider.officialIds.letour
    if ($letourId) {
      if (-not $byLetourId.ContainsKey($letourId)) {
        $byLetourId[$letourId] = [System.Collections.Generic.List[object]]::new()
      }
      $byLetourId[$letourId].Add($rider)
    }

    foreach ($alias in New-StringArray (@($rider.aliases) + @($rider.name))) {
      $key = Normalize-Name $alias
      if (-not $key) { continue }
      if (-not $aliasMap.ContainsKey($key)) {
        $aliasMap[$key] = [System.Collections.Generic.List[object]]::new()
      }
      if (-not @($aliasMap[$key] | Where-Object { $_.id -eq $rider.id }).Count) {
        $aliasMap[$key].Add($rider)
      }
    }
  }

  return [pscustomobject]@{
    byId = $byId
    byLetourId = $byLetourId
    aliasMap = $aliasMap
  }
}

function Resolve-RiderCandidate {
  param(
    [pscustomobject]$Context,
    [pscustomobject]$Candidate
  )

  if ($Candidate.canonicalRiderId -and $Context.byId.ContainsKey($Candidate.canonicalRiderId)) {
    return [pscustomobject]@{
      type = "matched"
      rider = $Context.byId[$Candidate.canonicalRiderId]
      ambiguity = $null
    }
  }

  $letourId = [string]$Candidate.officialIds.letour
  $normalizedName = Normalize-Name $Candidate.rawName
  $aliasMatches = if ($normalizedName -and $Context.aliasMap.ContainsKey($normalizedName)) { @($Context.aliasMap[$normalizedName].ToArray()) } else { @() }

  if ($letourId -and $Context.byLetourId.ContainsKey($letourId)) {
    $officialMatches = @($Context.byLetourId[$letourId].ToArray())
    if ($officialMatches.Count -eq 1) {
      return [pscustomobject]@{
        type = "matched"
        rider = $officialMatches[0]
        ambiguity = $null
      }
    }

    return [pscustomobject]@{
      type = "ambiguous"
      rider = $null
      ambiguity = "Multiple riders share Letour ID $letourId."
      candidates = $officialMatches
    }
  }

  if ($letourId -and $aliasMatches.Count -eq 1) {
    return [pscustomobject]@{
      type = "matched"
      rider = $aliasMatches[0]
      ambiguity = $null
    }
  }

  if ($letourId -and $aliasMatches.Count -gt 1) {
    return [pscustomobject]@{
      type = "ambiguous"
      rider = $null
      ambiguity = "Letour ID $letourId matched multiple alias candidates."
      candidates = $aliasMatches
    }
  }

  if ($aliasMatches.Count -eq 1) {
    return [pscustomobject]@{
      type = "matched"
      rider = $aliasMatches[0]
      ambiguity = $null
    }
  }

  if ($aliasMatches.Count -gt 1) {
    return [pscustomobject]@{
      type = "ambiguous"
      rider = $null
      ambiguity = "Alias '$($Candidate.rawName)' matched multiple riders."
      candidates = $aliasMatches
    }
  }

  if ($normalizedName) {
    $directMatches = @($Context.byId.Values | Where-Object {
      (Normalize-Name $_.name) -eq $normalizedName -or
      @($_.aliases | ForEach-Object { Normalize-Name $_ }) -contains $normalizedName
    })

    if ($directMatches.Count -eq 1) {
      return [pscustomobject]@{
        type = "matched"
        rider = $directMatches[0]
        ambiguity = $null
      }
    }

    if ($directMatches.Count -gt 1) {
      return [pscustomobject]@{
        type = "ambiguous"
        rider = $null
        ambiguity = "Name '$($Candidate.rawName)' matched multiple riders."
        candidates = $directMatches
      }
    }
  }

  return [pscustomobject]@{
    type = "missing"
    rider = $null
    ambiguity = $null
  }
}

function Merge-Alias {
  param(
    [object]$Rider,
    [string[]]$Values
  )

  $Rider.aliases = New-StringArray (@($Rider.aliases) + @($Values))
}

function Merge-RiderCoverage {
  param(
    [object]$Rider,
    [pscustomobject]$Candidate,
    [string]$SourceType,
    [int]$Stage,
    [string]$JerseyType
  )

  Merge-Alias -Rider $Rider -Values @($Candidate.rawName, $Candidate.name)

  if ($Candidate.officialIds.letour -and -not $Rider.officialIds.letour) {
    $Rider.officialIds.letour = [string]$Candidate.officialIds.letour
  }

  if (-not $Rider.team -and $Candidate.team) {
    $Rider.team = $Candidate.team
  }

  if ($SourceType -eq "winner") {
    $Rider.inclusion.stageWinner = $true
    $Rider.stageWinnerStages = New-IntArray (@($Rider.stageWinnerStages) + @($Stage))
  }

  if ($SourceType -eq "jersey") {
    $Rider.inclusion.jerseyHolder = $true
    $currentStages = @($Rider.jerseyHistory.$JerseyType)
    $Rider.jerseyHistory.$JerseyType = New-IntArray ($currentStages + @($Stage))
  }

  if ($Stage -and (($null -eq $Rider.latestQualifyingStage) -or ([int]$Stage -gt [int]$Rider.latestQualifyingStage))) {
    $Rider.latestQualifyingStage = [int]$Stage
  }

  if ($Rider.entryType -eq "derived" -and -not $Candidate.officialIds.letour) {
    $Rider.reviewNeeded = $true
  }
}

function New-DerivedRider {
  param(
    [pscustomobject]$Candidate,
    [string]$SourceType,
    [int]$Stage,
    [string]$JerseyType
  )

  $letourId = [string]$Candidate.officialIds.letour
  $canonicalId = if ($letourId) { "letour-rider-$letourId" } else { "derived-" + (Convert-ToSlug $Candidate.rawName) }
  $displayName = if ($Candidate.rawName) { Convert-RiderDisplayName $Candidate.rawName } else { $Candidate.name }

  $rider = [pscustomobject]@{
    id = $canonicalId
    aliases = New-StringArray @($Candidate.rawName, $Candidate.name)
    name = $displayName
    team = $Candidate.team
    country = ""
    roles = @()
    entryType = "derived"
    reviewNeeded = [bool](-not $letourId)
    officialIds = [pscustomobject]@{
      letour = $letourId
    }
    inclusion = [pscustomobject]@{
      editorial = $false
      stageWinner = $false
      jerseyHolder = $false
    }
    stageWinnerStages = @()
    jerseyHistory = [pscustomobject]@{
      yellow = @()
      green = @()
      polkaDot = @()
      white = @()
    }
    latestQualifyingStage = $null
    editorialOrder = $null
    derivedFrom = [pscustomobject]@{
      type = if ($letourId) { "letour-official" } else { "fallback-name" }
      source = if ($SourceType -eq "winner") { "stage-winner" } else { "jersey-holder" }
      createdAtStage = $Stage
      jerseyType = $JerseyType
    }
  }

  Merge-RiderCoverage -Rider $rider -Candidate $Candidate -SourceType $SourceType -Stage $Stage -JerseyType $JerseyType
  return $rider
}

function New-CoverageCandidate {
  param(
    [string]$SourceType,
    [int]$Stage,
    [string]$JerseyType,
    [object]$Entry
  )

  if (-not $Entry -or -not $Entry.name) { return $null }

  return [pscustomobject]@{
    sourceType = $SourceType
    stage = $Stage
    jerseyType = $JerseyType
    canonicalRiderId = if ($Entry.PSObject.Properties["riderId"] -and $Entry.riderId) { [string]$Entry.riderId } else { $null }
    rawName = if ($Entry.PSObject.Properties["rawName"] -and $Entry.rawName) { [string]$Entry.rawName } else { [string]$Entry.name }
    name = [string]$Entry.name
    team = if ($Entry.team) { [string]$Entry.team } else { "" }
    officialIds = New-OfficialIds $Entry.officialIds
  }
}

function Reset-DerivedCoverageState {
  param([object[]]$Riders)

  foreach ($rider in @($Riders)) {
    $rider.inclusion.stageWinner = $false
    $rider.inclusion.jerseyHolder = $false
    $rider.stageWinnerStages = @()
    $rider.jerseyHistory = New-JerseyHistory $null
    $rider.latestQualifyingStage = $null
    if ($rider.entryType -eq "derived") {
      $rider.reviewNeeded = [bool](-not $rider.officialIds.letour)
    }
  }
}

function Build-RiderCoverage {
  param([object]$Data)

  Reset-DerivedCoverageState -Riders @($Data.riders)

  $context = New-RiderRegistryContext -Riders @($Data.riders)
  $blockingIssues = [System.Collections.Generic.List[object]]::new()
  $coverageEvents = [System.Collections.Generic.List[object]]::new()

  $completedResults = @($Data.stageResults.PSObject.Properties |
    ForEach-Object { $_.Value } |
    Where-Object { $_.status -in @("preliminary", "official") } |
    Sort-Object stage)

  foreach ($result in $completedResults) {
    $winnerCandidate = New-CoverageCandidate -SourceType "winner" -Stage ([int]$result.stage) -JerseyType $null -Entry $result.winner
    if ($winnerCandidate) {
      $coverageEvents.Add($winnerCandidate)
    }

    foreach ($jerseyType in @("yellow", "green", "polkaDot", "white")) {
      $entry = if ($result.jerseysAfterStage) { $result.jerseysAfterStage.$jerseyType } else { $null }
      $candidate = New-CoverageCandidate -SourceType "jersey" -Stage ([int]$result.stage) -JerseyType $jerseyType -Entry $entry
      if ($candidate) {
        $coverageEvents.Add($candidate)
      }
    }
  }

  foreach ($candidate in $coverageEvents) {
    $resolution = Resolve-RiderCandidate -Context $context -Candidate $candidate

    switch ($resolution.type) {
      "matched" {
        Merge-RiderCoverage -Rider $resolution.rider -Candidate $candidate -SourceType $candidate.sourceType -Stage $candidate.stage -JerseyType $candidate.jerseyType
        if ($candidate.officialIds.letour -and -not $resolution.rider.officialIds.letour) {
          $resolution.rider.officialIds.letour = [string]$candidate.officialIds.letour
          $context = New-RiderRegistryContext -Riders @($Data.riders)
        }
      }
      "missing" {
        $derived = New-DerivedRider -Candidate $candidate -SourceType $candidate.sourceType -Stage $candidate.stage -JerseyType $candidate.jerseyType
        if ($context.byId.ContainsKey($derived.id)) {
          Merge-RiderCoverage -Rider $context.byId[$derived.id] -Candidate $candidate -SourceType $candidate.sourceType -Stage $candidate.stage -JerseyType $candidate.jerseyType
        } else {
          $Data.riders += $derived
        }
        $context = New-RiderRegistryContext -Riders @($Data.riders)
      }
      "ambiguous" {
        $blockingIssues.Add([pscustomobject]@{
          kind = "required-rider-ambiguous"
          sourceType = $candidate.sourceType
          stage = $candidate.stage
          jerseyType = $candidate.jerseyType
          name = $candidate.name
          rawName = $candidate.rawName
          letourId = $candidate.officialIds.letour
          message = $resolution.ambiguity
          candidateRiders = @($resolution.candidates | ForEach-Object {
            [pscustomobject]@{
              id = $_.id
              name = $_.name
              entryType = $_.entryType
              letourId = $_.officialIds.letour
            }
          })
        })
      }
    }
  }

  $curated = @($Data.riders | Where-Object { $_.entryType -eq "curated" } | Sort-Object editorialOrder)
  $derived = @($Data.riders | Where-Object { $_.entryType -eq "derived" } | Sort-Object @{ Expression = {
    if ($null -ne $_.latestQualifyingStage) {
      -1 * [int]$_.latestQualifyingStage
    } else {
      0
    }
  } }, @{ Expression = { $_.name } })
  $Data.riders = @($curated + $derived)

  return [pscustomobject]@{
    blockingIssues = @($blockingIssues)
  }
}

function Update-ResolvedRiderIds {
  param([object]$Data)

  $context = New-RiderRegistryContext -Riders @($Data.riders)

  foreach ($result in @($Data.stageResults.PSObject.Properties | ForEach-Object { $_.Value })) {
    if ($result.winner) {
      $candidate = New-CoverageCandidate -SourceType "winner" -Stage ([int]$result.stage) -JerseyType $null -Entry $result.winner
      $resolution = Resolve-RiderCandidate -Context $context -Candidate $candidate
      if ($resolution.type -eq "matched") {
        $result.winner.riderId = $resolution.rider.id
      }
    }

    foreach ($item in @($result.top3)) {
      $candidate = New-CoverageCandidate -SourceType "winner" -Stage ([int]$result.stage) -JerseyType $null -Entry $item
      $resolution = Resolve-RiderCandidate -Context $context -Candidate $candidate
      if ($resolution.type -eq "matched") {
        $item.riderId = $resolution.rider.id
      }
    }

    foreach ($jerseyType in @("yellow", "green", "polkaDot", "white")) {
      $entry = if ($result.jerseysAfterStage) { $result.jerseysAfterStage.$jerseyType } else { $null }
      if (-not $entry) { continue }
      $candidate = New-CoverageCandidate -SourceType "jersey" -Stage ([int]$result.stage) -JerseyType $jerseyType -Entry $entry
      $resolution = Resolve-RiderCandidate -Context $context -Candidate $candidate
      if ($resolution.type -eq "matched") {
        $entry.riderId = $resolution.rider.id
      }
    }
  }

  if ($Data.generalClassification -and $Data.generalClassification.standings) {
    foreach ($standing in @($Data.generalClassification.standings)) {
      $candidate = New-CoverageCandidate -SourceType "winner" -Stage ([int]$Data.generalClassification.stage) -JerseyType $null -Entry $standing
      $resolution = Resolve-RiderCandidate -Context $context -Candidate $candidate
      if ($resolution.type -eq "matched") {
        $standing.riderId = $resolution.rider.id
      }
    }
  }
}

function Get-RiderRegistryValidation {
  param([object]$Data)

  $duplicateIds = [System.Collections.Generic.List[object]]::new()
  $aliasConflicts = [System.Collections.Generic.List[object]]::new()
  $blockingIssues = [System.Collections.Generic.List[object]]::new()
  $fallbackIdentityRiders = [System.Collections.Generic.List[object]]::new()
  $derivedRiders = [System.Collections.Generic.List[object]]::new()
  $includedRiders = [System.Collections.Generic.List[object]]::new()

  $seenIds = @{}
  foreach ($rider in @($Data.riders)) {
    if ($seenIds.ContainsKey($rider.id)) {
      $duplicateIds.Add([pscustomobject]@{
        id = $rider.id
        names = @($seenIds[$rider.id], $rider.name)
      })
    } else {
      $seenIds[$rider.id] = $rider.name
    }

    if ($rider.entryType -eq "derived") {
      $derivedRiders.Add([pscustomobject]@{
        id = $rider.id
        name = $rider.name
        letourId = $rider.officialIds.letour
        reviewNeeded = [bool]$rider.reviewNeeded
        latestQualifyingStage = $rider.latestQualifyingStage
      })
    }

    if ($rider.reviewNeeded) {
      $fallbackIdentityRiders.Add([pscustomobject]@{
        id = $rider.id
        name = $rider.name
        entryType = $rider.entryType
      })
    }

    if ($rider.inclusion.editorial -or $rider.inclusion.stageWinner -or $rider.inclusion.jerseyHolder) {
      $includedRiders.Add([pscustomobject]@{
        id = $rider.id
        name = $rider.name
        entryType = $rider.entryType
      })
    }
  }

  $context = New-RiderRegistryContext -Riders @($Data.riders)
  foreach ($pair in $context.aliasMap.GetEnumerator()) {
    $riders = @($pair.Value)
    if ($riders.Count -gt 1) {
      $aliasConflicts.Add([pscustomobject]@{
        alias = $pair.Key
        riders = @($riders | ForEach-Object {
          [pscustomobject]@{
            id = $_.id
            name = $_.name
            entryType = $_.entryType
            letourId = $_.officialIds.letour
          }
        })
      })
    }
  }

  $completedResults = @($Data.stageResults.PSObject.Properties |
    ForEach-Object { $_.Value } |
    Where-Object { $_.status -in @("preliminary", "official") } |
    Sort-Object stage)

  foreach ($result in $completedResults) {
    foreach ($candidate in @(
      New-CoverageCandidate -SourceType "winner" -Stage ([int]$result.stage) -JerseyType $null -Entry $result.winner
    )) {
      if (-not $candidate) { continue }
      $resolution = Resolve-RiderCandidate -Context $context -Candidate $candidate
      if ($resolution.type -ne "matched") {
        $blockingIssues.Add([pscustomobject]@{
          kind = "winner-unmapped"
          stage = $candidate.stage
          name = $candidate.name
          letourId = $candidate.officialIds.letour
          message = if ($resolution.ambiguity) { $resolution.ambiguity } else { "Winner does not map to exactly one rider." }
        })
      }
    }

    foreach ($jerseyType in @("yellow", "green", "polkaDot", "white")) {
      $candidate = New-CoverageCandidate -SourceType "jersey" -Stage ([int]$result.stage) -JerseyType $jerseyType -Entry $result.jerseysAfterStage.$jerseyType
      if (-not $candidate) { continue }
      $resolution = Resolve-RiderCandidate -Context $context -Candidate $candidate
      if ($resolution.type -ne "matched") {
        $blockingIssues.Add([pscustomobject]@{
          kind = "jersey-holder-unmapped"
          stage = $candidate.stage
          jerseyType = $jerseyType
          name = $candidate.name
          letourId = $candidate.officialIds.letour
          message = if ($resolution.ambiguity) { $resolution.ambiguity } else { "Jersey holder does not map to exactly one rider." }
        })
      }
    }
  }

  foreach ($duplicate in @($duplicateIds)) {
    $blockingIssues.Add([pscustomobject]@{
      kind = "duplicate-id"
      id = $duplicate.id
      message = "Duplicate canonical rider id."
    })
  }

  $status = "complete"
  if ($blockingIssues.Count) {
    $status = "blocking"
  } elseif ($aliasConflicts.Count -or $fallbackIdentityRiders.Count) {
    $status = "review-needed"
  }

  return [pscustomobject]@{
    checkedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    status = $status
    duplicateIds = @($duplicateIds)
    aliasConflicts = @($aliasConflicts)
    blockingIssues = @($blockingIssues)
    fallbackIdentityRiders = @($fallbackIdentityRiders)
    derivedRiders = @($derivedRiders)
    includedRiders = @($includedRiders)
  }
}

function Set-CompactResultsMeta {
  param([object]$Data)

  if (-not $Data.resultsMeta) {
    $Data | Add-Member -NotePropertyName "resultsMeta" -NotePropertyValue ([pscustomobject]@{})
  }

  $latestCompletedStage = Get-LatestCompletedStageNumber -Data $Data
  $status = if ($Data.riderValidation) { $Data.riderValidation.status } else { "complete" }

  $Data.resultsMeta = [pscustomobject]@{
    checkedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    sourcePriority = @("letour", "pcs", "manualFallback")
    latestCompletedStage = $latestCompletedStage
    status = $status
    riderRegistryStatus = $status
  }

  $Data.meta.dataStatus.results = if ($status -eq "blocking") { "Official / blocking" } elseif ($status -eq "review-needed") { "Official / review needed" } else { "Official" }
}

$data = Read-TdfData -Path $DataPath
Ensure-RiderRegistryShape -Data $data
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

  $top3 = @(Parse-StageTop3 -Html $html)
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
      riderId = $null
      officialIds = $mergedTop3[0].officialIds
      letourSlug = $mergedTop3[0].letourSlug
      name = $mergedTop3[0].name
      rawName = $mergedTop3[0].rawName
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
    $generalClassification = Get-GeneralClassification -Stage $latestCompletedStage -RankingHtml $latestRankingHtml
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

$beforePostProcessing = Convert-ComparableJson ([pscustomobject]@{
  riders = $data.riders
  stageResults = $data.stageResults
  generalClassification = $data.generalClassification
  riderValidation = $data.riderValidation
  resultsMeta = $data.resultsMeta
})

$coverageResult = Build-RiderCoverage -Data $data
Update-ResolvedRiderIds -Data $data
$data | Add-Member -NotePropertyName "riderValidation" -NotePropertyValue (Get-RiderRegistryValidation -Data $data) -Force
Set-CompactResultsMeta -Data $data
$data.meta.updatedAt = (Get-Date).ToString("yyyy-MM-dd")

$afterPostProcessing = Convert-ComparableJson ([pscustomobject]@{
  riders = $data.riders
  stageResults = $data.stageResults
  generalClassification = $data.generalClassification
  riderValidation = $data.riderValidation
  resultsMeta = $data.resultsMeta
})

if ($beforePostProcessing -ne $afterPostProcessing) {
  $changed = $true
}

Write-Host "Rider registry status: $($data.riderValidation.status)"
Write-Host "Derived riders: $(@($data.riderValidation.derivedRiders).Count)"
Write-Host "Fallback identity riders: $(@($data.riderValidation.fallbackIdentityRiders).Count)"
Write-Host "Alias conflicts: $(@($data.riderValidation.aliasConflicts).Count)"
Write-Host "Blocking issues: $(@($data.riderValidation.blockingIssues).Count)"

if ($DryRun) {
  if (-not $changed) { Write-Host "No changes detected." }
  Write-Host "Dry run complete. Data file was not changed."
  if ($data.riderValidation.status -eq "blocking") {
    exit 2
  }
  exit 0
}

if (-not $changed) {
  Write-Host "No changes detected."
  if ($data.riderValidation.status -eq "blocking") {
    exit 2
  }
  exit 0
}

$before = Get-Content -Raw -Encoding UTF8 -Path $DataPath
$tempJson = $data | ConvertTo-Json -Depth 40
$after = "window.TDF_DATA = $tempJson;`n"

if ($before -eq $after) {
  Write-Host "No changes detected."
  if ($data.riderValidation.status -eq "blocking") {
    exit 2
  }
  exit 0
}

Write-TdfData -Path $DataPath -Data $data
Write-Host "Updated $DataPath"

if ($data.riderValidation.status -eq "blocking") {
  Write-Error "Rider registry validation is blocking. Daily commit should not proceed."
}
