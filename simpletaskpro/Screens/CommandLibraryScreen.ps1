# CommandLibraryScreen.ps1 - Command library with groups
# Based on TaskListScreen structure for consistency

class CommandLibraryScreen {
    [CommandService]$CommandService
    [Command[]]$Groups
    [System.Collections.Generic.List[object]]$FlatList  # Flattened list for navigation
    [int]$SelectedIndex = 0
    [int]$PreviousSelectedIndex = 0  # For animation tracking
    [int]$ScrollTop = 0
    [int]$Width
    [int]$Height
    [string]$CurrentFilter = "All"  # Filter mode: "All" or tag-based
    [string]$TagFilter = ""  # Tag-based filter like "git", "powershell", etc.
    [object]$AppReference = $null
    
    # Status messages
    [string]$StatusMessage = ""
    [datetime]$StatusMessageTime = [DateTime]::MinValue
    
    # Editing state
    [int]$EditingIndex = -1
    [string]$EditingField = ""  # "title", "description", "commandtext", "tags"
    [string]$EditingValue = ""
    [Command]$EditingCommand = $null
    [bool]$IsNewCommand = $false
    
    # Filter/search state
    [bool]$FilterInputActive = $false
    [string]$FilterInput = ""
    [string]$FilterPrompt = "Filter commands (tags, title, description):"
    
    # TaskListScreen-quality color system (using AppThemeManager)
    [string]$HeaderColor = ""
    [string]$SelectedBg = ""
    [string]$TagColor = "" 
    [string]$NormalColor = ""
    [string]$FieldColor = ""
    [string]$ValueColor = ""
    [string]$BrowserColor = ""
    
    CommandLibraryScreen() {
        $this.CommandService = [CommandService]::new()
        $this.FlatList = [System.Collections.Generic.List[object]]::new()
        $this.InitializeColors()
        $this.LoadGroups()
        
        # Using original hotkey system only
        
        $this.LoadGroups()
    }
    
    [void] InitializeColors() {
        # Use AppThemeManager for consistent TaskListScreen-quality theming
        $this.HeaderColor = [AppThemeManager]::GetColor("Header")
        $this.TagColor = [AppThemeManager]::GetColor("Text")
        $this.FieldColor = [AppThemeManager]::GetColor("Field")
        $this.ValueColor = [AppThemeManager]::GetColor("Value")
        $this.BrowserColor = [AppThemeManager]::GetColor("Browser")
        $this.NormalColor = [VT]::Reset()
        $this.SelectedBg = [AppThemeManager]::GetBackgroundColor("Selected")
    }
    
    [void] SetAppReference([object]$appRef) {
        $this.AppReference = $appRef
    }
    
