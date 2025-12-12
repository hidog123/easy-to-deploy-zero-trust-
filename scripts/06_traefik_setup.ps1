Write-Host " Deploying Traefik..." -ForegroundColor Cyan
docker rm -f traefik 2>$null
@"
api:
  dashboard: true
  insecure: true
entryPoints:
  web:
    address: ":80"
  traefik:
    address: ":9000"
providers:
  docker:
    endpoint: "npipe:////./pipe/docker_engine"
    exposedByDefault: false
log:
  level: INFO
"@ | Out-File -FilePath "config/traefik/traefik.yml" -Encoding UTF8
$cfg = (Resolve-Path "config/traefik/traefik.yml").Path
docker run -d --name traefik --network zt-network -p 80:80 -p 9000:9000 -v "//./pipe/docker_engine://./pipe/docker_engine" -v "${cfg}:/etc/traefik/traefik.yml" traefik:latest
Start-Sleep -Seconds 5
@"
TRAEFIK_URL=http://localhost:9000
STATUS=active
"@ | Out-File -FilePath "outputs/traefik_outputs.txt" -Encoding UTF8
Write-Host " Traefik ready: http://localhost:9000/dashboard/" -ForegroundColor Green
