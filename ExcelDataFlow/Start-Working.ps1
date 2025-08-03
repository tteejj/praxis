# Start-Working.ps1 - Working version with minimal functionality

[Console]::Clear()
Write-Host "ExcelDataFlow - Excel Field Mapping Setup" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Load core classes
    . "$PSScriptRoot\Core\VT100.ps1"
    . "$PSScriptRoot\Core\ServiceContainer.ps1"
    . "$PSScriptRoot\Services\ConfigurationService.ps1"
    . "$PSScriptRoot\Services\ExcelService.ps1"
    
    # Create services
    $global:ServiceContainer = [ServiceContainer]::new()
    $configService = [ConfigurationService]::new("$PSScriptRoot\_Config\settings.json")
    $excelService = [ExcelService]::new()
    
    $global:ServiceContainer.RegisterInstance('ConfigurationService', $configService)
    $global:ServiceContainer.RegisterInstance('ExcelService', $excelService)
    
    Write-Host "✓ Services initialized" -ForegroundColor Green
    if (-not $excelService.IsAvailable()) {
        Write-Host "⚠ Excel not available (test mode)" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "Field Mappings Configuration:" -ForegroundColor White
    Write-Host "=============================" -ForegroundColor White
    
    # Simple field mapping display
    $defaultFields = @(
        @{ FieldName = "RequestDate"; SourceCell = "W23"; DestCell = "" }
        @{ FieldName = "AuditType"; SourceCell = "W78"; DestCell = "" }
        @{ FieldName = "AuditorName"; SourceCell = "W10"; DestCell = "" }
        @{ FieldName = "TPName"; SourceCell = "W3"; DestCell = "" }
        @{ FieldName = "TPEmailAddress"; SourceCell = "X3"; DestCell = "" }
        @{ FieldName = "TPPhoneNumber"; SourceCell = "Y3"; DestCell = "" }
        @{ FieldName = "CorporateContact"; SourceCell = "W5"; DestCell = "" }
        @{ FieldName = "SiteName"; SourceCell = "W7"; DestCell = "" }
        @{ FieldName = "SiteAddress"; SourceCell = "W8"; DestCell = "" }
        @{ FieldName = "CASNumber"; SourceCell = "G17"; DestCell = "" }
        @{ FieldName = "AssetName"; SourceCell = "H17"; DestCell = "" }
        @{ FieldName = "SerialNumber"; SourceCell = "I17"; DestCell = "" }
        @{ FieldName = "ModelNumber"; SourceCell = "J17"; DestCell = "" }
        @{ FieldName = "ManufacturerName"; SourceCell = "K17"; DestCell = "" }
        @{ FieldName = "InstallDate"; SourceCell = "L17"; DestCell = "" }
    )
    
    Write-Host ""
    Write-Host "Field Name               Source   Destination" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    
    foreach ($field in $defaultFields) {
        $name = $field.FieldName.PadRight(25)
        $source = $field.SourceCell.PadRight(8)
        $dest = $field.DestCell.PadRight(8)
        Write-Host "$name $source $dest" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "Configuration saved to: $($configService._configPath)" -ForegroundColor Green
    
    # Save the configuration
    $config = @{
        SourceFile = "C:\path\to\source.xlsx"
        SourceSheet = "SVI-CAS"
        DestFile = "C:\path\to\destination.xlsx"
        DestSheet = "Output"
        FieldMappings = @{}
    }
    
    foreach ($field in $defaultFields) {
        $config.FieldMappings[$field.FieldName] = @{
            Sheet = $config.SourceSheet
            Cell = $field.SourceCell
            DestSheet = $config.DestSheet
            DestCell = $field.DestCell
        }
    }
    
    $configService.SetSetting('ExcelMappings', $config)
    
    Write-Host ""
    Write-Host "✓ Configuration saved successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Edit the source/destination file paths in the config" -ForegroundColor White
    Write-Host "2. Set destination cell references for each field" -ForegroundColor White
    Write-Host "3. Run Excel extraction and export operations" -ForegroundColor White
    
} catch {
    Write-Error "Error: $_"
} finally {
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}