    [void] Initialize([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
        $this.LoadGroups()
    }
    
    [void] LoadGroups() {
        $this.Groups = $this.CommandService.GetAllGroups().ToArray()
        $this.BuildFlatList()
        
        # Ensure selected index is valid
        if ($this.SelectedIndex -ge $this.FlatList.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
        }
    }
    
    [void] BuildFlatList() {
        $this.FlatList = [System.Collections.Generic.List[object]]::new()
        
        foreach ($group in $this.Groups) {
            if ($this.ShouldShowGroup($group)) {
                # Add group to flat list
                $this.FlatList.Add(@{
                    Type = "Group"
                    Command = $group
                    Level = 0
                    IsGroup = $true
                })
                
                # Add commands if group is not collapsed
                if (-not $group.CommandsCollapsed) {
                    foreach ($command in $group.Commands) {
                        if ($this.ShouldShowCommand($command)) {
                            $this.FlatList.Add(@{
                                Type = "Command"
                                Command = $command
                                Level = 1
                                IsGroup = $false
                            })
                        }
                    }
                }
            }
        }
    }
    
    [bool] ShouldShowGroup([Command]$group) {
        if (-not $group) { return $false }
        
        # Apply current filter
        if ($this.CurrentFilter -eq "All") {
            return $this.MatchesTagFilter($group)
        }
        
        return $this.MatchesTagFilter($group)
    }
    
    [bool] ShouldShowCommand([Command]$command) {
        if (-not $command) { return $false }
        
        # Apply current filter
        if ($this.CurrentFilter -eq "All") {
            return $this.MatchesTagFilter($command)
        }
        
        return $this.MatchesTagFilter($command)
    }
    
    [bool] MatchesTagFilter([Command]$command) {
        if ([string]::IsNullOrWhiteSpace($this.TagFilter)) {
            return $true
        }
        
        return $command.MatchesSearch($this.TagFilter)
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        try {
            # Clear screen
            [void]$sb.Append([VT]::Clear())
            
            # Render header
            $this.RenderHeader($sb)
            
            # Render command list
            $this.RenderCommandList($sb)
            
            # Render status bar
            $this.RenderStatusBar($sb)
            
            # Render filter input if active
            if ($this.FilterInputActive) {
                $this.RenderFilterInput($sb)
            }
            
            return $sb.ToString()
            
        } catch {
            return "Render error: $_"
        }
    }
    
    [void] RenderHeader([System.Text.StringBuilder]$sb) {
        # Title line with colors
        [void]$sb.Append([VT]::MoveTo(0, 0))
        [void]$sb.Append($this.HeaderColor)
        $title = " COMMANDLIB - Command Library ($($this.FlatList.Count) items)"
        $headerLine = $title.PadRight($this.Width)
        [void]$sb.Append($headerLine)
        [void]$sb.Append($this.NormalColor)
        
        # Column headers
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append([VT]::RGB(180, 180, 180))  # Gray headers
        $columnHeader = " Title                                       Description / Command"
        [void]$sb.Append($columnHeader.PadRight($this.Width))
        [void]$sb.Append([VT]::Reset())
        
        # Separator
        [void]$sb.Append([VT]::MoveTo(0, 2))
        [void]$sb.Append([VT]::RGB(100, 150, 255))  # Blue separator
        $separator = "─" * $this.Width
        [void]$sb.Append($separator)
        [void]$sb.Append([VT]::Reset())
    }
    
    [void] RenderCommandList([System.Text.StringBuilder]$sb) {
        $startY = 3
        $currentY = $startY
        $visibleHeight = $this.Height - 6  # Account for header and status
        
        # Calculate scroll position
        $this.EnsureVisible()
        
        for ($i = 0; $i -lt $visibleHeight -and ($this.ScrollTop + $i) -lt $this.FlatList.Count; $i++) {
            $flatIndex = $this.ScrollTop + $i
            $item = $this.FlatList[$flatIndex]
            $isSelected = ($flatIndex -eq $this.SelectedIndex)
            
            if ($isSelected) {
                # Render selected item with pillbox (takes 3 lines)
                $currentY = $this.RenderSelectedCommandItem($sb, $item, $isSelected, $currentY)
            } else {
                # Render normal item (takes 1 line)
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                $this.RenderCommandItem($sb, $item, $currentY, $isSelected)
                $currentY++
            }
        }
        
        # Fill remaining lines
        while ($currentY -lt ($this.Height - 3)) {
            [void]$sb.Append([VT]::MoveTo(0, $currentY))
            [void]$sb.Append(" ".PadRight($this.Width))
            $currentY++
        }
    }
    
    [void] RenderCommandItem([System.Text.StringBuilder]$sb, [object]$item, [int]$y, [bool]$isSelected) {
        $command = $item.Command
        $level = $item.Level
        
        # Set colors based on type (not selection - that's handled separately)
        if ($item.IsGroup) {
            [void]$sb.Append($this.HeaderColor)  # Use theme color for groups
        } else {
            [void]$sb.Append($this.ValueColor)   # Use theme color for commands
        }
        
        # Build the line
        $line = ""
        
        # Indentation
        $indent = " " * ($level * 2)
        $line += $indent
        
        if ($item.IsGroup) {
            # Group with collapse/expand indicator
            $indicator = if ($command.CommandsCollapsed) { "▶ " } else { "▼ " }
            $line += $indicator
            
            # Group title
            $groupTitle = $command.Title
            if ($command.Commands.Count -gt 0) {
                $groupTitle += " ($($command.Commands.Count))"
            }
            $line += $groupTitle.PadRight(40)
            
            # Group description
            if (-not [string]::IsNullOrWhiteSpace($command.Description)) {
                $line += $command.Description
            }
        } else {
            # Command
            $line += "  "  # Extra indent for commands
            
            # Command title (truncated to fit)
            $titleWidth = 38
            $title = $command.Title
            if ($title.Length -gt $titleWidth) {
                $title = $title.Substring(0, $titleWidth - 3) + "..."
            }
            $line += $title.PadRight($titleWidth)
            
            # Command text or description
            $remaining = $this.Width - $line.Length - 2
            if ($remaining -gt 0) {
                $detail = ""
                if (-not [string]::IsNullOrWhiteSpace($command.CommandText)) {
                    $detail = $command.CommandText
                } elseif (-not [string]::IsNullOrWhiteSpace($command.Description)) {
                    $detail = $command.Description
                }
                
                if ($detail.Length -gt $remaining) {
                    $detail = $detail.Substring(0, $remaining - 3) + "..."
                }
                $line += $detail
            }
        }
        
        # Add tags if they fit and not editing
        if ($command.Tags.Count -gt 0 -and $this.EditingIndex -ne $this.SelectedIndex) {
            [void]$sb.Append($this.TagColor)  # Switch to tag color
            $tagString = " ⟨" + ($command.Tags -join ", ") + "⟩"
            $maxTagLength = $this.Width - $line.TrimEnd().Length
            if ($tagString.Length -le $maxTagLength) {
                $line = $line.TrimEnd() + $tagString
            }
        }
        
        # Pad to full width and append
        $line = $line.PadRight($this.Width)
        [void]$sb.Append($line)
        [void]$sb.Append($this.NormalColor)
    }
    
    [void] RenderStatusBar([System.Text.StringBuilder]$sb) {
        $statusY = $this.Height - 2
        
        # Separator line
        [void]$sb.Append([VT]::MoveTo(0, $statusY))
        [void]$sb.Append($this.BrowserColor)  # Use theme color
        $separator = "─" * $this.Width
        [void]$sb.Append($separator)
        [void]$sb.Append($this.NormalColor)
        
        # Status line
        [void]$sb.Append([VT]::MoveTo(0, $statusY + 1))
        [void]$sb.Append($this.BrowserColor)  # Use theme color
        
        $statusLine = ""
        
        if (-not [string]::IsNullOrWhiteSpace($this.StatusMessage)) {
            $statusLine = "  " + $this.StatusMessage
        } else {
            $statusLine = "  [N]ew [E]dit [D]elete [Enter]Copy [F3]Search [F5]Tasks ESC:Quit"
        }
        
        $statusLine = $statusLine.PadRight($this.Width)
        [void]$sb.Append($statusLine)
        [void]$sb.Append($this.NormalColor)
    }
    
    [void] RenderFilterInput([System.Text.StringBuilder]$sb) {
        $y = $this.Height - 4
        
        # Filter input box
        [void]$sb.Append([VT]::MoveTo(0, $y))
        [void]$sb.Append([VT]::RGB(255, 255, 100))  # Yellow prompt
        $promptLine = $this.FilterPrompt.PadRight($this.Width)
        [void]$sb.Append($promptLine)
        [void]$sb.Append([VT]::Reset())
        
        [void]$sb.Append([VT]::MoveTo(0, $y + 1))
        [void]$sb.Append([VT]::RGB(255, 255, 255))  # White input
        [void]$sb.Append([VT]::RGBBG(100, 100, 100))  # Gray background
        $inputLine = "> " + $this.FilterInput
        $inputLine = $inputLine.PadRight($this.Width)
        [void]$sb.Append($inputLine)
        [void]$sb.Append([VT]::Reset())
    }
    
    # Input handling (same pattern as TaskListScreen)
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        
        # Handle filter input mode first
        if ($this.FilterInputActive) {
            return $this.HandleFilterInput($key)
        }
        
        # Handle editing mode input second
        if ($this.EditingIndex -ge 0) {
            return $this.HandleEditingInput($key)
        }
        
        # Handle F5 toggle for switching back to tasks
        if ($key.Key -eq [System.ConsoleKey]::F5 -and $this.AppReference) {
            $this.AppReference.SwitchToTasks()
            return $true
        }
        
        # Handle F3 for search mode
        if ($key.Key -eq [System.ConsoleKey]::F3) {
            $this.StartFilterMode()
            return $true
        }
        
        # Handle input keys - original functionality
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                # Check for Ctrl+Up (move command/group up)
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    if ($this.FlatList.Count -gt 0) {
                        $item = $this.FlatList[$this.SelectedIndex]
                        if ($item.IsGroup) {
                            $this.CommandService.MoveGroupUp($item.Command.Id)
                        } else {
                            $this.CommandService.MoveCommandUp($item.Command.Id)
                        }
                        $this.LoadGroups()
                        
                        # Find the moved item and select it
                        $this.FindAndSelectCommand($item.Command.Id)
                        $this.EnsureVisible()
                    }
                } else {
                    # Normal up navigation
                    if ($this.SelectedIndex -gt 0) {
                        $this.SetSelectedIndex($this.SelectedIndex - 1)
                        $this.EnsureVisible()
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                # Check for Ctrl+Down (move command/group down)
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    if ($this.FlatList.Count -gt 0) {
                        $item = $this.FlatList[$this.SelectedIndex]
                        if ($item.IsGroup) {
                            $this.CommandService.MoveGroupDown($item.Command.Id)
                        } else {
                            $this.CommandService.MoveCommandDown($item.Command.Id)
                        }
                        $this.LoadGroups()
                        
                        # Find the moved item and select it
                        $this.FindAndSelectCommand($item.Command.Id)
                        $this.EnsureVisible()
                    }
                } else {
                    # Normal down navigation
                    if ($this.SelectedIndex -lt ($this.FlatList.Count - 1)) {
                        $this.SetSelectedIndex($this.SelectedIndex + 1)
                        $this.EnsureVisible()
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::Spacebar) {
                # Toggle collapse for groups
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    if ($item.IsGroup -and $item.Command.HasCommands()) {
                        $item.Command.CommandsCollapsed = -not $item.Command.CommandsCollapsed
                        $this.CommandService.UpdateGroup($item.Command)
                        $this.LoadGroups()
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                # Copy command to clipboard
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    if (-not $item.IsGroup) {
                        $this.CommandService.CopyToClipboard($item.Command.Id)
                        $this.StatusMessage = "Command copied to clipboard!"
                        $this.StatusMessageTime = [DateTime]::Now
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::N) {
                # New command/group
                $this.StartNewCommand()
                return $true
            }
            ([System.ConsoleKey]::E) {
                # Edit command/group
                if ($this.FlatList.Count -gt 0) {
                    $this.StartInlineEdit("title")
                }
                return $true
            }
            ([System.ConsoleKey]::D) {
                # Delete command/group
                if ($this.FlatList.Count -gt 0) {
                    $this.DeleteCurrentCommand()
                }
                return $true
            }
            ([System.ConsoleKey]::Escape) {
                return $false  # Exit application
            }
            default {
                return $false
            }
        }
        
        return $false
    }
    
    [void] SetSelectedIndex([int]$newIndex) {
        $this.PreviousSelectedIndex = $this.SelectedIndex
        $this.SelectedIndex = $newIndex
    }
    
    [void] EnsureVisible() {
        $visibleHeight = $this.Height - 6  # Account for header and status bar
        
        if ($this.SelectedIndex -lt $this.ScrollTop) {
            $this.ScrollTop = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this.ScrollTop + $visibleHeight)) {
            $this.ScrollTop = $this.SelectedIndex - $visibleHeight + 1
        }
        
        $this.ScrollTop = [Math]::Max(0, [Math]::Min($this.ScrollTop, $this.FlatList.Count - $visibleHeight))
    }
    
    [void] FindAndSelectCommand([string]$commandId) {
        for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
            if ($this.FlatList[$i].Command.Id -eq $commandId) {
                $this.SelectedIndex = $i
                return
            }
        }
    }
    
