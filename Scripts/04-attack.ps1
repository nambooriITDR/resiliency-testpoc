<#
=========================================================

04-attack.ps1

Purpose
-------
Simulates a cyber attack against the protected workload.

Actions
-------
1. Validate baseline exists
2. Validate backup metadata exists
3. Clear blocking PostgreSQL sessions
4. Destroy database schema
5. Verify database destruction
6. Delete protected file
7. Verify business impact
8. Generate attack report

Output
------
tmp\attack-report.json

Next Step
---------
.\Scripts\05-restore.ps1

=========================================================
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
Write-Host " RESILIENCY TEST POC - ATTACK SIMULATION"
Write-Host "================================================="
Write-Host ""

# --------------------------------------------------
# Validate Inputs
# --------------------------------------------------

Info "Checking baseline..."

if (!(Test-Path ".\tmp\baseline.json")) {
    Fail "baseline.json not found"
}

Pass "Baseline found"

Info "Checking backup metadata..."

if (!(Test-Path ".\tmp\backup-metadata.json")) {
    Fail "backup-metadata.json not found"
}

Pass "Backup metadata found"

# --------------------------------------------------
# Remove Blocking Sessions
# --------------------------------------------------

Info "Removing blocking PostgreSQL sessions..."

docker compose exec -T postgres `
    psql `
    -U pocuser `
    -d pocdb `
    -c "
    SELECT pg_terminate_backend(pid)
    FROM pg_stat_activity
    WHERE state='idle in transaction'
    AND pid <> pg_backend_pid();
    " | Out-Null

Pass "Blocking sessions cleared"

# --------------------------------------------------
# Start Timer
# --------------------------------------------------

$attackStart = Get-Date

# --------------------------------------------------
# Destroy Database
# --------------------------------------------------

Info "Destroying database schema..."

docker compose exec -T postgres `
    psql `
    -U pocuser `
    -d pocdb `
    -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

Pass "Database schema destroyed"

# --------------------------------------------------
# Verify Tables Gone
# --------------------------------------------------

Info "Verifying database destruction..."

$tableCountRaw = docker compose exec -T postgres `
    psql `
    -U pocuser `
    -d pocdb `
    -t `
    -A `
    -c "
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema='public';
    "

$tableCount = ($tableCountRaw | Out-String).Trim()

$tableDestroyed = $false

if ($tableCount -eq "0")
{
    $tableDestroyed = $true
    Pass "Database objects removed"
}
else
{
    Fail "Tables still exist"
}

# --------------------------------------------------
# Delete Recovery File
# --------------------------------------------------

Info "Deleting recovery file..."

$fileName = ".\app_files\recovery-test.txt"

if (Test-Path $fileName)
{
    Remove-Item $fileName -Force
}

$fileDeleted = !(Test-Path $fileName)

if ($fileDeleted)
{
    Pass "Recovery file deleted"
}
else
{
    Fail "Recovery file still exists"
}

# --------------------------------------------------
# Validate Business Impact
# --------------------------------------------------

Info "Validating application impact..."

$businessImpactObserved = $false

try
{
    Invoke-RestMethod `
        -Uri "http://localhost:8080/list" `
        -TimeoutSec 10 | Out-Null
}
catch
{
    $businessImpactObserved = $true
}

if ($businessImpactObserved)
{
    Pass "Business impact confirmed"
}
else
{
    Fail "Application still functional"
}

# --------------------------------------------------
# --------------------------------------------------
# Attack Duration
# --------------------------------------------------

$attackEnd = Get-Date

$attackDuration = [Math]::Round(
    ($attackEnd - $attackStart).TotalSeconds,
    2
)

# --------------------------------------------------
# Generate Attack Report
# --------------------------------------------------

$attackReport = @{
    AttackTime             = Get-Date
    AttackDurationSeconds  = $attackDuration
    DatabaseDestroyed      = $tableDestroyed
    FileDeleted            = $fileDeleted
    BusinessImpactObserved = $businessImpactObserved
    AttackStatus           = "SUCCESS"
}

$attackReport |
ConvertTo-Json -Depth 5 |
Out-File ".\tmp\attack-report.json"

Pass "Attack report generated"

# --------------------------------------------------
# Summary
# --------------------------------------------------

Write-Host ""
Write-Host "================================================="
Write-Host " ATTACK REPORT"
Write-Host "================================================="
Write-Host ""

Write-Host "Database Destroyed...... PASS" -ForegroundColor Green
Write-Host "Recovery File Deleted... PASS" -ForegroundColor Green
Write-Host "Business Impact......... PASS" -ForegroundColor Green
Write-Host "Attack Duration......... $attackDuration Seconds"

Write-Host ""
Write-Host "Generated:"
Write-Host "  tmp\attack-report.json"

Write-Host ""
Write-Host "Next Step:"
Write-Host "  .\Scripts\05-restore.ps1"

Write-Host ""
Write-Host "================================================="