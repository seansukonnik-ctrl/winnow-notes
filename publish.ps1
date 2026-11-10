# Rebuild the Winnow core edition from the vault and copy it into plugins/winnow.
# Usage: .\publish.ps1 [-Vault <path>]
param([string]$Vault = $(if ($env:WINNOW_VAULT) { $env:WINNOW_VAULT } else { Join-Path $PSScriptRoot "..\Synced_PKM" }))
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$src = Join-Path $Vault "resources\winnow-plugin\src"

python (Join-Path $src "build.py")
if ($LASTEXITCODE -ne 0) { throw "build.py failed" }
$version = (Get-Content (Join-Path $src "VERSION") -Raw).Trim()
$plugin = Join-Path $Vault "resources\winnow-plugin\dist\winnow-$version-core.plugin"

$stage = Join-Path ([IO.Path]::GetTempPath()) ("winnow-publish-" + [guid]::NewGuid())
New-Item -ItemType Directory $stage | Out-Null
try {
    # Expand-Archive in PowerShell 5.1 only accepts .zip
    $zip = "$stage.zip"
    Copy-Item $plugin $zip
    Expand-Archive $zip -DestinationPath $stage
    Remove-Item $zip

    # Privacy guard: refuse obvious personal strings. Extend the pattern, never remove it.
    # The vault folder name and the OS user name are added at run time so they never sit in this repo.
    $pattern = [regex]::Escape((Split-Path (Resolve-Path $Vault) -Leaf)) + '|' + [regex]::Escape($env:USERNAME) + '|[A-Z]:\\Users\\|/Users/[^/]+/|@gmail\.com'
    $hits = Get-ChildItem $stage -Recurse -File -Force | Select-String -Pattern $pattern
    if ($hits) {
        $hits | ForEach-Object { Write-Host $_ }
        throw "publish: personal strings found in the build (above). Fix the source in the vault."
    }

    if (Test-Path plugins\winnow) { Remove-Item plugins\winnow -Recurse -Force }
    New-Item -ItemType Directory plugins -Force | Out-Null
    Copy-Item $stage plugins\winnow -Recurse
    Copy-Item LICENSE plugins\winnow\LICENSE
} finally {
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
}
$v = (Get-Content plugins\winnow\.claude-plugin\plugin.json -Raw | ConvertFrom-Json).version
Write-Host "publish: plugins/winnow is now $v"
Write-Host "Review with 'git status', then commit and push."
