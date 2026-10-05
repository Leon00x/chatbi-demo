param([string]$Python = '')

$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$backendRoot = Join-Path $projectRoot 'backend'
$venvPython = Join-Path $backendRoot '.venv\Scripts\python.exe'

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed with exit code $LASTEXITCODE. Check the message above."
    }
}

try {
    $npmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if (-not $npmCommand) { throw 'Install Node.js with npm, then run this script again.' }
    Invoke-Checked -Program 'node' -Arguments @('--version')

    if (Test-Path -LiteralPath $venvPython) {
        Write-Host 'Reusing backend/.venv.'
    } else {
        if ($Python) {
            $pythonCommand = $Python
            $pythonPrefix = @()
        } elseif (Get-Command py -ErrorAction SilentlyContinue) {
            $pythonCommand = 'py'
            $pythonPrefix = @('-3')
        } elseif (Get-Command python -ErrorAction SilentlyContinue) {
            $pythonCommand = 'python'
            $pythonPrefix = @()
        } else {
            throw 'Install Python with venv support, then run this script again.'
        }
        Invoke-Checked -Program $pythonCommand -Arguments ($pythonPrefix + @('-m', 'venv', (Join-Path $backendRoot '.venv')))
    }

    # Check the SQLite safety interface used by the backend, rather than pinning a runtime release.
    Invoke-Checked -Program $venvPython -Arguments @('-c', "import sqlite3, sys; print(sys.version.split()[0]); sys.exit(0 if hasattr(sqlite3.Connection, 'setlimit') else 'This backend needs sqlite3.Connection.setlimit (Python 3.11+). Choose a compatible Python and recreate backend/.venv.')")

    $envPath = Join-Path $backendRoot '.env'
    if (-not (Test-Path -LiteralPath $envPath)) {
        Copy-Item -LiteralPath (Join-Path $backendRoot '.env.example') -Destination $envPath
        Write-Host 'Created backend/.env from the template.'
    } else { Write-Host 'Keeping existing backend/.env.' }

    & $venvPython -c "import importlib.util, sys; sys.exit(0 if importlib.util.find_spec('pip') else 1)"
    if ($LASTEXITCODE -ne 0) { Invoke-Checked -Program $venvPython -Arguments @('-m', 'ensurepip') }
    Invoke-Checked -Program $venvPython -Arguments @('-m', 'pip', 'install', '-r', (Join-Path $backendRoot 'requirements.txt'))

    Push-Location (Join-Path $projectRoot 'frontend')
    try {
        if (Test-Path -LiteralPath 'package-lock.json') {
            Invoke-Checked -Program $npmCommand.Source -Arguments @('ci')
        } else { Invoke-Checked -Program $npmCommand.Source -Arguments @('install') }
    } finally { Pop-Location }

    Write-Host 'Setup complete. No services were started.'
    Write-Host 'Edit backend/.env with your MaaS endpoint, token and model, then follow guide.md to start manually.'
    Write-Host 'After manual startup, open the frontend URL printed by Vite. See guide.md for default commands and addresses.'
} catch {
    Write-Error $_
    exit 1
}
