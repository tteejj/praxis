# ProjectSettingsDialog.ps1 - Project settings configuration dialog

# Load required classes
Add-Type -AssemblyName System.Windows.Forms

# Source required files
. "$PSScriptRoot/../Components/Shared/SimpleDialogps1.txt"
. "$PSScriptRoot/../Core/FileBrowser.ps1"
. "$PSScriptRoot/../Core/VT100.ps1"

class ProjectSettingsDialog {
    [SimpleTask]$Task
    [SimpleDialog]$Dialog
    [bool]$DialogResult = $false
    
    ProjectSettingsDialog() {
        $this.Dialog = [SimpleDialog]::new("Project Settings", 70, 22)
        $this.Dialog.SetButtons("Save", "Cancel")
        
        # Set up event handlers
        $this.Dialog.OnSubmit = {
            $this.ValidateAndSave()
        }
        
        $this.Dialog.OnCancel = {
            $this.DialogResult = $false
        }
    }
    
    [bool] Show([SimpleTask]$task) {
        $this.Task = $task
        $this.SetupFields()
        
        $result = $this.Dialog.Show()
        $this.DialogResult = $result
        return $result
    }
    
    [void] SetupFields() {
        # Clear existing fields
        $this.Dialog.Fields.Clear()
        $this.Dialog.FieldOrder = @()
        
        # Add fields
        $this.Dialog.AddField("ProjectName", "Project Name", $this.Task.Title)
        $this.Dialog.AddField("ProjectFolder", "Project Folder", $this.Task.ProjectFolderPath)
        $this.Dialog.AddField("T2020File", "T2020 Call Log", $this.Task.T2020CallLogFile)
        $this.Dialog.AddField("ExportFile", "Export Data File", $this.Task.ExportDataFile)
        $this.Dialog.AddField("ActionLog", "Action Log Name", $this.Task.ActionLogName)
        $this.Dialog.AddField("ID1", "ID1 (3 chars)", $this.Task.ID1)
        $this.Dialog.AddField("ID2", "ID2 (12 chars)", $this.Task.ID2)
        
        # Make project name read-only (it's the task title)
        $this.Dialog.SetFieldReadOnly("ProjectName", $true)
    }
    
    [void] ValidateAndSave() {
        # Validate Project Folder
        $projectFolder = $this.Dialog.GetFieldValue("ProjectFolder")
        if ($projectFolder -and -not (Test-Path $projectFolder)) {
            $create = $this.ShowConfirmation("Project folder does not exist. Create it?")
            if ($create) {
                try {
                    New-Item -Path $projectFolder -ItemType Directory -Force | Out-Null
                } catch {
                    $this.ShowError("Could not create project folder: $_")
                    return
                }
            } else {
                $this.Dialog.SetFieldValue("ProjectFolder", "")
                $projectFolder = ""
            }
        }
        
        # Validate T2020 Call Log
        $t2020File = $this.Dialog.GetFieldValue("T2020File")
        if ($t2020File -and -not (Test-Path $t2020File)) {
            $this.ShowWarning("T2020 call log file not found - clearing field")
            $this.Dialog.SetFieldValue("T2020File", "")
            $t2020File = ""
        }
        
        # Validate Export Data File
        $exportFile = $this.Dialog.GetFieldValue("ExportFile")
        if ($exportFile -and -not (Test-Path $exportFile)) {
            $this.ShowWarning("Export data file not found - clearing field")
            $this.Dialog.SetFieldValue("ExportFile", "")
            $exportFile = ""
        }
        
        # Validate Action Log Name
        $actionLog = $this.Dialog.GetFieldValue("ActionLog")
        if ($actionLog -and ($actionLog.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0)) {
            $this.ShowError("Action log name contains invalid characters")
            return
        }
        
        # Validate ID fields
        $id1 = $this.Dialog.GetFieldValue("ID1")
        if ($id1.Length -gt 3) {
            $this.ShowError("ID1 must be 3 characters or less")
            return
        }
        
        $id2 = $this.Dialog.GetFieldValue("ID2")
        if ($id2.Length -gt 12) {
            $this.ShowError("ID2 must be 12 characters or less")
            return
        }
        
        # Save to task
        $this.Task.ProjectFolderPath = $projectFolder
        $this.Task.T2020CallLogFile = $t2020File
        $this.Task.ExportDataFile = $exportFile
        $this.Task.ActionLogName = if ($actionLog) { $actionLog } else { "action-log" }
        $this.Task.ID1 = $id1
        $this.Task.ID2 = $id2
        
        $this.DialogResult = $true
    }
    
    [bool] ShowConfirmation([string]$message) {
        # Simple confirmation using console input
        Write-Host "`n$message (y/n): " -NoNewline -ForegroundColor Yellow
        $response = [Console]::ReadKey($true)
        Write-Host $response.KeyChar
        return $response.KeyChar -eq 'y' -or $response.KeyChar -eq 'Y'
    }
    
    [void] ShowError([string]$message) {
        Write-Host "`nError: $message" -ForegroundColor Red
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        [Console]::ReadKey($true) | Out-Null
    }
    
    [void] ShowWarning([string]$message) {
        Write-Host "`nWarning: $message" -ForegroundColor Yellow
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        [Console]::ReadKey($true) | Out-Null
    }
    
    # File browser methods (called from hotkeys - future enhancement)
    [void] BrowseProjectFolder() {
        $folder = [FileBrowser]::ShowFolderBrowser("Select Project Folder", $this.Dialog.GetFieldValue("ProjectFolder"))
        if ($folder) { 
            $this.Dialog.SetFieldValue("ProjectFolder", $folder)
        }
    }
    
    [void] BrowseT2020File() {
        $initialDir = $this.Dialog.GetFieldValue("ProjectFolder")
        if (-not $initialDir) { $initialDir = "" }
        $file = [FileBrowser]::ShowFileBrowser("Select T2020 Call Log", "Text files (*.txt)|*.txt|All files (*.*)|*.*", $initialDir)
        if ($file) { 
            $this.Dialog.SetFieldValue("T2020File", $file)
        }
    }
    
    [void] BrowseExportFile() {
        $initialDir = $this.Dialog.GetFieldValue("ProjectFolder")
        if (-not $initialDir) { $initialDir = "" }
        $file = [FileBrowser]::ShowFileBrowser("Select Export Data File", "Text files (*.txt)|*.txt|All files (*.*)|*.*", $initialDir)
        if ($file) { 
            $this.Dialog.SetFieldValue("ExportFile", $file)
        }
    }
}