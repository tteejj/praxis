# CommandListScreen.ps1 - Complete command list with ALL features
# Based on TaskPro's proven TaskListScreen architecture

class CommandListScreen {
    [CommandService]$CommandService
    [Command[]]$Commands
    [System.Collections.Generic.List[object]]$FlatList  # Flattened list for navigation
    [int]$SelectedIndex = 0
    [int]$ScrollTop = 0
    [int]$Width
    [int]$Height
    
    # Search functionality
    [string]$SearchText = ""
    [bool]$SearchMode = $false
    [Command[]]$FilteredCommands
    
    # Inline editing state
    [int]$EditingIndex = -1
    [string]$EditingField = ""  # "title", "description", "tags", "command"
    [string]$EditingValue = ""
    [Command]$EditingCommand = $null
    [bool]$IsNewCommand = $false
    
    # Modern RGB Colors - matching TaskPro style
    [string]$HeaderColor = "`e[38;2;100;150;255m"     # Modern blue
    [string]$GroupColor = "`e[38;2;255;165;0m"        # Orange for groups
    [string]$CommandColor = "`e[38;2;250;248;240m"    # Cream white for commands
    [string]$DescriptionColor = "`e[38;2;180;180;180m" # Light gray for descriptions
    [string]$TagColor = "`e[38;2;255;20;147m"         # Deep pink for tags
    [string]$UsageColor = "`e[38;2;135;206;235m"      # Sky blue for usage
    [string]$SelectedBg = "`e[48;2;45;45;55m"         # Dark background highlight
    [string]$SearchColor = "`e[38;2;50;205;50m"       # Lime green for search
    [string]$NormalColor = "`e[0m"                     # Reset
    [string]$EditHighlight = "`e[48;2;255;255;255;38;2;0;0;0m"  # White background, black text
    
    # Status messages
    [string]$StatusMessage = ""
    [datetime]$StatusMessageTime = [datetime]::MinValue
    
    # Column widths for layout
    [int]$GroupCol = 15      # "[Group] "
    [int]$TitleCol = 40      # Command title
    [int]$UsageCol = 8       # "★99 "
    
    # Pillbox characters - same as TaskPro
    [string]$PillboxTopLeft = "╭"
    [string]$PillboxTopRight = "╮"
    [string]$PillboxBottomLeft = "╰"
    [string]$PillboxBottomRight = "╯"
    [string]$PillboxHorizontal = "─"
    [string]$PillboxVertical = "│"
    
    CommandListScreen([CommandService]$commandService) {
        $this.CommandService = $commandService
        $this.FlatList = [System.Collections.Generic.List[object]]::new()
        $this.LoadCommands()
    }
    
