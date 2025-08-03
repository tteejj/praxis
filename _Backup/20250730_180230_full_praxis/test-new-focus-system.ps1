# Test script for new focus system with reverse highlighting

# Load the framework - use absolute path
. "$PSScriptRoot/Start.ps1" -LoadOnly

# Load the new DialogField component - use absolute path  
. "$PSScriptRoot/Components/DialogField.ps1"

# Wait a moment for classes to be available
Start-Sleep -Milliseconds 100

# Create a test dialog using the new DialogField component
class TestFocusDialog : BaseDialog {
    [System.Collections.ArrayList]$_fields
    
    TestFocusDialog() : base("Test New Focus System", 60, 20) {
        $this._fields = [System.Collections.ArrayList]::new()
    }
    
    [void] InitializeContent() {
        # Create dialog fields using new DialogField component
        $nameField = [DialogField]::new("Project Name", "Enter project name")
        $nameField.KeyWidth = 14
        $this.AddContentControl($nameField, 1)
        $this._fields.Add($nameField) | Out-Null
        
        $descField = [DialogField]::new("Description", "Brief description")  
        $descField.KeyWidth = 14
        $this.AddContentControl($descField, 2)
        $this._fields.Add($descField) | Out-Null
        
        $priorityField = [DialogField]::new("Priority", "high/medium/low")
        $priorityField.KeyWidth = 14
        $this.AddContentControl($priorityField, 3)
        $this._fields.Add($priorityField) | Out-Null
        
        # Set up primary button action
        $this.OnPrimary = {
            Write-Host ""
            Write-Host "=== FIELD VALUES ===" -ForegroundColor Green
            foreach ($field in $this._fields) {
                Write-Host "$($field.Key): '$($field.Value)'" -ForegroundColor Cyan
            }
            Write-Host "===================" -ForegroundColor Green
            Write-Host ""
        }.GetNewClosure()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Position dialog fields with minimal spacing
        $currentY = $dialogY + 3  # Start below title
        $fieldWidth = $this.DialogWidth - 4  # Account for dialog padding
        $fieldHeight = 3  # Height for bordered fields
        
        foreach ($field in $this._fields) {
            $field.SetBounds(
                $dialogX + 2,  # Dialog padding
                $currentY,
                $fieldWidth,
                $fieldHeight
            )
            $currentY += $fieldHeight + 1  # Minimal spacing between fields
        }
    }
}

try {
    Write-Host "Starting Focus System Test..." -ForegroundColor Yellow
    Write-Host "- DialogField: Key highlighted with reverse colors when focused" -ForegroundColor Gray
    Write-Host "- MinimalTextBox: Full reverse highlighting when focused" -ForegroundColor Gray
    Write-Host "- MinimalButton: Border + reverse highlighting when focused" -ForegroundColor Gray
    Write-Host "- Use Tab to navigate, Enter on OK to see values, Escape to cancel" -ForegroundColor Gray
    Write-Host ""
    
    # Create and show the test dialog
    $dialog = [TestFocusDialog]::new()
    $global:ScreenManager.Push($dialog)
    
    # Run the main loop
    $global:ScreenManager.Run()
    
} catch {
    Write-Error "Test failed: $_"
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} finally {
    Write-Host "`nTest completed." -ForegroundColor Yellow
}