param([string]$Python = '')

# The online installer is replaced by the offline bootstrap. guide.md keeps
# calling setup.ps1, so this file stays as the documented entry point.
$ErrorActionPreference = 'Stop'
$bootstrap = Join-Path $PSScriptRoot 'bootstrap.ps1'
if (-not (Test-Path -LiteralPath $bootstrap)) {
    throw 'bootstrap.ps1 is missing. Restore it from the repository.'
}
& $bootstrap
exit $LASTEXITCODE
