#!/bin/bash

# 1. Update sistem i instaliraj osnovne pakete
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y git curl

# 2. Instaliraj Python ako već nije instaliran
if ! command -v python3 &> /dev/null; then
    sudo apt-get install -y python3
fi

if ! command -v pip3 &> /dev/null; then
    sudo apt-get install -y python3-pip
fi

# 3. Kloniraj GitHub repozitorijum
if [ -d "BackupWatch" ]; then
    echo "Direktorijum BackupWatch već postoji. Ažuriranje repozitorijuma..."
    cd BackupWatch
    git pull origin main
else
    echo "Kloniranje repozitorijuma..."
    git clone https://github.com/stefanzeljkic/BackupWatch.git
    cd BackupWatch
fi

# 4. Instaliraj potrebne biblioteke iz requirements.txt
pip3 install -r requirements.txt

# 5. Pokreni aplikaciju
echo "Pokretanje aplikacije..."
python3 app.py
