# ==============================================================================
# TP3 ADMINISTRATION RÉSEAUX — INTERCONNEXION MESSAGERIE AVEC UN CAMARADE
# Permet en classe de relier ta messagerie (elhadji.sn / universite.sn) à celle
# d'un camarade et de lui envoyer un courriel de test immédiatement.
# ==============================================================================
param(
    [Parameter(Mandatory=$true, HelpMessage="Domaine du camarade (ex: moussa.sn)")]
    [string]$DomaineCamarade,

    [Parameter(Mandatory=$true, HelpMessage="Adresse IP de la VM du camarade (ex: 192.168.1.55)")]
    [string]$IPCamarade,

    [Parameter(Mandatory=$false, HelpMessage="Adresse email du destinataire chez le camarade")]
    [string]$EmailDestinataire = ""
)

if ([string]::IsNullOrWhiteSpace($EmailDestinataire)) {
    $EmailDestinataire = "contact@$DomaineCamarade"
}

$SshKey = "c:\workspace\ops\tp3-admin_reseaux\ssh\tp3_ed25519"
$ServerIP = "192.168.126.100"

Write-Host "=== Connexion au serveur $ServerIP et configuration vers $DomaineCamarade ($IPCamarade) ===" -ForegroundColor Cyan
ssh -i $SshKey -o StrictHostKeyChecking=no root@$ServerIP "/usr/local/bin/connecter-camarade '$DomaineCamarade' '$IPCamarade' '$EmailDestinataire'"
