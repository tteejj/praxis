# CommandLibraryScreen.ps1 - Command library with groups
# Based on TaskListScreen structure for consistency

class CommandLibraryScreen : ListScreen {
    [CommandService]$CommandService
    [Command[]]$Groups
    # Inherited: [System.Collections.Generic.List[object]]$FlatList
    # Inherited: [int]$SelectedIndex = 0
    [int]$PreviousSelectedIndex = 0  # For animation tracking
    # Inherited: [int]$ScrollTop = 0
    # Inherited: [int]$Width
    # Inherited: [int]$Height
    [string]$CurrentFilter = "All"  # Filter mode: "All" or tag-based
    [string]$TagFilter = ""  # Tag-based filter like "git", "powershell", etc.
    
    # Status messages inherited from BaseListScreen
    # Inherited: [string]$StatusMessage = ""
    # Inherited: [datetime]$StatusMessageTime = [DateTime]::MinValue
    
    # Editing state inherited from BaseListScreen
    # Inherited: [int]$EditingIndex = -1
    # Inherited: [string]$EditingField = ""
    # Inherited: [string]$EditingValue = ""
    # Inherited: [int]$EditingCursor = 0
    # Inherited: [object]$EditingItem = $null (was EditingCommand)
    # Inherited: [bool]$IsNewItem = $false (was IsNewCommand)
    
    # Column widths (like TaskListScreen)
    [int]$COLUMN_TITLE = 30      # Command title
    [int]$COLUMN_COMMAND = 35    # Command text  
    [int]$COLUMN_DESC = 25       # Description
    
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
    [string]$EditHighlight = ""
    [string]$MutedColor = ""
    [string]$PillboxColor = ""
    
    CommandLibraryScreen([ServiceContainer]$services) : base($services) {
        $this.CommandService = [CommandService]::new()
        $this.Title = "Commands"
        # Inherited: $this.FlatList is initialized by base constructor
        $this.InitializeColors()
        $this.LoadGroups()
    }
    
    [void] InitializeColors() {
        # Use AppThemeManager for consistent TaskListScreen-quality theming
        $this.HeaderColor = [AppThemeManager]::GetColor("Header")
        $this.TagColor = [AppThemeManager]::GetColor("Text") 
        $this.FieldColor = [AppThemeManager]::GetColor("Field")
        $this.ValueColor = [AppThemeManager]::GetColor("Value")
        $this.BrowserColor = [AppThemeManager]::GetColor("Browser")
        $this.EditHighlight = [AppThemeManager]::GetColor("EditHighlight")
        $this.MutedColor = [AppThemeManager]::GetColor("Muted")
        $this.PillboxColor = [AppThemeManager]::GetPillboxColor()
        $this.NormalColor = [VT]::Reset()
        $this.SelectedBg = [AppThemeManager]::GetBackgroundColor("Selected")
    }
    
    
    [void] Initialize([int]$width, [int]$height) {
        $this.Width = [Math]::Max(80, $width)
        $this.Height = [Math]::Max(24, $height)
        $this.LoadGroups()
    }
    
    [void] LoadGroups() {
        $this.Groups = $this.CommandService.GetAllGroups().ToArray()
        $this.FlatList = $this.BuildFlatList()
        
        # Ensure selected index is valid
        if ($this.SelectedIndex -ge $this.FlatList.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
        }
    }
    
    [array] BuildFlatList() {
        return $this.BuildFlatListInternal($null)
    }
    
    [array] BuildFlatList([array]$inputGroups) {
        return $this.BuildFlatListInternal($inputGroups)
    }
    
