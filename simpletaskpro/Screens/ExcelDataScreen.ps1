# ExcelDataScreen.ps1 - Complete Excel data management screen for SimpleTaskPro
# Integrates all ExcelDataFlow functionality as a screen within SimpleTaskPro

class ExcelDataScreen {
    # Core screen properties
    [int]$Width
    [int]$Height
    [int]$SelectedIndex = 0
    [int]$ScrollTop = 0
    [object]$AppReference = $null
    
    # Excel services (from ExcelDataFlow)
    [object]$ServiceContainer = $null
    [object]$ConfigService = $null
    [object]$ExcelService = $null
    [object]$DataProcessingService = $null
    [object]$TextExportService = $null
    [object]$ExportProfileService = $null
    [object]$WorkflowManager = $null
    
    # Screen state
    [string]$CurrentView = "Main"  # "Main", "Mapping", "Export", "Profiles", "Browser"
    [string]$StatusMessage = ""
    [datetime]$StatusMessageTime = [datetime]::MinValue
    
    # Menu options
    [string[]]$MainMenuItems = @(
        "F1 - Excel Field Mapping Setup",
        "F2 - Data Processing Pipeline", 
        "F3 - Text Export (CSV/JSON/XML/TSV/TXT)",
        "F4 - Export Profile Management",
        "F5 - Excel File Browser",
        "F6 - Quick Data Export",
        "F7 - Data Preview",
        "F8 - Configuration Management",
        "F9 - Excel COM Test/Validation",
        "F10 - Return to Tasks"
    )
    
    # Configuration data
    [hashtable]$ExcelConfig = @{}
    [hashtable]$ExtractedData = @{}
    
    ExcelDataScreen() {
        $this.InitializeServices()
    }
    
    [void] InitializeServices() {
        try {
            # Create service container (adapted from ExcelDataFlow)
            . "$PSScriptRoot\..\Services\ExcelServiceContainer.ps1"
            $this.ServiceContainer = [ExcelServiceContainer]::new()
            
            # Get core services
            $this.ConfigService = $this.ServiceContainer.GetService('ConfigurationService')
            $this.ExcelService = $this.ServiceContainer.GetService('ExcelService')
            
            # Initialize processing services
            $this.DataProcessingService = [DataProcessingService]::new($this.ExcelService, $this.ConfigService)
            $this.TextExportService = [TextExportService]::new($this.ConfigService)
            $this.ExportProfileService = [ExportProfileService]::new($this.ConfigService)
            
            # Load configuration
            $this.LoadConfiguration()
            
        } catch {
            $this.StatusMessage = "Failed to initialize Excel services: $_"
            $this.StatusMessageTime = [datetime]::Now
        }
    }
    
    [void] LoadConfiguration() {
        try {
            $this.ExcelConfig = $this.ConfigService.GetExcelMappings()
            if (-not $this.ExcelConfig) {
                $this.ExcelConfig = @{}
            }
        } catch {
            $this.ExcelConfig = @{}
        }
    }
    
    [void] SetAppReference([object]$app) {
        $this.AppReference = $app
    }
    
