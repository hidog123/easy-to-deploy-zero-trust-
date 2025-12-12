Write-Host " Testing Zero Trust Architecture..." -ForegroundColor Cyan
function Test-Service {
    param($Name, $Url)
    Write-Host "`nTesting $Name..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $Url -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop | Out-Null
        Write-Host " $Name is accessible" -ForegroundColor Green
    } catch {
        Write-Host " $Name failed" -ForegroundColor Red
    }
}
Test-Service "Keycloak" "http://localhost:8080"
Test-Service "OPA" "http://localhost:8181/health"
Test-Service "Traefik" "http://localhost:9000"
Test-Service "ZTNA" "http://localhost:8081"
Write-Host "`n Running Containers:" -ForegroundColor Cyan
docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"
