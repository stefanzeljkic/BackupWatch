#!/bin/bash

# Install necessary packages
sudo apt-get update
sudo apt-get install -y git curl python3 python3-pip ufw nginx software-properties-common

# Clone the GitHub repository or pull the latest changes
if [ -d "/opt/BackupWatch" ]; then
    echo "BackupWatch directory already exists. Updating the repository..."
    cd /opt/BackupWatch
    sudo git pull origin main
else
    echo "Cloning the repository..."
    sudo git clone https://github.com/stefanzeljkic/BackupWatch.git /opt/BackupWatch
    cd /opt/BackupWatch
fi

# Install the required libraries from requirements.txt
sudo pip3 install -r /opt/BackupWatch/requirements.txt
sudo pip3 install bleach python-dotenv email_validator

# Enable UFW and open the necessary ports
sudo ufw enable
sudo ufw allow 8000
sudo ufw reload

# Install Nginx and Certbot
sudo apt-get install -y certbot python3-certbot-nginx

# Prompt for domain and email
read -p "Enter your domain name (e.g., example.com): " domain_name
read -p "Enter your email address for SSL certificate: " email_address

# Configure Nginx as a reverse proxy
sudo bash -c "cat > /etc/nginx/sites-available/$domain_name <<EOF
server {
    listen 80;
    server_name $domain_name www.$domain_name;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /.well-known/acme-challenge/ {
        allow all;
    }

    return 301 https://\$host\$request_uri;
}
EOF"

# Enable the new Nginx configuration
sudo ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# Obtain SSL certificate
sudo certbot --nginx -d $domain_name -d www.$domain_name --email $email_address --agree-tos --redirect

# Set up auto-renewal for SSL certificate
sudo bash -c "cat > /etc/cron.d/certbot-renew <<EOF
0 0 1 */2 * root certbot renew --quiet --post-hook 'systemctl reload nginx'
EOF"

sudo chmod 0644 /etc/cron.d/certbot-renew

# Create a systemd service file for BackupWatch
sudo bash -c 'cat <<EOF > /etc/systemd/system/backupwatch.service
[Unit]
Description=BackupWatch Service
After=network.target

[Service]
User=root
WorkingDirectory=/opt/BackupWatch
ExecStart=/usr/bin/python3 /opt/BackupWatch/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

# Reload systemd and start the service
sudo systemctl daemon-reload
sudo systemctl enable backupwatch.service
sudo systemctl start backupwatch.service

echo "Installation and configuration are complete."
