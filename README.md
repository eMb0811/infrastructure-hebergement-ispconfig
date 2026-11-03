# TP3 Administration Réseaux — Serveur d'Hébergement Multidomaine, DNS (BIND9), WordPress/Redis, Sauvegardes & Messagerie

Vous disposez désormais de **deux machines virtuelles distinctes** dans VMware Workstation, prêtes pour votre TP :
1. **Machine Virtuelle ISPConfig 3** *(La solution recommandée par votre enseignant)*
2. **Machine Virtuelle Virtualmin** *(La solution initiale)*

---

## 🌟 1. Machine Virtuelle ISPConfig 3 (Recommandée pour le TP)

- **Fichier VMware (`.vmx`) :** `c:\workspace\ops\tp3-admin_reseaux\vm-ispconfig\vm\tp3-ispconfig\tp3-ispconfig\tp3-ispconfig.vmx`
- **Hostname (FQDN) :** `ispconfig.elhadji.sn`
- **Interface 1 (`eth0` - NAT `VMnet8`) :** `192.168.126.110/24` *(IP fixe permanente avec votre PC Windows)*
- **Interface 2 (`eth1` - Bridge Wi-Fi/LAN) :** `192.168.1.10/24` *(IP sur le réseau de la classe pour communiquer avec vos camarades)*
- **Identifiant SSH / Console :** `root` (ou `ubuntu`)
- **Mot de passe universel :** `Passer@2026`
- **Commande SSH rapide depuis PowerShell :**
  ```powershell
  ssh -i "c:\workspace\ops\tp3-admin_reseaux\ssh\tp3_ed25519" root@192.168.126.110
  ```

### Accès aux interfaces Web (ISPConfig 3)
| Service | URL d'accès | Identifiant | Mot de passe |
| :--- | :--- | :--- | :--- |
| **Panel ISPConfig 3** | `https://192.168.126.110:8080` | `admin` | `Passer@2026` |
| **Webmail Roundcube** | `https://192.168.126.110:8081/webmail/` | `contact@elhadji.sn` | `Passer@2026` |
| **Site WordPress 1** | `http://elhadji.sn/` (Admin : `/wp-admin`) | `admin` | `Passer@2026` |
| **Site WordPress 2** | `http://universite.sn/` (Admin : `/wp-admin`) | `admin` | `Passer@2026` |

### Utilisateurs SSH / SFTP dédiés par domaine (sans root)
| Domaine | Utilisateur Linux | Mot de passe | Répertoire Web racine | Clé SSH autorisée |
| :--- | :--- | :--- | :--- | :--- |
| `elhadji.sn` | `elhadji` | `Passer@2026` | `/var/www/elhadji.sn/web/` | `ssh/tp3_ed25519` |
| `universite.sn` | `ucad` | `Passer@2026` | `/var/www/universite.sn/web/` | `ssh/tp3_ed25519` |
| `test.sn` | `testeur` | `Passer@2026` | `/var/www/test.sn/web/` | `ssh/tp3_ed25519` |

### Scripts PowerShell utiles pour ISPConfig
* **Activer la résolution DNS de votre PC vers ISPConfig :**
  ```powershell
  powershell -ExecutionPolicy Bypass -File "c:\workspace\ops\tp3-admin_reseaux\scripts\Activer-DNS-ISPConfig.ps1"
  ```
* **Lancer le diagnostic complet de vérification :**
  ```powershell
  powershell -ExecutionPolicy Bypass -File "c:\workspace\ops\tp3-admin_reseaux\scripts\Verifier-ISPConfig.ps1"
  ```

---

## 2. Correspondance exacte ISPConfig 3 avec l'énoncé du cours

1. **Multidomaine & Utilisateurs :**
   * Deux sites créés sous Nginx : `elhadji.sn` (espace `/var/www/clients/client0/web1`) et `universite.sn` (espace `/var/www/clients/client0/web2`).
2. **DNS & BIND9 :**
   * Fichiers de zone BIND9 générés directement par ISPConfig dans `/etc/bind/pri.elhadji.sn` et `/etc/bind/pri.universite.sn`.
   * Enregistrements `A`, `NS`, et `MX` configurés.
3. **Sauvegardes automatiques (Le critère clé de votre enseignant) :**
   * Dans ISPConfig $\rightarrow$ **Sites** $\rightarrow$ **Websites** $\rightarrow$ cliquez sur le domaine $\rightarrow$ onglet **Backup** :
     * **Backup interval :** `Daily` (Quotidien).
     * **Backup copies :** `7` (Conserver 7 sauvegardes).
4. **Messagerie multidomaine & Interconnexion :**
   * Boîtes mails configurées : `contact@elhadji.sn`, `etudiant@elhadji.sn`, `contact@universite.sn`, `etudiant@universite.sn`.
   * Pour relier votre messagerie à celle d'un camarade en classe :
     ```bash
     /usr/local/bin/connecter-camarade <domaine-du-camarade> <ip-du-camarade> [email-destinataire]
     ```

---

## 3. Rappel de la Machine Virtuelle 1 (Virtualmin)

- **Fichier VMware (`.vmx`) :** `c:\workspace\ops\tp3-admin_reseaux\vm\tp3-server\tp3-server\tp3-server.vmx`
- **IP NAT (`eth0`) :** `192.168.126.100`
- **Panel Virtualmin :** `https://192.168.126.100:10000` (root / `Passer@2026`)
- **Activer DNS Virtualmin sur Windows :** `scripts\Activer-DNS-TP.ps1`
- **Vérification Virtualmin :** `scripts\Verifier-TP3.ps1`
