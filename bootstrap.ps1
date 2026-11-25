<#
.SYNOPSIS
    Prepares the ChatBI demo for offline development on Windows.

.DESCRIPTION
    Downloads the dependency bundle for this machine from the GitHub release,
    verifies its checksum, installs backend/.venv and frontend/node_modules,
    and prints the startup commands from guide.md.

.PARAMETER Tag
    Release tag that holds the dependency bundles. Default: deps-v1.

.PARAMETER Repair
    Rebuild backend/.venv from the local bundle. node_modules is restored from
    the bundled npm cache when it is missing.

.PARAMETER Force
    Download and extract the bundle again even if it is already present.

.PARAMETER Uninstall
    Remove the PATH entry that this script added. Files are left in place.

.PARAMETER LocalOnly
    Prepare an extracted workshop kit using its bundled dependencies and check
    the runtimes. Leaves the user PATH untouched.
#>
param(
    [string]$Tag = 'deps-v1',
    [switch]$Repair,
    [switch]$Force,
    [switch]$Uninstall,
    [switch]$LocalOnly
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = 'hhuang37/chatbi-demo'
$projectRoot = $PSScriptRoot
$backendRoot = Join-Path $projectRoot 'backend'
$frontendRoot = Join-Path $projectRoot 'frontend'
$offlineRoot = Join-Path $projectRoot '.offline'
$downloadRoot = Join-Path $projectRoot '.download-tmp'
$venvPython = Join-Path $backendRoot '.venv\Scripts\python.exe'
# Prefer the Windows bsdtar; Git for Windows puts a GNU tar on PATH that treats
# "D:\..." as a remote host.
$tarExe = Join-Path $env:SystemRoot 'System32\tar.exe'

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-Download {
    param([string]$Url, [string]$Destination)
    # Windows PowerShell 5.1 buffers Invoke-WebRequest downloads and is very slow
    # for large files; curl.exe ships with Windows 10 1803 and later.
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    if (Test-Path -LiteralPath $curl) {
        & $curl --fail --location --retry 3 --silent --show-error --output $Destination $Url
        if ($LASTEXITCODE -eq 0) { return }
    }
    try {
        Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
        return
    } catch { }
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
}

function Get-Platform {
    # PROCESSOR_ARCHITECTURE and RuntimeInformation report X64 on Windows ARM64
    # when the shell runs under x64 emulation, so ask WMI first.
    $processor = Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($processor) {
        switch ([int]$processor.Architecture) {
            12 { return 'win-arm64' }
            9 { return 'win-x64' }
            0 { throw 'This demo needs a 64-bit Windows installation.' }
        }
    }
    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    switch ($arch.ToString()) {
        'Arm64' { return 'win-arm64' }
        'X64' { return 'win-x64' }
        'X86' { throw 'This demo needs a 64-bit Windows installation.' }
        default { throw "Unsupported Windows architecture: $arch" }
    }
}

function Remove-PathEntry {
    $nodeDir = Join-Path $offlineRoot 'node'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { return $false }
    $pattern = '[\\/]\.offline[\\/]node[\\/]?$'
    $parts = @($userPath -split ';' | Where-Object { $_ -and ($_ -notmatch $pattern) })
    $newPath = ($parts -join ';')
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    return $true
}

try {
    if ($LocalOnly -and ($Force -or $Uninstall)) {
        throw 'Use -LocalOnly with -Repair to rebuild a workshop kit from its bundled dependencies.'
    }

    if ($Uninstall) {
        Write-Step 'Removing the bundled Node.js entry from your user PATH'
        [void](Remove-PathEntry)
        Write-Host 'Done. Open a new terminal for the change to take effect.'
        Write-Host 'You can delete .offline, backend\.venv and frontend\node_modules to reclaim disk space.'
        exit 0
    }

    $platform = Get-Platform
    $versionSuffix = $Tag -replace '^deps-', ''
    $assetName = "chatbi-deps-$platform-$versionSuffix.zip"
    Write-Step "Platform: $platform"
    if (-not $LocalOnly) {
        Write-Step "Dependency bundle: $assetName (release $Tag)"
    }

    $manifestPath = Join-Path $offlineRoot 'manifest.json'
    $needBundle = $true
    if ((-not $Force) -and (Test-Path -LiteralPath $manifestPath)) {
        $needBundle = $false
        Write-Step 'Using the dependency bundle already in .offline'
    }

    if ($LocalOnly) {
        if ($needBundle) { throw 'The kit is missing .offline\manifest.json. Extract the full workshop ZIP again.' }
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.platform -ne $platform) {
            throw "This kit is for $($manifest.platform). Download the $platform workshop ZIP."
        }
        foreach ($entry in @('node\node.exe', 'node\npm.cmd', 'python\python.exe', 'wheels', 'npm-cache')) {
            if (-not (Test-Path -LiteralPath (Join-Path $offlineRoot $entry))) {
                throw "The kit is missing .offline\$entry. Extract the full workshop ZIP again."
            }
        }
    }

    if ($needBundle) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $baseUrl = "https://github.com/$repo/releases/download/$Tag"
        if (Test-Path -LiteralPath $downloadRoot) { Remove-Item -LiteralPath $downloadRoot -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $downloadRoot | Out-Null
        $zipPath = Join-Path $downloadRoot $assetName
        $sumsPath = Join-Path $downloadRoot 'SHA256SUMS'

        Write-Step "Downloading $baseUrl/$assetName"
        Invoke-Download -Url "$baseUrl/$assetName" -Destination $zipPath
        Invoke-Download -Url "$baseUrl/SHA256SUMS" -Destination $sumsPath

        Write-Step 'Verifying the SHA256 checksum'
        $line = Get-Content -LiteralPath $sumsPath | Where-Object { $_ -match [regex]::Escape($assetName) } | Select-Object -First 1
        if (-not $line) { throw "SHA256SUMS does not list $assetName" }
        $expected = ($line -split '\s+')[0].ToLowerInvariant()
        $actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($expected -ne $actual) {
            throw "Checksum mismatch for ${assetName}: expected $expected, got $actual"
        }

        Write-Step 'Extracting the bundle'
        $tmpDir = Join-Path $downloadRoot 'extract'
        New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
        $extracted = $false
        if (Test-Path -LiteralPath $tarExe) {
            Push-Location $tmpDir
            try {
                & $tarExe -xf $zipPath
                $extracted = ($LASTEXITCODE -eq 0)
            } finally {
                Pop-Location
            }
        }
        if (-not $extracted) {
            Expand-Archive -LiteralPath $zipPath -DestinationPath $tmpDir -Force
        }

        if (Test-Path -LiteralPath $offlineRoot) { Remove-Item -LiteralPath $offlineRoot -Recurse -Force }
        New-Item -ItemType Directory -Path $offlineRoot | Out-Null

        foreach ($name in @('node', 'python', 'wheels', 'npm-cache')) {
            $src = Join-Path $tmpDir $name
            if (Test-Path -LiteralPath $src) {
                Move-Item -LiteralPath $src -Destination (Join-Path $offlineRoot $name)
            }
        }
        $manifestSrc = Join-Path $tmpDir 'manifest.json'
        if (Test-Path -LiteralPath $manifestSrc) {
            Move-Item -LiteralPath $manifestSrc -Destination $manifestPath
        }

        $nodeModulesSrc = Join-Path $tmpDir 'node_modules'
        $nodeModulesDst = Join-Path $frontendRoot 'node_modules'
        if (Test-Path -LiteralPath $nodeModulesSrc) {
            if (Test-Path -LiteralPath $nodeModulesDst) { Remove-Item -LiteralPath $nodeModulesDst -Recurse -Force }
            Move-Item -LiteralPath $nodeModulesSrc -Destination $nodeModulesDst
        }

        Remove-Item -LiteralPath $tmpDir -Recurse -Force
        Remove-Item -LiteralPath $downloadRoot -Recurse -Force

        Write-Step 'Unblocking downloaded binaries'
        Get-ChildItem -LiteralPath $offlineRoot -Recurse -File | Where-Object {
            @('.exe', '.dll', '.pyd', '.cmd', '.bat', '.ps1') -contains $_.Extension.ToLowerInvariant()
        } | ForEach-Object { Unblock-File -LiteralPath $_.FullName }
    }

    $offlinePython = Join-Path $offlineRoot 'python\python.exe'
    if (-not (Test-Path -LiteralPath $offlinePython)) {
        throw 'The bundle does not contain python\python.exe. Run again with -Force.'
    }

    Write-Step 'Configuring the offline npm cache'
    $cacheValue = (Join-Path $offlineRoot 'npm-cache') -replace '\\', '/'
    $npmrcLines = @(
        "cache=$cacheValue",
        'prefer-offline=true',
        'audit=false',
        'fund=false'
    )
    [IO.File]::WriteAllLines((Join-Path $frontendRoot '.npmrc'), [string[]]$npmrcLines)

    $venvOk = $false
    if ((Test-Path -LiteralPath $venvPython) -and (-not $Repair)) {
        & $venvPython -c "import sys" 2>$null
        $venvOk = ($LASTEXITCODE -eq 0)
    }
    if (-not $venvOk) {
        Write-Step 'Creating backend\.venv from the bundled Python'
        $venvRoot = Join-Path $backendRoot '.venv'
        if (Test-Path -LiteralPath $venvRoot) { Remove-Item -LiteralPath $venvRoot -Recurse -Force }
        & $offlinePython -m venv $venvRoot
        if ($LASTEXITCODE -ne 0) { throw "Could not create backend\.venv (exit code $LASTEXITCODE)" }
    }

    Write-Step 'Installing backend packages from the local wheelhouse'
    $constraints = Join-Path $projectRoot 'offline\constraints.txt'
    $pipArgs = @('-m', 'pip', 'install', '--no-index', '--disable-pip-version-check',
        '--find-links', (Join-Path $offlineRoot 'wheels'))
    if (Test-Path -LiteralPath $constraints) { $pipArgs += @('-c', $constraints) }
    $pipArgs += @('-r', (Join-Path $backendRoot 'requirements.txt'))
    & $venvPython @pipArgs
    if ($LASTEXITCODE -ne 0) { throw "pip install failed with exit code $LASTEXITCODE" }

    $nodeDir = Join-Path $offlineRoot 'node'
    $nodeModules = Join-Path $frontendRoot 'node_modules'
    if (-not (Test-Path -LiteralPath $nodeModules)) {
        Write-Step 'Restoring frontend\node_modules from the bundled npm cache'
        Push-Location $frontendRoot
        try {
            & (Join-Path $nodeDir 'npm.cmd') ci --offline
            if ($LASTEXITCODE -ne 0) { throw "npm ci --offline failed with exit code $LASTEXITCODE" }
        } finally {
            Pop-Location
        }
    }

    $envPath = Join-Path $backendRoot '.env'
    if (-not (Test-Path -LiteralPath $envPath)) {
        Copy-Item -LiteralPath (Join-Path $backendRoot '.env.example') -Destination $envPath
        Write-Step 'Created backend\.env from the template'
    }

    if ($LocalOnly) {
        Write-Step 'Checking the bundled Python and frontend dependencies'
        & $venvPython -I -c "import sys, sqlite3, fastapi, uvicorn; assert hasattr(sqlite3.Connection, 'setlimit'); print(sys.version.split()[0])"
        if ($LASTEXITCODE -ne 0) { throw 'The prepared Python environment failed its import check.' }
        if (-not (Test-Path -LiteralPath (Join-Path $nodeModules 'echarts\package.json'))) {
            throw 'ECharts is missing. Extract the full workshop ZIP again.'
        }
        & (Join-Path $nodeDir 'node.exe') (Join-Path $nodeModules 'vite\bin\vite.js') --version
        if ($LASTEXITCODE -ne 0) { throw 'Vite could not run with the bundled Node.js.' }
        Write-Host 'Setup complete. No services were started.' -ForegroundColor Green
        Write-Host 'Follow Step 0 in guide.md to start the backend and frontend in two PowerShell terminals.'
        exit 0
    }

    $systemNode = Get-Command node -ErrorAction SilentlyContinue
    $addToPath = $false
    $prepend = $false
    if (-not $systemNode) {
        $addToPath = $true
    } else {
        $versionText = (& node --version) 2>$null
        if ($versionText -match '^v(\d+)') {
            if ([int]$Matches[1] -lt 20) {
                $addToPath = $true
                $prepend = $true
            }
        } else {
            $addToPath = $true
        }
    }

    $sessionHint = '$env:Path = "' + $nodeDir + ';$env:Path"'
    if ($addToPath) {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $entry = $nodeDir.TrimEnd('\')
        $already = $false
        if ($userPath) {
            $already = ($userPath -split ';' | Where-Object { $_.TrimEnd('\') -eq $entry }).Count -gt 0
        }
        if (-not $already) {
            $newPath = if ($prepend) { "$entry;$userPath" } else { "$userPath;$entry" }
            [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
            Write-Step 'Added the bundled Node.js to your user PATH'
            Write-Host '    Open a new terminal (restart your IDE) for that change to take effect.'
            Write-Host "    For this window only: $sessionHint"
        }
    }

    Write-Host ''
    if (-not (Test-Path -LiteralPath $venvPython)) {
        throw 'backend\.venv is missing after setup.'
    }
    Write-Host 'Setup complete. No services were started.' -ForegroundColor Green
    Write-Host ''
    Write-Host 'Next: edit backend\.env with your MaaS endpoint, token and model, then start both services.'
    Write-Host ''
    Write-Host '  Terminal 1 (backend):'
    Write-Host '    cd backend'
    Write-Host '    .\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload'
    Write-Host ''
    Write-Host '  Terminal 2 (frontend):'
    Write-Host '    cd frontend'
    Write-Host '    npm run dev -- --port 5173 --strictPort'
    Write-Host ''
    Write-Host 'Then open the address printed by Vite. See guide.md for details.'
} catch {
    Write-Error $_
    exit 1
}
