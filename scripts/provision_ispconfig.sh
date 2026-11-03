#!/bin/bash
# ==============================================================================
# TP3 ADMINISTRATION RÉSEAUX — PROVISIONING COMPLET ISPCONFIG 3 (STACK LEMP)
# Solution : ISPConfig 3 (Nginx + PHP-FPM + MariaDB + BIND9 + Postfix/Dovecot)
# Domaines : elhadji.sn (user: elhadji) & universite.sn (user: ucad)
# ==============================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SERVER_IP="192.168.126.110"
HOSTNAME_FQDN="ispconfig.elhadji.sn"
ADMIN_PASS="Passer@2026"
DOMAIN1="elhadji.sn"
USER1="elhadji"
DOMAIN2="universite.sn"
USER2="ucad"

echo "=================================================================="
echo " [1/8] Préparation du système et configuration du Hostname"
echo "=================================================================="
# Désactiver IPv6 pour éliminer tout délai réseau/timeout
sysctl -w net.ipv6.conf.all.disable_ipv6=1 || true
sysctl -w net.ipv6.conf.default.disable_ipv6=1 || true
sysctl -w net.ipv6.conf.lo.disable_ipv6=1 || true
cat > /etc/sysctl.d/99-disable-ipv6.conf <<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

hostnamectl set-hostname "$HOSTNAME_FQDN"

cat > /etc/hosts <<EOF
127.0.0.1       localhost
${SERVER_IP}    ${HOSTNAME_FQDN} ispconfig srv ${DOMAIN1} www.${DOMAIN1} mail.${DOMAIN1} webmail.${DOMAIN1} ${DOMAIN2} www.${DOMAIN2} mail.${DOMAIN2} webmail.${DOMAIN2}
EOF

apt-get update -y
apt-get install -y curl wget gnupg2 ca-certificates lsb-release apt-transport-https \
    software-properties-common dnsutils net-tools unzip jq swaks bsd-mailx cron redis-server php-cli php-mbstring php-curl php-redis

echo "root:${ADMIN_PASS}" | chpasswd

echo "=================================================================="
echo " [2/8] Installation automatique de ISPConfig 3 (Nginx + BIND9 + Mail)"
echo "=================================================================="
if [ ! -f /usr/local/ispconfig/server/server.sh ]; then
    rm -rf /tmp/ispconfig-ai /tmp/ispconfig-ai.tar.gz
    curl -4 -sL -o /tmp/ispconfig-ai.tar.gz "https://www.ispconfig.org/downloads/ispconfig-ai.tar.gz"
    mkdir -p /tmp/ispconfig-ai
    tar -C /tmp/ispconfig-ai/ -xzf /tmp/ispconfig-ai.tar.gz
    cd /tmp/ispconfig-ai

    # Exécution directe en PHP sans wrapper TTY
    php -q /tmp/ispconfig-ai/ispconfig.ai.php \
        --use-nginx \
        --use-php=system \
        --channel=stable \
        --lang=en \
        --no-quota \
        --no-mailman \
        --roundcube \
        --i-know-what-i-am-doing
fi

# Définir le mot de passe root MariaDB et admin ISPConfig à Passer@2026
PASS_HASH=$(php -r "echo password_hash('${ADMIN_PASS}', PASSWORD_DEFAULT);")
mysql -e "UPDATE dbispconfig.sys_user SET pass = '${PASS_HASH}' WHERE username = 'admin';" || true
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${ADMIN_PASS}'; FLUSH PRIVILEGES;" 2>/dev/null || true

