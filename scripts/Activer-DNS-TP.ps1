# ==============================================================================
# TP3 ADMINISTRATION RÉSEAUX — ACTIVER LE SERVEUR DNS DU TP SUR WINDOWS
# Configure l'adresse IP du serveur Linux (192.168.126.100) comme serveur DNS
# ==============================================================================

$ServerDNS = "192.168.126.100"

Write-Host "=== Configuration du DNS Windows vers le serveur BIND9 ($ServerDNS) ===" -ForegroundColor Cyan

# Cibler l'interface VMware VMnet8 ainsi que l'interface active (Wi-Fi / Ethernet)
$Adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and ($_.Name -match "VMnet8|Wi-Fi|Ethernet") }

foreach ($Adapter in $Adapters) {
    Write-Host " -> Configuration de la carte : $($Adapter.Name)" -ForegroundColor Yellow
    try {
        Set-DnsClientServerAddress -InterfaceIndex $Adapter.InterfaceIndex -ServerAddresses @($ServerDNS, "8.8.8.8") -ErrorAction Stop
    } catch {
        Write-Warning "Droits Administrateur requis pour modifier $($Adapter.Name). Relancez PowerShell en Administrateur."
    }
}

Clear-DnsClientCache
Write-Host "`n=== Test de résolution DNS via le serveur BIND9 ($ServerDNS) ===" -ForegroundColor Green
Resolve-DnsName -Name "elhadji.sn" -Server $ServerDNS -Type A
Resolve-DnsName -Name "universite.sn" -Server $ServerDNS -Type A
Resolve-DnsName -Name "elhadji.sn" -Server $ServerDNS -Type MX
Resolve-DnsName -Name "universite.sn" -Server $ServerDNS -Type MX
