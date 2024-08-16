#!/bin/bash

# Proveravamo da li se skripta pokreće sa root privilegijama
if [ "$(id -u)" -ne 0 ]; then
   echo "Molimo pokrenite skriptu kao root ili koristite sudo."
   exit 1
fi

# Prvo ćemo tražiti unos domena i emaila
read -p "Unesite domen (npr. example.com): " DOMAIN < /dev/tty
if [ -z "$DOMAIN" ]; then
    echo "Domen ne može biti prazan. Molimo unesite validan domen."
    exit 1
fi

read -p "Unesite email za Let's Encrypt: " EMAIL < /dev/tty
if [ -z "$EMAIL" ]; then
    echo "Email ne može biti prazan. Molimo unesite validan email."
    exit 1
fi

# Ažuriranje paketa
sudo apt update

# Instalacija Apache
sudo apt install -y apache2

# Provera statusa Apache-a
sudo systemctl status apache2

# Instalacija potrebnih modula za Apache
sudo a2enmod ssl
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_balancer
sudo a2enmod lbmethod_byrequests
sudo a2enmod headers

# Otvaranje portova 80 i 443
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Instalacija Certbot-a za Let's Encrypt
sudo apt install -y certbot python3-certbot-apache

# Nabavka SSL sertifikata preko Let's Encrypt-a
sudo certbot --apache --non-interactive --agree-tos -d "$DOMAIN" -m "$EMAIL"

# Kreiranje Apache virtual host-a za preusmeravanje saobraćaja na aplikaciju koja radi na portu 8000
APACHE_CONF="/etc/apache2/sites-available/$DOMAIN.conf"

echo "<VirtualHost *:80>
    ServerName $DOMAIN
    Redirect permanent / https://$DOMAIN/
</VirtualHost>

<VirtualHost *:443>
    ServerName $DOMAIN

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf

    ProxyPreserveHost On
    ProxyPass / http://127.0.0.1:8000/
    ProxyPassReverse / http://127.0.0.1:8000/

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>" | sudo tee "$APACHE_CONF"

# Omogućavanje novog virtual host-a
sudo a2ensite "$DOMAIN.conf"

# Restartovanje Apache-a da bi se primenile promene
sudo systemctl restart apache2

echo "Instalacija i konfiguracija je završena. Vaša aplikacija bi sada trebala biti dostupna na https://$DOMAIN"
