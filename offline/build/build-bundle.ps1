<#
.SYNOPSIS
    Builds the offline dependency bundle for one Windows platform.

.DESCRIPTION
    Downloads the pinned Node.js and CPython runtimes, resolves the backend
    wheels, installs node_modules, runs the project checks, then assembles and
    verifies dist/chatbi-deps-<platform>-<version>.zip.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('win-arm64', 'win-x64')]
    [string]$Platform,
    [string]$Version = 'v1'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$build = Join-Path $root ".build\bundle-$Platform"
$downloads = Join-Path $root '.build\downloads'
$nodeDir = Join-Path $build 'node'
$pythonDir = Join-Path $build 'python'
$wheelDir = Join-Path $build 'wheels'
$venvDir = Join-Path $build 'venv'
$npmCacheDir = Join-Path $build 'npm-cache'
$stage = Join-Path $build "stage-$Platform"
$verify = Join-Path $build "verify-$Platform"
$dist = Join-Path $root 'dist'
$zipPath = Join-Path $dist "chatbi-deps-$Platform-$Version.zip"
# Use the Windows bsdtar explicitly: Git for Windows ships a GNU tar earlier on
# PATH that treats "D:\..." as a remote host.
$tarExe = Join-Path $env:SystemRoot 'System32\tar.exe'

New-Item -ItemType Directory -Force -Path $build, $downloads, $dist | Out-Null

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-PinnedAsset {
    param($Entry)
    $path = Join-Path $downloads $Entry.file
    if (-not (Test-Path -LiteralPath $path)) {
        Write-Step "Downloading $($Entry.file)"
        Invoke-WebRequest -Uri $Entry.url -OutFile $path -UseBasicParsing
    }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $Entry.sha256.ToLowerInvariant()) {
        throw "Checksum mismatch for $($Entry.file): $hash"
    }
    return $path
}

function Expand-ZipArchive {
    param([string]$Path, [string]$Destination)
    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    if (Test-Path -LiteralPath $tarExe) {
        & $tarExe -xf $Path -C $Destination
        if ($LASTEXITCODE -eq 0) { return }
        Remove-Item -LiteralPath $Destination -Recurse -Force
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    }
    Expand-Archive -LiteralPath $Path -DestinationPath $Destination -Force
}

$config = Get-Content -LiteralPath (Join-Path $root 'offline\runtimes.json') -Raw | ConvertFrom-Json
$nodeAsset = $config.node.assets.$Platform
$pythonAsset = $config.python.assets.$Platform
if (-not $nodeAsset) { throw "runtimes.json has no Node.js asset for $Platform" }
if (-not $pythonAsset) { throw "runtimes.json has no Python asset for $Platform" }

if (-not (Test-Path -LiteralPath (Join-Path $nodeDir 'node.exe'))) {
    $nodeZip = Get-PinnedAsset -Entry $nodeAsset
    Write-Step 'Extracting Node.js'
    $tmp = Join-Path $build 'node-extract'
    Expand-ZipArchive -Path $nodeZip -Destination $tmp
    $inner = Get-ChildItem -LiteralPath $tmp -Directory | Select-Object -First 1
    if (-not $inner) { throw 'The Node.js archive has an unexpected layout.' }
    if (Test-Path -LiteralPath $nodeDir) { Remove-Item -LiteralPath $nodeDir -Recurse -Force }
    Move-Item -LiteralPath $inner.FullName -Destination $nodeDir
    Remove-Item -LiteralPath $tmp -Recurse -Force
}

if (-not (Test-Path -LiteralPath (Join-Path $pythonDir 'python.exe'))) {
    $pythonTar = Get-PinnedAsset -Entry $pythonAsset
    Write-Step 'Extracting CPython'
    $tmp = Join-Path $build 'python-extract'
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    & $tarExe -xzf $pythonTar -C $tmp
    if ($LASTEXITCODE -ne 0) { throw "tar.exe failed with exit code $LASTEXITCODE" }
    $inner = Join-Path $tmp 'python'
    if (-not (Test-Path -LiteralPath (Join-Path $inner 'python.exe'))) { throw 'The CPython archive has an unexpected layout.' }
    if (Test-Path -LiteralPath $pythonDir) { Remove-Item -LiteralPath $pythonDir -Recurse -Force }
    Move-Item -LiteralPath $inner -Destination $pythonDir
    Remove-Item -LiteralPath $tmp -Recurse -Force
}

