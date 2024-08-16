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

# Instalacija Apache, Certbot i Python modula, bez interaktivnih pitanja
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confnew" install apache2 certbot python3-certbot-apache

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

# Nabavka SSL sertifikata preko Let's Encrypt-a
sudo certbot --apache --non-interactive --agree-tos -d "$DOMAIN" -m "$EMAIL"

# Kreiranje Apache virtual host-a za preusmeravanje saobraćaja na aplikaciju koja radi na localhost:8000
APACHE_CONF="/etc/apache2/sites-available/$DOMAIN.conf"

echo "<VirtualHost *:80>
    ServerName $DOMAIN
    ProxyPreserveHost On
    ProxyPass / http://localhost:8000/
    ProxyPassReverse / http://localhost:8000/
</VirtualHost>

<VirtualHost *:443>
    SSLEngine on
    ServerName $DOMAIN

    Header always set Strict-Transport-Security \"max-age=31536000; includeSubDomains\"
    SSLCertificateFile /etc/letsencrypt/live/$DOMAIN/cert.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN/privkey.pem
    SSLCertificateChainFile /etc/letsencrypt/live/$DOMAIN/chain.pem

    ProxyPreserveHost On
    ProxyPass / http://localhost:8000/
    ProxyPassReverse / http://localhost:8000/
</VirtualHost>" | sudo tee "$APACHE_CONF"

# Omogućavanje novog virtual host-a
sudo a2ensite "$DOMAIN.conf"

# Restartovanje Apache-a da bi se primenile promene
sudo systemctl restart apache2

# Kreiranje cron zadatka za obnovu SSL sertifikata na svakih 30 dana
(crontab -l 2>/dev/null; echo "0 0 1 * * /usr/sbin/service apache2 stop && /usr/bin/certbot renew && /usr/sbin/service apache2 start") | crontab -

echo "Instalacija i konfiguracija je završena. Vaša aplikacija bi sada trebala biti dostupna na https://$DOMAIN"
echo "Kreiran je cron zadatak za automatsku obnovu SSL sertifikata svakog prvog dana u mesecu."
