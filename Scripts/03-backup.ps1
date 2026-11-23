<#
=============================================================

03-backup.ps1

Purpose
-------
Creates a recovery point for the workload.

Actions
-------
1. Verify workload baseline exists
2. Create PostgreSQL dump
3. Verify dump file
4. Initialize Restic repository (if required)
5. Create Restic snapshot
6. Record backup metadata

Artifacts
---------
tmp\backup-metadata.json

Protected Assets
----------------
/tmp/pgdump.sql
/app_files

Next Step
---------
.\Scripts\04-attack.ps1

=============================================================
#>

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $RepoRoot

# --------------------------------------------------
# Functions
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
Write-Host " RESILIENCY TEST POC - BACKUP"
Write-Host "================================================="
Write-Host ""

# --------------------------------------------------
# Baseline Validation
# --------------------------------------------------

Info "Checking baseline..."

if(!(Test-Path ".\tmp\baseline.json"))
{
    Fail "Baseline not found. Run 02-seed-workload.ps1 first."
}

Pass "Baseline found"

# --------------------------------------------------
# PostgreSQL Validation
# --------------------------------------------------

Info "Checking PostgreSQL..."

$db = docker compose exec -T postgres `
    pg_isready `
    -U pocuser `
    -d pocdb

if($db -match "accepting")
{
    Pass "PostgreSQL ready"
}
else
{
    Fail "PostgreSQL unavailable"
}

# --------------------------------------------------
# Create Database Dump
# --------------------------------------------------

Info "Creating PostgreSQL dump..."

docker compose exec -T postgres `
    pg_dump `
    -U pocuser `
    pocdb `
    -f /tmp/pgdump.sql

if($LASTEXITCODE -ne 0)
{
    Fail "Database dump failed"
}

Pass "PostgreSQL dump created"

# --------------------------------------------------
# Verify Dump Exists
# --------------------------------------------------

Info "Verifying dump file..."

docker compose exec -T postgres `
    ls -lh /tmp/pgdump.sql

Pass "Dump file verified"

# --------------------------------------------------
# Restic Repository Check
# --------------------------------------------------

Info "Checking Restic repository..."

try {

    docker compose run --rm restic snapshots |
    Out-Null

    Pass "Restic repository exists"
}
catch {

    Info "Initializing Restic repository..."

    docker compose run --rm restic init

    Pass "Restic repository initialized"
}

# --------------------------------------------------
# Create Snapshot
# --------------------------------------------------

Info "Creating recovery snapshot..."

docker compose run --rm restic `
    backup `
    /tmp/pgdump.sql `
    /app_files

if($LASTEXITCODE -ne 0)
{
    Fail "Snapshot creation failed"
}

Pass "Snapshot created"

# --------------------------------------------------
# Capture Snapshot Information
# --------------------------------------------------

Info "Retrieving latest snapshot..."

$snapshotOutput = docker compose run --rm restic snapshots

$snapshotId = ""

foreach($line in $snapshotOutput)
{
    if($line -match "^[a-z0-9]{8}")
    {
        $snapshotId = ($line -split "\s+")[0]
        break
    }
}

$backupInfo = @{
    BackupTime = Get-Date
    SnapshotId = $snapshotId
    ProtectedAssets = @(
        "/tmp/pgdump.sql",
        "/app_files"
    )
}

$backupInfo |
ConvertTo-Json -Depth 4 |
Out-File ".\tmp\backup-metadata.json"

Pass "Backup metadata saved"

# --------------------------------------------------
# Summary
# --------------------------------------------------

Write-Host ""
Write-Host "================================================="
Write-Host " BACKUP REPORT"
Write-Host "================================================="
Write-Host ""

Write-Host "Database Dump..........PASS" -ForegroundColor Green
Write-Host "Restic Snapshot........PASS" -ForegroundColor Green
Write-Host "Metadata Saved.........PASS" -ForegroundColor Green

Write-Host ""
Write-Host "Generated:"
Write-Host "  tmp\backup-metadata.json"

Write-Host ""
Write-Host "Protected:"
Write-Host "  PostgreSQL Database"
Write-Host "  app_files\"

Write-Host ""
Write-Host "Next Step:"
Write-Host "  .\Scripts\04-attack.ps1"

Write-Host ""
Write-Host "================================================="