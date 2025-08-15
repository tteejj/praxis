# Core/RenderEngine.ps1 - High-performance rendering engine for TUI
# Uses pooled StringBuilder to build entire screen output and single write to eliminate flicker

class RenderEngine {
    # Logger instance for proper logging
    hidden [Logger]$_logger = $null
    # String builder pool for memory efficiency
    static [System.Collections.Generic.Queue[System.Text.StringBuilder]]$_builderPool = [System.Collections.Generic.Queue[System.Text.StringBuilder]]::new()
    static [int]$_maxPoolSize = 5
    static [int]$_defaultCapacity = 4096
    
    # Screen state tracking
    hidden [hashtable]$_lastScreenState = @{}
    hidden [int]$_lastWidth = 0
    hidden [int]$_lastHeight = 0
    
    # Performance tracking
    hidden [hashtable]$_renderStats = @{
        FrameCount = 0
        LastFrameMs = 0
        AverageFrameMs = 0
        TotalRenderTimeMs = 0
    }
    
    # VT100 control sequences (cached for performance)
    hidden [hashtable]$_vtSequences = @{
        Clear = "`e[2J`e[H"
        ClearLine = "`e[K"
        Reset = "`e[0m"
        HideCursor = "`e[?25l"
        ShowCursor = "`e[?25h"
        SaveCursor = "`e[s"
        RestoreCursor = "`e[u"
    }
    
    RenderEngine([Logger]$logger = $null) {
        $this._logger = $logger
        
        # Pre-warm the string builder pool
        for ($i = 0; $i -lt [RenderEngine]::_maxPoolSize; $i++) {
            [RenderEngine]::_builderPool.Enqueue([System.Text.StringBuilder]::new([RenderEngine]::_defaultCapacity))
        }
        
        if ($this._logger) {
            $this._logger.Info("RenderEngine initialized with $([RenderEngine]::_maxPoolSize) pooled string builders")
        }
    }
    
    # Get a pooled string builder
    [System.Text.StringBuilder] GetStringBuilder() {
        if ([RenderEngine]::_builderPool.Count -gt 0) {
            $sb = [RenderEngine]::_builderPool.Dequeue()
            $sb.Clear()
            return $sb
        } else {
            # Pool exhausted, create new one
            if ($this._logger) {
                $this._logger.Debug("RenderEngine: String builder pool exhausted, creating new builder")
            }
            return [System.Text.StringBuilder]::new([RenderEngine]::_defaultCapacity)
        }
    }
    
    # Return a string builder to the pool
    [void] ReturnStringBuilder([System.Text.StringBuilder]$sb) {
        if ([RenderEngine]::_builderPool.Count -lt [RenderEngine]::_maxPoolSize) {
            $sb.Clear()
            [RenderEngine]::_builderPool.Enqueue($sb)
        }
        # If pool is full, let GC handle the extra builder
    }
    
