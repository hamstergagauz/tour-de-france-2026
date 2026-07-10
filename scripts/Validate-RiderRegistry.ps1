param(
  [string]$DataPath = "assets/data.js"
)

$ErrorActionPreference = "Stop"

function Read-TdfData {
  param([string]$Path)

  $raw = Get-Content -Raw -Encoding UTF8 -Path $Path
  $json = $raw -replace '^\s*window\.TDF_DATA\s*=\s*', ''
  $json = $json -replace ';\s*$', ''
  return $json | ConvertFrom-Json
}

$data = Read-TdfData -Path $DataPath
$validation = $data.riderValidation

if (-not $validation) {
  throw "riderValidation is missing. Run scripts/Update-StageResults.ps1 first."
}

Write-Host "Rider registry status: $($validation.status)"
Write-Host "Derived riders: $(@($validation.derivedRiders).Count)"
Write-Host "Fallback identity riders: $(@($validation.fallbackIdentityRiders).Count)"
Write-Host "Alias conflicts: $(@($validation.aliasConflicts).Count)"
Write-Host "Blocking issues: $(@($validation.blockingIssues).Count)"

if (@($validation.derivedRiders).Count) {
  Write-Host ""
  Write-Host "Derived riders:"
  @($validation.derivedRiders) |
    Sort-Object @{ Expression = { -1 * [int]($_.latestQualifyingStage) } }, name |
    ForEach-Object {
      Write-Host " - $($_.name) [$($_.id)] stage $($_.latestQualifyingStage) letour=$($_.letourId) reviewNeeded=$($_.reviewNeeded)"
    }
}

if (@($validation.aliasConflicts).Count) {
  Write-Host ""
  Write-Host "Alias conflicts:"
  @($validation.aliasConflicts) | ForEach-Object {
    $riders = @($_.riders | ForEach-Object { "$($_.name) [$($_.id)]" }) -join ", "
    Write-Host " - $($_.alias): $riders"
  }
}

if (@($validation.blockingIssues).Count) {
  Write-Host ""
  Write-Host "Blocking issues:"
  @($validation.blockingIssues) | ForEach-Object {
    Write-Host " - $($_.kind): $($_.message)"
  }
  exit 2
}

if ($validation.status -eq "review-needed") {
  Write-Warning "Rider registry needs review, but coverage is safe for daily updates."
  if (@($validation.fallbackIdentityRiders).Count) {
    Write-Host "Affected riders:"
    @($validation.fallbackIdentityRiders) | ForEach-Object {
      Write-Host " - $($_.name) [$($_.id)]"
    }
  }
  exit 0
}
