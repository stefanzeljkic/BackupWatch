@echo off

echo Starting BackupWatch installation...

REM Check if Git is installed and in PATH
echo Checking if Git is installed...
git --version >nul 2>&1
if errorlevel 1 (
    echo Git is not installed or not in PATH. Attempting to add Git to PATH...

    REM Add Git to PATH manually
    set "gitPath=C:\Program Files\Git\cmd"
    if exist "%gitPath%\git.exe" (
        echo Adding %gitPath% to PATH...
        setx PATH "%PATH%;%gitPath%"
        refreshenv
    ) else (
        echo Git executable not found in %gitPath%. Please install Git manually.
        pause
        exit /b
    )
    echo Git added to PATH successfully.

    REM Verify Git installation
    echo Verifying Git installation...
    git --version
    if errorlevel 1 (
        echo Git installation verification failed. Please install Git manually.
        pause
        exit /b
    )
    echo Git installation verified successfully.
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
echo Setting up BackupWatch in Program Files...
if not exist "C:\Program Files\BackupWatch" (
    mkdir "C:\Program Files\BackupWatch"
)
xcopy /E /I BackupWatch "C:\Program Files\BackupWatch"
if errorlevel 1 (
    echo Failed to move BackupWatch files to Program Files.
    pause
    exit /b
)
echo BackupWatch files moved successfully.

REM Install required Python packages
echo Installing Python packages...
cd "C:\Program Files\BackupWatch"
pip install -r requirements.txt
if errorlevel 1 (
    echo Failed to install Python packages.
    pause
    exit /b
)
echo Python packages installed successfully.

REM Open port 8000
echo Opening port 8000...
netsh advfirewall firewall add rule name="Open Port 8000" dir=in action=allow protocol=TCP localport=8000
if errorlevel 1 (
    echo Failed to open port 8000.
    pause
    exit /b
)
echo Port 8000 opened successfully.

REM Install and configure NSSM to run app.py as a service
echo Setting up NSSM for BackupWatch...
cd %TEMP%
powershell -command "Invoke-WebRequest -Uri https://nssm.cc/release/nssm-2.24.zip -OutFile nssm.zip"
powershell -command "Expand-Archive -Path nssm.zip -DestinationPath . -Force"
move nssm-2.24\win64\nssm.exe "C:\Windows\System32\"
if errorlevel 1 (
    echo Failed to set up NSSM.
    pause
    exit /b
)
echo NSSM set up successfully.

REM Check if BackupWatch service exists and remove it
nssm status BackupWatch >nul 2>&1
if not errorlevel 1 (
    echo BackupWatch service already exists. Removing existing service...
    nssm remove BackupWatch confirm
    if errorlevel 1 (
        echo Failed to remove existing BackupWatch service.
        pause
        exit /b
    )
    echo Existing BackupWatch service removed successfully.
)

REM Set up the service
echo Installing BackupWatch as a service...
nssm install BackupWatch "python.exe" "C:\Program Files\BackupWatch\app.py"
nssm set BackupWatch Start SERVICE_AUTO_START
if errorlevel 1 (
    echo Failed to install BackupWatch as a service.
    pause
    exit /b
)
echo BackupWatch service installed successfully.

REM Start the service
echo Starting BackupWatch service...
nssm start BackupWatch
if errorlevel 1 (
    echo Failed to start BackupWatch service.
    pause
    exit /b
)
echo BackupWatch service started successfully.

echo Installation complete. BackupWatch should now be running as a service.
pause
