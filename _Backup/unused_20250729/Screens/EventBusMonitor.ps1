# EventBusMonitor.ps1 - Dialog for monitoring EventBus activity

class EventBusMonitor : BaseDialog {
    [MinimalTextBox]$InfoDisplay
    [MinimalButton]$RefreshButton
    [MinimalButton]$ToggleHistoryButton
    [MinimalButton]$ToggleDebugButton
    [MinimalButton]$ClearHistoryButton
    [EventBus]$EventBus
    hidden [System.Timers.Timer]$RefreshTimer
    
    EventBusMonitor() : base("EventBus Monitor") {
        $this.DialogWidth = 70
        $this.DialogHeight = 20
        $this.PrimaryButtonText = "Close"
        $this.SecondaryButtonText = $null  # No secondary button
    }
    
    [void] InitializeContent() {
        # Get EventBus
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        
        # Create info display
        $this.InfoDisplay = [MinimalTextBox]::new()
        $this.InfoDisplay.ReadOnly = $true
        $this.InfoDisplay.ShowBorder = $false  # Dialog provides the border
        $this.InfoDisplay.Text = "Loading EventBus information..."
        $this.InfoDisplay.Height = 10  # Multi-line display
        $this.AddContentControl($this.InfoDisplay, 10)
        
        # Create buttons
        $this.RefreshButton = [MinimalButton]::new("Refresh", "r")
        $this.RefreshButton.OnClick = { $this.RefreshInfo() }.GetNewClosure()
        $this.AddContentControl($this.RefreshButton, 1)
        
        $this.ToggleHistoryButton = [MinimalButton]::new("Toggle History", "h")
        $this.ToggleHistoryButton.OnClick = { $this.ToggleHistory() }.GetNewClosure()
        $this.AddContentControl($this.ToggleHistoryButton, 1)
        
        $this.ToggleDebugButton = [MinimalButton]::new("Toggle Debug", "d")
        $this.ToggleDebugButton.OnClick = { $this.ToggleDebug() }.GetNewClosure()
        $this.AddContentControl($this.ToggleDebugButton, 1)
        
        $this.ClearHistoryButton = [MinimalButton]::new("Clear History", "c")
        $this.ClearHistoryButton.OnClick = { $this.ClearHistory() }.GetNewClosure()
        $this.AddContentControl($this.ClearHistoryButton, 1)
        
        # Primary button handler (Close)
        $this.OnPrimary = {
            # Just close the dialog
        }.GetNewClosure()
        
        # Initial refresh
        $this.RefreshInfo()
    }
    
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Position info display
        $this.InfoDisplay.SetBounds(
            $dialogX + $this.DialogPadding,
            $dialogY + 2,
            $this.DialogWidth - ($this.DialogPadding * 2),
            10
        )
        
        # Position buttons horizontally below info display
        $buttonY = $dialogY + 13
        $buttonWidth = 15
        $buttonSpacing = 2
        $totalButtonWidth = ($buttonWidth * 4) + ($buttonSpacing * 3)
        $buttonStartX = $dialogX + [int](($this.DialogWidth - $totalButtonWidth) / 2)
        
        $this.RefreshButton.SetBounds($buttonStartX, $buttonY, $buttonWidth, 1)
        $this.ToggleHistoryButton.SetBounds($buttonStartX + $buttonWidth + $buttonSpacing, $buttonY, $buttonWidth, 1)
        $this.ToggleDebugButton.SetBounds($buttonStartX + ($buttonWidth + $buttonSpacing) * 2, $buttonY, $buttonWidth, 1)
        $this.ClearHistoryButton.SetBounds($buttonStartX + ($buttonWidth + $buttonSpacing) * 3, $buttonY, $buttonWidth, 1)
    }
    
    [void] RefreshInfo() {
        if (-not $this.EventBus) { return }
        
        $report = $this.EventBus.GetDebugReport()
        
        # Add recent history if enabled
        if ($this.EventBus.EnableHistory) {
            $history = $this.EventBus.GetEventHistory()
            if ($history.Count -gt 0) {
                $report += "`n`nRecent Events:`n"
                $recent = $history | Select-Object -Last 10
                foreach ($event in $recent) {
                    $report += "  $($event.Timestamp.ToString('HH:mm:ss')) - $($event.EventName)`n"
                }
            }
        }
        
        # Add keyboard shortcuts
        $report += "`n`nKeyboard Shortcuts:`n"
        $report += "  [R] Refresh  [H] Toggle History  [D] Toggle Debug`n"
        $report += "  [C] Clear History  [Esc] Close"
        
        $this.InfoDisplay.Text = $report
        $this.InfoDisplay.Invalidate()
    }
    
    [void] ToggleHistory() {
        if ($this.EventBus) {
            $this.EventBus.EnableHistory = -not $this.EventBus.EnableHistory
            $this.RefreshInfo()
        }
    }
    
    [void] ToggleDebug() {
        if ($this.EventBus) {
            $this.EventBus.EnableDebugLogging = -not $this.EventBus.EnableDebugLogging
            $this.RefreshInfo()
        }
    }
    
    [void] ClearHistory() {
        if ($this.EventBus) {
            $this.EventBus.ClearHistory()
            $this.RefreshInfo()
        }
    }
    
}