    [void] Initialize([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
        $this.SelectedIndex = 0
        $this.ScrollTop = 0
        $this.CurrentView = "Main"
    }
    
    [string] Render() {
        $output = ""
        
        # Clear screen
        $output += "`e[2J`e[H"
        
        # Header
        $output += $this.RenderHeader()
        
        # Content based on current view
        switch ($this.CurrentView) {
            "Main" { $output += $this.RenderMainMenu() }
            "Mapping" { $output += $this.RenderMappingView() }
            "Export" { $output += $this.RenderExportView() }
            "Profiles" { $output += $this.RenderProfilesView() }
            "Browser" { $output += $this.RenderBrowserView() }
            default { $output += $this.RenderMainMenu() }
        }
        
        # Footer with status and help
        $output += $this.RenderFooter()
        
        return $output
    }
    
    [string] RenderHeader() {
        $output = ""
        $title = "Excel Data Management"
        $configStatus = if ($this.ExcelConfig.SourceFile) { 
            "Config: $($this.ExcelConfig.SourceFile | Split-Path -Leaf)" 
        } else { 
            "No Configuration" 
        }
        
        # Title bar
        $titleBar = "┌" + "─" * ($this.Width - 2) + "┐"
        $output += "`e[44m`e[97m$titleBar`e[0m`n"
        
        $titleLine = "│ $title" + " " * ($this.Width - $title.Length - $configStatus.Length - 4) + "$configStatus │"
        $output += "`e[44m`e[97m$titleLine`e[0m`n"
        
        $separator = "├" + "─" * ($this.Width - 2) + "┤"
        $output += "`e[44m`e[97m$separator`e[0m`n"
        
        return $output
    }
    
    [string] RenderMainMenu() {
        $output = ""
        $contentHeight = $this.Height - 6  # Account for header and footer
        
        # Main menu options
        for ($i = 0; $i -lt $this.MainMenuItems.Count; $i++) {
            $item = $this.MainMenuItems[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            
            if ($isSelected) {
                $output += "`e[47m`e[30m► $item" + " " * ($this.Width - $item.Length - 3) + "`e[0m`n"
            } else {
                $output += "  $item`n"
            }
        }
        
        # Configuration summary
        $output += "`n"
        $output += "Current Configuration:`n"
        if ($this.ExcelConfig.SourceFile) {
            $output += "  Source: $($this.ExcelConfig.SourceFile)`n"
            $output += "  Sheet: $($this.ExcelConfig.SourceSheet)`n"
            $output += "  Fields: $($this.ExcelConfig.FieldMappings.Count) mapped`n"
        } else {
            $output += "  No Excel configuration found. Use F1 to set up field mappings.`n"
        }
        
        return $output
    }
    
    [string] RenderMappingView() {
        return "Excel Field Mapping Setup - Use F1 to configure`n"
    }
    
    [string] RenderExportView() {
        return "Text Export Options - Multiple formats available`n"
    }
    
    [string] RenderProfilesView() {
        return "Export Profile Management - Save and reuse configurations`n"
    }
    
    [string] RenderBrowserView() {
        return "Excel File Browser - Navigate and select files`n"
    }
    
    [string] RenderFooter() {
        $output = ""
        
        # Status message
        if ($this.StatusMessage -and ([datetime]::Now - $this.StatusMessageTime).TotalSeconds -lt 5) {
            $statusLine = "├" + "─" * ($this.Width - 2) + "┤"
            $output += "`e[43m`e[30m$statusLine`e[0m`n"
            
            $message = "│ $($this.StatusMessage)" + " " * ($this.Width - $this.StatusMessage.Length - 3) + "│"
            $output += "`e[43m`e[30m$message`e[0m`n"
        }
        
        # Bottom border
        $bottomBar = "└" + "─" * ($this.Width - 2) + "┘"
        $output += "`e[44m`e[97m$bottomBar`e[0m`n"
        
        # Help line
        $help = "Use F1-F9 for functions, Arrow keys to navigate, Enter to select, F10 to return"
        $output += "`e[36m$help`e[0m`n"
        
        return $output
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        try {
            switch ($key.Key) {
                "F1" { $this.ShowExcelMappingSetup(); return $true }
                "F2" { $this.RunDataProcessing(); return $true }
                "F3" { $this.ShowTextExport(); return $true }
                "F4" { $this.ShowProfileManagement(); return $true }
                "F5" { $this.ShowFileBrowser(); return $true }
                "F6" { $this.RunQuickExport(); return $true }
                "F7" { $this.ShowDataPreview(); return $true }
                "F8" { $this.ShowConfigManagement(); return $true }
                "F9" { $this.RunExcelTest(); return $true }
                "F10" { $this.ReturnToTasks(); return $true }
                "Escape" { $this.ReturnToTasks(); return $true }
                "UpArrow" { $this.MoveUp(); return $true }
                "DownArrow" { $this.MoveDown(); return $true }
                "Enter" { $this.ExecuteSelected(); return $true }
                default { return $true }
            }
        } catch {
            $this.StatusMessage = "Error: $_"
            $this.StatusMessageTime = [datetime]::Now
            return $true
        }
        
        # Should never reach here, but PowerShell requires it
        return $true
    }
    
    # Excel Functions (F1-F9)
    
    [void] ShowExcelMappingSetup() {
        $this.StatusMessage = "Starting Excel Field Mapping Setup..."
        $this.StatusMessageTime = [datetime]::Now
        
        try {
            # Launch Excel mapping wizard
            . "$PSScriptRoot/../Tools/ExcelMappingTool.ps1"
            
            # After wizard completion, reload configuration
            $this.LoadConfiguration()
            $this.StatusMessage = "Excel mapping setup completed"
            
        } catch {
            $this.StatusMessage = "Failed to launch mapping setup: $_"
        }
        
        $this.StatusMessageTime = [datetime]::Now
    }
    
    [void] RunDataProcessing() {
        $this.StatusMessage = "Running Excel data processing pipeline..."
        $this.StatusMessageTime = [datetime]::Now
        
        try {
            if (-not $this.ExcelConfig.SourceFile) {
                $this.StatusMessage = "No Excel configuration found. Please run F1 first."
                $this.StatusMessageTime = [datetime]::Now
                return
            }
            
            $result = $this.DataProcessingService.ProcessDataWorkflow($false)
            if ($result.Success) {
                $this.ExtractedData = $result.ExtractedData
                $this.StatusMessage = "Data processing completed successfully! $($result.ExtractedData.Count) fields extracted"
            } else {
                $this.StatusMessage = "Data processing failed: $($result.Message)"
            }
            
        } catch {
            $this.StatusMessage = "Processing error: $_"
        }
        
        $this.StatusMessageTime = [datetime]::Now
    }
    
    [void] ShowTextExport() {
        $this.StatusMessage = "Opening text export dialog..."
        $this.StatusMessageTime = [datetime]::Now
        
        try {
            if (-not $this.ExtractedData -or $this.ExtractedData.Count -eq 0) {
                $this.StatusMessage = "No data to export. Run F2 to extract data first."
                $this.StatusMessageTime = [datetime]::Now
                return
            }
            
            # Launch text export dialog 
            $dialog = [TextExportDialog]::new($this.ExtractedData)
            $dialog.ServiceContainer = $this.ServiceContainer
            $dialog.Show()
            
            $this.StatusMessage = "Text export completed"
            
        } catch {
            $this.StatusMessage = "Export failed: $_"
        }
        
        $this.StatusMessageTime = [datetime]::Now
    }
    
    [void] ShowProfileManagement() {
        $this.StatusMessage = "Opening profile management..."
        $this.StatusMessageTime = [datetime]::Now
        
        try {
            # Launch profile management dialog
            $dialog = [ProfileSelectionDialog]::new()
            $dialog.ServiceContainer = $this.ServiceContainer
            $dialog.Show()
            
            $this.StatusMessage = "Profile management completed"
            
        } catch {
            $this.StatusMessage = "Profile management failed: $_"
        }
        
        $this.StatusMessageTime = [datetime]::Now
    }
    
    [void] ShowFileBrowser() {
        $this.StatusMessage = "Opening Excel file browser..."
        $this.StatusMessageTime = [datetime]::Now
        
        try {
            # Launch file browser dialog
            $dialog = [FolderBrowserDialog]::new()
            $dialog.ServiceContainer = $this.ServiceContainer
            $dialog.Show()
            
            $this.StatusMessage = "File browser completed"
            
        } catch {
            $this.StatusMessage = "File browser failed: $_"
        }
        
        $this.StatusMessageTime = [datetime]::Now
    }
    
    [void] RunQuickExport() {
        $this.StatusMessage = "Running quick data export..."
        $this.StatusMessageTime = [datetime]::Now
        
        try {
            # Run quick export using profiles
            . "$PSScriptRoot\..\..\standalone\exceldataflow\RunProfileExport.ps1"
            
            $this.StatusMessage = "Quick export completed"
            
        } catch {
            $this.StatusMessage = "Quick export failed: $_"
        }
        
        $this.StatusMessageTime = [datetime]::Now
    }
    
    [void] ShowDataPreview() {
        $this.StatusMessage = "Generating data preview..."
        $this.StatusMessageTime = [datetime]::Now
        
        try {
            if (-not $this.ExcelConfig.SourceFile) {
                $this.StatusMessage = "No configuration found. Run F1 first."
                $this.StatusMessageTime = [datetime]::Now
                return
            }
            
            $preview = $this.DataProcessingService.PreviewData(10)
            if ($preview.Success) {
                # Show preview in a simple display
                Write-Host "`nData Preview (first 10 fields):" -ForegroundColor Cyan
                foreach ($field in $preview.Preview.GetEnumerator()) {
                    Write-Host "  $($field.Key): $($field.Value.Value)" -ForegroundColor Gray
                }
                Read-Host "`nPress Enter to continue"
                
                $this.StatusMessage = "Data preview completed"
            } else {
                $this.StatusMessage = "Preview failed: $($preview.Message)"
            }
            
        } catch {
            $this.StatusMessage = "Preview error: $_"
        }
        
        $this.StatusMessageTime = [datetime]::Now
    }
    
    [void] ShowConfigManagement() {
        $this.StatusMessage = "Opening configuration management..."
        $this.StatusMessageTime = [datetime]::Now
        
        try {
            # Show current configuration
            Write-Host "`nCurrent Excel Configuration:" -ForegroundColor Cyan
            if ($this.ExcelConfig.SourceFile) {
                Write-Host "  Source File: $($this.ExcelConfig.SourceFile)" -ForegroundColor Gray
                Write-Host "  Source Sheet: $($this.ExcelConfig.SourceSheet)" -ForegroundColor Gray
                Write-Host "  Destination File: $($this.ExcelConfig.DestFile)" -ForegroundColor Gray
                Write-Host "  Destination Sheet: $($this.ExcelConfig.DestSheet)" -ForegroundColor Gray
                Write-Host "  Field Mappings: $($this.ExcelConfig.FieldMappings.Count)" -ForegroundColor Gray
            } else {
                Write-Host "  No configuration found" -ForegroundColor Yellow
            }
            
            Read-Host "`nPress Enter to continue"
            $this.StatusMessage = "Configuration review completed"
            
        } catch {
            $this.StatusMessage = "Configuration access failed: $_"
        }
        
        $this.StatusMessageTime = [datetime]::Now
    }
    
    [void] RunExcelTest() {
        $this.StatusMessage = "Testing Excel COM connection..."
        $this.StatusMessageTime = [datetime]::Now
        
        try {
            $isAvailable = $this.ExcelService.IsAvailable()
            if ($isAvailable) {
                $this.StatusMessage = "Excel COM is available and working"
            } else {
                $this.StatusMessage = "Excel COM not available (running in simulation mode)"
            }
            
        } catch {
            $this.StatusMessage = "Excel test failed: $_"
        }
        
        $this.StatusMessageTime = [datetime]::Now
    }
    
    [void] ReturnToTasks() {
        if ($this.AppReference) {
            $this.AppReference.SwitchToTasks()
        }
    }
    
    # Navigation helpers
    
    [void] MoveUp() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
        }
    }
    
    [void] MoveDown() {
        if ($this.SelectedIndex -lt ($this.MainMenuItems.Count - 1)) {
            $this.SelectedIndex++
        }
    }
    
    [void] ExecuteSelected() {
        # Execute the selected menu item
        switch ($this.SelectedIndex) {
            0 { $this.ShowExcelMappingSetup() }
            1 { $this.RunDataProcessing() }
            2 { $this.ShowTextExport() }
            3 { $this.ShowProfileManagement() }
            4 { $this.ShowFileBrowser() }
            5 { $this.RunQuickExport() }
            6 { $this.ShowDataPreview() }
            7 { $this.ShowConfigManagement() }
            8 { $this.RunExcelTest() }
            9 { $this.ReturnToTasks() }
        }
    }
}