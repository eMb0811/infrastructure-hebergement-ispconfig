#!/bin/bash
# ==============================================================================
# TP3 ADMINISTRATION RÉSEAUX — PROVISIONING COMPLET DU SERVEUR D'HÉBERGEMENT
# Solution : Virtualmin / Webmin (Stack LEMP + BIND9 + Postfix/Dovecot + Redis)
# Domaines : elhadji.sn (user: elhadji) & universite.sn (user: ucad)
# ==============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SERVER_IP="192.168.126.100"
HOSTNAME_FQDN="srv.elhadji.sn"
ADMIN_PASS="Passer@2026"
DOMAIN1="elhadji.sn"
USER1="elhadji"
DOMAIN2="universite.sn"
USER2="ucad"

echo "=================================================================="
echo " [1/9] Préparation du système et configuration du Hostname"
echo "=================================================================="
hostnamectl set-hostname "$HOSTNAME_FQDN"

cat > /etc/hosts <<EOF
127.0.0.1       localhost
${SERVER_IP}    ${HOSTNAME_FQDN} srv ${DOMAIN1} www.${DOMAIN1} mail.${DOMAIN1} webmail.${DOMAIN1} ${DOMAIN2} www.${DOMAIN2} mail.${DOMAIN2} webmail.${DOMAIN2}

# The following lines are desirable for IPv6 capable hosts
::1             localhost ip6-localhost ip6-loopback
EOF

apt-get update -y
apt-get install -y curl wget gnupg2 ca-certificates lsb-release apt-transport-https \
    software-properties-common dnsutils net-tools unzip jq swaks bsd-mailx cron

echo "=================================================================="
echo " [2/9] Installation de Virtualmin GPL (Stack LEMP + BIND9 + Mail)"
echo "=================================================================="
if [ ! -f /usr/sbin/virtualmin ]; then
    cd /root
    wget -q https://software.virtualmin.com/gpl/scripts/virtualmin-install.sh -O /root/virtualmin-install.sh
    chmod +x /root/virtualmin-install.sh
    # Installation en mode non-interactif avec le bundle LEMP (Nginx + MariaDB + PHP-FPM + BIND9 + Postfix + Dovecot)
    /root/virtualmin-install.sh --bundle LEMP --hostname "$HOSTNAME_FQDN" --yes
fi

# Désactiver ClamAV (antivirus lourd en RAM inutile en TP) pour garder un serveur ultra-rapide
systemctl stop clamav-daemon clamav-freshclam 2>/dev/null || true
systemctl disable clamav-daemon clamav-freshclam 2>/dev/null || true

# Définir le mot de passe root pour Webmin/Virtualmin
echo "root:${ADMIN_PASS}" | chpasswd
/usr/share/webmin/changepass.pl /etc/webmin root "${ADMIN_PASS}" || true

echo "=================================================================="
echo " [3/9] Installation de Redis Cache, extensions PHP et WP-CLI"
echo "=================================================================="
apt-get install -y redis-server php-redis php-imagick php-intl php-zip php-gd php-curl php-mbstring php-xml

# Détecter la version PHP par défaut et redémarrer son FPM
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
apt-get install -y "php${PHP_VER}-redis" "php${PHP_VER}-mysql" "php${PHP_VER}-fpm" "php${PHP_VER}-curl" "php${PHP_VER}-gd" "php${PHP_VER}-mbstring" "php${PHP_VER}-xml" "php${PHP_VER}-zip" "php${PHP_VER}-intl" || true

sed -i 's/^supervised .*/supervised systemd/' /etc/redis/redis.conf || true
systemctl enable --now redis-server
systemctl restart "php${PHP_VER}-fpm" || true

# Installation de WP-CLI pour déployer et configurer WordPress proprement
if [ ! -f /usr/local/bin/wp ]; then
    curl -sL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp
    chmod +x /usr/local/bin/wp
fi

echo "=================================================================="
echo " [4/9] Configuration et sécurisation du Pare-feu (Firewalld / UFW)"
echo "=================================================================="
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port=22/tcp
    firewall-cmd --permanent --add-port=53/tcp
    firewall-cmd --permanent --add-port=53/udp
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=443/tcp
    firewall-cmd --permanent --add-port=25/tcp
    firewall-cmd --permanent --add-port=465/tcp
    firewall-cmd --permanent --add-port=587/tcp
    firewall-cmd --permanent --add-port=110/tcp
    firewall-cmd --permanent --add-port=143/tcp
    firewall-cmd --permanent --add-port=993/tcp
    firewall-cmd --permanent --add-port=995/tcp
    firewall-cmd --permanent --add-port=10000/tcp
    firewall-cmd --permanent --add-port=20000/tcp
    firewall-cmd --reload
