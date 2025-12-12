#Requires -RunAsAdministrator

$ErrorActionPreference = "Continue"

function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warn { Write-Host $args -ForegroundColor Yellow }

Clear-Host
Write-Info @"


                                                                  
     ZERO TRUST ARCHITECTURE DEPLOYMENT - WINDOWS EDITION     
                                                                  
   Complete Enterprise Security Stack                            
    Identity & Access Management (Keycloak)                    
    Policy Engine (Open Policy Agent)                          
    Zero Trust Network Access                                  
    Threat Protection (CrowdSec)                              
                                                                  
═

"@

Start-Sleep -Seconds 2

# Check Docker
Write-Info "`n Checking prerequisites..."

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host " Docker is not installed" -ForegroundColor Red
    Write-Warn "Install Docker Desktop: https://www.docker.com/products/docker-desktop"
    exit 1
}

try {
    docker version | Out-Null
    Write-Success " Docker is running"
} catch {
    Write-Host " Docker is not running" -ForegroundColor Red
    Write-Warn "Please start Docker Desktop and try again"
    exit 1
}

# Create structure
Write-Info "`n Creating project structure..."
@("config", "config/traefik", "scripts", "outputs", "policies", "logs") | ForEach-Object {
    New-Item -Path $_ -ItemType Directory -Force | Out-Null
}
Write-Success " Project structure created"

# Create network
Write-Info "`n Setting up Docker network..."
try {
    $existing = docker network ls --filter name=zt-network --format "{{.Name}}"
    if ($existing -ne "zt-network") {
        docker network create zt-network | Out-Null
        Write-Success " Network 'zt-network' created"
    } else {
        Write-Warn "  Network 'zt-network' already exists"
    }
} catch {
    Write-Warn "  Network creation skipped"
}

# Deploy components
function Deploy-Component {
    param([string]$Name, [string]$Script, [string]$Desc)
    
    Write-Info "`n Deploying $Name..."
    Write-Host "   $Desc" -ForegroundColor DarkGray
    
    if (Test-Path $Script) {
        try {
            $StartTime = Get-Date
            & $Script
            $Duration = (Get-Date) - $StartTime
            Write-Success " $Name deployed ($('{0:N1}' -f $Duration.TotalSeconds)s)"
            return $true
        } catch {
            Write-Host " $Name failed: $_" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Warn "  Script not found: $Script"
        return $false
    }
}

Write-Info "`n=== STAGE 1: Keycloak IAM ==="
Deploy-Component "Keycloak" "scripts/02_keycloak_setup.ps1" "Authentication & Authorization"

Write-Info "`n=== STAGE 2: OPA Policy Engine ==="
Deploy-Component "OPA" "scripts/03_opa_setup.ps1" "Dynamic Policy Evaluation"

Write-Info "`n=== STAGE 3: ZTNA Tunnel ==="
Deploy-Component "ZTNA" "scripts/04_ztna_setup.ps1" "Secure Access Gateway"

Write-Info "`n=== STAGE 4: Traefik Proxy ==="
Deploy-Component "Traefik" "scripts/06_traefik_setup.ps1" "Reverse Proxy with Policy Enforcement"

Write-Info "`n=== STAGE 5: CrowdSec ==="
Deploy-Component "CrowdSec" "scripts/07_crowdsec_setup.ps1" "Threat Intelligence"

# Summary
Write-Info "`n"
Write-Info "                  DEPLOYMENT COMPLETE!                          "
Write-Info ""

Write-Host "`n Access Points:" -ForegroundColor Cyan
Write-Host "    Keycloak:    " -NoNewline; Write-Success "http://localhost:8080"
Write-Host "    OPA:         " -NoNewline; Write-Success "http://localhost:8181/health"
Write-Host "    Traefik:     " -NoNewline; Write-Success "http://localhost:9000/dashboard/"
Write-Host "    ZTNA:        " -NoNewline; Write-Success "http://localhost:8081"
Write-Host "    CrowdSec:    " -NoNewline; Write-Success "http://localhost:8083"

Write-Host "`n Default Credentials:" -ForegroundColor Cyan
Write-Host "   Keycloak: admin / admin123"

Write-Host "`n Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Test deployment:  " -NoNewline; Write-Success ".\test_zero_trust.ps1"
Write-Host "   2. View containers:  " -NoNewline; Write-Success "docker ps"
Write-Host "   3. Check logs:       " -NoNewline; Write-Success "docker logs <container-name>"

Write-Host "`n Running Containers:" -ForegroundColor Cyan
try {
    docker ps --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" | Select-String -Pattern "keycloak|opa|ztna|traefik|crowdsec"
} catch {
    Write-Warn "Could not list containers"
}
