@echo off

REM Check if Git is installed
git --version >nul 2>&1
if errorlevel 1 (
    echo Git is not installed. Installing Git...

    REM Download Git installer using bitsadmin
    bitsadmin /transfer "GitDownloadJob" https://github.com/git-for-windows/git/releases/download/v2.42.0.windows.1/Git-2.42.0-64-bit.exe "%TEMP%\git-installer.exe"

    REM Install Git silently
    start /wait %TEMP%\git-installer.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART

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
    bitsadmin /transfer "PythonDownloadJob" https://www.python.org/ftp/python/3.9.7/python-3.9.7-amd64.exe "%TEMP%\python-installer.exe"
    start /wait %TEMP%\python-installer.exe /quiet InstallAllUsers=1 PrependPath=1
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
bitsadmin /transfer "NSSMDownloadJob" https://nssm.cc/release/nssm-2.24.zip "%TEMP%\nssm.zip"
powershell -command "Expand-Archive -Path %TEMP%\nssm.zip -DestinationPath %TEMP%\nssm"
move %TEMP%\nssm\win64\nssm.exe "C:\Windows\System32\"

REM Set up the service
nssm install BackupWatch "python.exe" "C:\Program Files\BackupWatch\app.py"
nssm set BackupWatch Start SERVICE_AUTO_START

REM Start the service
nssm start BackupWatch

echo Installation complete. BackupWatch should now be running as a service.
pause
