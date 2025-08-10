# This is a COMPLETE REWRITE of TaskListScreen using ONLY StringBuilder
# NO SmoothRenderer, NO dual output, EVERYTHING in one StringBuilder

# The key insight: Build the ENTIRE screen content in StringBuilder, including pillbox integration
# FastLineBuilder provides the content, we integrate pillbox rendering directly

# Find the RenderTaskModeEnhanced method and completely replace it with this:

[string] RenderTaskModeEnhanced() {
    # No fallback modes - unified rendering is the only rendering system
    if ($this.LineBuilder -eq $null -or $this.Renderer -eq $null) {
        throw "Critical error: Unified rendering system not initialized"
    }
    
    # Build ENTIRE screen in single StringBuilder
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append([VT]::Clear())
    
    # Header with filter info - using centralized theme system
    [void]$sb.Append([VT]::MoveTo(0, 0))
    [void]$sb.Append([AppThemeManager]::GetColor("Header"))
    $headerText = " TASKPRO - Task Manager (Enhanced)"
    if ($this.CurrentFilter -ne "All") {
        $headerText += " [Filter: $($this.CurrentFilter)]"
    }
    if ($this.TagFilter -ne "") {
        $headerText += " [Tag: #$($this.TagFilter)]"
    }
    [void]$sb.Append($headerText.PadRight($this.Width))
    [void]$sb.Append([VT]::Reset())
    
    # Column headers
    [void]$sb.Append([VT]::MoveTo(0, 1))
    [void]$sb.Append([AppThemeManager]::GetColor("Header"))
    [void]$sb.Append(" ID1  ID2           Created     Due           Title")
    [void]$sb.Append(" ".PadRight($this.Width - " ID1  ID2           Created     Due           Title".Length))
    [void]$sb.Append([VT]::Reset())
    
    # Separator line
    [void]$sb.Append([VT]::MoveTo(0, 2))
    [void]$sb.Append([AppThemeManager]::GetColor("Header"))
    [void]$sb.Append(" " + [StringCache]::GetRepeatedChar('─', $this.Width - 1))
    [void]$sb.Append([VT]::Reset())
    
    # Status bar with theme integration and theme picker hotkey
    [void]$sb.Append([VT]::MoveTo(0, $this.Height - 1))
    [void]$sb.Append([AppThemeManager]::GetColor("StatusBar"))
    $currentTheme = [AppThemeManager]::GetCurrentThemeName()
    $status = "  [N]ew [E]dit [D]elete [F]ilter [T]ags [M]ode [Ctrl+Shift+T]heme:$currentTheme ESC:Quit "
    [void]$sb.Append($status.PadRight($this.Width))
    [void]$sb.Append([VT]::Reset())
    
    # COMPLETE TASK RENDERING WITH PILLBOX INTEGRATION
    if ($this.FlatList.Count -gt 0) {
        # Calculate visible area
        $startY = 3
        $availableHeight = $this.Height - 5
        $currentY = $startY
        
        # Render each task completely in StringBuilder
        for ($i = $this.ScrollTop; $i -lt $this.FlatList.Count -and ($currentY - $startY) < $availableHeight; $i++) {
            $item = $this.FlatList[$i]
            $task = $item.Task
            $level = $item.Level
            $isLast = $item.IsLast
            $isSelected = ($i -eq $this.SelectedIndex)
            
            # Position cursor
            [void]$sb.Append([VT]::MoveTo(0, $currentY))
            
            if ($isSelected) {
                # SELECTED ITEM: Render with pillbox
                
                # Top border
                [void]$sb.Append([AppThemeManager]::GetPillboxColor())
                [void]$sb.Append("╭" + [StringCache]::GetRepeatedChar('─', $this.Width - 2) + "╮")
                [void]$sb.Append([VT]::Reset())
                $currentY++
                
                # Content line with borders
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append([AppThemeManager]::GetPillboxColor() + "│")
                
                # Get content from FastLineBuilder (without selection highlighting)
                $contentLine = $this.LineBuilder.BuildContentLine($task, $level, $isLast, $false, $this)
                # Remove the leading space that FastLineBuilder adds for pillbox
                if ($contentLine.StartsWith(" ")) {
                    $contentLine = $contentLine.Substring(1)
                }
                [void]$sb.Append($contentLine)
                
                # Pad to right border
                $usedWidth = 1 + $contentLine.Length  # 1 for left border
                $paddingNeeded = $this.Width - $usedWidth - 1  # 1 for right border
                if ($paddingNeeded -gt 0) {
                    [void]$sb.Append([StringCache]::GetSpaces($paddingNeeded))
                }
                [void]$sb.Append([AppThemeManager]::GetPillboxColor() + "│")
                [void]$sb.Append([VT]::Reset())
                $currentY++
                
                # Tag line with borders
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append([AppThemeManager]::GetPillboxColor() + "│")
                
                # Get tag line from FastLineBuilder
                $tagLine = $this.LineBuilder.BuildTagLine($task, $level, $isLast, $false, $this)
                # Remove the leading space that FastLineBuilder adds for pillbox
                if ($tagLine.StartsWith(" ")) {
                    $tagLine = $tagLine.Substring(1)
                }
                [void]$sb.Append($tagLine)
                
                # Pad to right border
                $usedWidth = 1 + $tagLine.Length  # 1 for left border
                $paddingNeeded = $this.Width - $usedWidth - 1  # 1 for right border
                if ($paddingNeeded -gt 0) {
                    [void]$sb.Append([StringCache]::GetSpaces($paddingNeeded))
                }
                [void]$sb.Append([AppThemeManager]::GetPillboxColor() + "│")
                [void]$sb.Append([VT]::Reset())
                $currentY++
                
                # Bottom border
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                [void]$sb.Append([AppThemeManager]::GetPillboxColor())
                [void]$sb.Append("╰" + [StringCache]::GetRepeatedChar('─', $this.Width - 2) + "╯")
                [void]$sb.Append([VT]::Reset())
                $currentY++
                
            } else {
                # NORMAL ITEM: Render without pillbox
                
                # Content line
                $contentLine = $this.LineBuilder.BuildContentLine($task, $level, $isLast, $false, $this)
                [void]$sb.Append($contentLine)
                $currentY++
                
                # Tag line
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                $tagLine = $this.LineBuilder.BuildTagLine($task, $level, $isLast, $false, $this)
                [void]$sb.Append($tagLine)
                $currentY++
            }
        }
        
        # Clear remaining lines
        while ($currentY < $this.Height - 2) {
            [void]$sb.Append([VT]::MoveTo(0, $currentY))
            [void]$sb.Append([VT]::ClearLine())
            $currentY++
        }
        
    } else {
        # No tasks message
        [void]$sb.Append([VT]::MoveTo(2, 5))
        [void]$sb.Append([AppThemeManager]::GetColor("Muted"))
        [void]$sb.Append("No tasks match the current filter.")
        [void]$sb.Append([VT]::Reset())
    }
    
    # Cursor management
    if ($this.EditingIndex -ge 0) {
        [void]$sb.Append([VT]::ShowCursor())
        [void]$sb.Append("`e]12;#FF0000`e\")  # Red cursor for visibility
        # Cursor positioning integrated with main output
    } else {
        [void]$sb.Append([VT]::HideCursor())
        [void]$sb.Append("`e]12;#FFFFFF`e\")  # Reset cursor color
    }
    
    # Return complete screen - single StringBuilder output eliminates dual output conflicts
    return $sb.ToString()
}