fi

echo "=================================================================="
echo " [5/9] Activation et configuration du serveur DNS BIND9 (named)"
echo "=================================================================="
cat > /etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";

    // Écouter sur toutes les interfaces (NAT + Bridge salle de classe)
    listen-on { any; };
    listen-on-v6 { any; };

    // Autoriser les requêtes DNS depuis le PC Windows et le réseau de la classe
    allow-query { any; };
    allow-recursion { any; };
    recursion yes;

    // Transférer les requêtes externes vers la passerelle et Google/Cloudflare
    // pour conserver Internet sur Windows quand le serveur DNS du TP est actif
    forwarders {
        192.168.126.2;
        8.8.8.8;
        1.1.1.1;
    };

    // Désactiver la validation DNSSEC stricte pour permettre les domaines locaux (.sn de TP)
    dnssec-validation no;
};
EOF

named-checkconf
systemctl enable --now named
systemctl restart named

# Configurer l'interface principale eth0 (192.168.126.100) dans Virtualmin
sed -i 's/^iface=.*/iface=eth0/' /etc/webmin/virtual-server/config || true
grep -q "^iface=" /etc/webmin/virtual-server/config || echo "iface=eth0" >> /etc/webmin/virtual-server/config
virtualmin check-config || true

echo "=================================================================="
echo " [6/9] Création Multidomaine & Utilisateurs (elhadji.sn & universite.sn)"
echo "=================================================================="
if ! virtualmin list-domains --domain "$DOMAIN1" >/dev/null 2>&1; then
    virtualmin create-domain \
        --domain "$DOMAIN1" \
        --user "$USER1" \
        --pass "$ADMIN_PASS" \
        --desc "Domaine Principal - Elhadji" \
        --email "contact@${DOMAIN1}" \
        --default-ip \
        --dns-ip "$SERVER_IP" \
        --unix \
        --dir \
        --dns \
        --mail \
        --mysql \
        --virtualmin-nginx \
        --virtualmin-nginx-ssl
fi

if ! virtualmin list-domains --domain "$DOMAIN2" >/dev/null 2>&1; then
    virtualmin create-domain \
        --domain "$DOMAIN2" \
        --user "$USER2" \
        --pass "$ADMIN_PASS" \
        --desc "Portail Universitaire - UCAD" \
        --email "contact@${DOMAIN2}" \
        --default-ip \
        --dns-ip "$SERVER_IP" \
        --unix \
        --dir \
        --dns \
        --mail \
        --mysql \
        --virtualmin-nginx \
        --virtualmin-nginx-ssl
fi

# Ajout d'enregistrements DNS utiles (webmail, ns1) dans les deux zones
for dom in "$DOMAIN1" "$DOMAIN2"; do
    virtualmin modify-dns --domain "$dom" --add-record "webmail A ${SERVER_IP}" 2>/dev/null || true
    virtualmin modify-dns --domain "$dom" --add-record "ns1 A ${SERVER_IP}" 2>/dev/null || true
done

systemctl reload named || systemctl restart named