Write-Step 'Downloading the backend wheelhouse'
if (Test-Path -LiteralPath $wheelDir) { Remove-Item -LiteralPath $wheelDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $wheelDir | Out-Null
& (Join-Path $pythonDir 'python.exe') -m pip download `
    -r (Join-Path $root 'backend\requirements.txt') `
    -c (Join-Path $root 'offline\constraints.txt') `
    --only-binary=:all: --disable-pip-version-check `
    -d $wheelDir
if ($LASTEXITCODE -ne 0) { throw "pip download failed with exit code $LASTEXITCODE" }

$env:Path = "$nodeDir;$env:Path"
# Keep the cache isolated so the bundle ships only the packages this build fetched.
if (Test-Path -LiteralPath $npmCacheDir) { Remove-Item -LiteralPath $npmCacheDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $npmCacheDir | Out-Null
$env:npm_config_cache = $npmCacheDir

Write-Step 'Installing node_modules and running the frontend build'
Push-Location (Join-Path $root 'frontend')
try {
    & (Join-Path $nodeDir 'npm.cmd') ci
    if ($LASTEXITCODE -ne 0) { throw "npm ci failed with exit code $LASTEXITCODE" }
    & (Join-Path $nodeDir 'npm.cmd') run build
    if ($LASTEXITCODE -ne 0) { throw "npm run build failed with exit code $LASTEXITCODE" }
    $npmCache = $npmCacheDir
} finally {
    Pop-Location
}

Write-Step 'Running backend tests with the bundled Python'
if (Test-Path -LiteralPath $venvDir) { Remove-Item -LiteralPath $venvDir -Recurse -Force }
& (Join-Path $pythonDir 'python.exe') -m venv $venvDir
if ($LASTEXITCODE -ne 0) { throw 'Could not create the smoke-test virtual environment.' }
$venvPython = Join-Path $venvDir 'Scripts\python.exe'
& $venvPython -m pip install --no-index --disable-pip-version-check `
    --find-links $wheelDir -c (Join-Path $root 'offline\constraints.txt') `
    -r (Join-Path $root 'backend\requirements.txt')
if ($LASTEXITCODE -ne 0) { throw "pip install failed with exit code $LASTEXITCODE" }
Push-Location (Join-Path $root 'backend')
try {
    & $venvPython -m pytest -q
    if ($LASTEXITCODE -ne 0) { throw "pytest failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

Write-Step 'Assembling the bundle'
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item -LiteralPath $nodeDir -Destination (Join-Path $stage 'node') -Recurse
Copy-Item -LiteralPath $pythonDir -Destination (Join-Path $stage 'python') -Recurse
Copy-Item -LiteralPath $wheelDir -Destination (Join-Path $stage 'wheels') -Recurse
Copy-Item -LiteralPath (Join-Path $root 'frontend\node_modules') -Destination (Join-Path $stage 'node_modules') -Recurse
Copy-Item -LiteralPath $npmCache -Destination (Join-Path $stage 'npm-cache') -Recurse

$echartsVersion = (Get-Content -LiteralPath (Join-Path $root 'frontend\node_modules\echarts\package.json') -Raw | ConvertFrom-Json).version
$manifest = [ordered]@{
    platform = $Platform
    node = $config.node.version
    python = $config.python.version
    echarts = $echartsVersion
    constraints = 'offline/constraints.txt'
    built = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stage 'manifest.json') -Encoding ASCII

Write-Step 'Creating the zip archive'
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
$sevenZipPath = $null
$sevenZipCommand = Get-Command 7z.exe -ErrorAction SilentlyContinue
if ($sevenZipCommand) {
    $sevenZipPath = $sevenZipCommand.Source
} else {
    $candidate = 'C:\Program Files\7-Zip\7z.exe'
    if (Test-Path -LiteralPath $candidate) { $sevenZipPath = $candidate }
}
if ($sevenZipPath) {
    Push-Location $stage
    try {
        & $sevenZipPath a -tzip -mx=6 $zipPath '.\*' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "7z failed with exit code $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
} else {
    Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zipPath -CompressionLevel Optimal
}

Write-Step 'Verifying the archive from a clean extraction'
Expand-ZipArchive -Path $zipPath -Destination $verify

$verifiedPython = Join-Path $verify 'python\python.exe'
& $verifiedPython -c "import sqlite3, sys; print(sys.version.split()[0]); sys.exit(0 if hasattr(sqlite3.Connection, 'setlimit') else 1)"
if ($LASTEXITCODE -ne 0) { throw 'The bundled Python is missing sqlite3.Connection.setlimit.' }

$verifyVenv = Join-Path $verify 'venv'
& $verifiedPython -m venv $verifyVenv
$verifyVenvPython = Join-Path $verifyVenv 'Scripts\python.exe'
& $verifyVenvPython -m pip install --no-index --disable-pip-version-check `
    --find-links (Join-Path $verify 'wheels') -c (Join-Path $root 'offline\constraints.txt') `
    -r (Join-Path $root 'backend\requirements.txt')
if ($LASTEXITCODE -ne 0) { throw 'The extracted wheelhouse does not install.' }
Push-Location (Join-Path $root 'backend')
try {
    & $verifyVenvPython -m pytest -q
    if ($LASTEXITCODE -ne 0) { throw 'pytest failed against the extracted bundle.' }
} finally {
    Pop-Location
}

$env:NODE_PATH = Join-Path $verify 'node_modules'
& (Join-Path $verify 'node\node.exe') -e "const esbuild = require('esbuild'); if (!esbuild.version) { process.exit(1) } console.log('esbuild', esbuild.version)"
if ($LASTEXITCODE -ne 0) { throw 'esbuild cannot load from the extracted node_modules.' }
& (Join-Path $verify 'node\node.exe') (Join-Path $verify 'node_modules\vite\bin\vite.js') --version
if ($LASTEXITCODE -ne 0) { throw 'vite cannot start from the extracted node_modules.' }
if (-not (Test-Path -LiteralPath (Join-Path $verify 'node_modules\echarts\package.json'))) {
    throw 'echarts is missing from the extracted node_modules.'
}

# node.exe can still hold a handle for a moment after the version check.
for ($attempt = 0; $attempt -lt 5; $attempt++) {
    try {
        Remove-Item -LiteralPath $verify -Recurse -Force -ErrorAction Stop
        break
    } catch {
        if ($attempt -eq 4) {
            Write-Warning "Could not remove $verify; the bundle itself is ready."
        } else {
            Start-Sleep -Seconds 2
        }
    }
}

$sizeMb = [math]::Round((Get-Item -LiteralPath $zipPath).Length / 1MB, 1)
Write-Step "Bundle ready: $zipPath ($sizeMb MB)"