# Activer l'accès API Remote sur ISPConfig pour automatiser la création des domaines
mysql -u root -p"${ADMIN_PASS}" dbispconfig <<SQL
INSERT INTO remote_user (sys_userid, sys_groupid, sys_perm_user, sys_perm_group, sys_perm_other, remote_username, remote_password, remote_functions)
VALUES (1, 1, 'riud', 'riud', '', 'admin_api', MD5('${ADMIN_PASS}'), 'client_get_all,client_get,client_add,client_update,client_delete,domains_domain_get,domains_domain_add,sites_web_domain_add,sites_web_domain_get,sites_web_domain_update,sites_web_domain_set_status,sites_database_add,sites_database_user_add,dns_zone_add,dns_zone_get,dns_rr_add,dns_a_add,dns_mx_add,dns_cname_add,dns_ns_add,mail_domain_add,mail_domain_get,mail_user_add,mail_user_get,mail_alias_add,server_get')
ON DUPLICATE KEY UPDATE remote_password = MD5('${ADMIN_PASS}');
SQL

echo "=================================================================="
echo " [3/8] Activation et configuration avancée de BIND9 (named)"
echo "=================================================================="
cat > /etc/bind/named.conf.options <<EOF
options {
    directory "/var/cache/bind";
    listen-on { any; };
    listen-on-v6 { any; };
    allow-query { any; };
    allow-recursion { any; };
    recursion yes;
    forwarders {
        192.168.126.2;
        8.8.8.8;
        1.1.1.1;
    };
    dnssec-validation no;
};
EOF

named-checkconf
systemctl enable --now named
systemctl restart named

echo "=================================================================="
echo " [4/8] Configuration Pare-feu UFW"
echo "=================================================================="
ufw default allow incoming || true

echo "=================================================================="
echo " [5/8] Création Multidomaine (elhadji.sn & universite.sn) via API ISPConfig"
echo "=================================================================="
cat > /root/setup_ispconfig_api.php <<'PHP'
<?php
$remote_url = 'https://127.0.0.1:8080/remote/json.php';
$remote_user = 'admin_api';
$remote_pass = 'Passer@2026';

