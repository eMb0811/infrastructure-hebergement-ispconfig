# ==============================================================================
# TP3 ADMINISTRATION RÉSEAUX — ACTIVER LE DNS SUR LA VM ISPCONFIG (192.168.126.110)
# ==============================================================================

$ServerDNS = "192.168.126.110"

Write-Host "=== Configuration du DNS Windows vers le serveur ISPConfig BIND9 ($ServerDNS) ===" -ForegroundColor Cyan

$Adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and ($_.Name -match "VMnet8|Wi-Fi|Ethernet") }

foreach ($Adapter in $Adapters) {
    Write-Host " -> Configuration de la carte : $($Adapter.Name)" -ForegroundColor Yellow
    try {
        Set-DnsClientServerAddress -InterfaceIndex $Adapter.InterfaceIndex -ServerAddresses @($ServerDNS, "8.8.8.8") -ErrorAction Stop
    } catch {
        Write-Warning "Droits Administrateur requis pour $($Adapter.Name). Relancez PowerShell en Administrateur."
    }
}

Clear-DnsClientCache
Write-Host "`n=== Test de résolution DNS via le serveur ISPConfig ($ServerDNS) ===" -ForegroundColor Green
Resolve-DnsName -Name "elhadji.sn" -Server $ServerDNS -Type A
Resolve-DnsName -Name "universite.sn" -Server $ServerDNS -Type A
Resolve-DnsName -Name "elhadji.sn" -Server $ServerDNS -Type MX
Resolve-DnsName -Name "universite.sn" -Server $ServerDNS -Type MX
