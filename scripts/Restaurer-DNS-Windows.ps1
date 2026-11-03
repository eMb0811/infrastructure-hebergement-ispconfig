# ==============================================================================
# TP3 ADMINISTRATION RÉSEAUX — RESTAURER LE DNS AUTOMATIQUE (DHCP) SUR WINDOWS
# ==============================================================================

Write-Host "=== Restauration du DNS automatique (DHCP) sur Windows ===" -ForegroundColor Cyan

$Adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
foreach ($Adapter in $Adapters) {
    try {
        Set-DnsClientServerAddress -InterfaceIndex $Adapter.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
        Write-Host " -> DNS automatique restauré sur : $($Adapter.Name)" -ForegroundColor Green
    } catch {}
}

Clear-DnsClientCache
Write-Host "Cache DNS Windows vidé avec succès." -ForegroundColor Green