function restCall($method, $data = []) {
    global $remote_url;
    $curl = curl_init();
    curl_setopt($curl, CURLOPT_POST, 1);
    if ($data) {
        curl_setopt($curl, CURLOPT_POSTFIELDS, json_encode($data));
    }
    curl_setopt($curl, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($curl, CURLOPT_SSL_VERIFYHOST, false);
    curl_setopt($curl, CURLOPT_URL, $remote_url . '?' . $method);
    curl_setopt($curl, CURLOPT_RETURNTRANSFER, 1);
    $result = curl_exec($curl);
    curl_close($curl);
    return json_decode($result, true);
}

// 1. Login
$login = restCall('login', ['username' => $remote_user, 'password' => $remote_pass, 'client_login' => false]);
if (!isset($login['response'])) {
    die("API Login failed: " . json_encode($login) . "\n");
}
$session_id = $login['response'];
echo "API Login OK. Session: $session_id\n";

// 2. Clients
$clients_def = [
    'elhadji' => ['company' => 'Elhadji', 'contact' => 'Elhadji', 'email' => 'contact@elhadji.sn'],
    'ucad' => ['company' => 'Universite UCAD', 'contact' => 'Scolarite UCAD', 'email' => 'contact@universite.sn']
];

$client_ids = [];
foreach ($clients_def as $username => $c) {
    $existing = restCall('client_get', ['session_id' => $session_id, 'client_id' => ['username' => $username]]);
    if (isset($existing['response']['client_id'])) {
        $client_ids[$username] = $existing['response']['client_id'];
    } else {
        $cparams = [
            'company_name' => $c['company'],
            'contact_name' => $c['contact'],
            'username' => $username,
            'password' => 'Passer@2026',
            'email' => $c['email'],
            'default_mailserver' => 1,
            'default_webserver' => 1,
            'default_dnsserver' => 1,
            'default_dbserver' => 1,
            'limit_maildomain' => -1,
            'limit_mailbox' => -1,
            'limit_mailalias' => -1,
            'limit_mailforward' => -1,
            'limit_web_domain' => -1,
            'limit_web_quota' => -1,
            'limit_traffic_quota' => -1,
            'web_php_options' => 'no,fast-cgi,cgi,mod,suphp,php-fpm',
            'limit_dns_zone' => -1,
            'limit_dns_record' => -1,
            'limit_database' => -1,
            'country' => 'SN',
            'language' => 'en'
        ];
        $res = restCall('client_add', ['session_id' => $session_id, 'reseller_id' => 0, 'params' => $cparams]);
        $client_ids[$username] = $res['response'];
    }
    echo "Client $username ID: {$client_ids[$username]}\n";
}

// 3. Web Domains with Daily Backups & 7 Copies
$domains = [
    'elhadji.sn' => $client_ids['elhadji'],
    'universite.sn' => $client_ids['ucad']
];

foreach ($domains as $domain => $cid) {
    $existing = restCall('sites_web_domain_get', ['session_id' => $session_id, 'primary_id' => ['domain' => $domain]]);
    if (!isset($existing['response']['domain_id'])) {
        $wparams = [
            'server_id' => 1,
            'ip_address' => '*',
            'domain' => $domain,
            'type' => 'vhost',
            'parent_domain_id' => 0,
            'vhost_type' => 'name',
            'hd_quota' => -1,
            'traffic_quota' => -1,
            'cgi' => 'y',
            'ssi' => 'y',
            'suexec' => 'y',
            'errordocs' => 1,
            'is_subdomainwww' => 1,
            'subdomain' => 'none',
            'php' => 'php-fpm',
            'ruby' => 'n',
            'redirect_type' => '',
            'redirect_path' => '',
            'ssl' => 'y',
            'ssl_action' => '',
            'stats_type' => 'webalizer',
            'allow_override' => 'All',
            'php_open_basedir' => '/',
            'pm' => 'ondemand',
            'pm_max_requests' => 0,
            'pm_process_idle_timeout' => 10,
            'backup_interval' => 'daily',
            'backup_copies' => 7,
            'backup_format_web' => 'default',
            'backup_format_db' => 'gzip',
            'active' => 'y',
            'http_port' => '80',
            'https_port' => '443'
        ];
        $res = restCall('sites_web_domain_add', ['session_id' => $session_id, 'client_id' => $cid, 'params' => $wparams]);
        echo "Web Domain $domain added: " . json_encode($res) . "\n";
    }

    // 4. DNS Zones & Records
    $dres = restCall('dns_zone_get', ['session_id' => $session_id, 'primary_id' => ['origin' => "$domain."]]);
    if (!isset($dres['response']['id'])) {
        $dparams = [
            'server_id' => 1,
            'origin' => "$domain.",
            'ns' => "ns1.$domain.",
            'mbox' => "hostmaster.$domain.",
            'serial' => date('Ymd01'),
            'refresh' => 7200,
            'retry' => 540,
            'expire' => 604800,
            'minimum' => 3600,
            'ttl' => 3600,
            'active' => 'y',
            'xfer' => '',
            'also_notify' => '',
            'update_acl' => ''
        ];
        $zres = restCall('dns_zone_add', ['session_id' => $session_id, 'client_id' => $cid, 'params' => $dparams]);
        $zone_id = $zres['response'];
        echo "DNS Zone $domain ID: $zone_id\n";

        $records = [
            ['name' => "$domain.", 'type' => 'A', 'data' => '192.168.126.110'],
            ['name' => 'www', 'type' => 'A', 'data' => '192.168.126.110'],
            ['name' => 'mail', 'type' => 'A', 'data' => '192.168.126.110'],
            ['name' => 'webmail', 'type' => 'A', 'data' => '192.168.126.110'],
            ['name' => 'ns1', 'type' => 'A', 'data' => '192.168.126.110'],
            ['name' => "$domain.", 'type' => 'NS', 'data' => "ns1.$domain."],
            ['name' => "$domain.", 'type' => 'MX', 'data' => "mail.$domain.", 'aux' => 10]
        ];

        foreach ($records as $r) {
            $rparams = array_merge([
                'server_id' => 1,
                'zone' => $zone_id,
                'aux' => 0,
                'ttl' => 3600,
                'active' => 'y',
                'stamp' => 'CURRENT_TIMESTAMP',
                'serial' => 1
            ], $r);
            restCall('dns_rr_add', ['session_id' => $session_id, 'client_id' => $cid, 'params' => $rparams]);
        }
    }

    // 5. Mail Domain & Mail Users
    $mres = restCall('mail_domain_get', ['session_id' => $session_id, 'primary_id' => ['domain' => $domain]]);
    if (!isset($mres['response']['domain_id'])) {
        $mparams = ['server_id' => 1, 'domain' => $domain, 'active' => 'y'];
        restCall('mail_domain_add', ['session_id' => $session_id, 'client_id' => $cid, 'params' => $mparams]);
        echo "Mail Domain $domain added\n";

        $mailboxes = ['contact', 'etudiant'];
        foreach ($mailboxes as $mb) {
            $mup = [
                'server_id' => 1,
                'email' => "$mb@$domain",
                'login' => "$mb@$domain",
                'password' => 'Passer@2026',
                'name' => "$mb",
                'uid' => 5000,
                'gid' => 5000,
                'maildir' => "/var/vmail/$domain/$mb",
                'quota' => 0,
                'homedir' => '/var/vmail',
                'autoresponder' => 'n',
                'move_junk' => 'n',
                'postfix' => 'y',
                'disableimap' => 'n',
                'disablepop3' => 'n',
                'disablesmtp' => 'n'
            ];
            restCall('mail_user_add', ['session_id' => $session_id, 'client_id' => $cid, 'params' => $mup]);
            echo "Mailbox $mb@$domain added\n";
        }
    }
}

restCall('logout', ['session_id' => $session_id]);
echo "Configuration complete.\n";
PHP

php /root/setup_ispconfig_api.php

# Déclencher le daemon de synchronisation ISPConfig
/usr/local/ispconfig/server/server.sh || true

echo "=================================================================="
echo " [6/8] Déploiement de WordPress + Redis Cache sur les 2 domaines"
echo "=================================================================="
if [ ! -f /usr/local/bin/wp ]; then
    curl -sL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp
    chmod +x /usr/local/bin/wp
fi

deploy_wp_ispconfig() {
    local dom="$1"
    local title="$2"
    local docroot="/var/www/${dom}/web"
    local dbname="wp_${dom//./_}"
    local dbuser="usr_${dom//./_}"

    mkdir -p "$docroot"

    mysql -u root -p"${ADMIN_PASS}" -e "CREATE DATABASE IF NOT EXISTS \`${dbname}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -u root -p"${ADMIN_PASS}" -e "CREATE USER IF NOT EXISTS '${dbuser}'@'localhost' IDENTIFIED BY '${ADMIN_PASS}';"
    mysql -u root -p"${ADMIN_PASS}" -e "GRANT ALL PRIVILEGES ON \`${dbname}\`.* TO '${dbuser}'@'localhost'; FLUSH PRIVILEGES;"

    rm -f "${docroot}/index.html" "${docroot}/index.htm"

    if [ ! -f "${docroot}/wp-config.php" ]; then
        wp core download --path="$docroot" --locale=fr_FR --force --allow-root
        wp config create \
            --path="$docroot" \
            --dbname="$dbname" \
            --dbuser="$dbuser" \
            --dbpass="$ADMIN_PASS" \
            --dbhost="localhost" \
            --extra-php <<PHP
define( 'WP_REDIS_HOST', '127.0.0.1' );
define( 'WP_REDIS_PORT', 6379 );
define( 'WP_CACHE_KEY_SALT', '${dom}_' );
define( 'FS_METHOD', 'direct' );
PHP
            --allow-root

        wp core install \
            --path="$docroot" \
            --url="https://${dom}" \
            --title="$title" \
            --admin_user="admin" \
            --admin_password="$ADMIN_PASS" \
            --admin_email="contact@${dom}" \
            --skip-email \
            --allow-root

        wp rewrite structure '/%postname%/' --path="$docroot" --allow-root
        wp plugin install redis-cache --activate --path="$docroot" --allow-root
        wp redis enable --path="$docroot" --allow-root || true

        wp post create \
            --path="$docroot" \
            --post_type=post \
            --post_status=publish \
            --post_title="Validation TP3 (ISPConfig 3) : Multidomaine, BIND9, Sauvegardes & Messagerie (${dom})" \
            --post_content="<p>Site de démonstration officiel hébergé sous le panneau d'administration <strong>ISPConfig 3</strong>.</p><ul><li><strong>Gestionnaire :</strong> ISPConfig 3.2+</li><li><strong>Serveur Web :</strong> Nginx + PHP-FPM</li><li><strong>Cache :</strong> Redis Object Cache actif (127.0.0.1:6379)</li><li><strong>Serveur DNS :</strong> BIND9 (Zone ${dom})</li><li><strong>Sauvegardes configurées :</strong> Quotidiennes (Rétention 7 copies)</li><li><strong>Messagerie :</strong> Postfix + Dovecot pour @${dom}</li></ul>" \
            --allow-root
    fi

    WEB_USER=$(stat -c '%U' "$docroot" 2>/dev/null || echo "www-data")
    [ "$WEB_USER" = "root" ] && WEB_USER="www-data"
    chown -R "${WEB_USER}:${WEB_USER}" "$docroot"
}

deploy_wp_ispconfig "elhadji.sn" "Portail Officiel ISPConfig — Elhadji"
deploy_wp_ispconfig "universite.sn" "Portail Universitaire ISPConfig — UCAD"

systemctl reload nginx || systemctl restart nginx
systemctl reload named || systemctl restart named

echo "=================================================================="
echo " [7/8] Configuration Messagerie Postfix & Script Camarade"
echo "=================================================================="
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

cat > /usr/local/bin/connecter-camarade <<'EOS'
#!/bin/bash
set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: connecter-camarade <domaine-camarade> <ip-serveur-camarade> [email-destinataire]"
    exit 1
fi

PEER_DOMAIN="$1"
PEER_IP="$2"
PEER_EMAIL="${3:-contact@${PEER_DOMAIN}}"

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

sed -i "/${PEER_DOMAIN}/d" /etc/hosts
echo "${PEER_IP} mail.${PEER_DOMAIN} ${PEER_DOMAIN}" >> /etc/hosts

sed -i "/^${PEER_DOMAIN} /d" /etc/postfix/transport
echo "${PEER_DOMAIN} smtp:[${PEER_IP}]:25" >> /etc/postfix/transport
postmap /etc/postfix/transport
systemctl reload postfix

swaks --to "${PEER_EMAIL}" \
      --from "contact@elhadji.sn" \
      --server 127.0.0.1 \
      --header "Subject: Test Interconnexion ISPConfig TP3" \
      --body "Bonjour camarade ! Courriel envoye depuis le serveur ISPConfig elhadji.sn."

sleep 2
tail -n 15 /var/log/mail.log
EOS
chmod +x /usr/local/bin/connecter-camarade

echo "=================================================================="
echo " [8/8] Test d'envoi de courriels en local"
echo "=================================================================="
swaks --to "contact@${DOMAIN2}" --from "contact@${DOMAIN1}" --server 127.0.0.1 \
    --header "Subject: Test ISPConfig Messagerie" --body "Test de contact@elhadji.sn vers contact@universite.sn" || true

echo "=================================================================="
echo " PROVISIONING ISPCONFIG 3 TERMINÉ AVEC SUCCÈS !"
echo "=================================================================="
