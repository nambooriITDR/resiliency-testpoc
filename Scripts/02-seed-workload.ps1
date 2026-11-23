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
Write-Host " RESILIENCY TEST POC - WORKLOAD CREATION"
Write-Host "================================================="
Write-Host ""

# --------------------------------------------------
# Verify API
# --------------------------------------------------

Info "Checking Flask API..."

try {

    $health = Invoke-RestMethod `
        -Uri http://localhost:8080/

    if ($health.status -eq "ok") {
        Pass "API reachable"
    }
    else {
        Fail "Unexpected API response"
    }

}
catch {

    Fail "Unable to reach API"
}

# --------------------------------------------------
# Create Test Record #1
# --------------------------------------------------

Info "Creating workload record #1..."

$payload1 = @{
    content = "recovery-test-001"
} | ConvertTo-Json

Invoke-RestMethod `
    -Method POST `
    -Uri http://localhost:8080/create `
    -ContentType "application/json" `
    -Body $payload1 | Out-Null

Pass "Record 1 created"

# --------------------------------------------------
# Create Test Record #2
# --------------------------------------------------

Info "Creating workload record #2..."

$payload2 = @{
    content = "recovery-test-002"
} | ConvertTo-Json

Invoke-RestMethod `
    -Method POST `
    -Uri http://localhost:8080/create `
    -ContentType "application/json" `
    -Body $payload2 | Out-Null

Pass "Record 2 created"

# --------------------------------------------------
# Create File Workload
# --------------------------------------------------

Info "Creating file workload..."

New-Item `
    -ItemType Directory `
    -Force `
    -Path .\app_files | Out-Null

$fileName = ".\app_files\recovery-test.txt"

$content = @"
Recovery Validation Test File

Created On : $(Get-Date)

Purpose:
This file proves file-level recovery worked.

Project:
Resiliency-TestPOC
"@

Set-Content `
    -Path $fileName `
    -Value $content

Pass "Recovery file created"

# --------------------------------------------------
# Validate Records
# --------------------------------------------------

Info "Validating workload..."

$records = Invoke-RestMethod `
    -Uri http://localhost:8080/list

$recordCount = $records.Count

if ($recordCount -gt 0)
{
    Pass "$recordCount records found"
}
else
{
    Fail "No records found"
}

# --------------------------------------------------
# Validate File
# --------------------------------------------------

if(Test-Path $fileName)
{
    Pass "Recovery file exists"
}
else
{
    Fail "Recovery file missing"
}

# --------------------------------------------------
# Capture Baseline
# --------------------------------------------------

$RunId = Get-Date -Format "yyyyMMdd-HHmmss"

$baseline = @{
    RunId           = $RunId
    WorkloadCreated = Get-Date
    RecordCount     = $recordCount
    Records         = $records
    RecoveryFile    = "recovery-test.txt"
}

$baseline |
ConvertTo-Json -Depth 5 |
Out-File ".\tmp\baseline.json"

Pass "Baseline captured"

# --------------------------------------------------
# Summary
# --------------------------------------------------

Write-Host ""
Write-Host "================================================="
Write-Host " WORKLOAD CREATION REPORT"
Write-Host "================================================="
Write-Host ""

Write-Host "API Status..............PASS" -ForegroundColor Green
Write-Host "Database Records........$recordCount"
Write-Host "Recovery File...........recovery-test.txt"

Write-Host ""
Write-Host "Baseline Saved:"
Write-Host ".\tmp\baseline.json"

Write-Host ""
Write-Host "Next Step:"
Write-Host ".\Scripts\03-backup.ps1"

Write-Host ""
Write-Host "================================================="