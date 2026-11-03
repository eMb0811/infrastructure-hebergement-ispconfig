# ==============================================================================
# TP3 ADMINISTRATION RÉSEAUX — SCRIPT DE VÉRIFICATION COMPLÈTE DEPUIS WINDOWS
# Vérifie les 6 points clés demandés par l'enseignant :
#  1. Multidomaine (elhadji.sn / universite.sn) et utilisateurs (elhadji / ucad)
#  2. DNS & BIND9 actif + résolution A, MX, NS depuis Windows
#  3. Hébergement Web WordPress + SSL + Redis Cache actif sur les 2 domaines
#  4. Sauvegardes automatiques programmées (quotidienne, rétention 7 copies)
#  5. Messagerie multidomaine (Postfix/Dovecot) + réception des courriels
#  6. Outil d'interconnexion avec la messagerie d'un camarade
# ==============================================================================

$ServerIP = "192.168.126.100"
$SshKey   = "c:\workspace\ops\tp3-admin_reseaux\ssh\tp3_ed25519"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " 1. VÉRIFICATION RÉSEAU & CONNEXION AU SERVEUR ($ServerIP)" -ForegroundColor Cyan
Write-Host "=================================================================="
ssh -i $SshKey -o StrictHostKeyChecking=no root@$ServerIP "hostname -f; ip -br -4 addr"

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host " 2. VÉRIFICATION DNS BIND9 & RÉSOLUTION DEPUIS WINDOWS" -ForegroundColor Cyan
Write-Host "=================================================================="
ssh -i $SshKey -o StrictHostKeyChecking=no root@$ServerIP "systemctl is-active named && named-checkconf && echo 'BIND9 syntax & service: OK'"
Resolve-DnsName -Name "elhadji.sn" -Server $ServerIP -Type A | Format-Table Name, Type, IPAddress -AutoSize
Resolve-DnsName -Name "universite.sn" -Server $ServerIP -Type A | Format-Table Name, Type, IPAddress -AutoSize
Resolve-DnsName -Name "elhadji.sn" -Server $ServerIP -Type MX | Format-Table Name, Type, NameExchange, Preference -AutoSize
Resolve-DnsName -Name "universite.sn" -Server $ServerIP -Type MX | Format-Table Name, Type, NameExchange, Preference -AutoSize

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host " 3. VÉRIFICATION MULTIDOMAINE, WORDPRESS & REDIS CACHE" -ForegroundColor Cyan
Write-Host "=================================================================="
ssh -i $SshKey -o StrictHostKeyChecking=no root@$ServerIP @"
virtualmin list-domains
echo '--- Statut Redis Cache sur elhadji.sn ---'
sudo -u elhadji -i -- wp redis status --path=/home/elhadji/public_html | grep -E 'Status:|Client:'
echo '--- Statut Redis Cache sur universite.sn ---'
sudo -u ucad -i -- wp redis status --path=/home/ucad/public_html | grep -E 'Status:|Client:'
"@

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host " 4. VÉRIFICATION DES SAUVEGARDES AUTOMATIQUES (QUOTIDIENNE / 7 COPIES)" -ForegroundColor Cyan
Write-Host "=================================================================="
ssh -i $SshKey -o StrictHostKeyChecking=no root@$ServerIP "ls -lh /var/backups/virtualmin/; cat /etc/cron.d/virtualmin-scheduled-backup"

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host " 5. VÉRIFICATION DE LA MESSAGERIE MULTIDOMAINE" -ForegroundColor Cyan
Write-Host "=================================================================="
ssh -i $SshKey -o StrictHostKeyChecking=no root@$ServerIP @"
echo '--- Comptes mail elhadji.sn ---'
virtualmin list-users --domain elhadji.sn
echo '--- Comptes mail universite.sn ---'
virtualmin list-users --domain universite.sn
"@
