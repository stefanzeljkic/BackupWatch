#!/bin/bash

# 1. Set the frontend to non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# 2. Preemptively answer 'no' to any service restarts or configuration prompts
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git curl python3 python3-pip ufw

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
EOF'

# 6. Install the required libraries from requirements.txt without any prompts
sudo DEBIAN_FRONTEND=noninteractive pip3 install -r /opt/BackupWatch/requirements.txt

# 7. Ensure bleach, python-dotenv, and email_validator are installed
sudo DEBIAN_FRONTEND=noninteractive pip3 install bleach
sudo DEBIAN_FRONTEND=noninteractive pip3 install python-dotenv
sudo DEBIAN_FRONTEND=noninteractive pip3 install email_validator

# 8. Check if python-dotenv is installed correctly
if ! python3 -c "import dotenv" &> /dev/null; then
    echo "Error: python-dotenv failed to install."
    exit 1
fi

# 9. Enable UFW (firewall) non-interactively
echo "Enabling UFW (firewall)..."
echo "y" | sudo DEBIAN_FRONTEND=noninteractive ufw enable

# 10. Open port 8000 in the firewall
echo "Opening port 8000 in the firewall..."
sudo ufw allow 5000
sudo ufw allow 22


# 11. Create a systemd service file
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

# 12. Reload systemd, enable and start the service
echo "Reloading systemd, enabling and starting the BackupWatch service..."
sudo systemctl daemon-reload
sudo systemctl enable backupwatch.service
sudo systemctl start backupwatch.service


sudo ufw reload
echo "Installation and configuration are complete."
