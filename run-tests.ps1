#!/usr/bin/env pwsh
# Run-HuduTests.ps1

param (
    [string]$EnvironFile
)

$testsPath = Join-Path $PSScriptRoot "HuduAPI" "tests"
$modulePath = Join-Path $PSScriptRoot "HuduAPI" 'Huduapi.psd1'
$envFile = Join-Path $testsPath $EnvironFile

Write-Host "Starting tests in: $testsPath"
Write-Host "Using module: $modulePath"
Write-Host "Env file: $envFile"

# Ensure Pester 5+
$requiredVersion = "5.0.0"
if (-not (Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge $requiredVersion })) {
    Write-Host "Installing Pester $requiredVersion+..." -ForegroundColor Yellow
    Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck
}

Remove-Module Pester -ErrorAction SilentlyContinue
Import-Module Pester -MinimumVersion $requiredVersion -Force

Remove-Module Huduapi -ErrorAction SilentlyContinue
Import-Module $modulePath -Force

# Load env
if (Test-Path $envFile) {
    Write-Host "Sourcing environment from $envFile" -ForegroundColor Cyan
    . $envFile
}

# Validate env vars
$requiredVars = "HUDU_API_KEY", "HUDU_BASE_URL", "HUDU_TEST_RACK_ROLE_ID"
foreach ($var in $requiredVars) {
    if (-not (Get-Item "env:$var" -ErrorAction SilentlyContinue)) {
        throw "Missing required environment variable: $var"
    }
}
Write-Host "Using Hudu at $env:HUDU_BASE_URL" -ForegroundColor Green

# Run tests
$integrationTests = Get-ChildItem -Path $testsPath -Filter *.Tests.ps1 -Recurse

foreach ($integrationTest in $integrationTests) {
    Write-Host "Running: $($integrationTest.Name)" -ForegroundColor Blue
    $config = New-PesterConfiguration
    $config.Run.Path = $integrationTest.FullName
    $config.Output.Verbosity = "detailed"
    Invoke-Pester -Configuration $config
}
