param(
    [string]$OutDir = "$PSScriptRoot\..\assets\riders",
    [string[]]$Names
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$pages = @(
    @{ Name = "Tadej Pogacar"; Page = "Tadej_Poga%C4%8Dar"; CommonsFile = "" },
    @{ Name = "Jonas Vingegaard"; Page = "Jonas_Vingegaard"; CommonsFile = "" },
    @{ Name = "Remco Evenepoel"; Page = "Remco_Evenepoel"; CommonsFile = "" },
    @{ Name = "Primoz Roglic"; Page = "Primo%C5%BE_Rogli%C4%8D"; CommonsFile = "Primož Roglič 2017.jpg" },
    @{ Name = "Isaac del Toro"; Page = "Isaac_del_Toro"; CommonsFile = "" },
    @{ Name = "Paul Seixas"; Page = "Paul_Seixas"; CommonsFile = "Paul Seixas.jpg" },
    @{ Name = "Florian Lipowitz"; Page = "Florian_Lipowitz"; CommonsFile = "" },
    @{ Name = "Juan Ayuso"; Page = "Juan_Ayuso"; CommonsFile = "" },
    @{ Name = "Richard Carapaz"; Page = "Richard_Carapaz"; CommonsFile = "Richard Carapaz 2015.jpg" },
    @{ Name = "Mathieu van der Poel"; Page = "Mathieu_van_der_Poel"; CommonsFile = "Mathieu-van-der-poel-1360455287.jpg" },
    @{ Name = "Jasper Philipsen"; Page = "Jasper_Philipsen"; CommonsFile = "Jasper Philipsen 2023 (cropped).jpg" },
    @{ Name = "Mads Pedersen"; Page = "Mads_Pedersen"; CommonsFile = "Mads Pedersen (2020).jpg" },
    @{ Name = "Tim Merlier"; Page = "Tim_Merlier"; CommonsFile = "Tim Merlier.jpg" },
    @{ Name = "Biniam Girmay"; Page = "Biniam_Girmay"; CommonsFile = "Biniam Girmay Herentals 2022.jpg" },
    @{ Name = "Tom Pidcock"; Page = "Tom_Pidcock"; CommonsFile = "Tom Pidcock (2025) (cropped).jpg" },
    @{ Name = "Julian Alaphilippe"; Page = "Julian_Alaphilippe"; CommonsFile = "Julian Alaphilippe (48518120161).jpg" },
    @{ Name = "Ben Healy"; Page = "Ben_Healy"; CommonsFile = "2024 LBL start Ben Healy.jpg" },
    @{ Name = "Soren Waerenskjold"; Page = "S%C3%B8ren_W%C3%A6renskjold"; CommonsFile = "Søren Wærenskjold Tour de Belgique 2023.jpg" },
    @{ Name = "Olav Kooij"; Page = "Olav_Kooij"; CommonsFile = "Olav Kooij on the podium at the presentation ceremony for Stage 5 of the 2026 Tour de France.jpg" },
    @{ Name = "Alex Baudin"; Page = "Alex_Baudin"; CommonsFile = "Alex Baudin on the podium at the presentation ceremony for Stage 5 of the 2026 Tour de France.jpg" },
    @{ Name = "Mathias Vacek"; Page = "Mathias_Vacek"; CommonsFile = "Mathias Vacek on the podium at the presentation ceremony for Stage 5 of the 2026 Tour de France.jpg" },
    @{ Name = "Torstein Traeen"; Page = "Torstein_Tr%C3%A6en"; CommonsFile = "2023 LBL start Torstein Træen.jpg" },
    @{ Name = "Alex Molenaar"; Page = "Alex_Molenaar"; CommonsFile = "Alex Molenaar.JPG"; DirectUrl = "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f7/Alex_Molenaar.JPG/960px-Alex_Molenaar.JPG" },
    @{ Name = "Egan Bernal"; Page = "Egan_Bernal"; CommonsFile = "Egan Bernal KOERS 2019 01 (cropped).jpg"; DirectUrl = "https://upload.wikimedia.org/wikipedia/commons/6/6e/Egan_Bernal_KOERS_2019_01_%28cropped%29.jpg" }
)

if ($Names) {
    $pages = @($pages | Where-Object { $Names -contains $_.Name })
}

function Get-WikiSummary($page) {
    $summaryUrl = "https://en.wikipedia.org/api/rest_v1/page/summary/$page"
    return Invoke-RestMethod -Uri $summaryUrl -TimeoutSec 20 -Headers @{ "User-Agent" = "Codex Tour de France personal project" }
}

function Get-WikiSearchTitle($name) {
    $query = [uri]::EscapeDataString($name)
    $url = "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=$query&format=json&srlimit=1"
    $result = Invoke-RestMethod -Uri $url -TimeoutSec 20 -Headers @{ "User-Agent" = "Codex Tour de France personal project" }
    return $result.query.search[0].title
}

function Get-CommonsFileUrl($fileName) {
    $title = [uri]::EscapeDataString("File:$fileName")
    $url = "https://commons.wikimedia.org/w/api.php?action=query&prop=imageinfo&iiprop=url&iiurlwidth=900&titles=$title&format=json&formatversion=2"
    $result = Invoke-RestMethod -Uri $url -TimeoutSec 20 -Headers @{ "User-Agent" = "Codex Tour de France personal project" }
    return $result.query.pages[0].imageinfo[0].thumburl
}

$results = foreach ($p in $pages) {
    $safeName = ($p.Name.ToLowerInvariant() -replace '[^a-z0-9]+','-').Trim('-')
    $file = "$safeName.jpg"
    try {
        $thumb = ""
        $source = ""
        $page = ""

        if ($p.CommonsFile) {
            $thumb = if ($p.DirectUrl) { $p.DirectUrl } else { Get-CommonsFileUrl $p.CommonsFile }
            $source = "https://commons.wikimedia.org/wiki/File:$([uri]::EscapeDataString($p.CommonsFile).Replace('%20','_'))"
            $page = $p.CommonsFile
        }
        else {
            $summary = Get-WikiSummary $p.Page
            if (-not $summary.thumbnail.source) {
                $title = Get-WikiSearchTitle $p.Name
                if ($title) {
                    $summary = Get-WikiSummary ([uri]::EscapeDataString($title.Replace(' ', '_')))
                }
            }
            $thumb = $summary.thumbnail.source
            $source = $summary.content_urls.desktop.page
            $page = $summary.title
        }

        if ($thumb) {
            Invoke-WebRequest -Uri $thumb -OutFile (Join-Path $OutDir $file) -TimeoutSec 30 -Headers @{ "User-Agent" = "Codex Tour de France personal project" } | Out-Null
        }
        [pscustomobject]@{
            name = $p.Name
            page = $page
            image = $(if ($thumb) { "assets/riders/$file" } else { "" })
            source = $source
            thumb = $thumb
        }
    }
    catch {
        [pscustomobject]@{
            name = $p.Name
            page = ""
            image = ""
            source = "https://en.wikipedia.org/api/rest_v1/page/summary/$($p.Page)"
            thumb = ""
            error = $_.Exception.Message
        }
    }
}

$sourcesPath = Join-Path $OutDir "image-sources.json"
$existingResults = if (Test-Path -LiteralPath $sourcesPath) { @(Get-Content -Raw -Encoding UTF8 -LiteralPath $sourcesPath | ConvertFrom-Json) } else { @() }
$updatedNames = @($results | ForEach-Object { $_.name })
$mergedResults = @($existingResults | Where-Object { $_.name -notin $updatedNames }) + @($results)
$mergedResults | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $sourcesPath -Encoding UTF8
$results | Format-Table -AutoSize
