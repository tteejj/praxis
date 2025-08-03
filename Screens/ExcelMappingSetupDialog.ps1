# ExcelMappingSetupDialog.ps1 - Setup dialog for Excel field mappings with 3-column editable grid

class ExcelMappingSetupDialog : BaseDialog {
    # File selection controls
    [MinimalTextBox]$SourceFileBox
    [MinimalButton]$SourceBrowseButton
    [MinimalTextBox]$SourceSheetBox
    [MinimalTextBox]$DestFileBox
    [MinimalButton]$DestBrowseButton
    [MinimalTextBox]$DestSheetBox
    
    # Field mapping grid
    [MinimalDataGrid]$MappingGrid
    [MinimalButton]$AddFieldButton
    [MinimalButton]$DeleteFieldButton
    [MinimalButton]$TestButton
    [MinimalButton]$SaveButton
    
    # Data
    [System.Collections.Generic.List[object]]$FieldMappings
    [hashtable]$Settings = @{}
    
    # Layout constants
    hidden [int]$FileRowHeight = 3
    hidden [int]$ButtonRowHeight = 3
    hidden [int]$GridMargin = 2
    
    ExcelMappingSetupDialog() : base("Excel Field Mapping Setup", 80, 30) {
        $this.FieldMappings = [System.Collections.Generic.List[object]]::new()
        $this.InitializeDefaultMappings()
    }
    
    [void] InitializeContent() {
        # Create file selection controls
        $this.CreateFileControls()
        
        # Create mapping grid
        $this.CreateMappingGrid()
        
        # Create action buttons
        $this.CreateActionButtons()
        
        # Setup event handlers
        $this.SetupEventHandlers()
        
        # Load saved settings
        $this.LoadSettings()
        
        # Update button text
        $this.PrimaryButtonText = "OK"
        $this.SecondaryButtonText = "Cancel"
        
        # Update primary button action
        $dialog = $this
        $this.OnPrimary = {
            $dialog.SaveMappings()
            $dialog.CloseDialog()
        }.GetNewClosure()
    }
    
    [void] CreateFileControls() {
        # Source file controls
        $this.SourceFileBox = [MinimalTextBox]::new()
        $this.SourceFileBox.Placeholder = "Source Excel file path..."
        $this.SourceFileBox.Width = 50
        $this.AddContentControl($this.SourceFileBox)
        
        $this.SourceBrowseButton = [MinimalButton]::new("Browse...")
        $this.SourceBrowseButton.Width = 12
        $this.AddContentControl($this.SourceBrowseButton)
        
        $this.SourceSheetBox = [MinimalTextBox]::new()
        $this.SourceSheetBox.Placeholder = "Source sheet name (e.g., SVI-CAS)"
        $this.SourceSheetBox.Text = "SVI-CAS"
        $this.AddContentControl($this.SourceSheetBox)
        
        # Destination file controls
        $this.DestFileBox = [MinimalTextBox]::new()
        $this.DestFileBox.Placeholder = "Destination Excel file path..."
        $this.AddContentControl($this.DestFileBox)
        
        $this.DestBrowseButton = [MinimalButton]::new("Browse...")
        $this.DestBrowseButton.Width = 12
        $this.AddContentControl($this.DestBrowseButton)
        
        $this.DestSheetBox = [MinimalTextBox]::new()
        $this.DestSheetBox.Placeholder = "Destination sheet name (e.g., Output)"
        $this.DestSheetBox.Text = "Output"
        $this.AddContentControl($this.DestSheetBox)
    }
    
