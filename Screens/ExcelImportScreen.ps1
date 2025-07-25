# ExcelImportScreen.ps1 - Excel import screen using PRAXIS patterns

class ExcelImportScreen : Screen {
    [FastFileTree]$FileTree
    [ListBox]$PreviewList
    [Button]$ImportButton
    [Button]$BackButton
    [ProgressBar]$ImportProgress
    [string]$SelectedFile
    [hashtable]$ImportedData
    [string]$StatusMessage = "Select an Excel file to import (SVI-CAS worksheet)"
    
    # Layout
    hidden [int]$ButtonHeight = 3
    hidden [int]$StatusBarHeight = 1
    hidden [int]$ProgressHeight = 3
    
    ExcelImportScreen() : base() {
        $this.Title = "Excel Import"
    }
    
    [void] OnInitialize() {
        # Create file tree for Excel file selection
        $this.FileTree = [FastFileTree]::new()
        $this.FileTree.ShowBorder = $true
        $this.FileTree.Title = "Select Excel File"
        $this.FileTree.FileExtensions = @('.xlsx', '.xlsm', '.xls')
        $this.FileTree.ShowSize = $true
        $this.AddChild($this.FileTree)
        
        # Start with current directory
        $this.FileTree.LoadDirectory((Get-Location).Path)
        
        # Create preview list
        $this.PreviewList = [ListBox]::new()
        $this.PreviewList.Title = "Import Preview"
        $this.PreviewList.ShowBorder = $true
        $this.AddChild($this.PreviewList)
        
        # Create progress bar (initially hidden)
        $this.ImportProgress = [ProgressBar]::new()
        $this.ImportProgress.IsVisible = $false
        $this.AddChild($this.ImportProgress)
        
        # Create buttons
        $screen = $this  # Capture reference for closures
        
        $this.ImportButton = [Button]::new("Import")
        $this.ImportButton.IsEnabled = $false
        $this.ImportButton.OnClick = { $screen.StartImport() }.GetNewClosure()
        $this.AddChild($this.ImportButton)
        
        $this.BackButton = [Button]::new("Back")
        $this.BackButton.OnClick = { 
            $screen.ServiceContainer.GetService('ScreenManager').PopScreen() 
        }.GetNewClosure()
        $this.AddChild($this.BackButton)
        
        # Set up file selection handler
        $this.FileTree.OnFileSelected = {
            param($filePath)
            if ($filePath -match '\.xls[xm]?$') {
                $screen.SelectedFile = $filePath
                $screen.StatusMessage = "Selected: $(Split-Path $filePath -Leaf)"
                $screen.ImportButton.IsEnabled = $true
                $screen.PreviewFile()
                $screen.Invalidate()
            }
        }.GetNewClosure()
        
        # Key bindings
        $this.AddKeyBinding([ConsoleKey]::Escape, { 
            $this.ServiceContainer.GetService('ScreenManager').PopScreen() 
        })
        $this.AddKeyBinding([ConsoleKey]::I, { 
            if ($this.ImportButton.IsEnabled) { $this.StartImport() } 
        })
    }
    
    [void] OnBoundsChanged() {
        if (-not $this.FileTree) { return }
        
        # Calculate layout
        $fileTreeHeight = [Math]::Floor(($this.Height - $this.StatusBarHeight - $this.ButtonHeight - 2) * 0.5)
        $previewHeight = $this.Height - $fileTreeHeight - $this.StatusBarHeight - $this.ButtonHeight - 2
        
        # Position file tree at top
        $this.FileTree.SetBounds($this.X, $this.Y, $this.Width, $fileTreeHeight)
        
        # Position preview list below file tree
        $previewY = $this.Y + $fileTreeHeight + 1
        $this.PreviewList.SetBounds($this.X, $previewY, $this.Width, $previewHeight)
        
        # Position progress bar over preview area when visible
        if ($this.ImportProgress.IsVisible) {
            $progressY = $previewY + [Math]::Floor($previewHeight / 2) - 1
            $this.ImportProgress.SetBounds($this.X + 4, $progressY, $this.Width - 8, $this.ProgressHeight)
        }
        
        # Position buttons at bottom
        $buttonY = $this.Y + $this.Height - $this.ButtonHeight - $this.StatusBarHeight
        $buttonWidth = 12
        $this.ImportButton.SetBounds($this.X + $this.Width - ($buttonWidth * 2) - 4, $buttonY, $buttonWidth, 3)
        $this.BackButton.SetBounds($this.X + $this.Width - $buttonWidth - 2, $buttonY, $buttonWidth, 3)
    }
    
    [void] OnActivated() {
        ([Screen]$this).OnActivated()
        
        # Focus on file tree
        if ($this.FileTree) {
            $this.FileTree.Focus()
        }
    }
    
