@echo off
echo ========================================
echo DISCO GLSL Video Processor - Installer
echo ========================================
echo.

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

REM Check if Python is installed
echo [1/5] Checking Python installation...
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed or not in PATH!
    echo Please install Python 3.8 or higher from https://www.python.org/
    echo Make sure to check "Add Python to PATH" during installation.
    pause
    exit /b 1
)
echo Python found!
python --version
echo.

REM Check if pip is available
echo [2/5] Checking pip...
python -m pip --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: pip is not available!
    echo Installing pip...
    python -m ensurepip --upgrade
)
echo pip is ready!
echo.

REM Create virtual environment
set VENV_NAME=disco_venv
echo [3/5] Setting up virtual environment...
if not exist "%SCRIPT_DIR%%VENV_NAME%\Scripts\activate.bat" (
    echo Creating virtual environment...
    python -m venv "%SCRIPT_DIR%%VENV_NAME%"
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment!
        pause
        exit /b 1
    )
    echo Virtual environment created!
) else (
    echo Virtual environment already exists.
)
echo.

REM Activate venv and install dependencies
echo [4/5] Installing Python packages into virtual environment...
echo This may take a few minutes...
call "%SCRIPT_DIR%%VENV_NAME%\Scripts\activate.bat"
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo ERROR: Failed to install Python packages!
    pause
    exit /b 1
)
echo Python packages installed successfully!
echo.

REM Check for FFmpeg
echo [5/5] Checking FFmpeg installation...
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo WARNING: FFmpeg not found in PATH!
    echo.
    echo DISCO requires FFmpeg for video processing.
    echo.
    echo Install options:
    echo   1. Download from: https://www.gyan.dev/ffmpeg/builds/
    echo      Extract the zip, then add the "bin" folder to your system PATH.
    echo   2. choco install ffmpeg   (if you have Chocolatey)
    echo   3. winget install ffmpeg  (Windows 10/11)
    echo.
    echo After installing FFmpeg, you can run this installer again to verify,
    echo or just launch the app with startapp.bat.
    echo.
) else (
    echo FFmpeg found!
    ffmpeg -version 2>&1 | findstr "ffmpeg version"
    echo.
)

echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo To start the application, run: startapp.bat
echo Then open your browser to: http://localhost:8000
echo.
echo See install.txt for detailed instructions and troubleshooting.
echo.
pause
