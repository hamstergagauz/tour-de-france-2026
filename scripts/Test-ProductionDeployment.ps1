param(
  [string]$DataPath = "assets/data.js",
  [string]$ProductionDataUrl = "https://tdf.halktoplushu.md/assets/data.js",
  [int]$Attempts = 12,
  [int]$DelaySeconds = 10
)

$ErrorActionPreference = "Stop"

function ConvertFrom-TdfJavascript {
  param([string]$Content)

  $json = $Content -replace '^\s*window\.TDF_DATA\s*=\s*', ''
  $json = $json -replace ';\s*$', ''
  return $json | ConvertFrom-Json
}

function Get-LatestCompletedStage {
  param([object]$Data)

  return [int](@($Data.stageResults.PSObject.Properties |
    ForEach-Object { $_.Value } |
    Where-Object { $_.status -in @("preliminary", "official") } |
    Sort-Object { [int]$_.stage })[-1].stage)
}

$local = ConvertFrom-TdfJavascript -Content (Get-Content -Raw -Encoding UTF8 -LiteralPath $DataPath)
$expectedStage = Get-LatestCompletedStage -Data $local
$expectedDate = [string]$local.meta.updatedAt

for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
  Write-Host "Production verification attempt $attempt of ${Attempts}: $ProductionDataUrl"
  try {
    $separator = if ($ProductionDataUrl.Contains('?')) { '&' } else { '?' }
    $content = (Invoke-WebRequest -Uri "$ProductionDataUrl${separator}verify=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" -UseBasicParsing -TimeoutSec 30 -Headers @{ "Cache-Control" = "no-cache" }).Content
    $remote = ConvertFrom-TdfJavascript -Content $content
    $remoteStage = Get-LatestCompletedStage -Data $remote
    $remoteDate = [string]$remote.meta.updatedAt

    if ($remoteStage -eq $expectedStage -and $remoteDate -eq $expectedDate) {
      Write-Host "Production deployment verified: stage $remoteStage, updated $remoteDate."
      exit 0
    }

    Write-Warning "Production is not current yet: stage $remoteStage / $remoteDate; expected stage $expectedStage / $expectedDate."
  } catch {
    Write-Warning "Production verification failed: $($_.Exception.Message)"
  }

  if ($attempt -lt $Attempts) { Start-Sleep -Seconds $DelaySeconds }
}

Write-Error "Production did not match local data after $Attempts attempts."
