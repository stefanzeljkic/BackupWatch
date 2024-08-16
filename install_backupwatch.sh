#!/bin/bash

# 1. Set the frontend to non-interactive to avoid prompts during package installation
export DEBIAN_FRONTEND=noninteractive

# 2. Preemptively answer 'no' to any service restarts or configuration prompts
sudo apt-get install -y git curl python3 python3-pip ufw nginx software-properties-common

# 3. Configure dpkg if it was interrupted previously
sudo dpkg --configure -a

# 4. Clone the GitHub repository
if [ -d "/opt/BackupWatch" ]; then
    echo "BackupWatch directory already exists. Updating the repository..."
    cd /opt/BackupWatch
    sudo git pull origin main
else
    echo "Cloning the repository..."
    sudo git clone https://github.com/stefanzeljkic/BackupWatch.git /opt/BackupWatch
    cd /opt/BackupWatch
fi

# 5. Create or update the requirements.txt file
echo "Creating/updating requirements.txt file..."
sudo bash -c 'cat <<EOF > /opt/BackupWatch/requirements.txt
blinker==1.8.2
click==8.1.7
colorama==0.4.6
Flask==3.0.3
Flask-WTF==1.2.1
greenlet==3.0.3
itsdangerous==2.2.0
Jinja2==3.1.4
MarkupSafe==2.1.5
SQLAlchemy==2.0.32
typing_extensions==4.12.2
Werkzeug==3.0.3
WTForms==3.1.2
bleach
python-dotenv
email_validator
EOF'

# 6. Install the required libraries from requirements.txt without any prompts
sudo pip3 install -r /opt/BackupWatch/requirements.txt

# 7. Ensure bleach, python-dotenv, and email_validator are installed
sudo pip3 install bleach
sudo pip3 install python-dotenv
sudo pip3 install email_validator

# 8. Check if python-dotenv is installed correctly
if ! python3 -c "import dotenv" &> /dev/null; then
    echo "Error: python-dotenv failed to install."
    exit 1
fi

# 9. Enable UFW (firewall) non-interactively
echo "Enabling UFW (firewall)..."
echo "y" | sudo ufw enable

# 10. Open port 8000 in the firewall
echo "Opening port 8000 in the firewall..."
sudo ufw allow 8000
sudo ufw reload

# 11. Install Nginx
echo "Installing Nginx..."
sudo apt-get install -y nginx

# 12. Get domain name and email for SSL certificate
read -p "Enter your domain name (e.g., example.com): " domain_name
read -p "Enter your email address for SSL certificate: " email_address

# 13. Configure Nginx as a reverse proxy
echo "Configuring Nginx..."
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

# Enable Nginx site configuration
sudo ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# 14. Install Certbot for SSL certificate
echo "Installing Certbot and obtaining SSL certificate..."
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d $domain_name -d www.$domain_name --non-interactive --agree-tos --email $email_address

# 15. Set up auto-renewal for SSL certificate
echo "Setting up auto-renewal for SSL certificate..."
sudo bash -c "cat > /etc/cron.d/certbot-renew <<EOF
0 0 1 */2 * root certbot renew --quiet --post-hook 'systemctl reload nginx'
EOF"

sudo chmod 0644 /etc/cron.d/certbot-renew

# 16. Create a systemd service file
echo "Creating systemd service file..."
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

# 17. Reload systemd, enable and start the service
echo "Reloading systemd, enabling and starting the BackupWatch service..."
sudo systemctl daemon-reload
sudo systemctl enable backupwatch.service
sudo systemctl start backupwatch.service

echo "Installation and configuration are complete."
