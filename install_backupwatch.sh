#!/bin/bash

# 1. Update the system and install basic packages
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
if [ -f "requirements.txt" ]; then
    pip3 install -r requirements.txt
else
    echo "requirements.txt file not found, installing Flask manually..."
    pip3 install flask
fi

# 5. Create a systemd service file
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

# 6. Enable and start the systemd service
echo "Enabling and starting the BackupWatch service..."
sudo systemctl daemon-reload
sudo systemctl enable backupwatch.service
sudo systemctl start backupwatch.service

# 7. Open port 8000 in the firewall
echo "Opening port 8000 in the firewall..."
sudo ufw allow 8000
sudo ufw reload

echo "Installation and configuration are complete."
