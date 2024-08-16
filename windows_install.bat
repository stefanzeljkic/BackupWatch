@echo off

REM Download GitHub repository
cd %TEMP%
git clone https://github.com/stefanzeljkic/BackupWatch.git

REM Create directory and move files
mkdir "C:\Program Files\BackupWatch"
move BackupWatch "C:\Program Files\BackupWatch"

REM Install Python if not installed
if not exist "C:\Python39\python.exe" (
    echo Installing Python...
    powershell -command "Invoke-WebRequest -Uri https://www.python.org/ftp/python/3.9.7/python-3.9.7-amd64.exe -OutFile python-installer.exe"
    start /wait python-installer.exe /quiet InstallAllUsers=1 PrependPath=1
)

REM Install required Python packages
cd "C:\Program Files\BackupWatch"
pip install -r requirements.txt

REM Open port 8000
netsh advfirewall firewall add rule name="Open Port 8000" dir=in action=allow protocol=TCP localport=8000

REM Install and configure NSSM to run app.py as a service
cd %TEMP%
powershell -command "Invoke-WebRequest -Uri https://nssm.cc/release/nssm-2.24.zip -OutFile nssm.zip"
powershell -command "Expand-Archive -Path nssm.zip -DestinationPath ."
move nssm-2.24\win64\nssm.exe "C:\Windows\System32\"

REM Set up the service
nssm install BackupWatch "C:\Python39\python.exe" "C:\Program Files\BackupWatch\app.py"
nssm set BackupWatch Start SERVICE_AUTO_START

REM Start the service
nssm start BackupWatch

echo Installation complete. BackupWatch should now be running as a service.
pause
