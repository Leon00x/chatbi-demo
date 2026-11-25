#Requires -Version 5.1
#Requires -PSEdition Desktop

param(
    [Parameter(Mandatory = $true)]
    [string]$BundleZip,
    [Parameter(Mandatory = $true)]
    [ValidateSet('win-x64', 'win-arm64')]
    [string]$Platform
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Assert-PortFree {
    param([int]$Port)
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $Port)
    try {
        $listener.ExclusiveAddressUse = $true
        $listener.Start()
    } catch {
        throw "Cannot bind 127.0.0.1:${Port}. Free the port before running acceptance. $($_.Exception.Message)"
    } finally {
        $listener.Stop()
    }
}

function Get-LocalResponse {
    param([string]$Url)
    $request = [Net.WebRequest]::CreateHttp($Url)
    $request.Proxy = $null
    $request.AllowAutoRedirect = $false
    $request.Timeout = 2000
    $request.ReadWriteTimeout = 2000
    $response = $request.GetResponse()
    try {
        if ($response.StatusCode -ne [Net.HttpStatusCode]::OK) {
            throw "Unexpected HTTP status $([int]$response.StatusCode) from $Url."
        }
        $reader = [IO.StreamReader]::new($response.GetResponseStream(), [Text.Encoding]::UTF8)
        try {
            return $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
    } finally {
        $response.Dispose()
    }
}

function Wait-LocalResponse {
    param([Diagnostics.Process]$Process, [string]$Url)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $lastError = ''
    while ($timer.Elapsed.TotalSeconds -lt 60) {
        if ($Process.HasExited) {
            throw "Process $($Process.Id) exited with code $($Process.ExitCode) while waiting for $Url."
        }
        try {
            return Get-LocalResponse -Url $Url
        } catch {
            $lastError = $_.Exception.Message
            Start-Sleep -Milliseconds 400
        }
    }
    throw "Timed out waiting for $Url. $lastError"
}

function Stop-LabProcess {
    param([Diagnostics.Process]$Process)
    if ($null -eq $Process) { return }
    try {
        if (-not $Process.HasExited) {
            # The Windows venv launcher, Uvicorn reloader, and npm can spawn children.
            $killer = Start-Process -FilePath $taskkillExe -ArgumentList '/F', '/T', '/PID', $Process.Id `
                -NoNewWindow -Wait -PassThru
            try {
                if ($killer.ExitCode -ne 0 -and -not $Process.HasExited) {
                    throw "taskkill exited with code $($killer.ExitCode) for PID $($Process.Id)."
                }
            } finally {
                $killer.Dispose()
            }
        }
    } finally {
        $Process.Dispose()
    }
}

$processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$nativePlatform = switch ([int]$processor.Architecture) {
    9 { 'win-x64' }
    12 { 'win-arm64' }
    default { throw "Unsupported native processor architecture $($processor.Architecture)." }
}
if ($Platform -ne $nativePlatform) {
    throw "Platform $Platform requires a native $Platform host. This host is $nativePlatform."
}

$zip = (Resolve-Path -LiteralPath $BundleZip).Path
$system32 = Join-Path $env:SystemRoot 'System32'
$powershellExe = Join-Path $system32 'WindowsPowerShell\v1.0\powershell.exe'
$cmdExe = Join-Path $system32 'cmd.exe'
$taskkillExe = Join-Path $system32 'taskkill.exe'
$originalUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('lab ' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$originalEnvironment = @{}
$backendProcess = $null
$frontendProcess = $null

Assert-PortFree -Port 8000
Assert-PortFree -Port 5173
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    Write-Host "Extracting $zip into $scratch"
    Expand-Archive -LiteralPath $zip -DestinationPath $scratch
    $topLevel = @(Get-ChildItem -LiteralPath $scratch -Force)
    if ($topLevel.Count -ne 1 -or -not $topLevel[0].PSIsContainer) {
        throw 'The lab ZIP must contain a single project directory.'
    }
    $project = $topLevel[0].FullName
    foreach ($name in @('.env', '.venv')) {
        $unexpected = Get-ChildItem -LiteralPath $project -Recurse -Force -Filter $name | Select-Object -First 1
        if ($unexpected) { throw "The fresh lab ZIP contains $($unexpected.FullName)." }
    }
    $manifest = Get-Content -LiteralPath (Join-Path $project '.offline\lab-manifest.json') -Raw | ConvertFrom-Json
    if ($manifest.platform -ne $Platform -or $manifest.dependencyRelease -ne 'deps-v1') {
        throw "Unexpected lab manifest platform or dependency release for $Platform."
    }

    # Child processes get only the Windows search paths until setup has finished.
    # Block network package resolution while allowing loopback service checks.
    $environment = @{
        Path = "$system32;$env:SystemRoot;$(Split-Path -Parent $powershellExe)"
        HTTP_PROXY = 'http://127.0.0.1:1'
        HTTPS_PROXY = 'http://127.0.0.1:1'
        ALL_PROXY = 'http://127.0.0.1:1'
        NO_PROXY = '127.0.0.1,localhost,::1'
        PIP_CONFIG_FILE = 'NUL'
        PIP_NO_INDEX = '1'
        PIP_NO_CACHE_DIR = '1'
        npm_config_offline = 'true'
        npm_config_userconfig = (Join-Path $scratch 'user.npmrc')
        npm_config_globalconfig = (Join-Path $scratch 'global.npmrc')
        NODE_PATH = $null
        NODE_OPTIONS = $null
        PYTHONHOME = $null
        PYTHONPATH = $null
        PYTHONNOUSERSITE = '1'
        VIRTUAL_ENV = $null
        MAAS_API_KEY = $null
        MAAS_BASE_URL = $null
        MAAS_MODEL = $null
        SCENARIO = $null
        DATABASE_URL = $null
        CORS_ORIGINS = $null
    }
    foreach ($name in $environment.Keys) {
        $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, $environment[$name], 'Process')
    }
    $runtimeCommands = Get-Command -Name @('python', 'python3', 'py', 'node', 'npm.cmd') `
        -CommandType Application -ErrorAction SilentlyContinue
    if ($runtimeCommands) { throw "Installed runtimes still resolve on the sanitized PATH: $runtimeCommands" }

    Write-Host 'Running the guide setup command with bundled dependencies'
    Push-Location -LiteralPath $project
    try {
        & $powershellExe -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -LocalOnly
        $setupExitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($originalUserPath -cne [Environment]::GetEnvironmentVariable('Path', 'User')) {
        throw 'The user PATH changed during setup.'
    }
    if ($setupExitCode -ne 0) { throw "Setup failed with exit code $setupExitCode." }

    $backend = Join-Path $project 'backend'
    $frontend = Join-Path $project 'frontend'
    $venvPython = Join-Path $backend '.venv\Scripts\python.exe'
    $nodeDir = Join-Path $project '.offline\node'
    $npm = Join-Path $nodeDir 'npm.cmd'
    $env:Path = "$nodeDir;$env:Path"

    Push-Location -LiteralPath $backend
    try {
        & $venvPython -m pytest -q
        if ($LASTEXITCODE -ne 0) { throw "pytest failed with exit code $LASTEXITCODE." }
    } finally {
        Pop-Location
    }
    Push-Location -LiteralPath $frontend
    try {
        & $npm run build
        if ($LASTEXITCODE -ne 0) { throw "npm run build failed with exit code $LASTEXITCODE." }
    } finally {
        Pop-Location
    }

    Write-Host 'Starting both services using the guide commands'
    Assert-PortFree -Port 8000
    Assert-PortFree -Port 5173
    $backendProcess = Start-Process -FilePath $venvPython -WorkingDirectory $backend `
        -ArgumentList '-m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload' `
        -RedirectStandardOutput (Join-Path $scratch 'backend.stdout.log') `
        -RedirectStandardError (Join-Path $scratch 'backend.stderr.log') -PassThru
    $frontendProcess = Start-Process -FilePath $cmdExe -WorkingDirectory $frontend `
        -ArgumentList '/d /c npm.cmd run dev -- --port 5173 --strictPort' `
        -RedirectStandardOutput (Join-Path $scratch 'frontend.stdout.log') `
        -RedirectStandardError (Join-Path $scratch 'frontend.stderr.log') -PassThru

    $health = Wait-LocalResponse -Process $backendProcess -Url 'http://127.0.0.1:8000/api/health' | ConvertFrom-Json
    if ($health.status -ne 'ok' -or $health.maas.state -ne 'missing_key') {
        throw 'The backend did not report a ready environment with the default MaaS configuration.'
    }
    $scenario = Wait-LocalResponse -Process $frontendProcess -Url 'http://127.0.0.1:5173/api/scenario' | ConvertFrom-Json
    if ($scenario.id -ne 'sg-retail') { throw 'Vite returned an unexpected scenario from the backend.' }
    $html = Get-LocalResponse -Url 'http://127.0.0.1:5173/'
    $title = 'Lion City ' + [char]0x00B7 + ' ChatBI'
    if (-not $html.Contains("<title>$title</title>")) { throw 'The frontend page title was unexpected.' }
} catch {
    Get-ChildItem -LiteralPath $scratch -File -Filter '*.log' | ForEach-Object {
        Write-Host "--- $($_.Name) ---"
        Get-Content -LiteralPath $_.FullName -Tail 30 | Write-Host
    }
    throw
} finally {
    try {
        try {
            Stop-LabProcess -Process $frontendProcess
        } finally {
            Stop-LabProcess -Process $backendProcess
        }
    } finally {
        foreach ($name in $originalEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], 'Process')
        }
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}

Write-Host "Lab ZIP acceptance passed on native $Platform."
