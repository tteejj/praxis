# Base/ListScreen.ps1 - The "Smart Component" engine.

class ListScreen : Screen {
    [FastLineBuilder]$ContentBuilder
    [System.Collections.Generic.List[object]]$FlatList
    [int]$SelectedIndex = 0
    [int]$ScrollTop = 0
    [string]$StatusMessage = ""
    [datetime]$StatusMessageTime = [DateTime]::MinValue
    [string]$Title = ""
    hidden [bool] $_isRunning = $false

    ListScreen([ServiceContainer]$services) : base($services) { }

    # This hook is called by the base Screen.Initialize() method.
    [void] OnInitialize() {
        $this.FlatList = [System.Collections.Generic.List[object]]::new()
        $this.ContentBuilder = $this.Services.GetService("ContentBuilder")
        $this.LoadData() # Load initial data
        $this.Logger.Debug("ListScreen $($this.GetType().Name) post-construction setup complete")
    }
    
    # This is the main application loop for any screen that inherits from ListScreen.
    [void] Show() {
        $this._isRunning = $true
        $this.Initialize() # Call the base Screen initializer to wire up events
        
        while ($this._isRunning) {
            $output = $this.Render()   # 1. RENDER: Build the entire frame in memory.
            [Console]::Write($output)  # 2. WRITE: Perform a single, atomic write.
            $key = [Console]::ReadKey($true) # 3. INPUT: Wait for and handle the next key press.
            $this.HandleInput($key)
        }
    }

    # This is now a private helper called by this screen's own loop.
    [string] Render() {
        $sb = $this.RenderEngine.GetStringBuilder()
        try {
            [void]$sb.Append($this.RenderEngine.ClearScreen())
            [void]$sb.Append($this.MoveTo(0,0))
            [void]$sb.Append([VT]::HideCursor())

            $this.RenderHeader($sb)
    
            # This is the fix for the content rendering
            $this.RenderContent($sb)

            $this.RenderFooter($sb)
            $this.RenderStatus($sb)

            # Cursor logic for inline editing will go here
            return $sb.ToString()
        }
        finally {
            $this.RenderEngine.ReturnStringBuilder($sb)
        }
    }
    
    [void] RenderContent([System.Text.StringBuilder]$sb) {
        $startY = 3
        $contentHeight = $this.Height - $startY - 2
        
        $viewModels = @()
        # Each item takes 2 lines, so we can show half as many items as there are lines
        $maxVisibleItems = [Math]::Floor($contentHeight / 2)
        $endIndex = [Math]::Min($this.ScrollTop + $maxVisibleItems, $this.FlatList.Count)
        if ($endIndex -lt 0) { $endIndex = 0 }

        for ($i = $this.ScrollTop; $i -lt $endIndex; $i++) {
            $item = $this.FlatList[$i]
            $content = $this.RenderItem($item, $i, ($i -eq $this.SelectedIndex))
            $viewModels += @{ Text = $content; Item = $item; Index = $i }
        }

        $renderedContent = $this.RenderEngine.RenderWithPillbox($viewModels, $this.SelectedIndex, $startY, $this.ScrollTop)
        [void]$sb.Append($renderedContent)
    }

    # Override HandleCommand to include an exit command for the loop.
    [void] HandleScreenCommand([string]$command) {
        if ($command -eq 'app.exit') {
            $this._isRunning = $false
            return
        }
        # This will call the command handler in the final screen (e.g., TaskListScreen)
        $this.HandleDerivedCommand($command)
    }

    # Navigation methods
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

    # Header rendering
    [void] RenderHeader([System.Text.StringBuilder]$sb) {
        # Get theme colors
        $headerBg = [AppThemeManager]::GetColor("HeaderBackground")
        $headerFg = [AppThemeManager]::GetColor("HeaderForeground")
        
        # Position at top of screen
        $sb.Append("`e[1;1H")
        
        # Render title bar with background
        $titleLine = " $($this.Title)" + " " * ($this.Width - $this.Title.Length - 1)
        $sb.Append("`e[${headerBg}m`e[${headerFg}m$titleLine`e[0m`n")
        
        # Add separator line  
        $separator = "─" * $this.Width
        $sb.Append("`e[${headerBg}m$separator`e[0m`n")
    }

    # Footer rendering
    [void] RenderFooter([System.Text.StringBuilder]$sb) {
        $footerY = $this.Height - 2
        $sb.Append("`e[${footerY};1H")
        
        # Get theme colors
        $footerBg = [AppThemeManager]::GetColor("FooterBackground")
        $footerFg = [AppThemeManager]::GetColor("FooterForeground")
        
        # Help text
        $helpText = "Enter: Edit | N: New | Del: Delete | Arrow Keys: Navigate"
        $footerLine = " $helpText" + " " * ($this.Width - $helpText.Length - 1)
        $sb.Append("`e[${footerBg}m`e[${footerFg}m$footerLine`e[0m")
    }

    # Status rendering
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

    # Abstract methods to be implemented by derived classes
    [void] LoadData() {
        throw "LoadData() must be implemented by derived class"
    }
    
    [string] RenderItem([object]$item, [int]$index, [bool]$isSelected) {
        throw "RenderItem() must be implemented by derived class"
    }
    
    [void] HandleDerivedCommand([string]$command) {
        $this.Logger.Debug("ListScreen $($this.GetType().Name) received unhandled command: $command")
    }

    # Helper methods for derived classes
    [void] SetStatusMessage([string]$message, [int]$durationMs = 3000) {
        $this.StatusMessage = $message
        $this.StatusMessageTime = [DateTime]::Now
    }
}