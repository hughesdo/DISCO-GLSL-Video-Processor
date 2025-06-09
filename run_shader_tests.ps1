# GLSL Shader Test Runner - PowerShell Version
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "GLSL Shader Test Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Activate virtual environment
Write-Host "Activating virtual environment..." -ForegroundColor Yellow
& "disco_venv\Scripts\Activate.ps1"

# Check if Videos directory exists
if (-not (Test-Path "Videos")) {
    Write-Host "ERROR: Videos directory not found!" -ForegroundColor Red
    Write-Host "Please create a Videos directory and add some video and audio files." -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Create Outputs directory if it doesn't exist
if (-not (Test-Path "Outputs")) {
    Write-Host "Creating Outputs directory..." -ForegroundColor Green
    New-Item -ItemType Directory -Path "Outputs" | Out-Null
}

Write-Host ""
Write-Host "Starting shader test suite..." -ForegroundColor Green
Write-Host "This will test all shaders with random video/audio inputs" -ForegroundColor White
Write-Host "Each shader will render 250 frames as a preview" -ForegroundColor White
Write-Host ""

# Run the shader test runner
python shader_test_runner.py

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test run complete!" -ForegroundColor Green
Write-Host "Check the Outputs folder for results" -ForegroundColor White
Write-Host "========================================" -ForegroundColor Cyan
Read-Host "Press Enter to exit"
