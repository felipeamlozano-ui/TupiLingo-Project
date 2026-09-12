# detect_wifi_ip.ps1 -- Detecta o IP do adaptador Wi-Fi fisico.
# Retorna o IP via stdout. Retorna string vazia se nao encontrado.
# Chamado pelo dev.bat na funcao :detect_ip.

# PRIORIDADE 1: Adaptador com alias contendo "Wi-Fi"
$wifi = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.InterfaceAlias -like '*Wi-Fi*' -and
    $_.IPAddress -notlike '127.*' -and
    $_.IPAddress -notlike '169.254.*'
} | Select-Object -First 1

if ($wifi) {
    Write-Output $wifi.IPAddress
    exit 0
}

# PRIORIDADE 2: Qualquer adaptador de rede local (exclui loopback, APIPA, WSL, Docker)
$lan = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.IPAddress -notlike '127.*' -and
    $_.IPAddress -notlike '169.254.*' -and
    $_.IPAddress -notlike '172.1[6-9].*' -and
    $_.IPAddress -notlike '172.2[0-9].*' -and
    $_.IPAddress -notlike '172.3[01].*' -and
    $_.InterfaceAlias -notlike '*Loopback*' -and
    $_.InterfaceAlias -notlike '*vEthernet*'
} | Select-Object -First 1

if ($lan) {
    Write-Output $lan.IPAddress
    exit 0
}

# Nao encontrado
Write-Output ''
exit 0
