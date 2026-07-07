param(
  [string]$DataPath = "assets/data.js",
  [string]$ChannelId = "UCfDfvvMARk4TKcC62ALi6eA",
  [string]$ChannelName = "TNT Sports Cycling",
  [string]$ChannelUrl = "https://www.youtube.com/@TNTSportsCycling",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Get-HighlightType {
  param([string]$Title)

  if ($Title -match "(?i)race highlights") { return "Race Highlights" }
  if ($Title -match "(?i)final\s*km") { return "Final KM's" }
  if ($Title -match "(?i)reaction") { return "Reaction" }
  return "Clip"
}

function Get-StageNumber {
  param([string]$Title)

  if ($Title -match "(?i)stage\s+([0-9]{1,2})") {
    return [int]$Matches[1]
  }

  return $null
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

  $json = $Data | ConvertTo-Json -Depth 20
  $content = "window.TDF_DATA = $json;`n"
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText((Resolve-Path $Path), $content, $utf8NoBom)
}

$feedUrl = "https://www.youtube.com/feeds/videos.xml?channel_id=$ChannelId"
Write-Host "Fetching $feedUrl"

$requestHeaders = @{ "User-Agent" = "Mozilla/5.0" }
[xml]$feed = (Invoke-WebRequest -Uri $feedUrl -UseBasicParsing -TimeoutSec 30 -Headers $requestHeaders).Content
$ns = [System.Xml.XmlNamespaceManager]::new($feed.NameTable)
$ns.AddNamespace("a", "http://www.w3.org/2005/Atom")
$ns.AddNamespace("yt", "http://www.youtube.com/xml/schemas/2015")

$data = Read-TdfData -Path $DataPath

if (-not $data.videoSource) {
  $data | Add-Member -NotePropertyName "videoSource" -NotePropertyValue ([pscustomobject]@{})
}

$data.videoSource = [pscustomobject]@{
  name = $ChannelName
  channelUrl = $ChannelUrl
  channelId = $ChannelId
  feedUrl = $feedUrl
  note = "Primary source for daily highlights. RSS is checked after each stage."
}

if (-not $data.highlights) {
  $data | Add-Member -NotePropertyName "highlights" -NotePropertyValue @()
}

$existingIds = @{}
@($data.highlights) | ForEach-Object {
  if ($_.videoId) { $existingIds[$_.videoId] = $true }
}

$newItems = @()
$entries = $feed.SelectNodes("//a:entry", $ns)
foreach ($entry in $entries) {
  $title = $entry.SelectSingleNode("a:title", $ns).InnerText
  $videoId = $entry.SelectSingleNode("yt:videoId", $ns).InnerText
  $link = $entry.SelectSingleNode("a:link", $ns).href
  $publishedAt = $entry.SelectSingleNode("a:published", $ns).InnerText
  $stage = Get-StageNumber -Title $title

  if (-not $stage) { continue }
  if ($title -notmatch "(?i)\btour\b") { continue }
  if ($existingIds.ContainsKey($videoId)) { continue }

  $item = [pscustomobject]@{
    stage = $stage
    type = Get-HighlightType -Title $title
    title = $title
    url = $link
    videoId = $videoId
    source = $ChannelName
    publishedAt = $publishedAt
    discoveredAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    isShort = ($link -match "/shorts/")
  }

  $newItems += $item
  $existingIds[$videoId] = $true
}

if ($newItems.Count -eq 0) {
  Write-Host "No new Tour de France highlight videos found."
} else {
  Write-Host "Found $($newItems.Count) new Tour de France video(s)."
  $data.highlights = @($data.highlights) + $newItems
}

$data.meta.updatedAt = (Get-Date).ToString("yyyy-MM-dd")
$data.meta.youtubeHighlightsCheckedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

if (-not $data.meta.dataStatus.highlights) {
  $data.meta.dataStatus | Add-Member -NotePropertyName "highlights" -NotePropertyValue "RSS monitored"
} else {
  $data.meta.dataStatus.highlights = "RSS monitored"
}

if ($DryRun) {
  Write-Host "Dry run complete. Data file was not changed."
  exit 0
}

Write-TdfData -Path $DataPath -Data $data
Write-Host "Updated $DataPath"
