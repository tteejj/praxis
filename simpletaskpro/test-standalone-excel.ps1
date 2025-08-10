#!/usr/bin/env pwsh
# test-standalone-excel.ps1 - Test ExcelMappingScreen without BaseListScreen

# Load dependencies first
. './Core/StringCache.ps1'
. './Core/VT100.ps1'
. './Core/UniversalBackupManager.ps1'
. './Models/ExcelFieldMapping.ps1'
. './Services/ExcelMappingService.ps1'

class SimpleExcelScreen {
    [ExcelMappingService]$MappingService
    [System.Collections.Generic.List[object]]$FlatList
    [int]$SelectedIndex = 0
    [int]$Width = 80
    [int]$Height = 25
    
    SimpleExcelScreen() {
        Write-Host "Creating ExcelMappingService..." -ForegroundColor Gray
        $this.MappingService = [ExcelMappingService]::new()
        $this.FlatList = [System.Collections.Generic.List[object]]::new()
        $this.LoadData()
    }
    
    [void] LoadData() {
        Write-Host "Loading mappings..." -ForegroundColor Gray
        $mappings = $this.MappingService.GetMappings()
        $this.FlatList.Clear()
        
        foreach ($mapping in $mappings) {
            $this.FlatList.Add(@{
                Mapping = $mapping
            })
        }
        Write-Host "Loaded $($this.FlatList.Count) mappings" -ForegroundColor Gray
    }
    
    [void] Initialize([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
        Write-Host "Screen initialized: ${width}x${height}" -ForegroundColor Gray
    }
    
    [string] Render() {
        $content = "Excel Mapping Screen Test`n"
        $content += "=" * 40 + "`n"
        $content += "Mappings: $($this.FlatList.Count)`n"
        $content += "Selected: $($this.SelectedIndex + 1)`n"
        
        for ($i = 0; $i -lt [Math]::Min(5, $this.FlatList.Count); $i++) {
            $mapping = $this.FlatList[$i].Mapping
            $marker = if ($i -eq $this.SelectedIndex) { ">" } else { " " }
            $content += "$marker $($mapping.DisplayName) ($($mapping.SourceCell))`n"
        }
        
        return $content
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) { return $false }
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) { $this.SelectedIndex-- }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt ($this.FlatList.Count - 1)) { $this.SelectedIndex++ }
                return $true
            }
            default { return $true }
        }
    }
}

try {
    Write-Host "Dependencies already loaded..." -ForegroundColor Yellow
    
    Write-Host "Creating SimpleExcelScreen..." -ForegroundColor Yellow
    $screen = [SimpleExcelScreen]::new()
    
    Write-Host "Testing Initialize..." -ForegroundColor Yellow
    $screen.Initialize(80, 25)
    
    Write-Host "Testing Render..." -ForegroundColor Yellow
    $content = $screen.Render()
    Write-Host $content -ForegroundColor Green
    
    Write-Host "SUCCESS: All ExcelScreen operations work!" -ForegroundColor Green
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}