# ExcelServiceContainer.ps1 - Service container for Excel functionality in SimpleTaskPro
# Simplified version with static service loading

class ExcelServiceContainer {
    hidden [hashtable]$_services = @{}
    hidden [hashtable]$_singletons = @{}
    
    ExcelServiceContainer() {
        # Services should already be loaded by SimpleTaskPro.ps1
        $this.VerifyServicesLoaded()
        $this.RegisterServices()
    }
    
    [void] LoadExcelServices() {
        try {
            # Load Excel services from local files using Invoke-Expression to ensure global scope
            if (Test-Path "$PSScriptRoot/ConfigurationService.ps1") {
                $configServiceContent = Get-Content "$PSScriptRoot/ConfigurationService.ps1" -Raw
                Invoke-Expression $configServiceContent
            } else {
                $this.CreateConfigurationService()
            }
            
            if (Test-Path "$PSScriptRoot/ExcelService.ps1") {
                $excelServiceContent = Get-Content "$PSScriptRoot/ExcelService.ps1" -Raw
                Invoke-Expression $excelServiceContent
            } else {
                $this.CreateExcelService()
            }
            
            # Load additional services if they exist
            $additionalServices = @(
                "$PSScriptRoot/DataProcessingService.ps1",
                "$PSScriptRoot/TextExportService.ps1", 
                "$PSScriptRoot/ExportProfileService.ps1"
            )
            
            foreach ($servicePath in $additionalServices) {
                if (Test-Path $servicePath) {
                    $serviceContent = Get-Content $servicePath -Raw
                    Invoke-Expression $serviceContent
                }
            }
            
            Write-Host "Excel services loaded successfully" -ForegroundColor Green
            
        } catch {
            Write-Warning "Failed to load Excel services: $_"
            $this.CreateFallbackServices()
        }
    }
    
    [void] VerifyServicesLoaded() {
        Write-Host "Verifying Excel services are loaded..." -ForegroundColor Yellow
        
        $configServiceAvailable = Get-Command "ConfigurationService" -ErrorAction SilentlyContinue
        $excelServiceAvailable = Get-Command "ExcelService" -ErrorAction SilentlyContinue
        
        Write-Host "ConfigurationService available: $($configServiceAvailable -ne $null)" -ForegroundColor $(if ($configServiceAvailable) { "Green" } else { "Red" })
        Write-Host "ExcelService available: $($excelServiceAvailable -ne $null)" -ForegroundColor $(if ($excelServiceAvailable) { "Green" } else { "Red" })
        
        if (-not $configServiceAvailable) {
            Write-Host "Creating fallback ConfigurationService..." -ForegroundColor Yellow
            $this.CreateConfigurationService()
        }
        
        if (-not $excelServiceAvailable) {
            Write-Host "Creating fallback ExcelService..." -ForegroundColor Yellow
            $this.CreateExcelService()
        }
    }
    
    [void] CreateConfigurationService() {
        $configServiceCode = @'
class ConfigurationService {
    [string] $ConfigPath
    [hashtable] $Settings = @{}
    
    ConfigurationService([string] $configPath) {
        $this.ConfigPath = $configPath
        $this.LoadSettings()
    }
    
    [void] LoadSettings() {
        $settingsFile = Join-Path $this.ConfigPath "excel-settings.json"
        if (Test-Path $settingsFile) {
            try {
                $json = Get-Content $settingsFile -Raw
                $this.Settings = ConvertFrom-Json $json -AsHashtable
            } catch {
                $this.Settings = @{}
            }
        }
    }
    
    [object] GetSetting([string] $key, [object] $defaultValue) {
        return $this.Settings.$key ?? $defaultValue
    }
    
    [hashtable] GetExcelMappings() {
        return $this.GetSetting('ExcelMappings', @{})
    }
    
    [void] SaveSetting([string] $key, [object] $value) {
        $this.Settings[$key] = $value
        $this.SaveSettings()
    }
    
    [void] SaveSettings() {
        try {
            if (-not (Test-Path $this.ConfigPath)) {
                New-Item -ItemType Directory -Path $this.ConfigPath -Force | Out-Null
            }
            $settingsFile = Join-Path $this.ConfigPath "excel-settings.json"
            $json = ConvertTo-Json $this.Settings -Depth 10
            [System.IO.File]::WriteAllText($settingsFile, $json)
        } catch {
            Write-Warning "Failed to save settings: $_"
        }
    }
}
'@
        Invoke-Expression $configServiceCode
    }
    
    [void] CreateExcelService() {
        $excelServiceCode = @'
class ExcelService {
    [bool] IsAvailable() { 
        try {
            $excel = New-Object -ComObject Excel.Application -ErrorAction Stop
            $excel.Quit()
            return $true
        } catch {
            return $false
        }
    }
    
    [hashtable] OpenWorkbook([string] $path) { 
        return @{ Success = $false; Error = "Excel service not fully implemented" } 
    }
    
    [void] Cleanup() { }
}
'@
        Invoke-Expression $excelServiceCode
    }
    
    [void] CreateFallbackServices() {
        # Already handled above
    }
    
    [void] RegisterServices() {
        # Initialize singletons
        $this._singletons = @{
            'ConfigurationService' = $null
            'ExcelService' = $null
        }
        
        # Service factory functions with proper closure
        $container = $this
        
        $this._services['ConfigurationService'] = {
            if (-not $container._singletons['ConfigurationService']) {
                # Verify service is available before creating
                if (-not (Get-Command "ConfigurationService" -ErrorAction SilentlyContinue)) {
                    throw "ConfigurationService class not found. Services may not have loaded properly."
                }
                $configPath = Join-Path $container.GetType().Assembly.Location "../Data" -Resolve -ErrorAction SilentlyContinue
                if (-not $configPath) {
                    $configPath = "/tmp/simpletaskpro-excel"
                }
                $container._singletons['ConfigurationService'] = [ConfigurationService]::new($configPath)
            }
            return $container._singletons['ConfigurationService']
        }.GetNewClosure()
        
        $this._services['ExcelService'] = {
            if (-not $container._singletons['ExcelService']) {
                # Verify service is available before creating
                if (-not (Get-Command "ExcelService" -ErrorAction SilentlyContinue)) {
                    throw "ExcelService class not found. Services may not have loaded properly."
                }
                $container._singletons['ExcelService'] = [ExcelService]::new()
            }
            return $container._singletons['ExcelService']
        }.GetNewClosure()
    }
    
    [object] GetService([string]$serviceName) {
        if ($this._services.ContainsKey($serviceName)) {
            return $this._services[$serviceName].Invoke()
        }
        
        throw "Service '$serviceName' not found"
    }
    
    [bool] HasService([string]$serviceName) {
        return $this._services.ContainsKey($serviceName)
    }
    
    [void] Cleanup() {
        # Cleanup Excel COM objects
        if ($this._singletons['ExcelService']) {
            $this._singletons['ExcelService'].Cleanup()
        }
        
        $this._singletons.Clear()
    }
}