#!/bin/bash

# 1. Install basic packages
sudo apt-get install -y git curl python3 python3-pip ufw

# 2. Configure dpkg if it was interrupted previously
sudo dpkg --configure -a

# 3. Clone the GitHub repository
if [ -d "BackupWatch" ]; then
    echo "BackupWatch directory already exists. Updating the repository..."
    cd BackupWatch
    git pull origin main
else
    echo "Cloning the repository..."
    git clone https://github.com/stefanzeljkic/BackupWatch.git
    cd BackupWatch
fi

# 4. Install the required libraries from requirements.txt if it exists
#    and force the installation of specific versions of Flask, Werkzeug, Flask-WTF, and Jinja2
if [ -f "requirements.txt" ]; then
    pip3 install --user --force-reinstall Flask==2.0.1 Werkzeug==2.0.1 Flask-WTF==0.14.3 Jinja2==3.0.1 SQLAlchemy==1.4.15 requests==2.25.1
else
    echo "requirements.txt file not found, installing Flask and Flask-WTF manually..."
    pip3 install --user Flask==2.0.1 Werkzeug==2.0.1 Flask-WTF==0.14.3 Jinja2==3.0.1
fi

# 5. Enable UFW (firewall)
echo "Enabling UFW (firewall)..."
sudo ufw enable

# 6. Open port 8000 in the firewall
echo "Opening port 8000 in the firewall..."
sudo ufw allow 8000
sudo ufw reload

# 7. Create a systemd service file
echo "Creating systemd service file..."
sudo bash -c 'cat <<EOF > /etc/systemd/system/backupwatch.service
[Unit]
Description=BackupWatch Service
After=network.target

[Service]
User=backupwatch
WorkingDirectory=/home/backupwatch/BackupWatch
ExecStart=/usr/bin/python3 /home/backupwatch/BackupWatch/app.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

# 8. Enable and start the systemd service
echo "Enabling and starting the BackupWatch service..."
sudo systemctl daemon-reload
sudo systemctl enable backupwatch.service
sudo systemctl start backupwatch.service

echo "Installation and configuration are complete."
