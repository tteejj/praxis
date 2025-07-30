#!/usr/bin/env pwsh
# Run-Tests.ps1 - Test runner for PRAXIS

param(
    [string]$TestPath = "*",
    [string]$OutputFormat = "NUnitXml",
    [switch]$ShowDetailed,
    [switch]$CodeCoverage,
    [switch]$PerformanceOnly,
    [switch]$CI
)

$ErrorActionPreference = "Stop"
$testResults = @()
$startTime = Get-Date

Write-Host "`n🧪 PRAXIS Test Suite Runner" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Check if Pester is installed
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "❌ Pester not found. Installing Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -SkipPublisherCheck
}

Import-Module Pester -MinimumVersion 5.0

# Configure Pester
$config = New-PesterConfiguration
$config.Run.Path = "$PSScriptRoot"
$config.Run.PassThru = $true
$config.Output.Verbosity = if ($ShowDetailed) { 'Detailed' } else { 'Normal' }

# Test discovery
if ($TestPath -ne "*") {
    $config.Run.Path = Join-Path $PSScriptRoot $TestPath
}

if ($PerformanceOnly) {
    $config.Run.Path = "$PSScriptRoot/Performance"
}

# Code coverage
if ($CodeCoverage) {
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = @(
        "$PSScriptRoot/../Base/*.ps1",
        "$PSScriptRoot/../Components/*.ps1",
        "$PSScriptRoot/../Core/*.ps1",
        "$PSScriptRoot/../Models/*.ps1",
        "$PSScriptRoot/../Screens/*.ps1",
        "$PSScriptRoot/../Services/*.ps1"
    )
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.OutputPath = "$PSScriptRoot/coverage.xml"
}

# Output configuration
if ($CI) {
    $config.TestResult.Enabled = $true
    $config.TestResult.OutputFormat = $OutputFormat
    $config.TestResult.OutputPath = "$PSScriptRoot/test-results.xml"
}

# Run tests
Write-Host "`n🔍 Discovering tests..." -ForegroundColor Yellow
$result = Invoke-Pester -Configuration $config

# Generate summary report
Write-Host "`n📊 Test Results Summary" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan

$duration = (Get-Date) - $startTime
$passRate = if ($result.TotalCount -gt 0) { 
    [math]::Round(($result.PassedCount / $result.TotalCount) * 100, 2) 
} else { 0 }

Write-Host "Total Tests: $($result.TotalCount)" -ForegroundColor White
Write-Host "✅ Passed: $($result.PassedCount)" -ForegroundColor Green
Write-Host "❌ Failed: $($result.FailedCount)" -ForegroundColor Red
Write-Host "⏭️  Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
Write-Host "⏱️  Duration: $($duration.TotalSeconds) seconds" -ForegroundColor Cyan
Write-Host "📈 Pass Rate: $passRate%" -ForegroundColor $(if ($passRate -ge 80) { 'Green' } elseif ($passRate -ge 60) { 'Yellow' } else { 'Red' })

# Code coverage summary
if ($CodeCoverage -and $result.CodeCoverage) {
    Write-Host "`n📊 Code Coverage Summary" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    
    $coverage = [math]::Round($result.CodeCoverage.CoveragePercent, 2)
    Write-Host "Overall Coverage: $coverage%" -ForegroundColor $(if ($coverage -ge 80) { 'Green' } elseif ($coverage -ge 60) { 'Yellow' } else { 'Red' })
    Write-Host "Lines Covered: $($result.CodeCoverage.CommandsExecutedCount) / $($result.CodeCoverage.CommandsAnalyzedCount)"
}

# Performance test summary
if ($PerformanceOnly -or (Test-Path "$PSScriptRoot/Performance")) {
    Write-Host "`n⚡ Performance Test Summary" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    
    # Extract performance metrics from test output
    # This would be populated by performance tests
}

# Exit with appropriate code
if ($result.FailedCount -gt 0) {
    Write-Host "`n❌ Tests FAILED!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ All tests PASSED!" -ForegroundColor Green
    exit 0
}