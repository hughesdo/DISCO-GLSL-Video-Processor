@echo off
echo ========================================
echo DISCO GLSL Video Processor - Installer
echo ========================================
echo.

REM Check if Python is installed
echo [1/4] Checking Python installation...
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
echo [2/4] Checking pip...
python -m pip --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: pip is not available!
    echo Installing pip...
    python -m ensurepip --upgrade
)
echo pip is ready!
echo.

REM Install Python requirements
echo [3/4] Installing Python packages...
echo This may take a few minutes...
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
echo [4/4] Checking FFmpeg installation...
ffmpeg -version >nul 2>&1
if %errorlevel% neq 0 (
    echo FFmpeg not found in PATH!
    echo.
    echo OPTION 1 - Manual Installation (Recommended):
    echo   1. Download FFmpeg from: https://www.gyan.dev/ffmpeg/builds/
    echo   2. Extract the zip file
    echo   3. Add the 'bin' folder to your system PATH
    echo   4. Restart this installer
    echo.
    echo OPTION 2 - Use Chocolatey (if installed):
    echo   Run: choco install ffmpeg
    echo.
    echo OPTION 3 - Use winget (Windows 10/11):
    echo   Run: winget install ffmpeg
    echo.
    echo Please install FFmpeg and run this installer again.
    pause
    exit /b 1
) else (
    echo FFmpeg found!
    ffmpeg -version | findstr "ffmpeg version"
)
echo.

echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo All dependencies are installed and ready!
echo.
echo To start the application, run: startapp.bat
echo Then open your browser to: http://localhost:8000
echo.
pause

