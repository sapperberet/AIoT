# Face Recognition Backend - Quick Start
# This script starts all services for the hybrid Windows setup

Write-Host "Starting Face Recognition Backend Services..." -ForegroundColor Cyan
Write-Host ""

# Check if .env file exists
if (-not (Test-Path ".env")) {
    Write-Host "WARNING: .env file not found!" -ForegroundColor Yellow
    Write-Host "Creating .env from template..." -ForegroundColor Yellow
    Copy-Item ".env.example" ".env"
    Write-Host ""
    Write-Host "IMPORTANT: Edit .env and set your WiFi IP address!" -ForegroundColor Red
    Write-Host "   Find your IP with: ipconfig" -ForegroundColor Yellow
    Write-Host "   Then update MQTT_BROKER in .env file" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter after you've updated .env"
}

# Load environment variables from .env file
if (Test-Path ".env") {
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^([^#][^=]*)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($name, $value, "Process")
        }
    }
}

# Check if Docker is running
Write-Host "Checking Docker..." -ForegroundColor Cyan
try {
    $null = docker ps 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Docker is not running! Please start Docker Desktop." -ForegroundColor Red
        exit 1
    }
    Write-Host "SUCCESS: Docker is running" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Docker is not installed or not running!" -ForegroundColor Red
    exit 1
}

# Check if virtual environment exists
Write-Host ""
Write-Host "Checking Python virtual environment..." -ForegroundColor Cyan
if (-not (Test-Path "venv\Scripts\Activate.ps1")) {
    Write-Host "Virtual environment not found!" -ForegroundColor Yellow
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to create virtual environment!" -ForegroundColor Red
        Write-Host "Make sure Python 3.11+ is installed" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "SUCCESS: Virtual environment created" -ForegroundColor Green
} else {
    Write-Host "SUCCESS: Virtual environment exists" -ForegroundColor Green
}

# Activate virtual environment and install dependencies
Write-Host ""
Write-Host "Installing dependencies..." -ForegroundColor Cyan
Write-Host "(This may take 5-10 minutes on first run)" -ForegroundColor Yellow

& "venv\Scripts\Activate.ps1"

# Check if dependencies are installed
$pipList = pip list 2>&1
if ($pipList -notmatch "face-recognition") {
    Write-Host "Installing Python packages..." -ForegroundColor Yellow
    pip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to install dependencies!" -ForegroundColor Red
        exit 1
    }
    Write-Host "SUCCESS: Dependencies installed" -ForegroundColor Green
} else {
    Write-Host "SUCCESS: Dependencies already installed" -ForegroundColor Green
}

# Create directories if they don't exist
Write-Host ""
Write-Host "Checking directories..." -ForegroundColor Cyan
if (-not (Test-Path "persons")) {
    New-Item -ItemType Directory -Path "persons" | Out-Null
    Write-Host "Created persons/ directory" -ForegroundColor Yellow
}
if (-not (Test-Path "captures")) {
    New-Item -ItemType Directory -Path "captures" | Out-Null
    Write-Host "Created captures/ directory" -ForegroundColor Yellow
}

# Check if face images exist
$faceImages = Get-ChildItem -Path "persons" -Filter "*.jpg" -ErrorAction SilentlyContinue
if ($faceImages.Count -eq 0) {
    Write-Host ""
    Write-Host "WARNING: No face images found in persons/ directory!" -ForegroundColor Yellow
    Write-Host "Add face images before testing authentication:" -ForegroundColor Yellow
    Write-Host "  Copy-Item 'C:\Path\To\Photo.jpg' -Destination 'persons\yourname.jpg'" -ForegroundColor Gray
    Write-Host ""
}

# Start Docker services
Write-Host ""
Write-Host "Starting Docker services..." -ForegroundColor Cyan
docker-compose up -d mosquitto broker-beacon

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to start Docker services!" -ForegroundColor Red
    exit 1
}

# Wait for services to be ready
Write-Host "Waiting for services to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# Check Docker services
$dockerStatus = docker-compose ps
Write-Host ""
Write-Host "Docker Services Status:" -ForegroundColor Cyan
Write-Host $dockerStatus

# Start Face Detection Service in new window
Write-Host ""
Write-Host "Starting Face Detection Service..." -ForegroundColor Cyan
$faceServiceCmd = "cd '$PWD'; & venv\Scripts\Activate.ps1; python app.py; Read-Host 'Press Enter to close'"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $faceServiceCmd

# Wait a bit for face service to start
Start-Sleep -Seconds 2

# Start MQTT Bridge in new window
Write-Host "Starting MQTT Bridge..." -ForegroundColor Cyan
$bridgeCmd = "cd '$PWD'; & venv\Scripts\Activate.ps1; python face_auth_bridge.py; Read-Host 'Press Enter to close'"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $bridgeCmd

# Wait for services to initialize
Write-Host ""
Write-Host "Waiting for services to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Test services
Write-Host ""
Write-Host "Testing services..." -ForegroundColor Cyan

# Test face service health
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8000/healthz" -TimeoutSec 5
    if ($health.ok -eq $true) {
        Write-Host "SUCCESS: Face Detection Service is running" -ForegroundColor Green
    }
} catch {
    Write-Host "WARNING: Face Detection Service may not be ready yet" -ForegroundColor Yellow
    Write-Host "Check the Face Service window for errors" -ForegroundColor Yellow
}

# Check beacon logs
Write-Host ""
Write-Host "Checking beacon broadcasts..." -ForegroundColor Cyan
$beaconLogs = docker-compose logs --tail=5 broker-beacon
if ($beaconLogs -match "sent GLOBAL") {
    Write-Host "SUCCESS: Beacon is broadcasting" -ForegroundColor Green
} else {
    Write-Host "WARNING: Beacon may not be broadcasting correctly" -ForegroundColor Yellow
}

# Display summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "All Services Started!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Service Status:" -ForegroundColor White
Write-Host "   Docker Services: Running" -ForegroundColor Green
Write-Host "   Face Detection:  http://localhost:8000" -ForegroundColor Green
Write-Host "   MQTT Bridge:     Running" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor White
Write-Host "   1. Check both service windows for any errors" -ForegroundColor Yellow
Write-Host "   2. Add face images to persons/ directory (if not done)" -ForegroundColor Yellow
Write-Host "   3. Run your Flutter app and test authentication" -ForegroundColor Yellow
Write-Host ""
Write-Host "To stop all services:" -ForegroundColor White
Write-Host "   Run: .\stop.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "For troubleshooting, see COMPLETE_WORKFLOW.md" -ForegroundColor Gray
Write-Host ""