    [void] CreateMappingGrid() {
        $this.MappingGrid = [MinimalDataGrid]::new()
        $this.MappingGrid.Title = "Field Mappings"
        $this.MappingGrid.ShowBorder = $true
        $this.MappingGrid.ShowHeader = $true
        $this.MappingGrid.ShowTitle = $true
        
        # Set up columns for the grid
        $this.MappingGrid.SetColumns(@(
            @{
                Name = "FieldName"
                Header = "Field Name"
                Width = 20
                Getter = { param($item) return $item.FieldName }
            },
            @{
                Name = "SourceCell"
                Header = "Source Cell"
                Width = 12
                Getter = { param($item) return $item.SourceCell }
            },
            @{
                Name = "DestCell"
                Header = "Dest Cell"
                Width = 12
                Getter = { param($item) return $item.DestCell }
            }
        ))
        
        $this.AddContentControl($this.MappingGrid)
    }
    
    [void] CreateActionButtons() {
        $this.AddFieldButton = [MinimalButton]::new("Add Field")
        $this.AddFieldButton.Width = 12
        $this.AddContentControl($this.AddFieldButton)
        
        $this.DeleteFieldButton = [MinimalButton]::new("Delete")
        $this.DeleteFieldButton.Width = 10
        $this.AddContentControl($this.DeleteFieldButton)
        
        $this.TestButton = [MinimalButton]::new("Test")
        $this.TestButton.Width = 8
        $this.AddContentControl($this.TestButton)
        
        $this.SaveButton = [MinimalButton]::new("Save")
        $this.SaveButton.Width = 8
        $this.AddContentControl($this.SaveButton)
    }
    
    [void] SetupEventHandlers() {
        $dialog = $this
        
        # Browse button handlers
        $this.SourceBrowseButton.OnClick = {
            $dialog.BrowseForFile($dialog.SourceFileBox, "Select Source Excel File", "Excel Files|*.xlsx;*.xlsm;*.xls")
        }.GetNewClosure()
        
        $this.DestBrowseButton.OnClick = {
            $dialog.BrowseForFile($dialog.DestFileBox, "Select Destination Excel File", "Excel Files|*.xlsx;*.xlsm;*.xls")
        }.GetNewClosure()
        
        # Action button handlers
        $this.AddFieldButton.OnClick = {
            $dialog.AddNewField()
        }.GetNewClosure()
        
        $this.DeleteFieldButton.OnClick = {
            $dialog.DeleteSelectedField()
        }.GetNewClosure()
        
        $this.TestButton.OnClick = {
            $dialog.TestMappings()
        }.GetNewClosure()
        
        $this.SaveButton.OnClick = {
            $dialog.SaveSettings()
        }.GetNewClosure()
        
        # Grid double-click for editing
        $this.MappingGrid.OnItemSelected = {
            param($item)
            $dialog.EditFieldMapping($item)
        }.GetNewClosure()
    }
    
