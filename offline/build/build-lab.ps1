<#
.SYNOPSIS
    Packages the committed workshop source and a verified Windows dependency ZIP.

.DESCRIPTION
    Run for each Windows platform with the corresponding deps-v1 release asset.
    The source is archived from HEAD. Tag that same commit for the release.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('win-arm64', 'win-x64')]
    [string]$Platform,
    [Parameter(Mandatory = $true)]
    [string]$DependencyZip,
    [ValidatePattern('^lab-v\d+(\.\d+)*$')]
    [string]$Tag = 'lab-v1',
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$tarExe = Join-Path $env:SystemRoot 'System32\tar.exe'
$dependencyPath = (Resolve-Path -LiteralPath $DependencyZip).Path
$dependencySha256 = (Get-FileHash -LiteralPath $dependencyPath -Algorithm SHA256).Hash.ToLowerInvariant()
$expectedSha256 = @{
    'win-arm64' = '70aed3f743e785134eb6e0ee1b142ea4d345a217b2228c75aa6eb7845acf82a8'
    'win-x64' = '87df32483fdb4b51c815f3bcb853a6f29fc108d3c103b0721aa08ec8a267cd58'
}
if ($dependencySha256 -ne $expectedSha256[$Platform]) {
    throw "Expected the original deps-v1 ZIP for $Platform. SHA256: $dependencySha256"
}

$sourceCommit = git -C $root rev-parse --verify HEAD
if ($LASTEXITCODE -ne 0) { throw 'Could not resolve the source commit.' }

# These inputs correspond to the pinned dependency ZIPs.
$dependencyInputs = @(
    'backend/requirements.txt', 'frontend/package.json', 'frontend/package-lock.json',
    'offline/constraints.txt', 'offline/runtimes.json'
)
git -C $root diff --quiet --exit-code 0707d73e8b59ba9856007faf0de65264dad2d26e $sourceCommit -- @dependencyInputs
if ($LASTEXITCODE -ne 0) { throw 'Could not confirm that the source matches the deps-v1 dependency inputs.' }

if (-not $OutputDirectory) { $OutputDirectory = Join-Path $root 'dist' }
$outputRoot = (New-Item -ItemType Directory -Path $OutputDirectory -Force).FullName
$name = "chatbi-$Tag-$Platform"
$zipPath = Join-Path $outputRoot "$name.zip"
if (Test-Path -LiteralPath $zipPath) { throw "Archive already exists: $zipPath" }

$scratch = Join-Path $env:TEMP ('lab-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
$sourceZip = Join-Path $scratch 'source.zip'
$project = Join-Path $scratch $name
$dependencies = Join-Path $scratch 'deps'
$archive = Join-Path $scratch "$name.zip"
try {
    New-Item -ItemType Directory -Path $project, $dependencies | Out-Null
    git -C $root archive --format=zip --output=$sourceZip $sourceCommit
    if ($LASTEXITCODE -ne 0) { throw 'Could not archive the committed source.' }
    & $tarExe -xf $sourceZip -C $project
    if ($LASTEXITCODE -ne 0) { throw 'Could not extract the committed source.' }
    & $tarExe -xf $dependencyPath -C $dependencies
    if ($LASTEXITCODE -ne 0) { throw 'Could not extract the verified dependencies.' }

    $offline = (New-Item -ItemType Directory -Path (Join-Path $project '.offline')).FullName
    foreach ($entry in @('manifest.json', 'node', 'python', 'wheels', 'npm-cache')) {
        Move-Item -LiteralPath (Join-Path $dependencies $entry) -Destination $offline
    }
    Move-Item -LiteralPath (Join-Path $dependencies 'node_modules') -Destination (Join-Path $project 'frontend')

    [ordered]@{
        tag = $Tag
        platform = $Platform
        sourceCommit = $sourceCommit
        dependencyRelease = 'deps-v1'
        dependencySha256 = $dependencySha256
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $offline 'lab-manifest.json') -Encoding ASCII

    & $tarExe -a -cf $archive -C $scratch $name
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the workshop ZIP.' }
    Move-Item -LiteralPath $archive -Destination $zipPath
    $hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host "Built $zipPath from $sourceCommit"
    Write-Host "$hash  $name.zip"
} finally {
    if (Test-Path -LiteralPath $scratch) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