echo "=================================================================="
echo " [7/9] Déploiement de WordPress + Redis Cache sur les 2 domaines"
echo "=================================================================="
deploy_wordpress_site() {
    local dom="$1"
    local usr="$2"
    local title="$3"
    local docroot="/home/${usr}/public_html"
    local dbname="${usr}"

    # Récupérer ou définir le mot de passe MySQL du domaine
    mysql -e "CREATE DATABASE IF NOT EXISTS \`${dbname}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -e "ALTER USER '${usr}'@'localhost' IDENTIFIED BY '${ADMIN_PASS}';" 2>/dev/null || \
        mysql -e "CREATE USER IF NOT EXISTS '${usr}'@'localhost' IDENTIFIED BY '${ADMIN_PASS}';"
    mysql -e "GRANT ALL PRIVILEGES ON \`${dbname}\`.* TO '${usr}'@'localhost'; FLUSH PRIVILEGES;"

    rm -f "${docroot}/index.html" "${docroot}/index.htm"

    if [ ! -f "${docroot}/wp-config.php" ]; then
        sudo -u "$usr" -i -- wp core download --path="$docroot" --locale=fr_FR --force
        sudo -u "$usr" -i -- wp config create \
            --path="$docroot" \
            --dbname="$dbname" \
            --dbuser="$usr" \
            --dbpass="$ADMIN_PASS" \
            --dbhost="localhost" \
            --extra-php <<PHP
define( 'WP_REDIS_HOST', '127.0.0.1' );
define( 'WP_REDIS_PORT', 6379 );
define( 'WP_CACHE_KEY_SALT', '${dom}_' );
define( 'FS_METHOD', 'direct' );
PHP
        sudo -u "$usr" -i -- wp core install \
            --path="$docroot" \
            --url="https://${dom}" \
            --title="$title" \
            --admin_user="$usr" \
            --admin_password="$ADMIN_PASS" \
            --admin_email="contact@${dom}" \
            --skip-email

        # Permaliens propres et plugin Redis Object Cache
        sudo -u "$usr" -i -- wp rewrite structure '/%postname%/' --path="$docroot"
        sudo -u "$usr" -i -- wp plugin install redis-cache --activate --path="$docroot"
        sudo -u "$usr" -i -- wp redis enable --path="$docroot"

        # Créer un article de démonstration complet pour l'évaluation du TP
        sudo -u "$usr" -i -- wp post create \
            --path="$docroot" \
            --post_type=post \
            --post_status=publish \
            --post_title="Validation TP3 : Hébergement Multidomaine, DNS BIND9, Sauvegardes & Messagerie (${dom})" \
            --post_content="<p>Bienvenue sur le site de démonstration <strong>${dom}</strong> géré par l'utilisateur Linux <code>${usr}</code>.</p><ul><li><strong>Serveur Web :</strong> Nginx + PHP-FPM ${PHP_VER}</li><li><strong>Cache Serveur :</strong> Redis Object Cache actif (127.0.0.1:6379)</li><li><strong>Serveur DNS :</strong> BIND9 faisant autorité sur la zone <code>${dom}</code></li><li><strong>Messagerie :</strong> Postfix (SMTP) + Dovecot (IMAP/POP3) pour <code>@${dom}</code></li><li><strong>Sauvegardes :</strong> Automatiques quotidiennes (rétention 7 copies)</li></ul>"
    fi

    chown -R "${usr}:${usr}" "$docroot"
}

deploy_wordpress_site "$DOMAIN1" "$USER1" "Portail Cloud & DevOps — Elhadji (${DOMAIN1})"
deploy_wordpress_site "$DOMAIN2" "$USER2" "Portail Universitaire Numérique — UCAD (${DOMAIN2})"

