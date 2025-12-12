Write-Host " Deploying ZTNA..." -ForegroundColor Cyan
docker rm -f ztna-tunnel 2>$null
docker run -d --name ztna-tunnel --network zt-network -p 8081:80 nginx:alpine
Start-Sleep -Seconds 3
@"
TUNNEL_URL=http://localhost:8081
STATUS=active
"@ | Out-File -FilePath "outputs/ztna_outputs.txt" -Encoding UTF8
Write-Host " ZTNA ready: http://localhost:8081" -ForegroundColor Green
