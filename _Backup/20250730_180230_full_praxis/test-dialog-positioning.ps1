#!/usr/bin/env pwsh
# Test dialog positioning

# Load the framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

# Create a simple test dialog
class TestDialog : BaseDialog {
    TestDialog() : base("Test Dialog", 60, 20) {
        $this.BorderType = [BorderType]::Rounded
    }
    
    [void] InitializeContent() {
        # Add some test content
        $label = [UIElement]::new()
        $label.SetBounds(2, 2, 56, 1)
        $label.OnRender = {
            return "This is a test dialog to verify positioning"
        }.GetNewClosure()
        $this.AddContentControl($label, 1)
    }
}

# Create a test screen to host the dialog
class TestScreen : Screen {
    [void] OnInitialize() {
        $this.Title = "Test Screen"
        
        # Add a label showing screen bounds
        $label = [UIElement]::new()
        $label.SetBounds(2, 2, 50, 1)
        $screen = $this
        $label.OnRender = {
            return "Screen size: $($screen.Width) x $($screen.Height)"
        }.GetNewClosure()
        $this.AddChild($label)
        
        # Add button to show dialog
        $button = [MinimalButton]::new("Show Dialog")
        $button.SetBounds(2, 4, 20, 3)
        $button.OnClick = {
            $dialog = [TestDialog]::new()
            $global:ScreenManager.Push($dialog)
        }
        $this.AddChild($button)
    }
    
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        if ($key.Key -eq [System.ConsoleKey]::D -and -not $key.Modifiers) {
            # Show dialog on 'D' key
            $dialog = [TestDialog]::new()
            $global:ScreenManager.Push($dialog)
            return $true
        }
        return $false
    }
}

# Initialize and run
try {
    $testScreen = [TestScreen]::new()
    $global:ScreenManager.SetMainScreen($testScreen)
    
    Write-Host "Press 'D' to show dialog, ESC to exit" -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    $global:ScreenManager.Run()
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} finally {
    [Console]::CursorVisible = $true
    [Console]::Clear()
}