    [void] Initialize([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
    }
    
    [void] LoadCommands() {
        $this.Commands = $this.CommandService.GetAllCommands()
        $this.ApplySearchFilter()
        $this.BuildFlatList()
        
        if ($this.SelectedIndex -ge $this.FlatList.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
        }
    }
    
    [void] ApplySearchFilter() {
        if ([string]::IsNullOrWhiteSpace($this.SearchText)) {
            $this.FilteredCommands = $this.Commands
        } else {
            $searchQuery = $this.SearchText.ToLower()
            $this.FilteredCommands = $this.Commands | Where-Object {
                $_.Title.ToLower().Contains($searchQuery) -or
                $_.Description.ToLower().Contains($searchQuery) -or
                $_.CommandText.ToLower().Contains($searchQuery) -or
                $_.Group.ToLower().Contains($searchQuery) -or
                ($_.Tags | Where-Object { $_.ToLower().Contains($searchQuery) }).Count -gt 0
            }
        }
    }
    
    [void] BuildFlatList() {
        $this.FlatList.Clear()
        
        # Group commands by Group property
        $groupedCommands = $this.FilteredCommands | Group-Object -Property Group | Sort-Object Name
        
        foreach ($group in $groupedCommands) {
            # Add group header
            $groupItem = [PSCustomObject]@{
                Type = "GroupHeader"
                Group = $group.Name
                Command = $null
                IsSelectable = $false
            }
            $this.FlatList.Add($groupItem)
            
            # Add commands in this group
            $sortedCommands = $group.Group | Sort-Object Title
            foreach ($command in $sortedCommands) {
                $commandItem = [PSCustomObject]@{
                    Type = "Command"
                    Group = $group.Name
                    Command = $command
                    IsSelectable = $true
                }
                $this.FlatList.Add($commandItem)
            }
        }
        
        # Ensure we have at least one selectable item
        if ($this.FlatList.Count -eq 0) {
            $emptyItem = [PSCustomObject]@{
                Type = "Empty"
                Group = ""
                Command = $null
                IsSelectable = $false
            }
            $this.FlatList.Add($emptyItem)
        }
        
        # Adjust selected index to point to selectable item
        $this.EnsureSelectableIndex()
    }
    
    [void] EnsureSelectableIndex() {
        if ($this.FlatList.Count -eq 0) {
            $this.SelectedIndex = 0
            return
        }
        
        # If current selection is not selectable, find next selectable item
        if ($this.SelectedIndex -ge $this.FlatList.Count -or -not $this.FlatList[$this.SelectedIndex].IsSelectable) {
            for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
                if ($this.FlatList[$i].IsSelectable) {
                    $this.SelectedIndex = $i
                    return
                }
            }
            # No selectable items found
            $this.SelectedIndex = 0
        }
    }
    