    # Render view models with pillbox selection supporting two-line items
    [string] RenderWithPillbox([array]$viewModels, [int]$selectedIndex, [int]$startY, [int]$scrollTop = 0) {
        if ($this.Logger) { $this.Logger.Debug("DEBUG: RenderWithPillbox() called - viewModels.Count=$($viewModels.Count), selectedIndex=$selectedIndex, startY=$startY, scrollTop=$scrollTop") }
        $sb = $this.GetStringBuilder()
        
        try {
            # Calculate visible area
            $consoleHeight = [Console]::WindowHeight
            $consoleWidth = [Console]::WindowWidth
            $contentHeight = $consoleHeight - $startY - 3  # Leave room for footer/status
            if ($this.Logger) { $this.Logger.Debug("DEBUG: RenderWithPillbox() - consoleHeight=$consoleHeight, consoleWidth=$consoleWidth, contentHeight=$contentHeight") }
            
            # Account for two-line items - each item takes 2 lines
            $maxVisibleItems = [Math]::Floor($contentHeight / 2)
            $endIndex = [Math]::Min($scrollTop + $maxVisibleItems, $viewModels.Count)
            
            $currentY = $startY
            
            for ($i = $scrollTop; $i -lt $endIndex; $i++) {
                $viewModel = $viewModels[$i]
                $isSelected = ($i -eq $selectedIndex)
                
                # Parse two-line content
                $lines = $viewModel.Text -split "\[LINEBREAK\]"
                $contentLine = if ($lines.Count -gt 0) { $lines[0] } else { "" }
                $tagLine = if ($lines.Count -gt 1) { $lines[1] } else { "" }
                
                if ($isSelected) {
                    # Beautiful pillbox with box drawing characters
                    $pillboxBg = [AppThemeManager]::GetBackgroundColor("Selected")
                    $pillboxFg = [AppThemeManager]::GetColor("Text")
                    
                    # Top border
                    $sb.Append("`e[${currentY};1H")
                    $topBorder = "╭" + ("─" * ($consoleWidth - 2)) + "╮"
                    $sb.Append("${pillboxBg}${pillboxFg}$topBorder`e[0m")
                    $currentY++
                    
                    # Content line
                    $sb.Append("`e[${currentY};1H")
                    $contentPadded = "│ " + $contentLine.PadRight($consoleWidth - 4) + " │"
                    $sb.Append("${pillboxBg}${pillboxFg}$contentPadded`e[0m")
                    $currentY++
                    
                    # Tag line
                    $sb.Append("`e[${currentY};1H")
                    $tagPadded = "│ " + $tagLine.PadRight($consoleWidth - 4) + " │"
                    $sb.Append("${pillboxBg}${pillboxFg}$tagPadded`e[0m")
                    $currentY++
                    
                    # Bottom border
                    $sb.Append("`e[${currentY};1H")
                    $bottomBorder = "╰" + ("─" * ($consoleWidth - 2)) + "╯"
                    $sb.Append("${pillboxBg}${pillboxFg}$bottomBorder`e[0m")
                    $currentY++
                } else {
                    # Normal two-line item
                    $sb.Append("`e[${currentY};1H")
                    $normalContent = "  " + $contentLine
                    $sb.Append($normalContent.PadRight($consoleWidth))
                    $currentY++
                    
                    $sb.Append("`e[${currentY};1H")
                    $normalTag = "    " + $tagLine  # Extra indent for tag line
                    $sb.Append($normalTag.PadRight($consoleWidth))
                    $currentY++
                }
                
                # Add spacing between items
                if ($i -lt $endIndex - 1) {
                    $sb.Append("`e[${currentY};1H")
                    $sb.Append(" ".PadRight($consoleWidth))
                    $currentY++
                }
            }
            
            # Clear any remaining lines in content area
            while ($currentY -lt ($startY + $contentHeight)) {
                $sb.Append("`e[${currentY};1H`e[K")
                $currentY++
            }
            
            return $sb.ToString()
        } finally {
            $this.ReturnStringBuilder($sb)
        }
    }
    
    # Render a complete frame to the console
    [void] RenderFrame([array]$renderables) {
        $frameStart = Get-Date
        
        try {
            # Get current console dimensions
            $width = [Console]::WindowWidth
            $height = [Console]::WindowHeight
            
            # Check if we need to clear screen (size changed)
            $needsClear = ($width -ne $this._lastWidth -or $height -ne $this._lastHeight)
            $this._lastWidth = $width
            $this._lastHeight = $height
            
            # Build the complete frame output
            $sb = $this.GetStringBuilder()
            
            try {
                # Hide cursor during rendering to prevent flicker
                [void]$sb.Append($this._vtSequences.HideCursor)
                
                # Clear screen if needed
                if ($needsClear) {
                    [void]$sb.Append($this._vtSequences.Clear)
                }
                
                # Render each component
                foreach ($renderable in $renderables) {
                    if ($renderable -and $renderable.PSObject.Methods['Render']) {
                        try {
                            $content = $renderable.Render()
                            if ($content) {
                                [void]$sb.Append($content)
                            }
                        } catch {
                            [Logger]::Error("RenderEngine: Error rendering component $($renderable.GetType().Name)", $_)
                        }
                    }
                }
                
                # Show cursor at end
                [void]$sb.Append($this._vtSequences.ShowCursor)
                
                # Single write to console - this is the key to flicker-free rendering
                $output = $sb.ToString()
                if ($output.Length -gt 0) {
                    [Console]::Write($output)
                }
                
            } finally {
                $this.ReturnStringBuilder($sb)
            }
            
            # Update performance stats
            $frameTime = ((Get-Date) - $frameStart).TotalMilliseconds
            $this.UpdateRenderStats($frameTime)
            
        } catch {
            [Logger]::Error("RenderEngine: Critical error during frame render", $_)
            # Try to restore cursor visibility
            try { [Console]::Write($this._vtSequences.ShowCursor) } catch { }
        }
    }
    
    # Render a single component and return the output
    [string] RenderComponent([object]$component) {
        if (-not $component -or -not $component.PSObject.Methods['Render']) {
            return ""
        }
        
        try {
            return $component.Render()
        } catch {
            [Logger]::Error("RenderEngine: Error rendering component $($component.GetType().Name)", $_)
            return ""
        }
    }
    
