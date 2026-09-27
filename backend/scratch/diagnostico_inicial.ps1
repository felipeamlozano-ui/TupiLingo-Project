Write-Host "================================================================================"
Write-Host "1. DIAGNÓSTICO DE MEMÓRIA RAM (Get-CimInstance Win32_OperatingSystem)"
Write-Host "================================================================================"
$os = Get-CimInstance Win32_OperatingSystem
$totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
$freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
$usedGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
Write-Host ("TotalVisibleMemory : " + $totalGB + " GB")
Write-Host ("FreePhysicalMemory  : " + $freeGB + " GB")
Write-Host ("UsedPhysicalMemory  : " + $usedGB + " GB")

Write-Host "`n================================================================================"
Write-Host "2. DIAGNÓSTICO DE DISCO C: (Get-PSDrive C)"
Write-Host "================================================================================"
Get-PSDrive C | Select-Object Name, @{Name="UsedGB";Expression={[math]::Round($_.Used/1GB,2)}}, @{Name="FreeGB";Expression={[math]::Round($_.Free/1GB,2)}}, Root | Format-Table -AutoSize

Write-Host "================================================================================"
Write-Host "3. TOP 15 PROCESSOS POR CONSUMO DE RAM (WorkingSet64)"
Write-Host "================================================================================"
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 Id, ProcessName, @{Name="WorkingSetMB";Expression={[math]::Round($_.WorkingSet64/1MB,2)}}, @{Name="VMMB";Expression={[math]::Round($_.VM/1MB,2)}} | Format-Table -AutoSize

Write-Host "================================================================================"
Write-Host "4. STATUS DO DOCKER DESKTOP E SERVIÇO"
Write-Host "================================================================================"
try {
    $dver = & docker --version
    Write-Host ("docker --version: " + $dver)
} catch {
    Write-Host ("docker --version error: " + $_)
}

try {
    $dinfo = & docker info 2>&1
    Write-Host ("Docker Exit Code: " + $LASTEXITCODE)
    $dinfo | Select-Object -First 6 | ForEach-Object { Write-Host ("  " + $_) }
} catch {
    Write-Host ("docker info error: " + $_)
}

Write-Host "`nServiços Windows relacionados ao Docker:"
Get-Service -Name "*docker*" -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, Status, StartType | Format-Table -AutoSize
