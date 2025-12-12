Write-Host "  Deploying OPA..." -ForegroundColor Cyan
docker rm -f opa 2>$null
docker run -d --name opa --network zt-network -p 8181:8181 openpolicyagent/opa:latest run --server --addr=:8181
Start-Sleep -Seconds 5
@"
package zta.abac
default allow = false
allow {
    input.identity.authenticated == true
    input.device.compliant == true
}
"@ | Out-File -FilePath "policies/abac.rego" -Encoding UTF8
try { Invoke-RestMethod -Uri "http://localhost:8181/v1/policies/zta" -Method PUT -Body (Get-Content "policies/abac.rego" -Raw) -ContentType "text/plain" | Out-Null } catch {}
@"
OPA_URL=http://localhost:8181
STATUS=active
"@ | Out-File -FilePath "outputs/opa_outputs.txt" -Encoding UTF8
Write-Host " OPA ready: http://localhost:8181" -ForegroundColor Green
