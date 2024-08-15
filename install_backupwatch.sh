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

# 4. Create or update the requirements.txt file
echo "Creating/updating requirements.txt file..."
cat <<EOF > requirements.txt
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
EOF

# 5. Install the required libraries from requirements.txt
pip3 install --user -r requirements.txt

# 6. Install bleach separately if not installed from requirements.txt
pip3 install --user bleach

# 7. Enable UFW (firewall)
echo "Enabling UFW (firewall)..."
sudo ufw enable

# 8. Open port 8000 in the firewall
echo "Opening port 8000 in the firewall..."
sudo ufw allow 8000
sudo ufw reload

# 9. Create a systemd service file
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

# 10. Enable and start the systemd service
echo "Enabling and starting the BackupWatch service..."
sudo systemctl daemon-reload
sudo systemctl enable backupwatch.service
sudo systemctl start backupwatch.service

echo "Installation and configuration are complete."
