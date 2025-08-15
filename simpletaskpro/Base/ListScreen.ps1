# Base/ListScreen.ps1 - The "Smart Component" engine.

class ListScreen : Screen {
    [object]$ContentBuilder  # FastLineBuilder - avoid type dependency during loading
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
        # LoadData() is called by derived classes after they initialize their services
        $this.Logger.Debug("ListScreen $($this.GetType().Name) post-construction setup complete")
    }
    
    # This is the main application loop for any screen that inherits from ListScreen.
    [void] Show() {
        $this._isRunning = $true
        $this.Initialize() # Call the base Screen initializer to wire up events
        
        while ($this._isRunning) {
            $output = $this.Render()   # 1. RENDER: Build the entire frame in memory.
            [Console]::Write($output)  # 2. WRITE: Perform a single, atomic write.
            
            # 3. INPUT: Try Console.ReadKey with fallback for redirection issues
            $key = $null
            try {
                $key = [Console]::ReadKey($true)
            } catch {
                # Last resort - break out of loop if input fails  
                $this.Logger.Error("Console input failed", $_)
                $this._isRunning = $false
                break
            }
            
            if ($key) {
                # Use the InputProcessor to convert keys to commands and fire events
                $handled = $this.InputProcessor.ProcessKey($key)
            }
        }
    }

    # UPDATED VERSION - 2025-08-13-23:40 
    [string] Render() {
        $sb = $this.RenderEngine.GetStringBuilder()
        try {
            [void]$sb.Append($this.RenderEngine.ClearScreen())
            [void]$sb.Append($this.MoveTo(0,0))
            [void]$sb.Append([VT]::HideCursor())

            $this.RenderHeader($sb)
            $this.RenderColumnHeaders($sb)
            $this.RenderContent($sb)
            $this.RenderFooter($sb)
            $this.RenderStatus($sb)

            $finalOutput = $sb.ToString()
            
            # Debug output only when debug flag enabled
            if ($global:Debug) {
                try {
                    $finalOutput | Out-File -FilePath "./ACTUAL-OUTPUT.txt" -Encoding UTF8 -Force
                    
                    # ALSO LOG THE RAW BYTES IN HEX FORMAT  
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes($finalOutput)
                    $hexDump = ($bytes | ForEach-Object { $_.ToString("X2") }) -join " "
                    "BYTE COUNT: $($bytes.Length)" | Out-File -FilePath "./OUTPUT-BYTES.txt" -Encoding ASCII -Force
                    "HEX DUMP: $hexDump" | Out-File -FilePath "./OUTPUT-BYTES.txt" -Encoding ASCII -Append
                    
                    if ($this.Logger) {
                        $this.Logger.Debug("RENDER OUTPUT: Wrote $($bytes.Length) bytes to ACTUAL-OUTPUT.txt")
                        $this.Logger.Debug("RENDER OUTPUT PREVIEW: $($finalOutput.Substring(0, [Math]::Min(200, $finalOutput.Length)))")
                    }
                } catch {
                    if ($this.Logger) { $this.Logger.Error("Failed to write debug output", $_) }
                }
            }
            
            return $finalOutput
        }
        finally {
            $this.RenderEngine.ReturnStringBuilder($sb)
        }
    }
    
    [void] RenderContent([System.Text.StringBuilder]$sb) {
        $startY = 4  # Start after header + column headers
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
        $this.Logger.Debug("ListScreen.HandleScreenCommand called with: $command")
        
        if ($command -eq 'app.exit' -or $command -eq 'Escape') {
            $this.Logger.Debug("Exiting application")
            $this._isRunning = $false
            return
        }
        
        # Handle basic navigation
        switch ($command) {
            "nav.up" { 
                $this.Logger.Debug("Moving up")
                $this.MoveUp() 
            }
            "nav.down" { 
                $this.Logger.Debug("Moving down")
                $this.MoveDown() 
            }
            default {
                # This will call the command handler in the final screen (e.g., TaskListScreen)
                $this.HandleDerivedCommand($command)
            }
        }
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
        # Position at top of screen
        $sb.Append("`e[1;1H")
        
        # Get theme colors - use defaults if empty
        $headerBg = [AppThemeManager]::GetBackgroundColor("Header")
        $headerFg = [AppThemeManager]::GetColor("Header")
        if (-not $headerBg) { $headerBg = "`e[48;5;4m" }  # Blue background
        if (-not $headerFg) { $headerFg = "`e[38;5;15m" } # White text
        
        # Render title bar with background
        $titleLine = " $($this.Title)" + " " * ($this.Width - $this.Title.Length - 1)
        $sb.Append("$headerBg$headerFg$titleLine`e[0m")
        $sb.Append("`n")
        
        # Add separator line  
        $separator = "─" * $this.Width
        $sb.Append("$headerBg$separator`e[0m")
        $sb.Append("`n")
    }

    # Column headers rendering  
    [void] RenderColumnHeaders([System.Text.StringBuilder]$sb) {
        # Get theme colors
        $headerBg = [AppThemeManager]::GetBackgroundColor("Header")
        $headerFg = [AppThemeManager]::GetColor("Text")
        
        # Position after main header (line 3)
        $sb.Append("`e[3;1H")
        
        # Column layout: ID1(4) + ID2(14) + Created(12) + Due(12) + Tree(3) + Title(rest)
        $id1Col = "ID1"
        $id2Col = "ID2"  
        $createdCol = "Created"
        $dueCol = "Due"
        $treeCol = "   "
        $titleCol = "Task"
        
        $columnLine = $id1Col.PadRight(4) + 
                     $id2Col.PadRight(14) + 
                     $createdCol.PadRight(12) + 
                     $dueCol.PadRight(12) + 
                     $treeCol.PadRight(3) + 
                     $titleCol
        
        $columnLine = $columnLine.PadRight($this.Width)
        $columnOutput = "${headerBg}${headerFg}$columnLine`e[0m`n"
        $sb.Append($columnOutput)
        
        if ($this.Logger) { $this.Logger.Debug("DEBUG: RenderColumnHeaders() completed - columnLine: '$columnLine'") }
    }

    # Footer rendering
    [void] RenderFooter([System.Text.StringBuilder]$sb) {
        $footerY = $this.Height - 2
        $sb.Append("`e[${footerY};1H")
        
        # Get theme colors
        $footerBg = [AppThemeManager]::GetBackgroundColor("Header")
        $footerFg = [AppThemeManager]::GetColor("Header")
        
        # Help text
        $helpText = "Enter: Edit | N: New | Del: Delete | Arrow Keys: Navigate"
        $footerLine = " $helpText" + " " * ($this.Width - $helpText.Length - 1)
        $sb.Append("${footerBg}${footerFg}$footerLine`e[0m")
        
        if ($this.Logger) { $this.Logger.Debug("DEBUG: RenderFooter() completed - footerY: $footerY") }
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