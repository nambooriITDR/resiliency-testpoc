<#
=========================================================

06-validate.ps1

Purpose
-------
Validates recovery success against baseline.

Actions
-------
1. Verify evidence files exist
2. Verify application health
3. Verify record count
4. Verify file recovery
5. Generate validation report

Output
------
tmp\validation-report.json

=========================================================
#>

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $RepoRoot

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

Write-Host ""
Write-Host "================================================="
Write-Host " RECOVERY VALIDATION"
Write-Host "================================================="
Write-Host ""

# --------------------------------------------------
# Check Evidence Files
# --------------------------------------------------

$requiredFiles = @(
    ".\tmp\baseline.json",
    ".\tmp\backup-metadata.json",
    ".\tmp\attack-report.json",
    ".\tmp\restore-report.json"
)

foreach($file in $requiredFiles)
{
    if(Test-Path $file)
    {
        Pass "$file found"
    }
    else
    {
        Fail "$file missing"
    }
}

# --------------------------------------------------
# Load Baseline
# --------------------------------------------------

$baseline = Get-Content `
    ".\tmp\baseline.json" `
    | ConvertFrom-Json

$baselineCount = [int]$baseline.RecordCount

# --------------------------------------------------
# Application Health
# --------------------------------------------------

Info "Checking API..."

try
{
    $health = Invoke-RestMethod `
        -Uri "http://localhost:8080/"

    Pass "API healthy"
}
catch
{
    Fail "API unavailable"
}

# --------------------------------------------------
# Record Validation
# --------------------------------------------------

Info "Validating records..."

$records = Invoke-RestMethod `
    "http://localhost:8080/list"

$currentCount = $records.Count

if($currentCount -ge $baselineCount)
{
    Pass "Record validation successful"
}
else
{
    Fail "Record count mismatch"
}

# --------------------------------------------------
# File Validation
# --------------------------------------------------

Info "Validating recovery file..."

$fileExists =
    Test-Path ".\app_files\recovery-test.txt"

if($fileExists)
{
    Pass "Recovery file present"
}
else
{
    Fail "Recovery file missing"
}

# --------------------------------------------------
# Validation Timer
# --------------------------------------------------

$validationTime = Get-Date

# --------------------------------------------------
# Validation Report
# --------------------------------------------------

$report = @{
    ValidationTime      = $validationTime
    BaselineRecords     = $baselineCount
    CurrentRecords      = $currentCount
    ApplicationHealthy  = $true
    RecoveryFilePresent = $true
    ValidationStatus    = "SUCCESS"
}

$report |
ConvertTo-Json -Depth 5 |
Out-File ".\tmp\validation-report.json"

Pass "Validation report generated"

# --------------------------------------------------
# Summary
# --------------------------------------------------

Write-Host ""
Write-Host "================================================="
Write-Host " VALIDATION REPORT"
Write-Host "================================================="
Write-Host ""

Write-Host "Baseline Records...... $baselineCount"
Write-Host "Recovered Records..... $currentCount"

Write-Host ""
Write-Host "Application Health.... PASS" -ForegroundColor Green
Write-Host "File Recovery......... PASS" -ForegroundColor Green
Write-Host "Data Recovery......... PASS" -ForegroundColor Green

Write-Host ""
Write-Host "Generated:"
Write-Host "  tmp\validation-report.json"

Write-Host ""
Write-Host "OVERALL RECOVERY STATUS: SUCCESS" `
    -ForegroundColor Green

Write-Host ""
Write-Host "================================================="