Write-Host "  Deploying CrowdSec..." -ForegroundColor Cyan
docker rm -f crowdsec 2>$null
docker run -d --name crowdsec --network zt-network -p 8083:8080 crowdsecurity/crowdsec:latest
Start-Sleep -Seconds 10
@"
CROWDSEC_API=http://localhost:8083
STATUS=active
"@ | Out-File -FilePath "outputs/crowdsec_outputs.txt" -Encoding UTF8
Write-Host " CrowdSec ready: http://localhost:8083" -ForegroundColor Green