    # Filter/Search functionality
    [void] StartFilterMode() {
        $this.FilterInputActive = $true
        $this.FilterInput = $this.TagFilter
    }
    
    [bool] HandleFilterInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                $this.FilterInputActive = $false
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                $this.TagFilter = $this.FilterInput
                $this.FilterInputActive = $false
                $this.LoadGroups()  # Rebuild with new filter
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.FilterInput.Length -gt 0) {
                    $this.FilterInput = $this.FilterInput.Substring(0, $this.FilterInput.Length - 1)
                }
                return $true
            }
            default {
                if ([char]::IsControl($key.KeyChar) -eq $false -and $key.KeyChar -ne [char]0) {
                    $this.FilterInput += $key.KeyChar
                }
                return $true
            }
        }
        return $true
    }
    
    # CRUD operations (similar to TaskListScreen)
    [void] StartNewCommand() {
        "DEBUG: StartNewCommand - FlatList count: $($this.FlatList.Count)" | Out-File -FilePath "./startup-debug.log" -Append
        if ($this.FlatList.Count -eq 0) {
            # No groups exist, create first group
            "DEBUG: No groups exist, creating first group" | Out-File -FilePath "./startup-debug.log" -Append
            $this.StartNewGroup()
        } else {
            $item = $this.FlatList[$this.SelectedIndex]
            "DEBUG: Item type - IsGroup: $($item.IsGroup)" | Out-File -FilePath "./startup-debug.log" -Append
            if ($item.IsGroup) {
                # Create new command in this group
                "DEBUG: Creating new command in group: $($item.Command.Id)" | Out-File -FilePath "./startup-debug.log" -Append
                $this.StartNewCommandInGroup($item.Command.Id)
            } else {
                # Create new command in same group as selected command
                "DEBUG: Creating new command in group: $($item.Command.GroupId)" | Out-File -FilePath "./startup-debug.log" -Append
                $this.StartNewCommandInGroup($item.Command.GroupId)
            }
        }
    }
    
    [void] StartNewGroup() {
        $newGroup = [Command]::new("New Group")
        $newGroup.Description = "New command group"
        $this.CommandService.AddGroup($newGroup)
        $this.LoadGroups()
        
        # Find and select the new group
        $this.FindAndSelectCommand($newGroup.Id)
        $this.StartInlineEdit("title")
    }
    
    [void] StartNewCommandInGroup([string]$groupId) {
        "DEBUG: StartNewCommandInGroup - groupId: $groupId" | Out-File -FilePath "./startup-debug.log" -Append
        $newCommand = [Command]::new("New Command")
        $newCommand.CommandText = ""
        $newCommand.Description = "New command description"
        "DEBUG: Created new command with ID: $($newCommand.Id)" | Out-File -FilePath "./startup-debug.log" -Append
        
        $this.CommandService.AddCommand($newCommand, $groupId)
        "DEBUG: Added command to service" | Out-File -FilePath "./startup-debug.log" -Append
        
        $this.LoadGroups()
        "DEBUG: Loaded groups - new FlatList count: $($this.FlatList.Count)" | Out-File -FilePath "./startup-debug.log" -Append
        
        # Find and select the new command
        $this.FindAndSelectCommand($newCommand.Id)
        "DEBUG: Selected command at index: $($this.SelectedIndex)" | Out-File -FilePath "./startup-debug.log" -Append
        
        $this.StartInlineEdit("title")
        "DEBUG: Started inline edit" | Out-File -FilePath "./startup-debug.log" -Append
    }
    
    [void] DeleteCurrentCommand() {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        
        if ($item.IsGroup) {
            if ($item.Command.HasCommands()) {
                $this.StatusMessage = "Cannot delete group with commands"
                $this.StatusMessageTime = [DateTime]::Now
                return
            }
            $this.CommandService.DeleteGroup($item.Command.Id)
        } else {
            $this.CommandService.DeleteCommand($item.Command.Id)
        }
        
        $this.LoadGroups()
        
        # Adjust selection
        if ($this.SelectedIndex -ge $this.FlatList.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
        }
    }
    
    # Inline editing (similar to TaskListScreen)
    [void] StartInlineEdit([string]$field) {
        if ($this.FlatList.Count -eq 0) { return }
        
        $item = $this.FlatList[$this.SelectedIndex]
        $this.EditingIndex = $this.SelectedIndex
        $this.EditingField = $field
        $this.EditingCommand = $item.Command
        $this.IsNewCommand = $false
        
        switch ($field) {
            "title" { $this.EditingValue = $this.EditingCommand.Title }
            "description" { $this.EditingValue = $this.EditingCommand.Description }
            "commandtext" { $this.EditingValue = $this.EditingCommand.CommandText }
            "tags" { $this.EditingValue = $this.EditingCommand.Tags -join ", " }
            default { $this.EditingValue = "" }
        }
    }
    
    [bool] HandleEditingInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                $this.CancelEdit()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                $this.SaveEdit()
                return $true
            }
            ([System.ConsoleKey]::Tab) {
                # Cycle through editable fields
                $this.CycleEditField()
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.EditingValue.Length -gt 0) {
                    $this.EditingValue = $this.EditingValue.Substring(0, $this.EditingValue.Length - 1)
                }
                return $true
            }
            default {
                if ([char]::IsControl($key.KeyChar) -eq $false -and $key.KeyChar -ne [char]0) {
                    $this.EditingValue += $key.KeyChar
                }
                return $true
            }
        }
        return $true
    }
    
    [void] CycleEditField() {
        if ($this.EditingCommand.IsGroup()) {
            switch ($this.EditingField) {
                "title" { $this.EditingField = "description" }
                "description" { $this.EditingField = "tags" }
                "tags" { $this.EditingField = "title" }
                default { $this.EditingField = "title" }
            }
        } else {
            switch ($this.EditingField) {
                "title" { $this.EditingField = "commandtext" }
                "commandtext" { $this.EditingField = "description" }
                "description" { $this.EditingField = "tags" }
                "tags" { $this.EditingField = "title" }
                default { $this.EditingField = "title" }
            }
        }
        
        # Update editing value for new field
        switch ($this.EditingField) {
            "title" { $this.EditingValue = $this.EditingCommand.Title }
            "description" { $this.EditingValue = $this.EditingCommand.Description }
            "commandtext" { $this.EditingValue = $this.EditingCommand.CommandText }
            "tags" { $this.EditingValue = $this.EditingCommand.Tags -join ", " }
        }
    }
    
    [void] SaveEdit() {
        if ($this.EditingCommand) {
            switch ($this.EditingField) {
                "title" { $this.EditingCommand.Title = $this.EditingValue }
                "description" { $this.EditingCommand.Description = $this.EditingValue }
                "commandtext" { $this.EditingCommand.CommandText = $this.EditingValue }
                "tags" { 
                    $this.EditingCommand.Tags = @()
                    if (-not [string]::IsNullOrWhiteSpace($this.EditingValue)) {
                        $this.EditingCommand.Tags = ($this.EditingValue -split ",") | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                    }
                }
            }
            
            if ($this.EditingCommand.IsGroup()) {
                $this.CommandService.UpdateGroup($this.EditingCommand)
            } else {
                $this.CommandService.UpdateCommand($this.EditingCommand)
            }
            
            $this.LoadGroups()
        }
        
        $this.CancelEdit()
    }
    
    [void] CancelEdit() {
        $this.EditingIndex = -1
        $this.EditingField = ""
        $this.EditingValue = ""
        $this.EditingCommand = $null
        $this.IsNewCommand = $false
    }
}