$ErrorActionPreference = 'Stop'

$localAppData = $env:LOCALAPPDATA
$targetDir = Join-Path $localAppData 'ms-playwright-go\1.57.0'
Write-Host "Configuring target: $targetDir"

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

$nodePath = (Get-Command node.exe).Source
Write-Host "Using node from: $nodePath"
Copy-Item -Path $nodePath -Destination (Join-Path $targetDir 'node.exe') -Force

$pkgDir = Join-Path $targetDir 'package'
if (-not (Test-Path $pkgDir)) {
    New-Item -ItemType Directory -Path $pkgDir -Force | Out-Null
}

$sourceCore = 'c:\Users\Felipe\Desktop\TupiLingo\qa\node_modules\playwright-core'
Write-Host "Copying playwright-core from: $sourceCore"
Copy-Item -Path "$sourceCore\*" -Destination $pkgDir -Recurse -Force

$cmdContent = "@echo off`r`n`"%~dp0node.exe`" `"%~dp0package\cli.js`" %*"
[System.IO.File]::WriteAllText((Join-Path $targetDir 'playwright.cmd'), $cmdContent)

$ps1Content = "& `"`$PSScriptRoot\node.exe`" `"`$PSScriptRoot\package\cli.js`" @args"
[System.IO.File]::WriteAllText((Join-Path $targetDir 'playwright.ps1'), $ps1Content)

$shContent = "#!/bin/sh`n`"`$(dirname `"`$0`")/node`" `"`$(dirname `"`$0`")/package/cli.js`" `"`$@`""
[System.IO.File]::WriteAllText((Join-Path $targetDir 'playwright.sh'), $shContent)

Write-Host "Testing driver execution:"
& (Join-Path $targetDir 'playwright.cmd') --version

Write-Host "Driver configuration successful!"
