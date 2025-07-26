# EventBusMonitor.ps1 - Dialog for monitoring EventBus activity

class EventBusMonitor : Screen {
    [TextBox]$InfoDisplay
    [Button]$RefreshButton
    [Button]$ToggleHistoryButton
    [Button]$ToggleDebugButton
    [Button]$ClearHistoryButton
    [Button]$CloseButton
    [EventBus]$EventBus
    hidden [System.Timers.Timer]$RefreshTimer
    
    EventBusMonitor() : base() {
        $this.Title = "EventBus Monitor"
    }
    
    [void] OnInitialize() {
        # Get EventBus
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        
        # Create info display
        $this.InfoDisplay = [TextBox]::new()
        $this.InfoDisplay.ReadOnly = $true
        $this.InfoDisplay.ShowBorder = $true
        $this.InfoDisplay.Text = "Loading EventBus information..."
        $this.InfoDisplay.Initialize($global:ServiceContainer)
        $this.AddChild($this.InfoDisplay)
        
        # Create buttons
        $this.RefreshButton = [Button]::new("Refresh")
        $this.RefreshButton.OnClick = { $this.RefreshInfo() }
        $this.RefreshButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.RefreshButton)
        
        $this.ToggleHistoryButton = [Button]::new("Toggle History")
        $this.ToggleHistoryButton.OnClick = { $this.ToggleHistory() }
        $this.ToggleHistoryButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.ToggleHistoryButton)
        
        $this.ToggleDebugButton = [Button]::new("Toggle Debug")
        $this.ToggleDebugButton.OnClick = { $this.ToggleDebug() }
        $this.ToggleDebugButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.ToggleDebugButton)
        
        $this.ClearHistoryButton = [Button]::new("Clear History")
        $this.ClearHistoryButton.OnClick = { $this.ClearHistory() }
        $this.ClearHistoryButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.ClearHistoryButton)
        
        $this.CloseButton = [Button]::new("Close")
        $this.CloseButton.IsDefault = $true
        $this.CloseButton.OnClick = { 
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        }
        $this.CloseButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.CloseButton)
        
        # Key bindings
        $this.BindKey([System.ConsoleKey]::Escape, { 
            if ($global:ScreenManager) {
                $global:ScreenManager.Pop()
            }
        })
        $this.BindKey('r', { $this.RefreshInfo() })
        $this.BindKey('h', { $this.ToggleHistory() })
        $this.BindKey('d', { $this.ToggleDebug() })
        $this.BindKey('c', { $this.ClearHistory() })
        $this.BindKey([System.ConsoleKey]::Tab, { $this.FocusNext() })
        
        # Initial refresh
        $this.RefreshInfo()
        
        # Focus on close button
        $this.CloseButton.Focus()
    }
    
    [void] OnBoundsChanged() {
        # Layout components
        $padding = 2
        $buttonHeight = 3
        $buttonWidth = 20
        $buttonSpacing = 2
        
        # Info display takes most of the space
        $this.InfoDisplay.SetBounds(
            $this.X + $padding,
            $this.Y + $padding,
            $this.Width - ($padding * 2),
            $this.Height - $buttonHeight - ($padding * 3)
        )
        
        # Buttons at the bottom
        $totalButtonWidth = ($buttonWidth * 5) + ($buttonSpacing * 4)
        $buttonStartX = $this.X + [int](($this.Width - $totalButtonWidth) / 2)
        $buttonY = $this.Y + $this.Height - $buttonHeight - $padding
        
        $this.RefreshButton.SetBounds($buttonStartX, $buttonY, $buttonWidth, $buttonHeight)
        $this.ToggleHistoryButton.SetBounds($buttonStartX + $buttonWidth + $buttonSpacing, $buttonY, $buttonWidth, $buttonHeight)
        $this.ToggleDebugButton.SetBounds($buttonStartX + ($buttonWidth + $buttonSpacing) * 2, $buttonY, $buttonWidth, $buttonHeight)
        $this.ClearHistoryButton.SetBounds($buttonStartX + ($buttonWidth + $buttonSpacing) * 3, $buttonY, $buttonWidth, $buttonHeight)
        $this.CloseButton.SetBounds($buttonStartX + ($buttonWidth + $buttonSpacing) * 4, $buttonY, $buttonWidth, $buttonHeight)
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
    
    [void] FocusNext() {
        $focusableChildren = @($this.RefreshButton, $this.ToggleHistoryButton, 
                              $this.ToggleDebugButton, $this.ClearHistoryButton, 
                              $this.CloseButton)
        
        $currentIndex = -1
        for ($i = 0; $i -lt $focusableChildren.Count; $i++) {
            if ($focusableChildren[$i].IsFocused) {
                $currentIndex = $i
                break
            }
        }
        
        # Move to next
        $nextIndex = ($currentIndex + 1) % $focusableChildren.Count
        $focusableChildren[$nextIndex].Focus()
    }
}