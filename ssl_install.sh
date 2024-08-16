#!/bin/bash

# Check if the script is running with root privileges
if [ "$(id -u)" -ne 0 ]; then
   echo "Please run the script as root or use sudo."
   exit 1
fi

# Prompt for the domain and email address
read -p "Enter the domain (e.g., example.com): " DOMAIN < /dev/tty
if [ -z "$DOMAIN" ]; then
    echo "Domain cannot be empty. Please enter a valid domain."
    exit 1
fi

read -p "Enter the email for Let's Encrypt: " EMAIL < /dev/tty
if [ -z "$EMAIL" ]; then
    echo "Email cannot be empty. Please enter a valid email."
    exit 1
fi

# Update packages
sudo apt update

# Install Apache, Certbot, and Python modules without interactive prompts
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confnew" install apache2 certbot python3-certbot-apache

# Install required Apache modules
sudo a2enmod ssl
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2enmod proxy_balancer
sudo a2enmod lbmethod_byrequests
sudo a2enmod headers

# Open ports 80 and 443
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Stop Apache to free port 80
sudo systemctl stop apache2

# Attempt to obtain an SSL certificate via standalone mode
if ! sudo certbot certonly --non-interactive --agree-tos --standalone -d "$DOMAIN" -m "$EMAIL"; then
    echo "Failed to obtain SSL certificate via standalone mode."
    echo "Switching to DNS-01 challenge method."

    # Use DNS-01 challenge instead
    echo "Please add the following DNS TXT record and press Enter to continue:"
    sudo certbot certonly --manual --preferred-challenges=dns -d "$DOMAIN" --agree-tos -m "$EMAIL" --manual-public-ip-logging-ok

    echo "Press Enter to continue after adding the DNS TXT record."
    read -p ""
    
    if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        echo "Failed to obtain SSL certificate via DNS-01 challenge."
        exit 1
    fi
fi

# Start Apache again
sudo systemctl start apache2

# Configure Apache to use the obtained SSL certificate
APACHE_CONF="/etc/apache2/sites-available/$DOMAIN.conf"

echo "<VirtualHost *:80>
    ServerName $DOMAIN
    ProxyPreserveHost On
    ProxyPass / http://localhost:5000/
    ProxyPassReverse / http://localhost:5000/
</VirtualHost>

<VirtualHost *:443>
    SSLEngine on
    ServerName $DOMAIN

    Header always set Strict-Transport-Security \"max-age=31536000; includeSubDomains\"
    SSLCertificateFile /etc/letsencrypt/live/$DOMAIN/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN/privkey.pem
    SSLCertificateChainFile /etc/letsencrypt/live/$DOMAIN/chain.pem

    ProxyPreserveHost On
    ProxyPass / http://localhost:5000/
    ProxyPassReverse / http://localhost:5000/
</VirtualHost>" | sudo tee "$APACHE_CONF"

# Enable the new virtual host
sudo a2ensite "$DOMAIN.conf"

# Restart Apache to apply the changes
sudo systemctl restart apache2

# Create a cron job to renew SSL certificates every 30 days
(crontab -l 2>/dev/null; echo "0 0 1 * * /usr/sbin/service apache2 stop && /usr/bin/certbot renew && /usr/sbin/service apache2 start") | crontab -

echo "Installation and configuration are complete. Your application should now be accessible at https://$DOMAIN"
echo "A cron job has been created for automatic SSL certificate renewal on the first day of each month."
