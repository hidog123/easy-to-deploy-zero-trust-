Write-Host " Deploying Keycloak IAM..." -ForegroundColor Cyan
docker rm -f keycloak 2>$null
docker run -d --name keycloak --network zt-network -p 8080:8080 -e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin123 quay.io/keycloak/keycloak:latest start-dev
Write-Host "Waiting for Keycloak..." -ForegroundColor Yellow
Start-Sleep -Seconds 20
@"
KEYCLOAK_URL=http://localhost:8080
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin123
STATUS=active
"@ | Out-File -FilePath "outputs/keycloak_outputs.txt" -Encoding UTF8
Write-Host " Keycloak ready: http://localhost:8080 (admin/admin123)" -ForegroundColor Green
