# Base/ListScreen.ps1 - TaskListScreen-quality base class for all list screens
# Clean two-layer hierarchy: Screen -> ListScreen
# Integrates Phase 1 services with simple PowerShell-centric patterns

class ListScreen : Screen {
    # Phase 1 services (inherited from Screen base class)
    # - Services, RenderEngine, InputProcessor available
    
    # Content services for TaskListScreen-quality rendering
    [FastLineBuilder]$ContentBuilder
    
    # Core list management properties
    [System.Collections.Generic.List[object]]$FlatList
    [int]$SelectedIndex = 0
    [int]$ScrollTop = 0
    
    # Status messages
    [string]$StatusMessage = ""
    [datetime]$StatusMessageTime = [DateTime]::MinValue
    
    
    
    # Visual properties
    [string]$Title = ""
    
    # Navigation methods - needs to be implemented
    [void] MoveUp() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this.EnsureVisible()
        }
    }
    
    [void] MoveDown() {
        if ($this.SelectedIndex -lt ($this.FlatList.Count - 1)) {
            $this.SelectedIndex++
            $this.EnsureVisible()
        }
    }
    
    [void] EnsureVisible() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $visibleHeight = $this.Height - 6  # Account for header and status
        
        # Scroll up if selected item is above visible area
        if ($this.SelectedIndex -lt $this.ScrollTop) {
            $this.ScrollTop = $this.SelectedIndex
        }
        # Scroll down if selected item is below visible area
        elseif ($this.SelectedIndex -ge ($this.ScrollTop + $visibleHeight)) {
            $this.ScrollTop = $this.SelectedIndex - $visibleHeight + 1
        }
        
        # Ensure ScrollTop is within bounds
        $maxScrollTop = [Math]::Max(0, $this.FlatList.Count - $visibleHeight)
        $this.ScrollTop = [Math]::Max(0, [Math]::Min($this.ScrollTop, $maxScrollTop))
    }
    
    # Constructor - simple, just calls base constructor
    ListScreen([ServiceContainer]$services) : base($services) {
        # No complex logic here - moved to OnInitialize()
    }
    
    # Override OnInitialize for ListScreen-specific setup
    [void] OnInitialize() {
        $this.FlatList = [System.Collections.Generic.List[object]]::new()
        $this.ContentBuilder = $this.Services.GetService("ContentBuilder")
        $this.EventBus.Subscribe("command.executed", { param($payload) $this.HandleCommand($payload.Command) })
        
        $this.Logger.Debug("ListScreen $($this.GetType().Name) post-construction setup complete")
    }
    
    # === SCREEN LIFECYCLE METHODS ===
    
    # Initialize screen with given dimensions
    [void] Initialize([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
        
        # Initialize theme manager if available
        try {
            [AppThemeManager]::SetScreenDimensions($width, $height)
        } catch {
            # AppThemeManager might not be available, that's ok
        }
        
        # Trigger data refresh
        $this.LoadData()
        $this.RefreshList()
        
        if ($this.Logger) {
            $this.Logger.Debug("$($this.GetType().Name): Initialized with dimensions ${width}x${height}")
        }
    }
    
    # === LIST MANAGEMENT METHODS ===
    
    # Refresh the flat list display - calls BuildFlatList() to rebuild from data
    [void] RefreshList() {
        try {
            $this.FlatList = $this.BuildFlatList()
            
            # Ensure selected index is still valid
            if ($this.SelectedIndex -ge $this.FlatList.Count) {
                $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
            }
            
            if ($this.Logger) {
                $this.Logger.Debug("$($this.GetType().Name): Refreshed list with $($this.FlatList.Count) items")
            }
        } catch {
            if ($this.Logger) {
                $this.Logger.Error("$($this.GetType().Name): Failed to refresh list", $_)
            }
            # Initialize empty list on error
            $this.FlatList = [System.Collections.Generic.List[object]]::new()
        }
    }
    
    # === ABSTRACT METHODS - Implement in derived classes ===
    
    [void] LoadData() {
        throw "LoadData() must be implemented by derived class"
    }
    
    [array] BuildFlatList([array]$inputItems = $null) {
        throw "BuildFlatList() must be implemented by derived class" 
    }
    
    [string] RenderItem([object]$item, [int]$index, [bool]$isSelected) {
        throw "RenderItem() must be implemented by derived class"
    }
    
    # === RENDER METHODS - ListScreen provides base implementation ===
    
    [void] RenderHeader([System.Text.StringBuilder]$sb) {
        # Get theme colors
        $headerBg = [AppThemeManager]::GetColor("HeaderBackground")  # Blue background
        $headerFg = [AppThemeManager]::GetColor("HeaderForeground")  # White text
        
        # Position at top of screen
        $sb.Append("`e[1;1H")
        
        # Render title bar with background
        $titleLine = " $($this.Title)" + " " * ($this.Width - $this.Title.Length - 1)
        $sb.Append("`e[${headerBg}m`e[${headerFg}m$titleLine`e[0m`n")
        
        # Add separator line  
        $separator = "─" * $this.Width
        $sb.Append("`e[${headerBg}m$separator`e[0m`n")
    }
    
    [void] RenderContent([System.Text.StringBuilder]$sb) {
        # This is lean and correct. It just gathers the pre-formatted strings.
        $viewModels = @()
        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
            $viewModel = @{
                Text = $this.RenderItem($this.FlatList[$i], $i, ($i -eq $this.SelectedIndex))
                Item = $this.FlatList[$i]
                Index = $i
            }
            $viewModels += $viewModel
        }
        
        # It passes the work to the RenderEngine.
        $renderedContent = $this.RenderEngine.RenderWithPillbox($viewModels, $this.SelectedIndex, 3, $this.ScrollTop)
        $sb.Append($renderedContent)
    }
    
    [void] RenderFooter([System.Text.StringBuilder]$sb) {
        $footerY = $this.Height - 2
        $sb.Append("`e[${footerY};1H")
        
        # Get theme colors
        $footerBg = [AppThemeManager]::GetColor("FooterBackground")  # Blue background  
        $footerFg = [AppThemeManager]::GetColor("FooterForeground")  # White text
        
        # Help text
        $helpText = "Enter: Edit | N: New | Del: Delete | Arrow Keys: Navigate"
        $footerLine = " $helpText" + " " * ($this.Width - $helpText.Length - 1)
        $sb.Append("`e[${footerBg}m`e[${footerFg}m$footerLine`e[0m")
    }
    
    [void] RenderStatus([System.Text.StringBuilder]$sb) {
        $statusY = $this.Height
        $sb.Append("`e[${statusY};1H")
        
        # Status message or count
        $statusText = if ($this.StatusMessage) {
            $this.StatusMessage
        } else {
            "$($this.FlatList.Count) items"
        }
        
        $sb.Append("$statusText`e[K")  # Clear to end of line
    }
    
    # === STATUS MESSAGE METHODS ===
    
    [void] SetStatusMessage([string]$message, [int]$durationMs = 3000) {
        $this.StatusMessage = $message
        $this.StatusMessageTime = [DateTime]::Now
        
        # Clear message after duration - simplified approach
        # TODO: Implement proper timer-based clearing
        if ($durationMs -gt 0) {
            # For now, just set the message and let the render loop check the time
            # The render methods already check StatusMessageTime
        }
    }
    
    [string[]] GetEditableFields([object]$item) {
        throw "GetEditableFields() must be implemented by derived class"  
    }
    
    [void] SaveItem([object]$item) {
        throw "SaveItem() must be implemented by derived class"
    }
    
    [object] CreateNewItem() {
        throw "CreateNewItem() must be implemented by derived class"
    }
    
    # === INPUT HANDLING ===

    [void] HandleScreenCommand([string]$command) {
        switch ($command) {
            "nav.up" { $this.MoveUp() }
            "nav.down" { $this.MoveDown() }
            "action.new" { $this.StartNewItem() }
            "action.delete" { $this.DeleteCurrentItem() }
            "action.edit" {
                if ($this.FlatList.Count -gt 0) {
                    $fields = $this.GetEditableFields($this.FlatList[$this.SelectedIndex])
                    if ($fields.Count -gt 0) {
                        $this.StartEdit($fields[0])
                    }
                }
            }
            default {
                $this.HandleDerivedCommand($command)
            }
        }
    }

    # Override in derived classes for screen-specific commands
    [void] HandleDerivedCommand([string]$command) {
        if ($this.Logger) {
            $this.Logger.Debug("ListScreen $($this.GetType().Name) received unhandled command: $command")
        }
    }

    [void] DeleteCurrentItem() {
        if ($this.FlatList.Count -eq 0) { return }
        
        # Simple deletion - override in derived classes for proper deletion logic
        $this.FlatList.RemoveAt($this.SelectedIndex)
        
        if ($this.SelectedIndex -ge $this.FlatList.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
        }
        
        $this.SetStatusMessage("Item deleted", 2000)
    }
    
    # Simple Render method - override in derived classes for better rendering
    [string] Render() {
        $sb = $this.RenderEngine.GetStringBuilder()
        try {
            # Header
            [void]$sb.Append($this.MoveTo(0, 0))
            [void]$sb.Append(" $($this.Title)".PadRight($this.Width))
            [void]$sb.AppendLine()
            
            # Content - using advanced RenderEngine with pillbox
            $startY = 2
            $availableHeight = $this.Height - 4
            
            # Build view models for RenderEngine
            $viewModels = @()
            $endIndex = [Math]::Min($this.ScrollTop + $availableHeight, $this.FlatList.Count)
            
            for ($i = $this.ScrollTop; $i -lt $endIndex; $i++) {
                $item = $this.FlatList[$i]
                $content = $this.RenderItem($item, $i, ($i -eq $this.SelectedIndex))
                
                $viewModel = @{
                    Text = $content
                    Item = $item
                    Index = $i
                }
                $viewModels += $viewModel
            }
            
            # Calculate local selected index for RenderEngine
            $localSelectedIndex = if ($this.SelectedIndex -ge $this.ScrollTop -and $this.SelectedIndex -lt $endIndex) {
                $this.SelectedIndex - $this.ScrollTop
            } else {
                -1
            }
            
            # Use RenderEngine's beautiful pillbox rendering
            $pillboxContent = $this.RenderEngine.RenderWithPillbox($viewModels, $localSelectedIndex, $startY, $this.ScrollTop)
            [void]$sb.Append($pillboxContent)
            
            # Status
            [void]$sb.Append($this.MoveTo(0, $this.Height - 1))
            if ($this.StatusMessage -and ((Get-Date) - $this.StatusMessageTime).TotalMilliseconds -lt 3000) {
                [void]$sb.Append($this.StatusMessage)
            } else {
                $count = if ($this.FlatList) { $this.FlatList.Count } else { 0 }
                $current = if ($count -gt 0) { $this.SelectedIndex + 1 } else { 0 }
                [void]$sb.Append("Items: $count | Selected: $current")
            }
            [void]$sb.Append($this.ClearLine())
            
            return $sb.ToString()
        } finally {
            $this.RenderEngine.ReturnStringBuilder($sb)
        }
    }
    
    # Stub implementations for inline editing (to be implemented later)
    [void] StartNewItem() {
        $this.SetStatusMessage("New item creation not implemented in base class", 2000)
    }
    
    [void] StartEdit([string]$field) {
        $this.SetStatusMessage("Inline editing not implemented in base class", 2000)
    }
}