    [Command] GetSelectedCommand() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.FlatList.Count) {
            $item = $this.FlatList[$this.SelectedIndex]
            if ($item.Type -eq "Command") {
                return $item.Command
            }
        }
        return $null
    }
    
    [int] GetItemHeight([int]$itemIndex) {
        # Dynamic height calculation for selected item based on content
        if ($itemIndex -eq $this.SelectedIndex) {
            $item = $this.FlatList[$itemIndex]
            if ($item.Type -eq "Command") {
                return $this.CalculateDynamicHeight($item.Command)
            } else {
                return 2  # Group headers get standard height when selected
            }
        } else {
            return 2  # Normal items remain 2 lines
        }
    }
    
    [int] CalculateDynamicHeight([Command]$command) {
        $requiredLines = 2  # Base: top border + bottom border
        
        # Content analysis
        if ($this.HasMainContent($command)) { $requiredLines++ }
        if ($this.HasTags($command)) { $requiredLines++ }
        if ($this.HasMetadata($command)) { $requiredLines++ }
        if ($this.HasCommandText($command)) { $requiredLines++ }
        
        # Spacer line only if we have content
        if ($requiredLines -gt 2) { $requiredLines++ }  # Add spacer
        
        return $requiredLines
    }
    
    [bool] HasMainContent([Command]$command) {
        return -not [string]::IsNullOrWhiteSpace($command.Title) -or -not [string]::IsNullOrWhiteSpace($command.Description)
    }
    
    [bool] HasTags([Command]$command) {
        return $command.Tags.Count -gt 0
    }
    
    [bool] HasMetadata([Command]$command) {
        return $command.UseCount -gt 0 -or $command.LastUsed -ne [datetime]::MinValue
    }
    
    [bool] HasCommandText([Command]$command) {
        return -not [string]::IsNullOrWhiteSpace($command.CommandText)
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Header
        [void]$sb.Append([VT]::MoveTo(0, 0))
        [void]$sb.Append([VT]::ClearLine())
        [void]$sb.Append("$($this.HeaderColor)COMMAND LIBRARY$($this.NormalColor)")
        
        # Search bar
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append([VT]::ClearLine())
        if ($this.SearchMode) {
            [void]$sb.Append("$($this.SearchColor)Search: $($this.SearchText)_$($this.NormalColor)")
        } else {
            [void]$sb.Append("$($this.DescriptionColor)Search commands... (Ctrl+S to search, F3 for search mode)$($this.NormalColor)")
        }
        
        # Separator
        [void]$sb.Append([VT]::MoveTo(0, 2))
        [void]$sb.Append([VT]::ClearLine())
        [void]$sb.Append("═" * $this.Width)
        
        # Calculate visible area
        $startY = 3
        $endY = $this.Height - 2
        $visibleHeight = $endY - $startY
        
        # Calculate scroll and visible items with dynamic heights
        $this.CalculateScroll($visibleHeight)
        $visibleItems = $this.GetVisibleItems($visibleHeight)
        
        # Render visible items
        $currentY = $startY
        foreach ($itemInfo in $visibleItems) {
            $item = $this.FlatList[$itemInfo.Index]
            $isSelected = ($itemInfo.Index -eq $this.SelectedIndex)
            
            if ($item.Type -eq "GroupHeader") {
                $currentY += $this.RenderGroupHeader($sb, $item, $currentY, $isSelected)
            } elseif ($item.Type -eq "Command") {
                $currentY += $this.RenderCommand($sb, $item, $currentY, $isSelected, $itemInfo.Height)
            } elseif ($item.Type -eq "Empty") {
                $currentY += $this.RenderEmpty($sb, $currentY)
            }
            
            if ($currentY -ge $endY) { break }
        }
        
        # Clear remaining lines
        for ($y = $currentY; $y -lt $endY; $y++) {
            [void]$sb.Append([VT]::MoveTo(0, $y))
            [void]$sb.Append([VT]::ClearLine())
        }
        
        # Status bar
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 2))
        [void]$sb.Append([VT]::ClearLine())
        [void]$sb.Append("─" * $this.Width)
        
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 1))
        [void]$sb.Append([VT]::ClearLine())
        
        if (-not [string]::IsNullOrWhiteSpace($this.StatusMessage) -and ((Get-Date) - $this.StatusMessageTime).TotalSeconds -lt 3) {
            [void]$sb.Append("$($this.UsageColor)$($this.StatusMessage)$($this.NormalColor)")
        } else {
            if ($this.FlatList.Count -eq 0) {
                [void]$sb.Append("$($this.DescriptionColor)No commands found$($this.NormalColor)")
            } else {
                $selectableCount = ($this.FlatList | Where-Object { $_.IsSelectable }).Count
                $currentSelectable = $this.GetSelectablePosition() + 1
                [void]$sb.Append("$($this.DescriptionColor)[$currentSelectable/$selectableCount] Enter:Copy  E:Edit  N:New  D:Delete  R:Run  T:Tags  Q:Quit  ^S/F3:Search$($this.NormalColor)")
            }
        }
        
        return $sb.ToString()
    }
    
    [int] GetSelectablePosition() {
        $count = 0
        for ($i = 0; $i -lt $this.SelectedIndex; $i++) {
            if ($i -lt $this.FlatList.Count -and $this.FlatList[$i].IsSelectable) {
                $count++
            }
        }
        return $count
    }
    
    [void] CalculateScroll([int]$visibleHeight) {
        if ($this.FlatList.Count -eq 0) { return }
        
        # Calculate total height needed up to selected item
        $heightToSelected = 0
        for ($i = 0; $i -lt $this.SelectedIndex; $i++) {
            $heightToSelected += $this.GetItemHeight($i)
        }
        
        $selectedHeight = $this.GetItemHeight($this.SelectedIndex)
        
        # Adjust scroll to ensure selected item is visible
        if ($heightToSelected -lt $this.ScrollTop) {
            $this.ScrollTop = $heightToSelected
        } elseif ($heightToSelected + $selectedHeight -ge $this.ScrollTop + $visibleHeight) {
            $this.ScrollTop = $heightToSelected + $selectedHeight - $visibleHeight
        }
        
        # Ensure scroll doesn't go negative
        $this.ScrollTop = [Math]::Max(0, $this.ScrollTop)
    }
    
    [array] GetVisibleItems([int]$visibleHeight) {
        $visibleItems = @()
        $currentHeight = 0
        
        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
            $itemHeight = $this.GetItemHeight($i)
            
            # Skip items above scroll position
            if ($currentHeight + $itemHeight -le $this.ScrollTop) {
                $currentHeight += $itemHeight
                continue
            }
            
            # Add visible items
            if ($currentHeight -lt $this.ScrollTop + $visibleHeight) {
                $visibleItems += [PSCustomObject]@{
                    Index = $i
                    Height = $itemHeight
                }
                $currentHeight += $itemHeight
            } else {
                break
            }
        }
        
        return $visibleItems
    }
    
    [int] RenderGroupHeader([System.Text.StringBuilder]$sb, [object]$item, [int]$startY, [bool]$isSelected) {
        $groupName = $item.Group
        if ([string]::IsNullOrWhiteSpace($groupName)) {
            $groupName = "Uncategorized"
        }
        
        # Group header line
        [void]$sb.Append([VT]::MoveTo(0, $startY))
        [void]$sb.Append([VT]::ClearLine())
        
        if ($isSelected) {
            [void]$sb.Append("$($this.SelectedBg)$($this.GroupColor)► $groupName$($this.NormalColor)")
        } else {
            [void]$sb.Append("$($this.GroupColor)$groupName$($this.NormalColor)")
        }
        
        # Separator line
        [void]$sb.Append([VT]::MoveTo(0, $startY + 1))
        [void]$sb.Append([VT]::ClearLine())
        [void]$sb.Append("$($this.DescriptionColor)" + ("─" * [Math]::Min($groupName.Length + 2, $this.Width)) + "$($this.NormalColor)")
        
        return 2
    }
    
    [int] RenderCommand([System.Text.StringBuilder]$sb, [object]$item, [int]$startY, [bool]$isSelected, [int]$itemHeight) {
        $command = $item.Command
        
        if ($isSelected -and $itemHeight -gt 2) {
            return $this.RenderCommandPillbox($sb, $command, $startY, $itemHeight)
        } else {
            return $this.RenderCommandSimple($sb, $command, $startY, $isSelected)
        }
    }
    
    [int] RenderCommandSimple([System.Text.StringBuilder]$sb, [Command]$command, [int]$startY, [bool]$isSelected) {
        [void]$sb.Append([VT]::MoveTo(0, $startY))
        [void]$sb.Append([VT]::ClearLine())
        
        $displayText = $this.GetCommandDisplayText($command, $false)
        
        if ($isSelected) {
            [void]$sb.Append("$($this.SelectedBg)$displayText$($this.NormalColor)")
        } else {
            [void]$sb.Append($displayText)
        }
        
        # Empty line for spacing
        [void]$sb.Append([VT]::MoveTo(0, $startY + 1))
        [void]$sb.Append([VT]::ClearLine())
        
        return 2
    }
    
    [int] RenderCommandPillbox([System.Text.StringBuilder]$sb, [Command]$command, [int]$startY, [int]$itemHeight) {
        $boxWidth = [Math]::Min($this.Width - 4, 80)  # Leave margins
        $contentWidth = $boxWidth - 2  # Account for borders
        
        # Top border
        [void]$sb.Append([VT]::MoveTo(0, $startY))
        [void]$sb.Append([VT]::ClearLine())
        [void]$sb.Append("$($this.HeaderColor)$($this.PillboxTopLeft)$($this.PillboxHorizontal * $contentWidth)$($this.PillboxTopRight)$($this.NormalColor)")
        
        $currentY = $startY + 1
        
        # Main content line
        if ($this.HasMainContent($command)) {
            [void]$sb.Append([VT]::MoveTo(0, $currentY))
            [void]$sb.Append([VT]::ClearLine())
            
            $mainText = $this.GetCommandDisplayText($command, $true)
            $truncatedText = $this.TruncateText($mainText, $contentWidth)
            
            [void]$sb.Append("$($this.HeaderColor)$($this.PillboxVertical)$($this.NormalColor)$($this.SelectedBg)$truncatedText$($this.NormalColor)$($this.HeaderColor)$($this.PillboxVertical)$($this.NormalColor)")
            $currentY++
        }
        
        # Command text line
        if ($this.HasCommandText($command)) {
            [void]$sb.Append([VT]::MoveTo(0, $currentY))
            [void]$sb.Append([VT]::ClearLine())
            
            $cmdText = "Command: $($command.CommandText)"
            $truncatedCmd = $this.TruncateText($cmdText, $contentWidth)
            
            [void]$sb.Append("$($this.HeaderColor)$($this.PillboxVertical)$($this.NormalColor)$($this.SelectedBg)$($this.DescriptionColor)$truncatedCmd$($this.NormalColor)$($this.HeaderColor)$($this.PillboxVertical)$($this.NormalColor)")
            $currentY++
        }
        
        # Tags line
        if ($this.HasTags($command)) {
            [void]$sb.Append([VT]::MoveTo(0, $currentY))
            [void]$sb.Append([VT]::ClearLine())
            
            $tagsText = "Tags: " + ($command.Tags | ForEach-Object { "#$_" }) -join " "
            $truncatedTags = $this.TruncateText($tagsText, $contentWidth)
            
            [void]$sb.Append("$($this.HeaderColor)$($this.PillboxVertical)$($this.NormalColor)$($this.SelectedBg)$($this.TagColor)$truncatedTags$($this.NormalColor)$($this.HeaderColor)$($this.PillboxVertical)$($this.NormalColor)")
            $currentY++
        }
        
        # Metadata line
        if ($this.HasMetadata($command)) {
            [void]$sb.Append([VT]::MoveTo(0, $currentY))
            [void]$sb.Append([VT]::ClearLine())
            
            $metaText = "Used: $($command.UseCount) times"
            if ($command.LastUsed -ne [datetime]::MinValue) {
                $metaText += ", Last: $($command.LastUsed.ToString('yyyy-MM-dd'))"
            }
            $truncatedMeta = $this.TruncateText($metaText, $contentWidth)
            
            [void]$sb.Append("$($this.HeaderColor)$($this.PillboxVertical)$($this.NormalColor)$($this.SelectedBg)$($this.UsageColor)$truncatedMeta$($this.NormalColor)$($this.HeaderColor)$($this.PillboxVertical)$($this.NormalColor)")
            $currentY++
        }
        
        # Spacer line (empty content)
        if ($currentY -lt $startY + $itemHeight - 1) {
            [void]$sb.Append([VT]::MoveTo(0, $currentY))
            [void]$sb.Append([VT]::ClearLine())
            [void]$sb.Append("$($this.HeaderColor)$($this.PillboxVertical)$($this.NormalColor)$($this.SelectedBg)" + (" " * $contentWidth) + "$($this.NormalColor)$($this.HeaderColor)$($this.PillboxVertical)$($this.NormalColor)")
            $currentY++
        }
        
        # Bottom border
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append([VT]::ClearLine())
        [void]$sb.Append("$($this.HeaderColor)$($this.PillboxBottomLeft)$($this.PillboxHorizontal * $contentWidth)$($this.PillboxBottomRight)$($this.NormalColor)")
        
        return $itemHeight
    }
    
    [int] RenderEmpty([System.Text.StringBuilder]$sb, [int]$startY) {
        [void]$sb.Append([VT]::MoveTo(0, $startY))
        [void]$sb.Append([VT]::ClearLine())
        [void]$sb.Append("$($this.DescriptionColor)No commands found. Press N to create a new command.$($this.NormalColor)")
        
        [void]$sb.Append([VT]::MoveTo(0, $startY + 1))
        [void]$sb.Append([VT]::ClearLine())
        
        return 2
    }
    
    [string] GetCommandDisplayText([Command]$command, [bool]$detailed) {
        $text = ""
        
        # Group prefix
        if (-not [string]::IsNullOrWhiteSpace($command.Group)) {
            $text += "$($this.GroupColor)[$($command.Group)]$($this.NormalColor) "
        }
        
        # Title
        if (-not [string]::IsNullOrWhiteSpace($command.Title)) {
            $text += "$($this.CommandColor)$($command.Title)$($this.NormalColor)"
        } elseif (-not [string]::IsNullOrWhiteSpace($command.CommandText)) {
            # Show truncated command text if no title
            $cmdPreview = $command.CommandText
            if ($cmdPreview.Length -gt 40) {
                $cmdPreview = $cmdPreview.Substring(0, 37) + "..."
            }
            $text += "$($this.CommandColor)$cmdPreview$($this.NormalColor)"
        } else {
            # Fallback for command with no title and no command text
            $text += "$($this.CommandColor)[Empty Command]$($this.NormalColor)"
        }
        
        # Description
        if ($detailed -and -not [string]::IsNullOrWhiteSpace($command.Description)) {
            $text += "$($this.DescriptionColor) - $($command.Description)$($this.NormalColor)"
        }
        
        # Usage count
        if ($command.UseCount -gt 0) {
            $text += " $($this.UsageColor)★$($command.UseCount)$($this.NormalColor)"
        }
        
        # Tags (in simple view)
        if (-not $detailed -and $command.Tags.Count -gt 0) {
            $tagText = ($command.Tags | ForEach-Object { "#$_" }) -join " "
            $text += " $($this.TagColor)$tagText$($this.NormalColor)"
        }
        
        return $text
    }
    
    [string] TruncateText([string]$text, [int]$maxWidth) {
        # Strip ANSI codes for length calculation
        $cleanText = $text -replace '\x1b\[[0-9;]*m', ''
        if ($cleanText.Length -le $maxWidth) {
            return $text.PadRight($maxWidth)
        }
        
        # Find a good truncation point in the clean text
        $truncateAt = $maxWidth - 3
        $cleanTruncated = $cleanText.Substring(0, $truncateAt)
        
        # Apply truncation to original text (approximately)
        # This is a simplified approach - could be more sophisticated
        return ($text.Substring(0, [Math]::Min($text.Length, $truncateAt + 20)) -replace '\x1b\[[0-9;]*m$', '') + "..."
    }
    
    [void] SetStatusMessage([string]$message) {
        $this.StatusMessage = $message
        $this.StatusMessageTime = Get-Date
    }
    
    # COMPLETE INPUT HANDLING - ALL FEATURES PRESERVED
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle search mode first
        if ($this.SearchMode) {
            return $this.HandleSearchInput($key)
        }
        
        # Navigation keys
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                $this.MoveSelection(-1)
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                $this.MoveSelection(1)
                return $true
            }
            ([System.ConsoleKey]::PageUp) {
                $this.MoveSelection(-10)
                return $true
            }
            ([System.ConsoleKey]::PageDown) {
                $this.MoveSelection(10)
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.MoveToFirst()
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.MoveToLast()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                $this.ExecuteSelectedCommand()
                return $true
            }
            ([System.ConsoleKey]::F3) {
                $this.ToggleSearchMode()
                return $true
            }
        }
        
        # Ctrl key combinations
        if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
            switch ($key.Key) {
                ([System.ConsoleKey]::S) {
                    $this.ToggleSearchMode()
                    return $true
                }
            }
        }
        
        # Character-based shortcuts
        $char = $key.KeyChar.ToString().ToLower()
        switch ($char) {
            'e' { $this.EditCommand(); return $true }
            'n' { $this.NewCommand(); return $true }
            'd' { $this.DeleteCommand(); return $true }
            'r' { $this.RunCommand(); return $true }
            't' { $this.ShowTagStatistics(); return $true }
            'q' { return $false } # Signal to quit
        }
        
        return $true # Consume all other keys
    }
    
    [bool] HandleSearchInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                $this.ExitSearchMode()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                $this.ExitSearchMode()
                return $true
            }
            ([System.ConsoleKey]::F3) {
                $this.ExitSearchMode()
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.SearchText.Length -gt 0) {
                    $this.SearchText = $this.SearchText.Substring(0, $this.SearchText.Length - 1)
                    $this.ApplySearchFilter()
                    $this.BuildFlatList()
                }
                return $true
            }
        }
        
        # Add character to search
        if ($key.KeyChar -match '[a-zA-Z0-9\-_\.\s]') {
            $this.SearchText += $key.KeyChar
            $this.ApplySearchFilter()
            $this.BuildFlatList()
        }
        
        return $true
    }
    
    [void] MoveSelection([int]$delta) {
        if ($this.FlatList.Count -eq 0) { return }
        
        $newIndex = $this.SelectedIndex + $delta
        
        # Find next selectable item in the direction we're moving
        if ($delta -gt 0) {
            # Moving down
            for ($i = $newIndex; $i -lt $this.FlatList.Count; $i++) {
                if ($this.FlatList[$i].IsSelectable) {
                    $this.SelectedIndex = $i
                    return
                }
            }
        } else {
            # Moving up
            for ($i = $newIndex; $i -ge 0; $i--) {
                if ($this.FlatList[$i].IsSelectable) {
                    $this.SelectedIndex = $i
                    return
                }
            }
        }
    }
    
    [void] MoveToFirst() {
        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
            if ($this.FlatList[$i].IsSelectable) {
                $this.SelectedIndex = $i
                return
            }
        }
    }
    
    [void] MoveToLast() {
        for ($i = $this.FlatList.Count - 1; $i -ge 0; $i--) {
            if ($this.FlatList[$i].IsSelectable) {
                $this.SelectedIndex = $i
                return
            }
        }
    }
    
    [void] ToggleSearchMode() {
        $this.SearchMode = -not $this.SearchMode
        if (-not $this.SearchMode) {
            $this.SearchText = ""
            $this.ApplySearchFilter()
            $this.BuildFlatList()
        }
    }
    
    [void] ExitSearchMode() {
        $this.SearchMode = $false
    }
    
    # COMPLETE COMMAND OPERATIONS - ALL FEATURES PRESERVED
    [void] ExecuteSelectedCommand() {
        $command = $this.GetSelectedCommand()
        if ($command -ne $null) {
            $this.CopyToClipboard($command)
            $this.SetStatusMessage("Command copied to clipboard!")
        }
    }
    
    [void] CopyToClipboard([Command]$command) {
        try {
            $this.CommandService.CopyToClipboard($command.Id)
            $this.LoadCommands() # Refresh to show updated usage count
        } catch {
            $this.SetStatusMessage("Failed to copy command: $($_.Exception.Message)")
        }
    }
    
    [void] EditCommand() {
        $command = $this.GetSelectedCommand()
        if ($command -eq $null) {
            $this.SetStatusMessage("No command selected")
            return
        }
        
        try {
            # Clear screen and show edit dialog
            [Console]::Clear()
            
            $dialog = [CommandEditDialog]::new($this.CommandService, $command)
            $dialog.Show()
            
            # Refresh commands after editing
            $this.LoadCommands()
            $this.SetStatusMessage("Command updated successfully!")
        } catch {
            $this.SetStatusMessage("Failed to edit command: $($_.Exception.Message)")
        }
    }
    
    [void] NewCommand() {
        try {
            # Clear screen and show new command dialog
            [Console]::Clear()
            
            $dialog = [CommandEditDialog]::new($this.CommandService)
            $dialog.Show()
            
            # Refresh commands after creation
            $this.LoadCommands()
            $this.SetStatusMessage("Command created successfully!")
        } catch {
            $this.SetStatusMessage("Failed to create command: $($_.Exception.Message)")
        }
    }
    
    [void] DeleteCommand() {
        $command = $this.GetSelectedCommand()
        if ($command -eq $null) {
            $this.SetStatusMessage("No command selected")
            return
        }
        
        try {
            # Simple confirmation
            [Console]::Clear()
            Write-Host ""
            Write-Host "DELETE COMMAND" -ForegroundColor Red
            Write-Host ""
            Write-Host "Title: $($command.Title)" -ForegroundColor White
            Write-Host "Command: $($command.CommandText)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Are you sure you want to delete this command? (y/N): " -NoNewline -ForegroundColor Yellow
            
            $response = Read-Host
            if ($response.ToLower() -eq 'y') {
                $this.CommandService.DeleteCommand($command.Id)
                $this.LoadCommands()
                $this.SetStatusMessage("Command deleted successfully!")
            } else {
                $this.SetStatusMessage("Delete cancelled")
            }
        } catch {
            $this.SetStatusMessage("Failed to delete command: $($_.Exception.Message)")
        }
    }
    
    [void] RunCommand() {
        $command = $this.GetSelectedCommand()
        if ($command -eq $null) {
            $this.SetStatusMessage("No command selected")
            return
        }
        
        try {
            # Increment usage count
            $this.CommandService.IncrementUseCount($command.Id)
            
            # For security and simplicity, just copy to clipboard instead of executing
            $this.CopyToClipboard($command)
            $this.SetStatusMessage("Command copied to clipboard (usage count updated)")
        } catch {
            $this.SetStatusMessage("Failed to run command: $($_.Exception.Message)")
        }
    }
    
    [void] ShowTagStatistics() {
        try {
            # Clear screen and show tag statistics
            [Console]::Clear()
            
            $allTags = $this.CommandService.GetTags()
            $tagStats = @{}
            
            # Calculate tag usage
            foreach ($command in $this.Commands) {
                foreach ($tag in $command.Tags) {
                    if ($tagStats.ContainsKey($tag)) {
                        $tagStats[$tag]++
                    } else {
                        $tagStats[$tag] = 1
                    }
                }
            }
            
            if ($allTags.Count -eq 0) {
                Write-Host "No tags found in command library." -ForegroundColor Yellow
            } else {
                Write-Host "TAG STATISTICS" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Total unique tags: $($allTags.Count)" -ForegroundColor White
                Write-Host ""
                
                # Show tags sorted by usage
                Write-Host "Tags by usage:" -ForegroundColor Yellow
                $sortedTags = $tagStats.GetEnumerator() | Sort-Object Value -Descending
                foreach ($tagInfo in $sortedTags) {
                    $tag = $tagInfo.Key
                    $count = $tagInfo.Value
                    Write-Host "  #$tag" -ForegroundColor Magenta -NoNewline
                    Write-Host " ($count commands)" -ForegroundColor Gray
                    
                    # Show sample commands with this tag
                    $sampleCommands = $this.Commands | Where-Object { $_.Tags -contains $tag } | Select-Object -First 2
                    foreach ($cmd in $sampleCommands) {
                        Write-Host "    - $($cmd.Title)" -ForegroundColor DarkGray
                    }
                }
                
                Write-Host ""
                Write-Host "Search examples:" -ForegroundColor Yellow
                Write-Host "  Search for '#docker' to find Docker commands" -ForegroundColor Gray
                Write-Host "  Search for 'git' to find Git-related commands" -ForegroundColor Gray
            }
            
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            [Console]::ReadKey($true) | Out-Null
        } catch {
            $this.SetStatusMessage("Failed to show tag statistics: $($_.Exception.Message)")
        }
    }
}