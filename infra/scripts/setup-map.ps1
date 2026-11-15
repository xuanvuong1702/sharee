param(
    [string]$Region = "vietnam"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$mapDir = Join-Path $root "infra\maps"
$dataDir = Join-Path $mapDir "data"
$pbf = Join-Path $mapDir "$Region-latest.osm.pbf"

New-Item -ItemType Directory -Force $dataDir | Out-Null

if (-not (Test-Path $pbf)) {
    $url = "https://download.geofabrik.de/asia/$Region-latest.osm.pbf"
    Write-Host "Downloading $url ..."
    Invoke-WebRequest -Uri $url -OutFile $pbf
}

Push-Location $mapDir
try {
    $marker = Join-Path $dataDir ".imported"
    if (-not (Test-Path $marker)) {
        Write-Host "Importing OSM extract (first run, 10-20 minutes) ..."
        docker compose run --rm tile-server import
        New-Item -ItemType File -Force $marker | Out-Null
    }
    docker compose up -d
    Write-Host "Tile server: http://localhost:8082/tile/{z}/{x}/{y}.png"
}
finally {
    Pop-Location
}
