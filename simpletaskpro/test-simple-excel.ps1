#!/usr/bin/env pwsh
# test-simple-excel.ps1 - Minimal test for ExcelMappingScreen

try {
    Write-Host "Loading minimal dependencies..." -ForegroundColor Yellow
    
    # Load only what's absolutely required
    . './Core/StringCache.ps1'
    . './Core/VT100.ps1' 
    . './Core/UniversalBackupManager.ps1'
    . './Models/ExcelFieldMapping.ps1'
    . './Services/ExcelMappingService.ps1'
    
    Write-Host "Creating ExcelMappingService..." -ForegroundColor Yellow
    $service = [ExcelMappingService]::new()
    Write-Host "Service created with $($service.Mappings.Count) mappings" -ForegroundColor Green
    
    # Test the service directly
    $mappings = $service.GetMappings()
    Write-Host "Retrieved $($mappings.Count) mappings from service" -ForegroundColor Green
    
    foreach ($mapping in $mappings | Select-Object -First 3) {
        Write-Host "  - $($mapping.DisplayName): $($mapping.SourceCell) → $($mapping.DestinationCell)" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}