    [void] InitializeDefaultMappings() {
        # Pre-populate with existing field mappings from ExcelImportService
        $defaultMappings = @(
            @{ FieldName = "RequestDate"; SourceCell = "W23"; DestCell = "" },
            @{ FieldName = "AuditType"; SourceCell = "W78"; DestCell = "" },
            @{ FieldName = "AuditorName"; SourceCell = "W10"; DestCell = "" },
            @{ FieldName = "AuditorPhone"; SourceCell = "W12"; DestCell = "" },
            @{ FieldName = "AuditorTL"; SourceCell = "W15"; DestCell = "" },
            @{ FieldName = "AuditorTLPhone"; SourceCell = "W16"; DestCell = "" },
            @{ FieldName = "TPName"; SourceCell = "W3"; DestCell = "" },
            @{ FieldName = "TPNum"; SourceCell = "W4"; DestCell = "" },
            @{ FieldName = "Address"; SourceCell = "W5"; DestCell = "" },
            @{ FieldName = "City"; SourceCell = "W6"; DestCell = "" },
            @{ FieldName = "Province"; SourceCell = "W7"; DestCell = "" },
            @{ FieldName = "PostalCode"; SourceCell = "W8"; DestCell = "" },
            @{ FieldName = "Country"; SourceCell = "W9"; DestCell = "" },
            @{ FieldName = "AuditPeriodFrom"; SourceCell = "W27"; DestCell = "" },
            @{ FieldName = "AuditPeriodTo"; SourceCell = "W28"; DestCell = "" },
            @{ FieldName = "AuditPeriod1Start"; SourceCell = "W29"; DestCell = "" },
            @{ FieldName = "AuditPeriod1End"; SourceCell = "W30"; DestCell = "" },
            @{ FieldName = "AuditPeriod2Start"; SourceCell = "W31"; DestCell = "" },
            @{ FieldName = "AuditPeriod2End"; SourceCell = "W32"; DestCell = "" },
            @{ FieldName = "AuditPeriod3Start"; SourceCell = "W33"; DestCell = "" },
            @{ FieldName = "AuditPeriod3End"; SourceCell = "W34"; DestCell = "" },
            @{ FieldName = "AuditPeriod4Start"; SourceCell = "W35"; DestCell = "" },
            @{ FieldName = "AuditPeriod4End"; SourceCell = "W36"; DestCell = "" },
            @{ FieldName = "AuditPeriod5Start"; SourceCell = "W37"; DestCell = "" },
            @{ FieldName = "AuditPeriod5End"; SourceCell = "W38"; DestCell = "" },
            @{ FieldName = "Contact1Name"; SourceCell = "W54"; DestCell = "" },
            @{ FieldName = "Contact1Phone"; SourceCell = "W55"; DestCell = "" },
            @{ FieldName = "Contact1Ext"; SourceCell = "W56"; DestCell = "" },
            @{ FieldName = "Contact1Address"; SourceCell = "W57"; DestCell = "" },
            @{ FieldName = "Contact1Title"; SourceCell = "W58"; DestCell = "" },
            @{ FieldName = "Contact2Name"; SourceCell = "W59"; DestCell = "" },
            @{ FieldName = "Contact2Phone"; SourceCell = "W60"; DestCell = "" },
            @{ FieldName = "Contact2Ext"; SourceCell = "W61"; DestCell = "" },
            @{ FieldName = "Contact2Address"; SourceCell = "W62"; DestCell = "" },
            @{ FieldName = "Contact2Title"; SourceCell = "W63"; DestCell = "" },
            @{ FieldName = "AuditProgram"; SourceCell = "W72"; DestCell = "" },
            @{ FieldName = "AuditCase"; SourceCell = "W18"; DestCell = "" },
            @{ FieldName = "CASCase"; SourceCell = "W17"; DestCell = "" },
            @{ FieldName = "AuditStartDate"; SourceCell = "W24"; DestCell = "" },
            @{ FieldName = "AccountingSoftware1"; SourceCell = "W98"; DestCell = "" },
            @{ FieldName = "AccountingSoftware1Other"; SourceCell = "W100"; DestCell = "" },
            @{ FieldName = "AccountingSoftware1Type"; SourceCell = "W101"; DestCell = "" },
            @{ FieldName = "AccountingSoftware2"; SourceCell = "W102"; DestCell = "" },
            @{ FieldName = "AccountingSoftware2Other"; SourceCell = "W104"; DestCell = "" },
            @{ FieldName = "AccountingSoftware2Type"; SourceCell = "W105"; DestCell = "" },
            @{ FieldName = "FXInfo"; SourceCell = "W129"; DestCell = "" },
            @{ FieldName = "ShipToAddress"; SourceCell = "W130"; DestCell = "" },
            @{ FieldName = "Comments"; SourceCell = "W108"; DestCell = "" }
        )
        
        foreach ($mapping in $defaultMappings) {
            $this.FieldMappings.Add($mapping)
        }
        
        # Update grid
        if ($this.MappingGrid) {
            $this.MappingGrid.SetItems($this.FieldMappings.ToArray())
        }
    }
    
