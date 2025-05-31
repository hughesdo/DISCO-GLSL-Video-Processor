@echo off
title GLSL Shader Video Processor
echo ========================================
echo GLSL Shader Video Processor Startup
echo ========================================

REM Use a different name to avoid conflict with existing .venv file
set VENV_NAME=disco_venv

REM Create virtual environment if needed
if not exist "%VENV_NAME%\Scripts\activate.bat" (
    echo Creating virtual environment...
    python -m venv %VENV_NAME%
    if errorlevel 1 (
        echo ERROR: Failed to create virtual environment
        echo Make sure Python is installed and in your PATH
        pause
        exit /b 1
    )
    echo Virtual environment created successfully!
)

REM Activate virtual environment
echo Activating virtual environment...
call %VENV_NAME%\Scripts\activate.bat

REM Install dependencies
if exist "requirements.txt" (
    echo Installing/updating dependencies...
    python -m pip install --upgrade pip
    python -m pip install -r requirements.txt
) else (
    echo Installing basic dependencies...
    python -m pip install fastapi uvicorn librosa numpy moderngl pillow
)

REM Start server and open browser
echo.
echo Starting FastAPI server...
echo Server will be available at: http://localhost:8000
echo.

REM Start server in background
start /b python -m uvicorn main:app --reload --port 8000

REM Wait for server to start
timeout /t 3 /nobreak >nul

REM Open browser
echo Opening browser...
start http://localhost:8000

echo.
echo ========================================
echo Application is running!
echo Press Ctrl+C to stop the server
echo Close this window to exit
echo ========================================
echo.

REM Show server output
python -m uvicorn main:app --reload --port 8000