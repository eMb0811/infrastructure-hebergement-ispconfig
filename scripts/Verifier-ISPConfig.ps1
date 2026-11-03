# ==============================================================================
# TP3 ADMINISTRATION RÉSEAUX — SCRIPT DE VÉRIFICATION SUR LA VM ISPCONFIG
# ==============================================================================

$ServerIP = "192.168.126.110"
$SshKey   = "c:\workspace\ops\tp3-admin_reseaux\ssh\tp3_ed25519"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " 1. VÉRIFICATION RÉSEAU & CONNEXION ISPCONFIG ($ServerIP)" -ForegroundColor Cyan
Write-Host "=================================================================="
ssh -i $SshKey -o StrictHostKeyChecking=no root@$ServerIP "hostname -f; ip -br -4 addr"

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host " 2. VÉRIFICATION DNS BIND9 & RÉSOLUTION DEPUIS WINDOWS" -ForegroundColor Cyan
Write-Host "=================================================================="
ssh -i $SshKey -o StrictHostKeyChecking=no root@$ServerIP "systemctl is-active named && named-checkconf && ls -l /etc/bind/pri.*"
Resolve-DnsName -Name "elhadji.sn" -Server $ServerIP -Type A | Format-Table Name, Type, IPAddress -AutoSize
Resolve-DnsName -Name "universite.sn" -Server $ServerIP -Type A | Format-Table Name, Type, IPAddress -AutoSize
Resolve-DnsName -Name "elhadji.sn" -Server $ServerIP -Type MX | Format-Table Name, Type, NameExchange, Preference -AutoSize
Resolve-DnsName -Name "universite.sn" -Server $ServerIP -Type MX | Format-Table Name, Type, NameExchange, Preference -AutoSize

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host " 3. VÉRIFICATION DES SITES WORDPRESS & CACHE REDIS" -ForegroundColor Cyan
Write-Host "=================================================================="
ssh -i $SshKey -o StrictHostKeyChecking=no root@$ServerIP "wp redis status --path=/var/www/elhadji.sn/web --allow-root | grep -E 'Status:|Client:'; wp redis status --path=/var/www/universite.sn/web --allow-root | grep -E 'Status:|Client:'"

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host " 4. VÉRIFICATION DES DOMAINES ET SAUVEGARDES (DAILY / 7 COPIES)" -ForegroundColor Cyan
Write-Host "=================================================================="
ssh -i $SshKey -o StrictHostKeyChecking=no root@$ServerIP "mysql -e 'SELECT domain_id, domain, document_root, backup_interval, backup_copies FROM dbispconfig.web_domain;'"

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host " 5. VÉRIFICATION DE LA MESSAGERIE ISPCONFIG" -ForegroundColor Cyan
Write-Host "=================================================================="
ssh -i $SshKey -o StrictHostKeyChecking=no root@$ServerIP "mysql -e 'SELECT mailuser_id, email, homedir, maildir FROM dbispconfig.mail_user;'"

Write-Host "`n==================================================================" -ForegroundColor Cyan
Write-Host " 6. TEST ACCÈS HTTP/HTTPS AUX SITES & AU WEBMAIL ROUNDCUBE" -ForegroundColor Cyan
Write-Host "=================================================================="
curl.exe -ks --resolve "elhadji.sn:80:$ServerIP" "http://elhadji.sn/" | Select-String "<title>"
curl.exe -ks --resolve "universite.sn:80:$ServerIP" "http://universite.sn/" | Select-String "<title>"
curl.exe -ksL "https://$ServerIP:8081/webmail/" | Select-String "<title>"
curl.exe -ksI "https://$ServerIP:8080/" | Select-Object -First 4