    [void] PreviewFile() {
        if (-not $this.SelectedFile) { return }
        
        $this.PreviewList.ClearItems()
        $this.PreviewList.AddItem("File: $(Split-Path $this.SelectedFile -Leaf)")
        $this.PreviewList.AddItem("Path: $($this.SelectedFile)")
        $this.PreviewList.AddItem("")
        $this.PreviewList.AddItem("This will import data from the 'SVI-CAS' worksheet")
        $this.PreviewList.AddItem("Press 'Import' to continue...")
    }
    
    [void] StartImport() {
        if (-not $this.SelectedFile) { return }
        
        $this.ImportButton.IsEnabled = $false
        $this.ImportProgress.IsVisible = $true
        $this.ImportProgress.Value = 0
        $this.StatusMessage = "Importing from Excel..."
        $this.OnBoundsChanged()  # Reposition progress bar
        $this.Invalidate()
        
        try {
            # Get Excel import service
            $excelService = $this.ServiceContainer.GetService('ExcelImportService')
            if (-not $excelService) {
                throw "Excel import service not available"
            }
            
            # Import data
            $this.ImportProgress.Value = 20
            $this.StatusMessage = "Reading Excel file..."
            $this.Invalidate()
            
            $this.ImportedData = $excelService.ImportFromExcel($this.SelectedFile)
            
            $this.ImportProgress.Value = 50
            $this.StatusMessage = "Processing data..."
            $this.Invalidate()
            
            # Display preview
            $this.ShowImportPreview()
            
            $this.ImportProgress.Value = 80
            $this.StatusMessage = "Creating project..."
            $this.Invalidate()
            
            # Create project from imported data
            $project = $excelService.CreateProjectFromImport($this.ImportedData)
            
            # Save project
            $projectService = $this.ServiceContainer.GetService('ProjectService')
            $projectService.CreateProject($project)
            
            $this.ImportProgress.Value = 100
            $this.StatusMessage = "Import completed successfully! Project ID2: $($project.ID2)"
            $this.Invalidate()
            
            # Show success and return to projects screen after delay
            Start-Sleep -Seconds 2
            $screenManager = $this.ServiceContainer.GetService('ScreenManager')
            $screenManager.PopScreen()
            
            # Fire event to refresh projects list
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $eventBus.Publish([EventNames]::ProjectCreated, $this, @{ Project = $project })
            }
        }
        catch {
            $this.StatusMessage = "Import failed: $_"
            $this.ImportProgress.IsVisible = $false
            $this.ImportButton.IsEnabled = $true
            $this.OnBoundsChanged()  # Reset layout
            $this.Invalidate()
        }
    }
    
    [void] ShowImportPreview() {
        $this.PreviewList.ClearItems()
        $this.PreviewList.AddItem("=== IMPORTED DATA PREVIEW ===")
        $this.PreviewList.AddItem("")
        
        # Core project info
        if ($this.ImportedData.CASCase) {
            $this.PreviewList.AddItem("ID2 (CAS Case#): $($this.ImportedData.CASCase)")
        }
        if ($this.ImportedData.TPName) {
            $this.PreviewList.AddItem("TP Name: $($this.ImportedData.TPName)")
        }
        if ($this.ImportedData.TPNum) {
            $this.PreviewList.AddItem("TP Number: $($this.ImportedData.TPNum)")
        }
        if ($this.ImportedData.AuditType) {
            $this.PreviewList.AddItem("Audit Type: $($this.ImportedData.AuditType)")
        }
        
        # Address
        if ($this.ImportedData.Address -or $this.ImportedData.City) {
            $this.PreviewList.AddItem("")
            $this.PreviewList.AddItem("ADDRESS:")
            if ($this.ImportedData.Address) {
                $this.PreviewList.AddItem("  $($this.ImportedData.Address)")
            }
            if ($this.ImportedData.City -or $this.ImportedData.Province) {
                $this.PreviewList.AddItem("  $($this.ImportedData.City), $($this.ImportedData.Province) $($this.ImportedData.PostalCode)")
            }
        }
        
        # Auditor info
        if ($this.ImportedData.AuditorName) {
            $this.PreviewList.AddItem("")
            $this.PreviewList.AddItem("AUDITOR:")
            $this.PreviewList.AddItem("  $($this.ImportedData.AuditorName) - $($this.ImportedData.AuditorPhone)")
            if ($this.ImportedData.AuditorTL) {
                $this.PreviewList.AddItem("  Team Lead: $($this.ImportedData.AuditorTL)")
            }
        }
        
        $this.PreviewList.AddItem("")
        $this.PreviewList.AddItem("Press 'Import' to create project...")
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 1024
        
        # Render base screen first
        $null = $sb.Append(([Screen]$this).OnRender())
        
        # Render status bar at bottom
        $statusY = $this.Y + $this.Height - 1
        $null = $sb.Append($this.VT.MoveTo($this.X, $statusY))
        $null = $sb.Append($this.ThemeManager.GetCached('StatusBar'))
        $null = $sb.Append(' ' * $this.Width)  # Clear line
        $null = $sb.Append($this.VT.MoveTo($this.X + 2, $statusY))
        $null = $sb.Append($this.StatusMessage)
        $null = $sb.Append($this.VT.Reset)
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}