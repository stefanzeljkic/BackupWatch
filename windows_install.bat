@echo off

echo Starting BackupWatch installation...

REM Check if Chocolatey is installed and in PATH
echo Checking if Chocolatey is installed...
choco --version >nul 2>&1
if errorlevel 1 (
    echo Chocolatey is not installed. Installing Chocolatey...
    
    REM Install Chocolatey
    @powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))" >nul 2>&1
    
    REM Add Chocolatey to PATH manually
    setx PATH "%PATH%;C:\ProgramData\chocolatey\bin"
    refreshenv
    
    echo Chocolatey installed successfully.
) else (
    echo Chocolatey is already installed.
)

REM Ensure choco command is available
choco --version >nul 2>&1
if errorlevel 1 (
    echo Chocolatey command not recognized. Manually adding Chocolatey to PATH...
    setx PATH "%PATH%;C:\ProgramData\chocolatey\bin"
    refreshenv
    echo Chocolatey added to PATH.
)

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
) else (
    echo Git is already installed.
)

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

REM Clone GitHub repository
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
