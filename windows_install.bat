@echo off

echo Starting BackupWatch installation...

REM Check if Chocolatey is installed
echo Checking if Chocolatey is installed...
choco --version >nul 2>&1
if errorlevel 1 (
    echo Chocolatey is not installed. Installing Chocolatey...
    @"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
    if errorlevel 1 (
        echo Failed to install Chocolatey.
        pause
        exit /b
    )
    echo Chocolatey installed successfully.
)

REM Update PATH for Chocolatey
SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
refreshenv

REM Check if Git is installed
echo Checking if Git is installed...
git --version >nul 2>&1
if errorlevel 1 (
    echo Git is not installed. Installing Git using Chocolatey...
    choco install git -y
    if errorlevel 1 (
        echo Failed to install Git.
        pause
        exit /b
    )
    echo Git installed successfully.
)

REM Check if Python is installed
echo Checking if Python is installed...
python --version >nul 2>&1
if errorlevel 1 (
    echo Python is not installed. Installing Python using Chocolatey...
    choco install python -y
    if errorlevel 1 (
        echo Failed to install Python.
        pause
        exit /b
    )
    echo Python installed successfully.
)

REM Update PATH for Python
SET "PATH=%PATH%;C:\Python39\;C:\Python39\Scripts\"
refreshenv

REM Check if BackupWatch directory already exists and remove it
if exist "%TEMP%\BackupWatch" (
    echo Removing existing BackupWatch directory...
    rmdir /s /q "%TEMP%\BackupWatch"
    if errorlevel 1 (
        echo Failed to remove existing BackupWatch directory.
        pause
        exit /b
    )
    echo Existing BackupWatch directory removed successfully.
)

REM Clone BackupWatch repository
echo Cloning BackupWatch repository...
cd %TEMP%
git clone https://github.com/stefanzeljkic/BackupWatch.git
if errorlevel 1 (
    echo Failed to clone BackupWatch repository.
    pause
    exit /b
)
echo BackupWatch repository cloned successfully.

REM Create directory and move files
echo Setting up BackupWatch in C:\BackupWatch...
if not exist "C:\BackupWatch" (
    mkdir "C:\BackupWatch"
)
xcopy /E /I BackupWatch "C:\BackupWatch"
if errorlevel 1 (
    echo Failed to move BackupWatch files to C:\BackupWatch.
    pause
    exit /b
)
echo BackupWatch files moved successfully.

REM Install required Python packages
echo Installing Python packages...
cd "C:\BackupWatch"
pip install -r requirements.txt
if errorlevel 1 (
    echo Failed to install Python packages.
    pause
    exit /b
)
echo Python packages installed successfully.

REM Install requests package
echo Installing requests package...
pip install requests
if errorlevel 1 (
    echo Failed to install requests package.
    pause
    exit /b
)
echo Requests package installed successfully.

REM Open port 5000
echo Opening port 5000...
netsh advfirewall firewall add rule name="Open Port 5000" dir=in action=allow protocol=TCP localport=5000
if errorlevel 1 (
    echo Failed to open port 5000.
    pause
    exit /b
)
echo Port 5000 opened successfully.

REM Install and configure NSSM
echo Setting up NSSM for BackupWatch...
cd %TEMP%
powershell -command "Invoke-WebRequest -Uri https://nssm.cc/release/nssm-2.24.zip -OutFile nssm.zip"
powershell -command "Expand-Archive -Path nssm.zip -DestinationPath . -Force"
if not exist "C:\Program Files\NSSM" (
    mkdir "C:\Program Files\NSSM"
)
move nssm-2.24\win64\nssm.exe "C:\Program Files\NSSM\"
if errorlevel 1 (
    echo Failed to set up NSSM.
    pause
    exit /b
)
echo NSSM set up successfully.

echo Installation complete. NSSM is installed, but the BackupWatch service has not been configured.
pause
