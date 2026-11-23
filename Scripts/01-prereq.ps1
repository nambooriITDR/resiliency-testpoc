$ErrorActionPreference = "Stop"

# --------------------------------------------------
# Repository Root
# --------------------------------------------------

$RepoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $RepoRoot

# --------------------------------------------------
# Helper Functions
# --------------------------------------------------

function Pass($Message) {
    Write-Host "[PASS] $Message" -ForegroundColor Green
}

function Fail($Message) {
    Write-Host "[FAIL] $Message" -ForegroundColor Red
    exit 1
}

function Info($Message) {
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

# --------------------------------------------------
# Banner
# --------------------------------------------------

Write-Host ""
Write-Host "================================================="
Write-Host " RESILIENCY TEST POC - PREREQUISITE VALIDATION"
Write-Host "================================================="
Write-Host ""

# --------------------------------------------------
# Docker Check
# --------------------------------------------------

Info "Checking Docker Engine..."

try {
    docker version | Out-Null
    Pass "Docker Engine available"
}
catch {
    Fail "Docker Engine is not running"
}

# --------------------------------------------------
# Repository Structure Validation
# --------------------------------------------------

Info "Validating repository structure..."

$requiredPaths = @(
    ".\docker-compose.yml",
    ".\flask",
    ".\app_files",
    ".\tmp",
    ".\Scripts"
)

foreach ($path in $requiredPaths) {

    if (Test-Path $path) {
        Pass "$path found"
    }
    else {
        Fail "$path missing"
    }
}

# --------------------------------------------------
# Application Files Validation
# --------------------------------------------------

Info "Checking application files..."

$requiredFiles = @(
    ".\flask\app.py",
    ".\flask\Dockerfile",
    ".\flask\requirements.txt"
)

foreach ($file in $requiredFiles) {

    if (Test-Path $file) {
        Pass "$file found"
    }
    else {
        Fail "$file missing"
    }
}

# --------------------------------------------------
# Compose Warning Check
# --------------------------------------------------

Info "Checking docker-compose.yml..."

$composeContent = Get-Content .\docker-compose.yml -Raw

if ($composeContent -match "(?m)^version:") {

    Write-Host ""
    Write-Host "[WARNING] Obsolete 'version:' attribute detected." -ForegroundColor Yellow
    Write-Host "[WARNING] Consider removing it from docker-compose.yml" -ForegroundColor Yellow
}

# --------------------------------------------------
# Start Infrastructure
# --------------------------------------------------

Info "Starting infrastructure..."

docker compose up -d --build

if ($LASTEXITCODE -ne 0) {
    Fail "docker compose deployment failed"
}

Pass "Infrastructure deployment initiated"

# --------------------------------------------------
# PostgreSQL Readiness
# --------------------------------------------------

Info "Waiting for PostgreSQL..."

$attempt = 0
$maxAttempts = 20

do {

    $attempt++

    try {

        $dbStatus = docker compose exec -T postgres `
            pg_isready `
            -U pocuser `
            -d pocdb

        if ($dbStatus -match "accepting connections") {

            Pass "PostgreSQL accepting connections"
            break
        }

    }
    catch {}

    Start-Sleep -Seconds 3

}
while ($attempt -lt $maxAttempts)

if ($attempt -eq $maxAttempts) {
    Fail "PostgreSQL never became ready"
}

# --------------------------------------------------
# Container Validation
# --------------------------------------------------

Info "Validating containers..."

$services = @(
    "postgres",
    "flask",
    "minio",
    "opensearch",
    "opensearch-dashboards"
)

foreach ($svc in $services) {

    $serviceCheck = docker compose ps $svc

    if ($serviceCheck -match "Up") {

        Pass "$svc running"
    }
    else {

        Fail "$svc not running"
    }
}

# --------------------------------------------------
# Flask Validation
# --------------------------------------------------

Info "Validating Flask API..."

try {

    $response = Invoke-RestMethod `
        -Uri "http://localhost:8080/" `
        -TimeoutSec 10

    if ($response.status -eq "ok") {
        Pass "Flask API reachable"
    }
    else {
        Fail "Unexpected Flask response"
    }

}
catch {

    Fail "Flask API unreachable"
}

# --------------------------------------------------
# MinIO Validation
# --------------------------------------------------

Info "Validating MinIO..."

try {

    Invoke-WebRequest `
        -Uri "http://localhost:9001" `
        -UseBasicParsing `
        -TimeoutSec 10 | Out-Null

    Pass "MinIO Console reachable"
}
catch {

    Fail "MinIO Console unreachable"
}

# --------------------------------------------------
# OpenSearch Validation
# --------------------------------------------------

Info "Validating OpenSearch..."

try {

    Invoke-RestMethod `
        -Uri "http://localhost:9200" `
        -TimeoutSec 10 | Out-Null

    Pass "OpenSearch reachable"
}
catch {

    Fail "OpenSearch unreachable"
}

# --------------------------------------------------
# Final Report
# --------------------------------------------------

Write-Host ""
Write-Host "================================================="
Write-Host " ENVIRONMENT READINESS REPORT"
Write-Host "================================================="
Write-Host ""

Write-Host "Docker Engine..........PASS" -ForegroundColor Green
Write-Host "Repository Structure...PASS" -ForegroundColor Green
Write-Host "PostgreSQL.............PASS" -ForegroundColor Green
Write-Host "Flask API..............PASS" -ForegroundColor Green
Write-Host "MinIO..................PASS" -ForegroundColor Green
Write-Host "OpenSearch.............PASS" -ForegroundColor Green

Write-Host ""
Write-Host "Environment Status : READY" -ForegroundColor Green

Write-Host ""
Write-Host "Next Step:"
Write-Host ".\Scripts\02-seed-workload.ps1"

Write-Host ""
Write-Host "================================================="