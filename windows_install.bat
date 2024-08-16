@echo off

echo Starting BackupWatch installation...

REM Check if Git is installed
git --version >nul 2>&1
if errorlevel 1 (
    echo Git is not installed. Installing Git...

    REM Install Chocolatey if not already installed
    echo Installing Chocolatey...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
    if errorlevel 1 (
        echo Failed to install Chocolatey. Please check the Chocolatey installation manually.
        pause
        exit /b
    )
    echo Chocolatey installed successfully.

    REM Use Chocolatey to force reinstall Git
    echo Forcing Git installation via Chocolatey...
    choco install git -y --force
    if errorlevel 1 (
        echo Git installation via Chocolatey failed. Please install Git manually.
        pause
        exit /b
    )
    echo Git installed successfully.

    REM Refresh environment variables
    echo Refreshing environment variables...
    refreshenv
    if errorlevel 1 (
        echo Failed to refresh environment variables.
        pause
        exit /b
    )
    echo Environment variables refreshed.

    REM Attempt to find Git executable
    for /r "C:\Program Files" %%i in (git.exe) do set "gitPath=%%i"
    if "%gitPath%"=="" (
        echo Git installation not found. Please install Git manually.
        pause
        exit /b
    )
    echo Git found at %gitPath%.

    REM Add Git to PATH if not already there
    setx PATH "%PATH%;%gitPath%"
    if errorlevel 1 (
        echo Failed to update PATH with Git installation path.
        pause
        exit /b
    )
    echo PATH updated with Git installation path.

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

REM Continue with the rest of the script...
