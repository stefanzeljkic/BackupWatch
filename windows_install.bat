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

REM Continue with the rest of the script...

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

REM Continue with Python installation and other setup steps...
