#!/bin/bash
# P01 - preparation de vm3 (serveur, LAN2 192.168.20.10)
# Installe : FTP (vsftpd), Telnet, Apache avec authentification basique, HTTPS (auto-signe), SSH
# ATTENTION : services volontairement non securises, uniquement pour le lab isole.

set -e
export DEBIAN_FRONTEND=noninteractive

LAB_USER="labuser"
LAB_PASS="Lab@2026"
WEB_USER="webadmin"
WEB_PASS="Secret2026"

echo "[1/6] Installation des paquets"
apt-get update -y
apt-get install -y vsftpd telnetd openbsd-inetd apache2 apache2-utils openssh-server openssl

echo "[2/6] Compte systeme de test (Telnet, FTP, SSH)"
id "$LAB_USER" >/dev/null 2>&1 || useradd -m -s /bin/bash "$LAB_USER"
echo "$LAB_USER:$LAB_PASS" | chpasswd
echo "Fichier de test P01 - contenu confidentiel" > /home/$LAB_USER/confidentiel.txt
chown $LAB_USER:$LAB_USER /home/$LAB_USER/confidentiel.txt

echo "[3/6] FTP (vsftpd, en clair, ports passifs 40000-40010)"
cp -n /etc/vsftpd.conf /etc/vsftpd.conf.orig
cat > /etc/vsftpd.conf <<'EOF'
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
pam_service_name=vsftpd
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40010
EOF
systemctl restart vsftpd
systemctl enable vsftpd

echo "[4/6] Telnet (via inetd, en clair, port 23)"
update-inetd --enable telnet || true
systemctl restart openbsd-inetd
systemctl enable openbsd-inetd

echo "[5/6] Apache : zone protegee par authentification basique"
mkdir -p /var/www/html/prive
cat > /var/www/html/prive/index.html <<'EOF'
<html><body><h1>Zone privee - Projet P01</h1>
<p>Si vous lisez ceci, l'authentification a reussi.</p></body></html>
EOF
htpasswd -bc /etc/apache2/.htpasswd-p01 "$WEB_USER" "$WEB_PASS"
cat > /etc/apache2/conf-available/p01-auth.conf <<'EOF'
<Directory /var/www/html/prive>
    AllowOverride None
    AuthType Basic
    AuthName "Zone privee P01"
    AuthUserFile /etc/apache2/.htpasswd-p01
    Require valid-user
</Directory>
EOF
a2enconf p01-auth

echo "[6/6] HTTPS : certificat auto-signe + site 443"
a2enmod ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -subj "/C=MG/O=ESTI/CN=web.esti.mg" \
  -keyout /etc/ssl/private/p01.key -out /etc/ssl/certs/p01.crt
cat > /etc/apache2/sites-available/p01-ssl.conf <<'EOF'
<VirtualHost *:443>
    ServerName web.esti.mg
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/p01.crt
    SSLCertificateKeyFile /etc/ssl/private/p01.key
    ErrorLog ${APACHE_LOG_DIR}/p01-ssl-error.log
    CustomLog ${APACHE_LOG_DIR}/p01-ssl-access.log combined
</VirtualHost>
EOF
a2ensite p01-ssl
systemctl enable ssh
systemctl restart ssh
apache2ctl configtest
systemctl restart apache2

echo
echo "===== Ports a l'ecoute ====="
ss -ltn | grep -E ':(21|22|23|80|443) ' || true
echo
echo "Comptes de test :"
echo "  Telnet / FTP / SSH : $LAB_USER / $LAB_PASS"
echo "  HTTP/HTTPS /prive  : $WEB_USER / $WEB_PASS"
