param(
  [string]$SourceDirectory = "D:\AI-HQ\01_Projects\Personal\Tour de France 2026 - Rider Photos\mi base",
  [string]$DestinationDirectory = (Join-Path $PSScriptRoot "..\assets\riders\official")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
  throw "Rider photo database not found: $SourceDirectory"
}

$photos = @(Get-ChildItem -LiteralPath $SourceDirectory -File -Filter "*.jpg" | Sort-Object Name)
if ($photos.Count -eq 0) {
  throw "No JPG rider photos found in: $SourceDirectory"
}

$entries = foreach ($photo in $photos) {
  if ($photo.Name -notmatch '^(?<id>\d{3}) - (?<slug>.+)_hamster_GE\.jpg$') {
    throw "Unexpected rider photo filename: $($photo.Name)"
  }

  [pscustomobject]@{
    id = $Matches.id
    slug = $Matches.slug
    sourceName = $photo.Name
    sourcePath = $photo.FullName
  }
}

$duplicateIds = @($entries | Group-Object id | Where-Object Count -gt 1)
if ($duplicateIds.Count -gt 0) {
  throw "Duplicate official rider photo IDs: $($duplicateIds.Name -join ', ')"
}

New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null

foreach ($entry in $entries) {
  Copy-Item -LiteralPath $entry.sourcePath -Destination (Join-Path $DestinationDirectory "$($entry.id).jpg") -Force
}

$backgroundScript = Join-Path $PSScriptRoot "Replace-RiderPhotoBackground.py"
& python $backgroundScript --directory $DestinationDirectory
if ($LASTEXITCODE -ne 0) {
  throw "Failed to replace rider photo backgrounds."
}

$manifest = @($entries | ForEach-Object {
  [ordered]@{
    officialId = $_.id
    riderSlug = $_.slug
    sourceName = $_.sourceName
    websiteFile = "$($_.id).jpg"
  }
})
$manifestPath = Join-Path $DestinationDirectory "manifest.json"
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host "Imported $($entries.Count) rider photos with white backgrounds to $DestinationDirectory"
Write-Host "Manifest: $manifestPath"