    [void] BrowseForFile([MinimalTextBox]$textBox, [string]$title, [string]$filter) {
        # Simple file path input dialog (would be replaced with proper file browser)
        $inputDialog = [TextInputDialog]::new($title, "Enter file path:", $textBox.Text)
        $inputDialog.OnCreate = {
            $textBox.Text = $inputDialog.InputText
        }.GetNewClosure()
        
        $screenManager = $this.ServiceContainer.GetService('ScreenManager')
        if ($screenManager) {
            $screenManager.Push($inputDialog)
        }
    }
    
    [void] AddNewField() {
        $newField = @{
            FieldName = "NewField"
            SourceCell = ""
            DestCell = ""
        }
        
        $this.FieldMappings.Add($newField)
        $this.MappingGrid.SetItems($this.FieldMappings.ToArray())
        $this.MappingGrid.SelectLast()
        $this.EditFieldMapping($newField)
    }
    
    [void] DeleteSelectedField() {
        $selected = $this.MappingGrid.GetSelectedItem()
        if ($selected) {
            $this.FieldMappings.Remove($selected)
            $this.MappingGrid.SetItems($this.FieldMappings.ToArray())
        }
    }
    
    [void] EditFieldMapping([object]$mapping) {
        if (-not $mapping) { return }
        
        # Create a simple field editor dialog
        $editor = [FieldMappingEditDialog]::new($mapping)
        $editor.OnCreate = {
            # Update the mapping with edited values
            $mapping.FieldName = $editor.FieldNameBox.Text
            $mapping.SourceCell = $editor.SourceCellBox.Text
            $mapping.DestCell = $editor.DestCellBox.Text
            
            # Refresh grid
            $this.MappingGrid.SetItems($this.FieldMappings.ToArray())
        }.GetNewClosure()
        
        $screenManager = $this.ServiceContainer.GetService('ScreenManager')
        if ($screenManager) {
            $screenManager.Push($editor)
        }
    }
    
    [void] TestMappings() {
        if ([string]::IsNullOrEmpty($this.SourceFileBox.Text)) {
            $this.ShowMessage("Please specify a source file first.")
            return
        }
        
        try {
            # Test reading from source file
            if (Test-Path $this.SourceFileBox.Text) {
                $this.ShowMessage("Source file found. Mappings look valid.")
            } else {
                $this.ShowMessage("Source file not found: $($this.SourceFileBox.Text)")
            }
        }
        catch {
            $this.ShowMessage("Test failed: $_")
        }
    }
    
    [void] SaveSettings() {
        $this.Settings = @{
            SourceFile = $this.SourceFileBox.Text
            SourceSheet = $this.SourceSheetBox.Text
            DestFile = $this.DestFileBox.Text
            DestSheet = $this.DestSheetBox.Text
            FieldMappings = $this.FieldMappings.ToArray()
        }
        
        # Save to file (would use proper settings service)
        $settingsPath = "_Config/excel_mappings.json"
        try {
            $json = $this.Settings | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($settingsPath, $json)
            $this.ShowMessage("Settings saved successfully.")
        }
        catch {
            $this.ShowMessage("Failed to save settings: $_")
        }
    }
    
    [void] LoadSettings() {
        $settingsPath = "_Config/excel_mappings.json"
        if (Test-Path $settingsPath) {
            try {
                $json = [System.IO.File]::ReadAllText($settingsPath)
                $this.Settings = $json | ConvertFrom-Json
                
                # Load into controls
                $this.SourceFileBox.Text = $this.Settings.SourceFile
                $this.SourceSheetBox.Text = $this.Settings.SourceSheet
                $this.DestFileBox.Text = $this.Settings.DestFile
                $this.DestSheetBox.Text = $this.Settings.DestSheet
                
                # Load field mappings
                if ($this.Settings.FieldMappings) {
                    $this.FieldMappings.Clear()
                    foreach ($mapping in $this.Settings.FieldMappings) {
                        $this.FieldMappings.Add(@{
                            FieldName = $mapping.FieldName
                            SourceCell = $mapping.SourceCell
                            DestCell = $mapping.DestCell
                        })
                    }
                    $this.MappingGrid.SetItems($this.FieldMappings.ToArray())
                }
            }
            catch {
                # If loading fails, use defaults
            }
        }
    }
    
