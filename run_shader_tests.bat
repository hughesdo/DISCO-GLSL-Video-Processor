@echo off
echo ========================================
echo GLSL Shader Test Runner
echo ========================================
echo.

REM Activate virtual environment
echo Activating virtual environment...
call disco_venv\Scripts\activate.bat

REM Check if Videos directory exists
if not exist "Videos" (
    echo ERROR: Videos directory not found!
    echo Please create a Videos directory and add some video and audio files.
    echo.
    pause
    exit /b 1
)

REM Create Outputs directory if it doesn't exist
if not exist "Outputs" (
    echo Creating Outputs directory...
    mkdir Outputs
)

echo.
echo Starting shader test suite...
echo This will test all shaders with random video/audio inputs
echo Each shader will render 250 frames as a preview
echo.

REM Run the shader test runner
python shader_test_runner.py

echo.
echo ========================================
echo Test run complete!
echo Check the Outputs folder for results
echo ========================================
pause