    # Move cursor to specific position
    [string] MoveTo([int]$x, [int]$y) {
        return "`e[$($y + 1);$($x + 1)H"
    }
    
    # Clear from cursor to end of line
    [string] ClearLine() {
        return $this._vtSequences.ClearLine
    }
    
    # Clear entire screen
    [string] ClearScreen() {
        return $this._vtSequences.Clear
    }
    
    # Reset all formatting
    [string] Reset() {
        return $this._vtSequences.Reset
    }
    
    # Set foreground color (RGB)
    [string] SetForegroundColor([int]$r, [int]$g, [int]$b) {
        return "`e[38;2;$r;$g;${b}m"
    }
    
    # Set background color (RGB)
    [string] SetBackgroundColor([int]$r, [int]$g, [int]$b) {
        return "`e[48;2;$r;$g;${b}m"
    }
    
    # Set foreground color (8-bit)
    [string] SetForegroundColor8([int]$color) {
        return "`e[38;5;${color}m"
    }
    
    # Set background color (8-bit)
    [string] SetBackgroundColor8([int]$color) {
        return "`e[48;5;${color}m"
    }
    
    # Text formatting
    [string] Bold() { return "`e[1m" }
    [string] Dim() { return "`e[2m" }
    [string] Italic() { return "`e[3m" }
    [string] Underline() { return "`e[4m" }
    [string] Reverse() { return "`e[7m" }
    [string] Strikethrough() { return "`e[9m" }
    
    # Update render performance statistics
    [void] UpdateRenderStats([double]$frameTimeMs) {
        $this._renderStats.FrameCount++
        $this._renderStats.LastFrameMs = [math]::Round($frameTimeMs, 2)
        $this._renderStats.TotalRenderTimeMs += $frameTimeMs
        $this._renderStats.AverageFrameMs = [math]::Round($this._renderStats.TotalRenderTimeMs / $this._renderStats.FrameCount, 2)
        
        # Log slow frames
        if ($frameTimeMs -gt 50) {
            [Logger]::Warn("RenderEngine: Slow frame detected: $($frameTimeMs)ms")
        }
        
        # Log stats periodically
        if ($this._renderStats.FrameCount % 100 -eq 0) {
            [Logger]::Debug("RenderEngine: Frame $($this._renderStats.FrameCount), Avg: $($this._renderStats.AverageFrameMs)ms, Last: $($this._renderStats.LastFrameMs)ms")
        }
    }
    
    # Get current render statistics
    [hashtable] GetRenderStats() {
        return $this._renderStats.Clone()
    }
    
    # Reset render statistics
    [void] ResetRenderStats() {
        $this._renderStats = @{
            FrameCount = 0
            LastFrameMs = 0
            AverageFrameMs = 0
            TotalRenderTimeMs = 0
        }
        [Logger]::Info("RenderEngine: Render statistics reset")
    }
    
    # Optimize console settings for better performance
    [void] OptimizeConsole() {
        try {
            # Disable cursor blinking if supported
            [Console]::Write("`e[?12l")
            
            # Enable alternative screen buffer if needed
            # [Console]::Write("`e[?1049h")
            
            if ($this._logger) {
                $this._logger.Debug("RenderEngine: Console optimizations applied")
            }
        } catch {
            if ($this._logger) {
                $this._logger.Warn("RenderEngine: Could not apply all console optimizations: $_")
            }
        }
    }
    
    # Restore console to normal state
    [void] RestoreConsole() {
        try {
            # Show cursor
            [Console]::Write($this._vtSequences.ShowCursor)
            
            # Reset formatting
            [Console]::Write($this._vtSequences.Reset)
            
            # Disable alternative screen buffer if it was enabled
            # [Console]::Write("`e[?1049l")
            
            if ($this._logger) {
                $this._logger.Debug("RenderEngine: Console state restored") 
            }
        } catch {
            if ($this._logger) {
                $this._logger.Warn("RenderEngine: Could not fully restore console state: $_")
            }
        }
    }
    
    # Emergency screen clear (for crash recovery)
    [void] EmergencyClear() {
        try {
            [Console]::Clear()
            [Console]::Write($this._vtSequences.ShowCursor)
            [Console]::Write($this._vtSequences.Reset)
            [Logger]::Info("RenderEngine: Emergency screen clear performed")
        } catch {
            # Last resort - just try to show cursor
            try { [Console]::Write("`e[?25h") } catch { }
        }
    }
}