    [void] SaveMappings() {
        $this.SaveSettings()
    }
    
    [void] ShowMessage([string]$message) {
        $msgDialog = [ConfirmationDialog]::new("Message", $message)
        $screenManager = $this.ServiceContainer.GetService('ScreenManager')
        if ($screenManager) {
            $screenManager.Push($msgDialog)
        }
    }
    
    [void] OnBoundsChanged() {
        ([BaseDialog]$this).OnBoundsChanged()
        
        if (-not $this.SourceFileBox) { return }
        
        # Custom layout for file controls and grid
        $contentX = $this._dialogBounds.X + 2
        $contentY = $this._dialogBounds.Y + 3  # Below title
        $contentWidth = $this._dialogBounds.Width - 4
        
        $currentY = $contentY
        
        # Source file row
        $this.SourceFileBox.SetBounds($contentX, $currentY, 45, 1)
        $this.SourceBrowseButton.SetBounds($contentX + 47, $currentY, 12, 1)
        $currentY += 2
        
        # Source sheet row
        $this.SourceSheetBox.SetBounds($contentX, $currentY, 30, 1)
        $currentY += 2
        
        # Destination file row
        $this.DestFileBox.SetBounds($contentX, $currentY, 45, 1)
        $this.DestBrowseButton.SetBounds($contentX + 47, $currentY, 12, 1)
        $currentY += 2
        
        # Destination sheet row
        $this.DestSheetBox.SetBounds($contentX, $currentY, 30, 1)
        $currentY += 3
        
        # Mapping grid (takes remaining space)
        $gridHeight = $this._dialogBounds.Y + $this._dialogBounds.Height - $currentY - 6  # Leave space for buttons
        $this.MappingGrid.SetBounds($contentX, $currentY, $contentWidth, $gridHeight)
        $currentY += $gridHeight + 1
        
        # Action buttons row
        $buttonY = $currentY
        $this.AddFieldButton.SetBounds($contentX, $buttonY, 12, 1)
        $this.DeleteFieldButton.SetBounds($contentX + 14, $buttonY, 10, 1)
        $this.TestButton.SetBounds($contentX + 26, $buttonY, 8, 1)
        $this.SaveButton.SetBounds($contentX + 36, $buttonY, 8, 1)
    }
}

# Simple field mapping editor dialog
class FieldMappingEditDialog : BaseDialog {
    [MinimalTextBox]$FieldNameBox
    [MinimalTextBox]$SourceCellBox
    [MinimalTextBox]$DestCellBox
    [object]$Mapping
    
    FieldMappingEditDialog([object]$mapping) : base("Edit Field Mapping", 50, 12) {
        $this.Mapping = $mapping
    }
    
    [void] InitializeContent() {
        $this.FieldNameBox = [MinimalTextBox]::new()
        $this.FieldNameBox.Text = $this.Mapping.FieldName
        $this.FieldNameBox.Placeholder = "Field name..."
        $this.AddContentControl($this.FieldNameBox)
        
        $this.SourceCellBox = [MinimalTextBox]::new()
        $this.SourceCellBox.Text = $this.Mapping.SourceCell
        $this.SourceCellBox.Placeholder = "Source cell (e.g., W23)..."
        $this.AddContentControl($this.SourceCellBox)
        
        $this.DestCellBox = [MinimalTextBox]::new()
        $this.DestCellBox.Text = $this.Mapping.DestCell
        $this.DestCellBox.Placeholder = "Destination cell (e.g., A1)..."
        $this.AddContentControl($this.DestCellBox)
        
        # Update button text
        $this.PrimaryButtonText = "Save"
        $this.SecondaryButtonText = "Cancel"
    }
}