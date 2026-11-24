<#
=========================================================

05-restore.ps1

Purpose
-------
Restores the protected workload after attack simulation.

Actions
-------
1. Validate attack evidence
2. Restore latest Restic snapshot
3. Restore PostgreSQL dump
4. Restore application files
5. Restart Flask
6. Verify recovery
7. Generate restore report

Output
------
tmp\restore-report.json

Next Step
---------
.\Scripts\06-validate.ps1

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
Write-Host " RESILIENCY TEST POC - RECOVERY"
Write-Host "================================================="
Write-Host ""

# --------------------------------------------------
# Validate Inputs
# --------------------------------------------------

Info "Checking attack report..."

if (!(Test-Path ".\tmp\attack-report.json"))
{
    Fail "attack-report.json not found"
}

Pass "Attack report found"

Info "Checking backup metadata..."

if (!(Test-Path ".\tmp\backup-metadata.json"))
{
    Fail "backup-metadata.json not found"
}

Pass "Backup metadata found"

# --------------------------------------------------
# Start Restore Timer
# --------------------------------------------------

$restoreStart = Get-Date

# --------------------------------------------------
# Restore Restic Snapshot
# --------------------------------------------------

Info "Restoring latest snapshot..."

docker compose run --rm restic `
    restore latest `
    --target /tmp/recovery

if ($LASTEXITCODE -ne 0)
{
    Fail "Snapshot restore failed"
}

Pass "Snapshot restored"

# --------------------------------------------------
# Restore PostgreSQL Database
# --------------------------------------------------

Info "Restoring PostgreSQL database..."

docker compose exec -T postgres `
    psql `
    -U pocuser `
    -d pocdb `
    -f /tmp/recovery/tmp/pgdump.sql

if ($LASTEXITCODE -ne 0)
{
    Fail "Database restore failed"
}

Pass "Database restored"

# --------------------------------------------------
# Restore Files
# --------------------------------------------------

Info "Restoring application files..."

Copy-Item `
    -Path ".\tmp\recovery\app_files\*" `
    -Destination ".\app_files\" `
    -Recurse `
    -Force

Pass "Files restored"

# --------------------------------------------------
# Restart Flask
# --------------------------------------------------

Info "Restarting Flask..."

docker compose restart flask | Out-Null

Start-Sleep 10

Pass "Flask restarted"

# --------------------------------------------------
# Verify Database Tables
# --------------------------------------------------

Info "Verifying database objects..."

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

if ([int]$tableCount -gt 0)
{
    Pass "Database objects restored"
}
else
{
    Fail "Database objects missing"
}

# --------------------------------------------------
# Verify Recovery File
# --------------------------------------------------

Info "Verifying recovery file..."

$fileExists = Test-Path ".\app_files\recovery-test.txt"

if ($fileExists)
{
    Pass "Recovery file restored"
}
else
{
    Fail "Recovery file missing"
}

# --------------------------------------------------
# --------------------------------------------------
# Stop Restore Timer
# --------------------------------------------------

$restoreEnd = Get-Date

$restoreDuration = [Math]::Round(
    ($restoreEnd - $restoreStart).TotalSeconds,
    2
)

# --------------------------------------------------
# Generate Restore Report
# --------------------------------------------------

$restoreReport = @{
    RestoreTime          = Get-Date
    RestoreDuration      = $restoreDuration
    DatabaseRestored     = $true
    FilesRestored        = $true
    ApplicationRestarted = $true
    RestoreStatus        = "SUCCESS"
}

$restoreReport |
ConvertTo-Json -Depth 5 |
Out-File ".\tmp\restore-report.json"

Pass "Restore report generated"

# --------------------------------------------------
# Summary
# --------------------------------------------------

Write-Host ""
Write-Host "================================================="
Write-Host " RESTORE REPORT"
Write-Host "================================================="
Write-Host ""

Write-Host "Database Restored...... PASS" -ForegroundColor Green
Write-Host "Files Restored......... PASS" -ForegroundColor Green
Write-Host "Flask Restarted........ PASS" -ForegroundColor Green
Write-Host "Restore Duration....... $restoreDuration Seconds"

Write-Host ""
Write-Host "Generated:"
Write-Host "  tmp\restore-report.json"

Write-Host ""
Write-Host "Next Step:"
Write-Host "  .\Scripts\06-validate.ps1"

Write-Host ""
Write-Host "================================================="