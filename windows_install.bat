@echo off

REM Check if Git is installed
git --version >nul 2>&1
if errorlevel 1 (
    echo Git is not installed. Installing Git...

    REM Install Chocolatey if not already installed
    powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"

    REM Use Chocolatey to install Git
    choco install git -y

    REM Verify Git installation
    git --version >nul 2>&1
    if errorlevel 1 (
        echo Git installation failed. Please install Git manually.
        pause
        exit /b
    )
    echo Git installed successfully.
)

REM Clone GitHub repository
cd %TEMP%
git clone https://github.com/stefanzeljkic/BackupWatch.git

REM Create directory and move files
if not exist "C:\Program Files\BackupWatch" (
    mkdir "C:\Program Files\BackupWatch"
)
xcopy /E /I BackupWatch "C:\Program Files\BackupWatch"

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo Python is not installed. Installing Python...
    choco install python -y
    python --version >nul 2>&1
    if errorlevel 1 (
        echo Python installation failed. Please install Python manually.
        pause
        exit /b
    )
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
nssm install BackupWatch "python.exe" "C:\Program Files\BackupWatch\app.py"
nssm set BackupWatch Start SERVICE_AUTO_START

REM Start the service
nssm start BackupWatch

echo Installation complete. BackupWatch should now be running as a service.
pause