    [array] BuildFlatListInternal([array]$inputGroups) {
        $groupArray = if ($inputGroups) { $inputGroups } else { $this.Groups }
        $newList = [System.Collections.Generic.List[object]]::new()
        
        foreach ($group in $groupArray) {
            if ($this.ShouldShowGroup($group)) {
                # Add group to flat list
                $newList.Add(@{
                    Type = "Group"
                    Command = $group
                    Level = 0
                    IsGroup = $true
                })
                
                # Add commands if group is not collapsed
                if (-not $group.CommandsCollapsed) {
                    foreach ($command in $group.Commands) {
                        if ($this.ShouldShowCommand($command)) {
                            $newList.Add(@{
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
        
        return $newList.ToArray()
    }
    
    # Implement abstract methods from BaseListScreen
    [void] LoadData() {
        $this.LoadGroups()
    }
    
    [string] RenderItem([object]$item, [int]$index, [bool]$isSelected) {
        $command = $item.Command
        $level = $item.Level
        $isGroup = $item.IsGroup
        
        return $this.FormatCommandLine($command, $level, $isGroup, $isSelected)
    }
    
    [string[]] GetEditableFields([object]$item) {
        # For commands, return the editable fields
        return @("Title", "CommandText", "Description", "Tags")
    }
    
    [void] SaveItem([object]$item) {
        $command = if ($item -is [hashtable]) { $item.Command } else { $item }
        $this.CommandService.UpdateCommand($command)
        $this.CommandService.Save()
    }
    
    [object] CreateNewItem() {
        $newCommand = [Command]::new()
        $newCommand.Title = "New Command"
        $newCommand.CommandText = ""
        $newCommand.Description = ""
        $newCommand.Tags = @()
        
        # Add to service and return wrapped in hashtable
        $this.CommandService.AddCommand($newCommand)
        return @{
            Type = "Command"
            Command = $newCommand
            Level = 1
            IsGroup = $false
        }
    }
    
    [string] FormatCommandLine([Command]$command, [int]$level, [bool]$isGroup, [bool]$isSelected) {
        $sb = [System.Text.StringBuilder]::new()
        
        if ($isGroup) {
            # Format group line
            $prefix = if ($command.CommandsCollapsed) { "▼ " } else { "▲ " }
            [void]$sb.Append("$prefix$($command.Title)")
        } else {
            # Format command line
            $indent = "  "  # Indent for commands under groups
            [void]$sb.Append("$indent$($command.Title.PadRight(28)) $($command.CommandText)")
        }
        
        return $sb.ToString()
    }
    
    # Override field access methods for Command objects
    [string] GetFieldValue([object]$item, [string]$field) {
        $command = if ($item -is [hashtable]) { $item.Command } else { $item }
        
        switch ($field) {
            "Title" { return if ($command.Title) { $command.Title } else { "" } }
            "CommandText" { return if ($command.CommandText) { $command.CommandText } else { "" } }
            "Description" { return if ($command.Description) { $command.Description } else { "" } }
            "Tags" { return if ($command.Tags) { $command.Tags -join ", " } else { "" } }
            default { 
                # Call base class method
                $baseMethod = [ListScreen].GetMethod("GetFieldValue")
                return $baseMethod.Invoke($this, @($item, $field))
            }
        }
        return ""
    }
    
    [void] SetFieldValue([object]$item, [string]$field, [string]$value) {
        $command = if ($item -is [hashtable]) { $item.Command } else { $item }
        
        switch ($field) {
            "Title" { $command.Title = $value }
            "CommandText" { $command.CommandText = $value }
            "Description" { $command.Description = $value }
            "Tags" { 
                $command.Tags.Clear()
                if ($value) {
                    $tags = $value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    foreach ($tag in $tags) { $command.Tags.Add($tag) }
                }
            }
            default { 
                # Call base class method
                $baseMethod = [ListScreen].GetMethod("SetFieldValue")
                $baseMethod.Invoke($this, @($item, $field, $value))
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
            
            # Cursor management (exactly like TaskListScreen)
            if ($this.EditingIndex -ge 0) {
                [void]$sb.Append([VT]::ShowCursor())
                [void]$sb.Append("`e]12;#FF0000`e\")  # Red cursor for visibility
                $this.PositionEditingCursor($sb)
            } elseif ($this.FilterInputActive) {
                [void]$sb.Append([VT]::ShowCursor())
                [void]$sb.Append("`e]12;#FF0000`e\")
                $filterCursorX = 2 + $this.FilterInput.Length
                [void]$sb.Append([VT]::MoveTo($filterCursorX, $this.Height - 1))
            } else {
                [void]$sb.Append([VT]::HideCursor())
                [void]$sb.Append("`e]12;#FFFFFF`e\")
            }
            
            return $sb.ToString()
            
        } catch {
            return "Render error: $_"
        }
    }
    
    [void] RenderHeader([System.Text.StringBuilder]$sb) {
        # Title line with AppThemeManager colors
        [void]$sb.Append([VT]::MoveTo(0, 0))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        $title = " COMMANDLIB - Command Library ($($this.FlatList.Count) items)"
        if ($this.CurrentFilter -ne "All" -or $this.TagFilter -ne "") {
            $title += " [Filtered]"
        }
        [void]$sb.Append($title.PadRight($this.Width))
        [void]$sb.Append([VT]::Reset())
        
        # Column headers (using TaskListScreen styling)
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append([AppThemeManager]::GetColor("Text"))
        [void]$sb.Append(" Title".PadRight($this.COLUMN_TITLE))
        [void]$sb.Append("Command Text".PadRight($this.COLUMN_COMMAND))
        [void]$sb.Append("Description")
        [void]$sb.Append([VT]::Reset())
        
        # Separator using StringCache for performance
        [void]$sb.Append([VT]::MoveTo(0, 2))
        [void]$sb.Append([AppThemeManager]::GetColor("Header"))
        [void]$sb.Append(" " + [StringCache]::GetRepeatedChar('─', $this.Width - 1))
        [void]$sb.Append([VT]::Reset())
    }
    
    [void] RenderCommandList([System.Text.StringBuilder]$sb) {
        $startY = 3
        $currentY = $startY
        $visibleHeight = [Math]::Max(5, $this.Height - 6)  # Account for header and status, minimum 5 lines
        
        # Calculate scroll position
        $this.EnsureVisible()
        
        for ($i = 0; $i -lt $visibleHeight -and ($this.ScrollTop + $i) -lt $this.FlatList.Count; $i++) {
            $flatIndex = $this.ScrollTop + $i
            $item = $this.FlatList[$flatIndex]
            $isSelected = ($flatIndex -eq $this.SelectedIndex)
            $isEditing = ($this.EditingIndex -eq $flatIndex)
            
            if ($isSelected) {
                # Render selected item with pillbox (takes 3 lines) - handles both new and existing
                $currentY = $this.RenderSelectedCommandItem($sb, $item, $isEditing, $currentY)
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
    
    [int] RenderSelectedCommandItem([System.Text.StringBuilder]$sb, [object]$item, [bool]$isEditing, [int]$currentY) {
        # Use pre-initialized pillbox color from InitializeColors
        
        # Top border
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append($this.PillboxColor)
        [void]$sb.Append("╭" + [StringCache]::GetRepeatedChar('─', $this.Width - 2) + "╮")
        [void]$sb.Append($this.NormalColor)
        $currentY++
        
        # Content line
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append($this.PillboxColor)
        [void]$sb.Append("│ ")
        
        # Build content based on item type
        $command = $item.Command
        $level = $item.Level
        $content = ""
        
        # Indentation
        $indent = " " * ($level * 2)
        $content += $indent
        
        # Render command fields in columns (exactly like TaskListScreen)
        if (-not $item.IsGroup) {
            # Column 1: Title
            if ($isEditing -and $this.EditingField -eq "title") {
                $titleValue = $this.EditingValue
                if ($titleValue.Length -gt $this.COLUMN_TITLE) { $titleValue = $titleValue.Substring(0, $this.COLUMN_TITLE) }
                $content += [AppThemeManager]::GetColor("EditHighlight") + $titleValue.PadRight($this.COLUMN_TITLE) + [VT]::Reset()
            } else {
                $titleText = if ($command.Title) { $command.Title } else { "" }
                if ($titleText.Length -gt $this.COLUMN_TITLE) { $titleText = $titleText.Substring(0, $this.COLUMN_TITLE) }
                $content += [AppThemeManager]::GetColor("Value") + $titleText.PadRight($this.COLUMN_TITLE) + [VT]::Reset()
            }
            
            # Column 2: Command Text
            if ($isEditing -and $this.EditingField -eq "commandtext") {
                $cmdValue = $this.EditingValue
                if ($cmdValue.Length -gt $this.COLUMN_COMMAND) { $cmdValue = $cmdValue.Substring(0, $this.COLUMN_COMMAND) }
                $content += [AppThemeManager]::GetColor("EditHighlight") + $cmdValue.PadRight($this.COLUMN_COMMAND) + [VT]::Reset()
            } else {
                $cmdText = if ($command.CommandText) { $command.CommandText } else { "" }
                if ($cmdText.Length -gt $this.COLUMN_COMMAND) { $cmdText = $cmdText.Substring(0, $this.COLUMN_COMMAND) }
                $content += [AppThemeManager]::GetColor("Field") + $cmdText.PadRight($this.COLUMN_COMMAND) + [VT]::Reset()
            }
            
            # Column 3: Description
            if ($isEditing -and $this.EditingField -eq "description") {
                $descValue = $this.EditingValue
                if ($descValue.Length -gt $this.COLUMN_DESC) { $descValue = $descValue.Substring(0, $this.COLUMN_DESC) }
                $content += [AppThemeManager]::GetColor("EditHighlight") + $descValue.PadRight($this.COLUMN_DESC) + [VT]::Reset()
            } else {
                $descText = if ($command.Description) { $command.Description } else { "" }
                if ($descText.Length -gt $this.COLUMN_DESC) { $descText = $descText.Substring(0, $this.COLUMN_DESC) }
                $content += [AppThemeManager]::GetColor("Browser") + $descText.PadRight($this.COLUMN_DESC) + [VT]::Reset()
            }
        } elseif ($item.IsGroup) {
            # Group with collapse/expand indicator
            $indicator = if ($command.CommandsCollapsed) { "▶ " } else { "▼ " }
            $content += $indicator
            
            # Group title (with editing support)
            if ($isEditing -and $this.EditingField -eq "title") {
                $editValue = $this.EditingValue
                if ($this.EditingValue.Length -gt 38) {
                    $editValue = $this.EditingValue.Substring(0, 35) + "..."
                }
                $content += "[$editValue]"
                if ($command.Commands.Count -gt 0) {
                    $content += " ($($command.Commands.Count))"
                }
                $content = $content.PadRight(38)
            } else {
                $groupTitle = $command.Title
                if ($command.Commands.Count -gt 0) {
                    $groupTitle += " ($($command.Commands.Count))"
                }
                $content += $groupTitle.PadRight(38)
            }
            
            # Group description (with editing support)
            if ($isEditing -and $this.EditingField -eq "description") {
                $remaining = $this.Width - $content.Length - 6
                if ($remaining -gt 0) {
                    $editValue = $this.EditingValue
                    if ($editValue.Length -gt $remaining) {
                        $editValue = $editValue.Substring(0, $remaining - 6) + "..."
                    }
                    $content += " - [$editValue]"
                }
            } elseif (-not [string]::IsNullOrWhiteSpace($command.Description)) {
                $remaining = $this.Width - $content.Length - 6  # Account for borders and padding
                if ($remaining -gt 0) {
                    $desc = $command.Description
                    if ($desc.Length -gt $remaining) {
                        $desc = $desc.Substring(0, $remaining - 3) + "..."
                    }
                    $content += " - " + $desc
                }
            }
        } else {
            # Command
            $content += "  "  # Extra indent for commands
            
            # Command title (with editing support)
            if ($isEditing -and $this.EditingField -eq "title") {
                $editValue = $this.EditingValue
                if ($editValue.Length -gt 36) {
                    $editValue = $editValue.Substring(0, 33) + "..."
                }
                $content += "[$editValue]".PadRight(36)
            } else {
                $titleWidth = 36
                $title = $command.Title
                if ($title.Length -gt $titleWidth) {
                    $title = $title.Substring(0, $titleWidth - 3) + "..."
                }
                $content += $title.PadRight($titleWidth)
            }
            
            # Command text or description (with editing support)
            $remaining = $this.Width - $content.Length - 6  # Account for borders and padding
            if ($remaining -gt 0) {
                if ($isEditing -and $this.EditingField -eq "commandtext") {
                    $editValue = $this.EditingValue
                    if ($editValue.Length -gt $remaining) {
                        $editValue = $editValue.Substring(0, $remaining - 6) + "..."
                    }
                    $content += " [$editValue]"
                } elseif ($isEditing -and $this.EditingField -eq "description") {
                    $editValue = $this.EditingValue
                    if ($editValue.Length -gt $remaining) {
                        $editValue = $editValue.Substring(0, $remaining - 6) + "..."
                    }
                    $content += " [$editValue]"
                } else {
                    $detail = ""
                    if (-not [string]::IsNullOrWhiteSpace($command.CommandText)) {
                        $detail = $command.CommandText
                    } elseif (-not [string]::IsNullOrWhiteSpace($command.Description)) {
                        $detail = $command.Description
                    }
                    
                    if ($detail.Length -gt $remaining) {
                        $detail = $detail.Substring(0, $remaining - 3) + "..."
                    }
                    $content += " " + $detail
                }
            }
        }
        
        # Truncate content if too long and append
        $maxContentLength = $this.Width - 4  # Account for borders
        if ($content.Length -gt $maxContentLength) {
            $content = $content.Substring(0, $maxContentLength - 3) + "..."
        }
        
        [void]$sb.Append($content.PadRight($maxContentLength))
        [void]$sb.Append(" │")
        [void]$sb.Append([VT]::Reset())
        $currentY++
        
        # Tags line (exactly like TaskListScreen)
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append($this.PillboxColor)
        [void]$sb.Append("│ ")
        
        # Render tags with editing support
        if ($isEditing -and $this.EditingField -eq "tags") {
            # Show editing tags with highlight
            $tagsText = "Tags: " + $this.EditingValue
            [void]$sb.Append([AppThemeManager]::GetColor("EditHighlight") + $tagsText + [VT]::Reset())
        } else {
            # Show existing tags
            $tagsText = "Tags: "
            if ($command.Tags -and $command.Tags.Count -gt 0) {
                $tagsList = $command.Tags -join ", "
                $tagsText += $tagsList
            } else {
                $tagsText += "(none)"
            }
            [void]$sb.Append([AppThemeManager]::GetColor("Text") + $tagsText + [VT]::Reset())
        }
        
        # Pad and close tags line
        $tagsLineContent = ($maxContentLength - 6)  # Account for "│ " and " │"
        [void]$sb.Append((" " * [Math]::Max(0, $tagsLineContent - $tagsText.Length)))
        [void]$sb.Append(" │")
        [void]$sb.Append([VT]::Reset())
        $currentY++
        
        # Bottom border
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append($this.PillboxColor)
        [void]$sb.Append("╰" + [StringCache]::GetRepeatedChar('─', $this.Width - 2) + "╯")
        [void]$sb.Append([VT]::Reset())
        $currentY++
        
        return $currentY
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
        
        # Separator line using StringCache and AppThemeManager
        [void]$sb.Append([VT]::MoveTo(0, $statusY))
        [void]$sb.Append([AppThemeManager]::GetColor("StatusBar"))
        [void]$sb.Append(" " + [StringCache]::GetRepeatedChar('─', $this.Width - 1))
        [void]$sb.Append([VT]::Reset())
        
        # Status line
        [void]$sb.Append([VT]::MoveTo(0, $statusY + 1))
        [void]$sb.Append([AppThemeManager]::GetColor("StatusBar"))
        
        $statusLine = ""
        
        if ($this.EditingIndex -ge 0) {
            # Show editing status with helpful instructions
            $fieldName = $this.EditingField.ToUpper()
            if ($this.IsNewCommand) {
                $statusLine = "  NEW COMMAND [$fieldName]: Type text, Tab=Next field, Enter=Save, Esc=Cancel, Home/End/Arrows to navigate"
            } else {
                $statusLine = "  EDITING [$fieldName]: Type text, Tab=Next field, Enter=Save, Esc=Cancel, Home/End/Arrows to navigate"
            }
        } elseif (-not [string]::IsNullOrWhiteSpace($this.StatusMessage)) {
            $statusLine = "  " + $this.StatusMessage
        } else {
            $statusLine = "  [N]ew [E]dit [D]elete [Enter]Copy [F3]Search [F5]Tasks ESC:Quit"
        }
        
        [void]$sb.Append($statusLine.PadRight($this.Width))
        [void]$sb.Append([VT]::Reset())
    }
    
    [void] RenderFilterInput([System.Text.StringBuilder]$sb) {
        $y = $this.Height - 4
        
        # Filter input box
        [void]$sb.Append([VT]::MoveTo(0, $y))
        [void]$sb.Append($this.FieldColor)  # Use theme color for prompt
        $promptLine = $this.FilterPrompt.PadRight($this.Width)
        [void]$sb.Append($promptLine)
        [void]$sb.Append($this.NormalColor)
        
        [void]$sb.Append([VT]::MoveTo(0, $y + 1))
        [void]$sb.Append([AppThemeManager]::GetBackgroundColor("Selected"))  # Use theme background
        $inputLine = "> " + $this.FilterInput
        $inputLine = $inputLine.PadRight($this.Width)
        [void]$sb.Append($inputLine)
        [void]$sb.Append($this.NormalColor)
    }
    
    # Override HandleInput to integrate with BaseListScreen editing
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # If BaseListScreen is handling editing, let it handle the input
        if ($this.EditingItem -ne $null) {
            return $this.HandleInput($key)
        }
        
        # Handle filter input mode first
        if ($this.FilterInputActive) {
            return $this.HandleFilterInput($key)
        }
        
        # Handle F5 toggle for switching back to tasks
        if ($key.Key -eq [System.ConsoleKey]::F5) {
            try {
                $this.EventBus.Publish("NavigateTo", "tasks")
            } catch {
                # Ignore F5 switch errors
            }
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
                # Copy command to clipboard or start editing
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    if (-not $item.IsGroup -and $this.EditingIndex -eq -1) {
                        # Copy command text to clipboard
                        try {
                            $command = $item.Command
                            if (-not [string]::IsNullOrWhiteSpace($command.CommandText)) {
                                # Use built-in clipboard if available
                                if (Get-Command Set-Clipboard -ErrorAction SilentlyContinue) {
                                    $command.CommandText | Set-Clipboard
                                    $this.StatusMessage = "Command copied to clipboard: $($command.Title)"
                                } else {
                                    # Fallback for systems without Set-Clipboard
                                    $this.StatusMessage = "Clipboard not available: $($command.CommandText)"
                                }
                            } else {
                                $this.StatusMessage = "No command text to copy for: $($command.Title)"
                            }
                        } catch {
                            $this.StatusMessage = "Failed to copy command: $_"
                        }
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
    
    # CRUD operations (exactly like TaskListScreen)
    [void] StartNewCommand() {
        if ($this.FlatList.Count -eq 0) {
            # No groups exist, create first group
            $this.StartNewGroup()
        } else {
            # Create new command inline - just set editing state directly
            $this.EditingIndex = $this.SelectedIndex
            $this.EditingField = "title"
            $this.EditingValue = ""
            $this.EditingCursor = 0
            $this.IsNewCommand = $true
            
            # Create temporary command object for editing
            $this.EditingCommand = [Command]::new("")
            $this.EditingCommand.Title = ""
            $this.EditingCommand.CommandText = ""
            $this.EditingCommand.Description = ""
            $this.EditingCommand.Tags = @()
            
            # Set group ID based on current selection
            $item = $this.FlatList[$this.SelectedIndex]
            if ($item.IsGroup) {
                $this.EditingCommand.GroupId = $item.Command.Id
            } else {
                $this.EditingCommand.GroupId = $item.Command.GroupId
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
    
    [void] StartNewCommandEdit([string]$groupId) {
        if ($global:Debug) { "DEBUG: StartNewCommandEdit - groupId: $groupId" | Out-File -FilePath "./startup-debug.log" -Append }
        
        # Create temporary command (DON'T ADD TO SERVICE YET)
        $newCommand = [Command]::new("")
        $newCommand.CommandText = ""
        $newCommand.Description = ""
        $newCommand.GroupId = $groupId
        if ($global:Debug) { "DEBUG: Created temporary command for editing" | Out-File -FilePath "./startup-debug.log" -Append }
        
        # Create temporary FlatList item for display purposes
        $tempItem = [PSCustomObject]@{
            Command = $newCommand
            IsGroup = $false
            IndentLevel = 1
        }
        
        # Find the insertion position (after the group header) with bounds checking
        $insertIndex = $this.FlatList.Count  # Default to end of list
        
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.FlatList.Count) {
            if ($this.FlatList[$this.SelectedIndex].IsGroup) {
                # If we're on a group, insert right after it
                $insertIndex = $this.SelectedIndex + 1
            } else {
                # If we're on a command, find its parent group and insert after
                for ($i = $this.SelectedIndex; $i -ge 0; $i--) {
                    if ($this.FlatList[$i].IsGroup) {
                        $insertIndex = $i + 1
                        break
                    }
                }
            }
        }
        
        # Ensure insertIndex is within bounds
        if ($insertIndex -gt $this.FlatList.Count) {
            $insertIndex = $this.FlatList.Count
        }
        
        # Insert temporary item into FlatList for rendering
        $this.FlatList.Insert($insertIndex, $tempItem)
        
        # Set up editing state
        $this.SelectedIndex = $insertIndex
        $this.EditingIndex = $insertIndex
        $this.EditingField = "title"
        $this.EditingCommand = $newCommand
        $this.IsNewCommand = $true
        $this.EditingValue = ""
        
        if ($global:Debug) { "DEBUG: Started new command editing mode at index $insertIndex" | Out-File -FilePath "./startup-debug.log" -Append }
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
            "title" { 
                $this.EditingValue = $this.EditingCommand.Title
                $this.EditingCursor = $this.EditingValue.Length
            }
            "description" { 
                $this.EditingValue = $this.EditingCommand.Description
                $this.EditingCursor = $this.EditingValue.Length
            }
            "commandtext" { 
                $this.EditingValue = $this.EditingCommand.CommandText
                $this.EditingCursor = $this.EditingValue.Length
            }
            "tags" { 
                $this.EditingValue = $this.EditingCommand.Tags -join ", "
                $this.EditingCursor = $this.EditingValue.Length
            }
            default { 
                $this.EditingValue = ""
                $this.EditingCursor = 0
            }
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
                $this.NextEditField()
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.EditingCursor -gt 0) {
                    $this.EditingValue = $this.EditingValue.Remove($this.EditingCursor - 1, 1)
                    $this.EditingCursor--
                }
                return $true
            }
            ([System.ConsoleKey]::Delete) {
                if ($this.EditingCursor -lt $this.EditingValue.Length) {
                    $this.EditingValue = $this.EditingValue.Remove($this.EditingCursor, 1)
                }
                return $true
            }
            ([System.ConsoleKey]::LeftArrow) {
                if ($this.EditingCursor -gt 0) {
                    $this.EditingCursor--
                }
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                if ($this.EditingCursor -lt $this.EditingValue.Length) {
                    $this.EditingCursor++
                }
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.EditingCursor = 0
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.EditingCursor = $this.EditingValue.Length
                return $true
            }
            default {
                if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                    $this.EditingValue = $this.EditingValue.Insert($this.EditingCursor, $key.KeyChar)
                    $this.EditingCursor++
                }
                return $true
            }
        }
        return $true
    }
    
    # Field cycling exactly like TaskListScreen
    [void] NextEditField() {
        # Save current field value only if something was entered, then move to next field
        # Field cycle: title → commandtext → description → tags → title (cycle)
        switch ($this.EditingField) {
            "title" {
                # Only update if user entered something
                if ($this.EditingValue.Trim() -ne "") {
                    $this.EditingCommand.Title = $this.EditingValue.Trim()
                }
                $this.EditingField = "commandtext"
                # Preserve existing command text when switching fields
                $this.EditingValue = if ($this.EditingCommand.CommandText) { $this.EditingCommand.CommandText } else { "" }
                $this.EditingCursor = $this.EditingValue.Length
            }
            "commandtext" {
                # Only update if user entered something
                if ($this.EditingValue.Trim() -ne "") {
                    $this.EditingCommand.CommandText = $this.EditingValue.Trim()
                }
                $this.EditingField = "description"
                # Preserve existing description when switching fields
                $this.EditingValue = if ($this.EditingCommand.Description) { $this.EditingCommand.Description } else { "" }
                $this.EditingCursor = $this.EditingValue.Length
            }
            "description" {
                # Only update if user entered something
                if ($this.EditingValue.Trim() -ne "") {
                    $this.EditingCommand.Description = $this.EditingValue.Trim()
                }
                $this.EditingField = "tags"
                # Preserve existing tags when switching fields
                $this.EditingValue = if ($this.EditingCommand.Tags.Count -gt 0) { ($this.EditingCommand.Tags -join ", ") } else { "" }
                $this.EditingCursor = $this.EditingValue.Length
            }
            "tags" {
                # Only update if user entered something
                if ($this.EditingValue.Trim() -ne "") {
                    $tagParts = $this.EditingValue -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                    $this.EditingCommand.Tags = $tagParts
                }
                
                # Always cycle back to title - complete cycle
                $this.EditingField = "title"
                # Preserve existing title when switching fields
                $this.EditingValue = if ($this.EditingCommand.Title) { $this.EditingCommand.Title } else { "" }
                $this.EditingCursor = $this.EditingValue.Length
            }
        }
    }
    
    [void] SaveEdit() {
        if ($this.EditingCommand) {
            # Update the field being edited
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
            
            if ($this.IsNewCommand) {
                # Remove temporary item from FlatList first
                if ($this.EditingIndex -ge 0 -and $this.EditingIndex -lt $this.FlatList.Count) {
                    try {
                        $this.FlatList.RemoveAt($this.EditingIndex)
                    } catch {
                        if ($global:Debug) { "DEBUG: Error removing temporary item: $_" | Out-File -FilePath "./startup-debug.log" -Append }
                    }
                }
                
                # NEW COMMAND: Only save if they actually typed something
                if (-not [string]::IsNullOrWhiteSpace($this.EditingCommand.Title)) {
                    if ($global:Debug) { "DEBUG: Saving new command: $($this.EditingCommand.Title)" | Out-File -FilePath "./startup-debug.log" -Append }
                    $this.CommandService.AddCommand($this.EditingCommand, $this.EditingCommand.GroupId)
                    $this.LoadGroups()
                    # Find and select the new command
                    $this.FindAndSelectCommand($this.EditingCommand.Id)
                } else {
                    if ($global:Debug) { "DEBUG: New command cancelled - no title entered" | Out-File -FilePath "./startup-debug.log" -Append }
                    # Reload groups to refresh display without temporary item
                    $this.LoadGroups()
                }
            } else {
                # EXISTING COMMAND: Update it
                if ($this.EditingCommand.IsGroup()) {
                    $this.CommandService.UpdateGroup($this.EditingCommand)
                } else {
                    $this.CommandService.UpdateCommand($this.EditingCommand)
                }
                $this.LoadGroups()
            }
        }
        
        $this.CancelEdit()
    }
    
    [void] CancelEdit() {
        if ($this.IsNewCommand) {
            # Remove temporary item from FlatList
            if ($this.EditingIndex -ge 0 -and $this.EditingIndex -lt $this.FlatList.Count) {
                try {
                    $this.FlatList.RemoveAt($this.EditingIndex)
                    if ($this.SelectedIndex -ge $this.FlatList.Count) {
                        $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
                    }
                } catch {
                    # Ignore removal errors
                }
            }
        }
        
        $this.EditingIndex = -1
        $this.EditingField = ""
        $this.EditingValue = ""
        $this.EditingCursor = 0
        $this.EditingCommand = $null
        $this.IsNewCommand = $false
    }
    
    # Cursor positioning (exactly like TaskListScreen)
    [void] PositionEditingCursor([System.Text.StringBuilder]$sb) {
        if ($this.EditingIndex -lt 0 -or $this.EditingIndex -ge $this.FlatList.Count) { return }
        
        # Calculate Y position of selected item on screen
        $startY = 3  # Header takes 3 lines
        $currentY = $startY
        
        # Find the selected item's position by counting visible items
        $visibleIndex = $this.EditingIndex - $this.ScrollTop
        
        # Each item takes 1 line normally, but selected takes 4 (pillbox: top + content + tags + bottom)
        for ($i = 0; $i -lt $visibleIndex; $i++) {
            $itemIndex = $this.ScrollTop + $i
            if ($itemIndex -eq $this.SelectedIndex) {
                $currentY += 4  # This was the selected pillbox (4 lines)
            } else {
                $currentY += 1  # Normal item (1 line)
            }
        }
        
        # Now $currentY is at the top of our editing item
        # Position cursor in the pillbox (4 lines: top + content + tags + bottom)
        if ($this.EditingIndex -eq $this.SelectedIndex) {
            if ($this.EditingField -eq "tags") {
                $tagY = $currentY + 2  # Tags are on line 3 of pillbox (0=top, 1=content, 2=tags, 3=bottom)
                $cursorX = 1 + 6 + $this.EditingCursor  # "│ Tags: " = 7 chars
                [void]$sb.Append([VT]::MoveTo($cursorX, $tagY))
            } else {
                $contentY = $currentY + 1  # Other fields are on line 2 of pillbox
                $cursorX = $this.CalculateFieldCursorX($this.EditingField, $this.EditingCursor)
                [void]$sb.Append([VT]::MoveTo($cursorX, $contentY))
            }
        }
    }
    
    # Calculate X position based on field and cursor position (like TaskListScreen)
    [int] CalculateFieldCursorX([string]$field, [int]$cursorPos) {
        $baseX = 1  # Account for pillbox left border
        $indent = 4  # 4 spaces for indentation (level * 2)
        
        switch ($field) {
            "title" {
                # Title is in first column
                return $baseX + $indent + $cursorPos
            }
            "commandtext" {
                # Command is in second column (after title + 1 space)
                return $baseX + $indent + $this.COLUMN_TITLE + 1 + $cursorPos
            }
            "description" {
                # Description is in third column (after title + command + 2 spaces)
                return $baseX + $indent + $this.COLUMN_TITLE + 1 + $this.COLUMN_COMMAND + 1 + $cursorPos
            }
            "tags" {
                # Tags are on second line of pillbox, with "Tags: " prefix
                return $baseX + 7 + $cursorPos  # 7 for "Tags: "
            }
        }
        
        # Default fallback
        return $baseX + $indent + $cursorPos
    }
    
    # Override GetFieldScreenPosition for command fields
    [hashtable] GetFieldScreenPosition([string]$field, [int]$cursor, [object]$item) {
        # Simple implementation for command screen
        switch ($field) {
            "Name" { return @{ X = 5 + $cursor; Y = 10 } }
            "Command" { return @{ X = 25 + $cursor; Y = 10 } }
            "Category" { return @{ X = 60 + $cursor; Y = 10 } }
            default { return @{ X = 5 + $cursor; Y = 10 } }
        }
        # Explicit return to satisfy PowerShell
        return @{ X = 5 + $cursor; Y = 10 }
    }
}