# S'assurer que Nginx gère les permaliens WordPress (try_files) et redirige ou sert proprement HTTP/HTTPS
for conf in /etc/nginx/sites-available/*.conf; do
    [ -e "$conf" ] || continue
    if ! grep -q "try_files \$uri \$uri/ /index.php" "$conf"; then
        sed -i '/root \/home\/.*\/public_html;/a \    location / {\n        try_files $uri $uri/ /index.php?$args;\n    }' "$conf" || true
    fi
done
nginx -t && systemctl reload nginx

echo "=================================================================="
echo " [8/9] Configuration des Sauvegardes Automatiques (Quotidienne, 7 copies)"
echo "=================================================================="
mkdir -p /var/backups/virtualmin
chmod 700 /var/backups/virtualmin

# Créer une sauvegarde immédiate des deux domaines pour vérification
virtualmin backup-domain \
    --dest "/var/backups/virtualmin/backup-$(date +%F)" \
    --domain "$DOMAIN1" \
    --domain "$DOMAIN2" \
    --all-features \
    --newformat \
    --mkdir

# Configurer la sauvegarde planifiée dans Virtualmin (/etc/webmin/virtual-server/backups)
BACKUP_ID="1730484000"
mkdir -p /etc/webmin/virtual-server/backups
cat > "/etc/webmin/virtual-server/backups/${BACKUP_ID}" <<EOF
id=${BACKUP_ID}
doms=${DOMAIN1} ${DOMAIN2}
all=0
features=dir dns mail mysql virtualmin-nginx virtualmin-nginx-ssl unix
dest=file:///var/backups/virtualmin/backup-%Y-%m-%d
mkdir=1
newformat=1
onebyone=1
strftime=1
purge=7
mins=0
hours=2
days=*
months=*
weekdays=*
special=daily
enabled=1
email=contact@${DOMAIN1}
email_err=0
EOF

# Ajouter la tâche cron correspondante si non présente
cat > /etc/cron.d/virtualmin-scheduled-backup <<EOF
# Sauvegarde automatique quotidienne Virtualmin (rétention : 7 jours)
0 2 * * * root /usr/sbin/virtualmin backup-domain --dest "/var/backups/virtualmin/backup-\$(date +\\%F)" --domain ${DOMAIN1} --domain ${DOMAIN2} --all-features --newformat --mkdir --purge 7 >/dev/null 2>&1
EOF
chmod 644 /etc/cron.d/virtualmin-scheduled-backup

echo "=================================================================="
echo " [9/9] Configuration Messagerie Multidomaine & Script Camarade"
echo "=================================================================="
# Création des comptes courriels pour les deux domaines
virtualmin create-user --domain "$DOMAIN1" --user "contact" --pass "$ADMIN_PASS" --real "Contact Elhadji" --quota 0 2>/dev/null || true
virtualmin create-user --domain "$DOMAIN1" --user "etudiant" --pass "$ADMIN_PASS" --real "Etudiant Elhadji" --quota 0 2>/dev/null || true
virtualmin create-user --domain "$DOMAIN2" --user "contact" --pass "$ADMIN_PASS" --real "Contact Universite" --quota 0 2>/dev/null || true
virtualmin create-user --domain "$DOMAIN2" --user "scolarite" --pass "$ADMIN_PASS" --real "Scolarite UCAD" --quota 0 2>/dev/null || true

# Configuration Postfix pour l'interconnexion en salle de classe (SMTP port 25 ouvert + TLS opportuniste)
postconf -e "inet_interfaces = all"
postconf -e "inet_protocols = ipv4"
postconf -e "smtp_tls_security_level = may"
postconf -e "smtpd_tls_security_level = may"
postconf -e "mynetworks = 127.0.0.0/8 192.168.126.0/24 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12"
touch /etc/postfix/transport
postmap /etc/postfix/transport
postconf -e "transport_maps = hash:/etc/postfix/transport"
systemctl restart postfix
systemctl restart dovecot

# Test d'envoi de mail réel entre les 2 domaines locaux
swaks --to "contact@${DOMAIN2}" \
      --from "contact@${DOMAIN1}" \
      --server 127.0.0.1 \
      --header "Subject: Test Messagerie Multidomaine (${DOMAIN1} -> ${DOMAIN2})" \
      --body "Bonjour, ceci est un courriel de validation envoyé depuis ${DOMAIN1} vers ${DOMAIN2}." || true

swaks --to "contact@${DOMAIN1}" \
      --from "contact@${DOMAIN2}" \
      --server 127.0.0.1 \
      --header "Subject: Reponse Messagerie Multidomaine (${DOMAIN2} -> ${DOMAIN1})" \
      --body "Bonjour, le domaine ${DOMAIN2} a bien recu votre message et vous repond !" || true

# Création du script d'interconnexion avec la messagerie d'un camarade en classe
cat > /usr/local/bin/connecter-camarade <<'EOS'
#!/bin/bash
set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: connecter-camarade <domaine-camarade> <ip-serveur-camarade> [email-destinataire]"
    echo "Exemple: connecter-camarade moussa.sn 192.168.1.55 contact@moussa.sn"
    exit 1
fi

PEER_DOMAIN="$1"
PEER_IP="$2"
PEER_EMAIL="${3:-contact@${PEER_DOMAIN}}"

echo "[1/4] Configuration du forward DNS BIND9 pour la zone ${PEER_DOMAIN} vers ${PEER_IP}..."
if ! grep -q "zone \"${PEER_DOMAIN}\"" /etc/bind/named.conf.local; then
cat >> /etc/bind/named.conf.local <<EOF

zone "${PEER_DOMAIN}" {
    type forward;
    forward only;
    forwarders { ${PEER_IP}; };
};
EOF
fi
named-checkconf && systemctl reload named

echo "[2/4] Ajout dans /etc/hosts et table de routage SMTP Postfix (/etc/postfix/transport)..."
sed -i "/${PEER_DOMAIN}/d" /etc/hosts
echo "${PEER_IP} mail.${PEER_DOMAIN} ${PEER_DOMAIN}" >> /etc/hosts

sed -i "/^${PEER_DOMAIN} /d" /etc/postfix/transport
echo "${PEER_DOMAIN} smtp:[${PEER_IP}]:25" >> /etc/postfix/transport
postmap /etc/postfix/transport
systemctl reload postfix

echo "[3/4] Envoi d'un courriel de test depuis contact@elhadji.sn vers ${PEER_EMAIL}..."
swaks --to "${PEER_EMAIL}" \
      --from "contact@elhadji.sn" \
      --server 127.0.0.1 \
      --header "Subject: Test Interconnexion Messagerie TP3 (depuis elhadji.sn)" \
      --body "Bonjour camarade ! Ce message provient du serveur de messagerie elhadji.sn."

echo "[4/4] Dernières lignes du journal /var/log/mail.log :"
sleep 2
tail -n 15 /var/log/mail.log
EOS
chmod +x /usr/local/bin/connecter-camarade

echo "=================================================================="
echo " PROVISIONING TERMINÉ AVEC SUCCÈS !"
echo "=================================================================="
