# Face Recognition Backend - Stop Script
# This script stops all services

Write-Host "Stopping Face Recognition Backend Services..." -ForegroundColor Cyan
Write-Host ""

# Stop Docker services
Write-Host "Stopping Docker services..." -ForegroundColor Yellow
docker-compose down

if ($LASTEXITCODE -eq 0) {
    Write-Host "SUCCESS: Docker services stopped" -ForegroundColor Green
} else {
    Write-Host "WARNING: Error stopping Docker services" -ForegroundColor Yellow
}

# Display manual cleanup instructions
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Services Stopped" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Manual Steps:" -ForegroundColor White
Write-Host "   1. Close Face Detection Service window (Ctrl+C)" -ForegroundColor Yellow
Write-Host "   2. Close MQTT Bridge window (Ctrl+C)" -ForegroundColor Yellow
Write-Host ""
Write-Host "To verify all stopped:" -ForegroundColor White
Write-Host "   docker-compose ps" -ForegroundColor Gray
Write-Host ""
