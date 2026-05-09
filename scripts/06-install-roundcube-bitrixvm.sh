#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

require_root
require_confirm

mkdir -p /var/www
cd /var/www

if [ ! -d "$ROUNDCUBE_DIR" ]; then
  wget -O roundcube.tar.gz "https://github.com/roundcube/roundcubemail/releases/download/${ROUNDCUBE_VERSION}/roundcubemail-${ROUNDCUBE_VERSION}-complete.tar.gz"
  tar -xzf roundcube.tar.gz
  mv "roundcubemail-${ROUNDCUBE_VERSION}" "$ROUNDCUBE_DIR"
fi

mkdir -p "$ROUNDCUBE_DIR/db" "$ROUNDCUBE_DIR/logs" "$ROUNDCUBE_DIR/temp"

cat > "$ROUNDCUBE_DIR/config/config.inc.php" <<EOF2
<?php

\$config['db_dsnw'] = 'sqlite:////$ROUNDCUBE_DIR/db/roundcube.sqlite?mode=0646';

\$config['imap_host'] = 'tls://127.0.0.1:143';
\$config['imap_conn_options'] = array(
  'ssl' => array(
    'verify_peer' => false,
    'verify_peer_name' => false,
  ),
);

\$config['smtp_host'] = 'tls://$MAIL_HOST:587';
\$config['smtp_user'] = '%u';
\$config['smtp_pass'] = '%p';

\$config['support_url'] = '';
\$config['product_name'] = 'Company Mail';
\$config['des_key'] = '$(openssl rand -base64 24)';
\$config['plugins'] = array('archive', 'zipdownload');
\$config['skin'] = 'elastic';
\$config['enable_installer'] = false;
\$config['default_charset'] = 'UTF-8';
EOF2

chown -R "$APACHE_USER:$APACHE_GROUP" "$ROUNDCUBE_DIR"
find "$ROUNDCUBE_DIR" -type d -exec chmod 755 {} \;
find "$ROUNDCUBE_DIR" -type f -exec chmod 644 {} \;
chmod -R 775 "$ROUNDCUBE_DIR/temp" "$ROUNDCUBE_DIR/logs" "$ROUNDCUBE_DIR/db"
chown -R "$APACHE_USER:$APACHE_GROUP" "$ROUNDCUBE_DIR/temp" "$ROUNDCUBE_DIR/logs" "$ROUNDCUBE_DIR/db"

mkdir -p /etc/httpd/bx/conf /etc/nginx/bx/site_avaliable /etc/nginx/bx/site_enabled

cat > "/etc/httpd/bx/conf/bx_ext_${MAIL_HOST}.conf" <<EOF2
<VirtualHost $APACHE_BACKEND>
    ServerName $MAIL_HOST
    DocumentRoot $ROUNDCUBE_DIR
    DirectoryIndex index.php index.html

    <Directory "$ROUNDCUBE_DIR">
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <Directory "$ROUNDCUBE_DIR/config">
        Require all denied
    </Directory>

    <Directory "$ROUNDCUBE_DIR/temp">
        Require all denied
    </Directory>

    <Directory "$ROUNDCUBE_DIR/logs">
        Require all denied
    </Directory>

    <Directory "$ROUNDCUBE_DIR/SQL">
        Require all denied
    </Directory>

    ErrorLog /var/log/httpd/${MAIL_HOST}_error.log
    CustomLog /var/log/httpd/${MAIL_HOST}_access.log combined
</VirtualHost>
EOF2

backend_port="${APACHE_BACKEND##*:}"
cat > "/etc/nginx/bx/site_avaliable/bx_ext_${MAIL_HOST}.conf" <<EOF2
server {
    listen 80;
    server_name $MAIL_HOST;

    root $ROUNDCUBE_DIR;
    index index.php index.html;

    include /etc/nginx/bx/conf/letsencrypt-challenge-tokens.conf;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        proxy_pass http://$APACHE_BACKEND;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header HTTPS off;
        proxy_set_header X-Forwarded-Proto http;
    }

    location ~ ^/(README|INSTALL|LICENSE|CHANGELOG|UPGRADING)$ {
        deny all;
    }

    location ~ ^/(config|temp|logs|SQL)/ {
        deny all;
    }
}
EOF2

ln -sf "/etc/nginx/bx/site_avaliable/bx_ext_${MAIL_HOST}.conf" "/etc/nginx/bx/site_enabled/bx_ext_${MAIL_HOST}.conf"

httpd -t
nginx -t
systemctl reload httpd
systemctl reload nginx

echo "Check: curl -I http://$MAIL_HOST"
