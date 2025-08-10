# FastLineBuilder.ps1 - Pre-built line templates for fast TaskListScreen rendering
# Eliminates StringBuilder concatenation and fixes tree connector visual/copy-paste mismatch

using namespace System.Collections.Generic

class FastLineBuilder {
    # Pre-built templates for different line types
    static [hashtable]$Templates = @{
        # Content line templates
        'parent_task' = '{0}    {1}             {2}  {3}                {4}'
        'subtask_branch' = '{0}    {1}             {2}                     ├─ {3}'
        'subtask_last' = '{0}    {1}             {2}                     └─ {3}'
        
        # Tag line templates  
        'parent_tags' = '   {0}     {1}  {2}                {3}'
        'parent_tags_with_continuation' = '   {0}     {1}  {2}                │  {3}'
        'subtask_tags_branch' = '   {0}     {1}                     ├─ {3}'
        'subtask_tags_last' = '   {0}     {1}                     └─ {3}'
        'subtask_tags_empty_branch' = '   {0}     {1}                     ├─ '
        'subtask_tags_empty_last' = '   {0}     {1}                     └─ '
        
        # Empty tag lines (for spacing) 
        'parent_empty' = '                                        '
        'parent_empty_with_continuation' = '                                        │  '
        'subtask_empty_branch' = '                                        ├─ '
        'subtask_empty_last' = '                                        └─ '
    }
    
    
    FastLineBuilder() {
        # Instance constructor - nothing needed
    }
    
    # Build complete content line with ALL features: colors, editing, collapse, proper formatting
    [string] BuildContentLine([SimpleTask]$task, [int]$level, [bool]$isLast, [bool]$isSelected = $false, [object]$screen = $null) {
        $sb = [System.Text.StringBuilder]::new()
        
        # MOVE EVERYTHING RIGHT BY ONE SPACE FOR PILLBOX
        [void]$sb.Append(" ")
        
        # Get screen reference for colors and editing state
        if (-not $screen) { return " " + $this.BuildBasicContentLine($task, $level, $isLast, $isSelected) }
        
        $isEditingThis = ($screen.EditingTask -and $screen.EditingTask.Id -eq $task.Id)
        
        if ($level -eq 0) {
            # === PARENT TASK ===
            
            # COLUMN 1: ID1 (5 chars) - Project code with colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "id1") {
                $fieldValue = $screen.EditingValue.PadRight(3)
                [void]$sb.Append($screen.EditHighlight + $fieldValue + " " + $screen.NormalColor)
            } else {
                $id1Text = if ($task.ID1 -and $task.ID1 -ne "") { $task.ID1.PadRight(3) } else { "   " }
                [void]$sb.Append($screen.FieldColor + $id1Text + "  " + $screen.NormalColor)
            }
            
            # COLUMN 2: ID2 (14 chars) - Project identifier with colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "id2") {
                $fieldValue = $screen.EditingValue.PadRight(12)
                [void]$sb.Append($screen.EditHighlight + $fieldValue + " " + $screen.NormalColor)
            } else {
                $id2Text = if ($task.ID2 -and $task.ID2 -ne "") { $task.ID2.PadRight(12) } else { " ".PadRight(12) }
                [void]$sb.Append($screen.ValueColor + $id2Text + "  " + $screen.NormalColor)
            }
            
            # COLUMN 3: CREATED DATE (12 chars) - Date with colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "created") {
                $displayValue = if ($screen.EditingValue -ne "") { $screen.EditingValue.PadRight(10) } else { " ".PadRight(10) }
                [void]$sb.Append($screen.EditHighlight + $displayValue + "  " + $screen.NormalColor)
            } else {
                $createdText = if ($task.CreatedDate -eq [datetime]::MinValue) { " ".PadRight(10) } else { $task.CreatedDate.ToString("yyyy-MM-dd") }
                [void]$sb.Append($screen.BrowserColor + $createdText + "  " + $screen.NormalColor)
            }
            
            # COLUMN 4: DUE DATE (12 chars) - Date with due date colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "date") {
                $displayValue = if ($screen.EditingValue -ne "") { $screen.EditingValue.PadRight(10) } else { " ".PadRight(10) }
                [void]$sb.Append($screen.EditHighlight + $displayValue + "  " + $screen.NormalColor)
            } else {
                [void]$sb.Append($screen.GetDateColorAndTextFormatted($task))
                [void]$sb.Append("  ")
            }
            
            # COLUMN 5: ARROW (3 chars) - ▼/▶ with proper collapse logic
            if ($task.Subtasks.Count -gt 0) {
                if ($screen.GlobalCollapseSubtasks -or $task.SubtasksCollapsed) {
                    [void]$sb.Append("▶  ")  # Collapsed
                } else {
                    [void]$sb.Append("▼  ")  # Expanded
                }
            } else {
                [void]$sb.Append("   ")
            }
            
            # COLUMN 6: TITLE with proper task theme colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "title") {
                $minWidth = 20
                $fieldWidth = [Math]::Max($minWidth, [Math]::Max($screen.EditingValue.Length + 2, $task.Title.Length + 2))
                $displayValue = if ($screen.EditingValue -ne "") { $screen.EditingValue.PadRight($fieldWidth) } else { " ".PadRight($fieldWidth) }
                [void]$sb.Append($screen.EditHighlight + $displayValue + $screen.NormalColor)
            } else {
                $taskColor = $screen.GetTaskColor($task.ColorTheme)
                [void]$sb.Append($taskColor + $task.Title + $screen.NormalColor)
            }
            
        } else {
            # === SUBTASK ===
            
            # COLUMN 1: STATUS (5 chars) - ☐/■ with colors
            if ($task.Completed) {
                [void]$sb.Append("■    ")  # Filled square + 4 spaces
            } else {
                [void]$sb.Append("☐    ")  # Open square + 4 spaces
            }
            
            # COLUMN 2: PRIORITY (14 chars) - Priority with colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "priority") {
                $fieldValue = $screen.EditingValue.PadRight(2)
                [void]$sb.Append($screen.EditHighlight + $fieldValue + " ".PadRight(11) + $screen.NormalColor)
            } else {
                $priorityChar = switch ($task.Priority) {
                    "High" { "H" }
                    "Medium" { "M" }
                    "Low" { "L" }
                    "Today" { "T" }
                    default { " " }
                }
                $priorityColor = switch ($task.Priority) {
                    "High" { $screen.HighColor }
                    "Medium" { $screen.MediumColor }
                    "Low" { $screen.LowColor }
                    "Today" { $screen.TodayColor }
                    default { $screen.TagColor }
                }
                [void]$sb.Append($priorityColor + $priorityChar + $screen.NormalColor + " ".PadRight(13))
            }
            
            # COLUMN 3: CREATED DATE (12 chars) - Date with subtask colors
            $createdText = if ($task.CreatedDate -eq [datetime]::MinValue) { " ".PadRight(10) } else { $task.CreatedDate.ToString("yyyy-MM-dd") }
            [void]$sb.Append($screen.SubtaskColor + $createdText + "  " + $screen.NormalColor)
            
            # COLUMN 4: DUE DATE (12 chars) - Due date with colors
            if ($task.DueDate -ne [datetime]::MinValue) {
                $dueDateText = $task.DueDate.ToString("yyyy-MM-dd")
                $dateColor = $screen.GetDateColor($task.DueDate)
                [void]$sb.Append($dateColor + $dueDateText.PadRight(10) + "  " + $screen.NormalColor)
            } else {
                [void]$sb.Append(" ".PadRight(12))
            }
            
            # COLUMN 5: TREE CONNECTORS (7 chars) - "    ├─ " or "    └─ " 
            if ($isSelected) {
                [void]$sb.Append("       ")  # Hide connectors for pillbox
            } else {
                if ($isLast) {
                    [void]$sb.Append("    └─ ")
                } else {
                    [void]$sb.Append("    ├─ ")
                }
            }
            
            # COLUMN 6: TITLE with subtask theme colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "title") {
                $minWidth = 20
                $fieldWidth = [Math]::Max($minWidth, [Math]::Max($screen.EditingValue.Length + 2, $task.Title.Length + 2))
                $displayValue = if ($screen.EditingValue -ne "") { $screen.EditingValue.PadRight($fieldWidth) } else { " ".PadRight($fieldWidth) }
                [void]$sb.Append($screen.EditHighlight + $displayValue + $screen.NormalColor)
            } else {
                $subtaskColor = $screen.GetSubtaskColor($task.ColorTheme)
                [void]$sb.Append($subtaskColor + $task.Title + $screen.NormalColor)
            }
        }
        
        return $sb.ToString()
    }
    
    # Fallback method for basic content without screen reference
    [string] BuildBasicContentLine([SimpleTask]$task, [int]$level, [bool]$isLast, [bool]$isSelected = $false) {
        $sb = [System.Text.StringBuilder]::new()
        
        if ($level -eq 0) {
            # Parent task - basic format
            $id1Text = if ($task.ID1 -and $task.ID1 -ne "") { $task.ID1.PadRight(3) } else { "   " }
            [void]$sb.Append($id1Text + "  ")
            
            $id2Text = if ($task.ID2 -and $task.ID2 -ne "") { $task.ID2.PadRight(12) } else { " ".PadRight(12) }
            [void]$sb.Append($id2Text + "  ")
            
            $createdText = if ($task.CreatedDate -eq [datetime]::MinValue) { " ".PadRight(10) } else { $task.CreatedDate.ToString("yyyy-MM-dd") }
            [void]$sb.Append($createdText + "  ")
            
            $dueText = if ($task.DueDate -eq [datetime]::MinValue) { " ".PadRight(10) } else { $task.DueDate.ToString("yyyy-MM-dd") }
            [void]$sb.Append($dueText + "  ")
            
            if ($task.Subtasks.Count -gt 0) {
                [void]$sb.Append("▼  ")
            } else {
                [void]$sb.Append("   ")
            }
            
            [void]$sb.Append($task.Title)
            
        } else {
            # Subtask - basic format
            if ($task.Completed) {
                [void]$sb.Append("■    ")
            } else {
                [void]$sb.Append("☐    ")
            }
            
            $priorityChar = switch ($task.Priority) {
                "High" { "H" }
                "Medium" { "M" }
                "Low" { "L" }
                "Today" { "T" }
                default { " " }
            }
            [void]$sb.Append($priorityChar + " ".PadRight(13))
            
            $createdText = if ($task.CreatedDate -eq [datetime]::MinValue) { " ".PadRight(10) } else { $task.CreatedDate.ToString("yyyy-MM-dd") }
            [void]$sb.Append($createdText + "  ")
            
            if ($task.DueDate -ne [datetime]::MinValue) {
                $dueDateText = $task.DueDate.ToString("yyyy-MM-dd")
                [void]$sb.Append($dueDateText.PadRight(10) + "  ")
            } else {
                [void]$sb.Append(" ".PadRight(12))
            }
            
            if ($isSelected) {
                [void]$sb.Append("       ")
            } else {
                if ($isLast) {
                    [void]$sb.Append("    └─ ")
                } else {
                    [void]$sb.Append("    ├─ ")
                }
            }
            
            [void]$sb.Append($task.Title)
        }
        
        return $sb.ToString()
    }
    
    # Build complete tag line with ALL features: colors, editing, tree connectors
    [string] BuildTagLine([SimpleTask]$task, [int]$level, [bool]$isLast, [bool]$isSelected = $false, [object]$screen = $null) {
        $sb = [System.Text.StringBuilder]::new()
        
        # MOVE EVERYTHING RIGHT BY ONE SPACE FOR PILLBOX
        [void]$sb.Append(" ")
        
        # Match exact column spacing from BuildContentLine
        # COLUMNS: ID1(5) + ID2(14) + Created(12) + Due(12) + Arrow(3) = 46 chars before title area
        $columnSpacing = " ".PadRight(46)
        
        # Get screen reference for colors and editing state
        if (-not $screen) { return " " + $this.BuildBasicTagLine($task, $level, $isLast, $isSelected) }
        
        $isEditingThis = ($screen.EditingTask -and $screen.EditingTask.Id -eq $task.Id)
        
        # Handle tag editing
        if ($isEditingThis -and $screen.EditingField -eq "tags") {
            # Show active tags field with reverse video highlighting
            $indentSize = 46  # Column spacing
            if ($level -eq 1) {
                $indentSize += 7  # "    └─ "
            }
            [void]$sb.Append(" " * $indentSize)
            $existingTags = ($task.Tags -join ", ")
            $minWidth = 15
            $fieldWidth = [Math]::Max($minWidth, [Math]::Max($screen.EditingValue.Length + 2, $existingTags.Length + 2))
            $displayValue = if ($screen.EditingValue -ne "") { $screen.EditingValue.PadRight($fieldWidth) } else { " ".PadRight($fieldWidth) }
            [void]$sb.Append("⟨" + $screen.EditHighlight + $displayValue + $screen.NormalColor + "⟩")
            return $sb.ToString()
        }
        
        # Normal tag rendering with colors
        $tagText = if ($task.Tags.Count -gt 0) {
            $screen.TagColor + "⟨" + ($task.Tags -join ", ") + "⟩" + $screen.NormalColor
        } else {
            ""
        }
        
        if ($level -eq 0) {
            # Parent task tag line - just spacing + tags or continuation line
            if ($task.Subtasks.Count -gt 0 -and -not $isSelected -and -not ($screen.GlobalCollapseSubtasks -or $task.SubtasksCollapsed)) {
                # Show continuation line to subtasks with proper colors (one extra space before │)
                [void]$sb.Append($columnSpacing + " " + $screen.TagColor + "│  " + $screen.NormalColor + $tagText)
            } else {
                # Normal parent task: just spacing + tags
                [void]$sb.Append($columnSpacing + $tagText)
            }
        } else {
            # Subtask tag line - tree connectors only for non-last subtasks
            if ($isSelected) {
                # Hide connectors when pillbox is selected
                [void]$sb.Append($columnSpacing + "       " + $tagText)
            } else {
                # Only show connectors for non-last subtasks (maintains tree structure)
                if ($isLast) {
                    # Last subtask: no connector on tag line, align with parent continuation
                    [void]$sb.Append($columnSpacing + "        " + $tagText)
                } else {
                    # Non-last subtask: continue vertical line on tag line
                    [void]$sb.Append($columnSpacing + " " + $screen.TagColor + "│  " + $screen.NormalColor + $tagText)
                }
            }
        }
        
        return $sb.ToString()
    }
    
    # Fallback method for basic tag line without screen reference  
    [string] BuildBasicTagLine([SimpleTask]$task, [int]$level, [bool]$isLast, [bool]$isSelected = $false) {
        $sb = [System.Text.StringBuilder]::new()
        
        # Match exact column spacing from BuildContentLine
        $columnSpacing = " ".PadRight(46)
        
        $tagText = if ($task.Tags.Count -gt 0) {
            "⟨" + ($task.Tags -join ", ") + "⟩"
        } else {
            ""
        }
        
        if ($level -eq 0) {
            # Parent task tag line
            if ($task.Subtasks.Count -gt 0 -and -not $isSelected) {
                [void]$sb.Append($columnSpacing + " │  " + $tagText)
            } else {
                [void]$sb.Append($columnSpacing + $tagText)
            }
        } else {
            # Subtask tag line - only show connectors for non-last subtasks
            if ($isSelected) {
                [void]$sb.Append($columnSpacing + "       " + $tagText)
            } else {
                if ($isLast) {
                    # Last subtask: no connector on tag line, align with parent continuation
                    [void]$sb.Append($columnSpacing + "        " + $tagText)
                } else {
                    # Non-last subtask: continue vertical line on tag line  
                    [void]$sb.Append($columnSpacing + " │  " + $tagText)
                }
            }
        }
        
        return $sb.ToString()
    }
    
    # Calculate content length for proper pillbox sizing and padding
    [int] GetContentLength([SimpleTask]$task, [int]$level, [object]$screen = $null) {
        if (-not $screen) { return $this.GetBasicContentLength($task, $level) }
        
        $length = 0
        
        if ($level -eq 0) {
            # Parent task: ID1(5) + ID2(14) + Created(12) + Due(12) + Arrow(3) + Title
            $length = 5 + 14 + 12 + 12 + 3
            $length += $task.Title.Length
        } else {
            # Subtask: Status(5) + Priority(14) + Created(12) + Due(12) + Connector(7) + Title
            $length = 5 + 14 + 12 + 12 + 7
            $length += $task.Title.Length
        }
        
        return $length
    }
    
    # Basic content length without screen reference
    [int] GetBasicContentLength([SimpleTask]$task, [int]$level) {
        $length = 0
        
        if ($level -eq 0) {
            $length = 5 + 14 + 12 + 12 + 3  # Columns
            $length += $task.Title.Length
        } else {
            $length = 5 + 14 + 12 + 12 + 7  # Columns + connector
            $length += $task.Title.Length
        }
        
        return $length
    }
    
    # Add proper padding to content line for right-edge alignment
    [string] BuildContentLineWithPadding([SimpleTask]$task, [int]$level, [bool]$isLast, [bool]$isSelected = $false, [object]$screen = $null, [int]$targetWidth = 0) {
        $contentLine = $this.BuildContentLine($task, $level, $isLast, $isSelected, $screen)
        
        if ($targetWidth -gt 0) {
            $currentLength = $this.GetContentLength($task, $level, $screen)
            $paddingNeeded = $targetWidth - $currentLength
            if ($paddingNeeded -gt 0) {
                $contentLine += " " * $paddingNeeded
            }
        }
        
        return $contentLine
    }
    
    # Calculate cursor position for editing fields
    [hashtable] GetEditingCursorPosition([SimpleTask]$task, [int]$level, [string]$editingField, [int]$editingCursor, [int]$startY = 3) {
        $cursorX = 0
        $cursorY = $startY
        
        if ($level -eq 0) {
            # Parent task cursor positions (no priority column for level 0)
            switch ($editingField) {
                "id1" { 
                    $cursorX = $editingCursor
                }
                "id2" { 
                    $cursorX = 5 + $editingCursor  # After ID1 column (5 chars)
                }
                "created" { 
                    $cursorX = 5 + 14 + $editingCursor  # After ID1 (5) + ID2 (14)
                }
                "date" { 
                    $cursorX = 5 + 14 + 12 + $editingCursor  # After ID1 (5) + ID2 (14) + Created (12) 
                }
                "title" { 
                    $cursorX = 5 + 14 + 12 + 12 + 3 + $editingCursor  # After ID1 + ID2 + Created + Date + Arrow
                }
            }
        } else {
            # Subtask cursor positions
            switch ($editingField) {
                "priority" { 
                    $cursorX = 5 + $editingCursor  # After status column
                }
                "title" { 
                    $cursorX = 5 + 14 + 12 + 12 + 7 + $editingCursor  # After all columns + connector
                }
            }
        }
        
        # Tags are always on the second line
        if ($editingField -eq "tags") {
            $cursorY = $startY + 1
            $cursorX = 5 + 14 + 12 + 12 + 3  # Column spacing
            if ($level -eq 1) {
                $cursorX += 7  # "    └─ "
            }
            $cursorX += 1 + $editingCursor  # "⟨" + cursor position
        }
        
        return @{
            X = $cursorX
            Y = $cursorY
        }
    }
    
    # Build all lines for a task list
    [List[string]] BuildAllLines([SimpleTask[]]$tasks, [int]$selectedIndex = -1) {
        $lines = [List[string]]::new()
        $flatList = $this.FlattenTasks($tasks)
        
        for ($i = 0; $i -lt $flatList.Count; $i++) {
            $item = $flatList[$i]
            $task = $item.Task
            $level = $item.Level
            $isLast = $item.IsLast  
            $isSelected = ($i -eq $selectedIndex)
            
            # Add content line
            $contentLine = $this.BuildContentLine($task, $level, $isLast, $isSelected)
            [void]$lines.Add($contentLine)
            
            # Add tag line (always present for consistent spacing)
            $tagLine = $this.BuildTagLine($task, $level, $isLast, $isSelected)
            [void]$lines.Add($tagLine)
        }
        
        return $lines
    }
    
    # Build all lines from existing FlatList (already flattened)
    [List[string]] BuildAllLinesFromFlatList([System.Collections.Generic.List[object]]$flatList, [int]$selectedIndex = -1) {
        $lines = [List[string]]::new()
        
        for ($i = 0; $i -lt $flatList.Count; $i++) {
            $item = $flatList[$i]
            $task = $item.Task
            $level = $item.Level
            $isLast = $item.IsLast
            $isSelected = ($i -eq $selectedIndex)
            
            # Add content line
            $contentLine = $this.BuildContentLine($task, $level, $isLast, $isSelected)
            [void]$lines.Add($contentLine)
            
            # Add tag line (always present for consistent spacing)
            $tagLine = $this.BuildTagLine($task, $level, $isLast, $isSelected)
            [void]$lines.Add($tagLine)
        }
        
        return $lines
    }
    
    # Flatten task hierarchy for rendering
    [List[object]] FlattenTasks([SimpleTask[]]$tasks) {
        $flatList = [List[object]]::new()
        
        foreach ($task in $tasks) {
            # Add parent task
            $parentItem = @{
                Task = $task
                Level = 0
                IsLast = $false
            }
            [void]$flatList.Add($parentItem)
            
            # Add subtasks
            if ($task.Subtasks -and $task.Subtasks.Count -gt 0) {
                for ($i = 0; $i -lt $task.Subtasks.Count; $i++) {
                    $subtask = $task.Subtasks[$i]
                    $isLastSubtask = ($i -eq ($task.Subtasks.Count - 1))
                    
                    $subtaskItem = @{
                        Task = $subtask
                        Level = 1
                        IsLast = $isLastSubtask
                    }
                    [void]$flatList.Add($subtaskItem)
                }
            }
        }
        
        return $flatList
    }
    
    # Format date for display
    [string] FormatDate([datetime]$date) {
        if ($date -eq [datetime]::MinValue) {
            return "          "  # 10 spaces
        }
        return $date.ToString("yyyy-MM-dd")
    }
    
    # Template-based line builders with ALL FEATURES: colors, editing, collapse/expand
    [string] BuildContentLineFromTemplate([SimpleTask]$task, [int]$level, [bool]$isLast, [bool]$isSelected = $false, [object]$screen = $null) {
        # If no screen reference, fall back to basic template
        if (-not $screen) { return " " + $this.BuildBasicContentLineFromTemplate($task, $level, $isLast, $isSelected) }
        
        $sb = [System.Text.StringBuilder]::new()
        
        # MOVE EVERYTHING RIGHT BY ONE SPACE FOR PILLBOX
        [void]$sb.Append(" ")
        $isEditingThis = ($screen.EditingTask -and $screen.EditingTask.Id -eq $task.Id)
        
        if ($level -eq 0) {
            # === PARENT TASK WITH ALL FEATURES ===
            
            # COLUMN 1: ID1 with colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "id1") {
                $fieldValue = $screen.EditingValue.PadRight(3)
                [void]$sb.Append($screen.EditHighlight + $fieldValue + " " + $screen.NormalColor)
            } else {
                $id1Text = if ($task.ID1 -and $task.ID1 -ne "") { $task.ID1.PadRight(3) } else { "   " }
                [void]$sb.Append($screen.FieldColor + $id1Text + "  " + $screen.NormalColor)
            }
            
            # COLUMN 2: ID2 with colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "id2") {
                $fieldValue = $screen.EditingValue.PadRight(12)
                [void]$sb.Append($screen.EditHighlight + $fieldValue + " " + $screen.NormalColor)
            } else {
                $id2Text = if ($task.ID2 -and $task.ID2 -ne "") { $task.ID2.PadRight(12) } else { " ".PadRight(12) }
                [void]$sb.Append($screen.ValueColor + $id2Text + "  " + $screen.NormalColor)
            }
            
            # COLUMN 3: CREATED DATE with colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "created") {
                $displayValue = if ($screen.EditingValue -ne "") { $screen.EditingValue.PadRight(10) } else { " ".PadRight(10) }
                [void]$sb.Append($screen.EditHighlight + $displayValue + "  " + $screen.NormalColor)
            } else {
                $createdText = if ($task.CreatedDate -eq [datetime]::MinValue) { " ".PadRight(10) } else { $task.CreatedDate.ToString("yyyy-MM-dd") }
                [void]$sb.Append($screen.BrowserColor + $createdText + "  " + $screen.NormalColor)
            }
            
            # COLUMN 4: DUE DATE with due date colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "date") {
                $displayValue = if ($screen.EditingValue -ne "") { $screen.EditingValue.PadRight(10) } else { " ".PadRight(10) }
                [void]$sb.Append($screen.EditHighlight + $displayValue + "  " + $screen.NormalColor)
            } else {
                [void]$sb.Append($screen.GetDateColorAndTextFormatted($task))
                [void]$sb.Append("  ")
            }
            
            # COLUMN 5: COLLAPSE/EXPAND ARROW with logic
            if ($task.Subtasks.Count -gt 0) {
                if ($screen.GlobalCollapseSubtasks -or $task.SubtasksCollapsed) {
                    [void]$sb.Append("▶  ")  # Collapsed
                } else {
                    [void]$sb.Append("▼  ")  # Expanded
                }
            } else {
                [void]$sb.Append("   ")
            }
            
            # COLUMN 6: TITLE with task theme colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "title") {
                $minWidth = 20
                $fieldWidth = [Math]::Max($minWidth, [Math]::Max($screen.EditingValue.Length + 2, $task.Title.Length + 2))
                $displayValue = if ($screen.EditingValue -ne "") { $screen.EditingValue.PadRight($fieldWidth) } else { " ".PadRight($fieldWidth) }
                [void]$sb.Append($screen.EditHighlight + $displayValue + $screen.NormalColor)
            } else {
                $taskColor = $screen.GetTaskColor($task.ColorTheme)
                [void]$sb.Append($taskColor + $task.Title + $screen.NormalColor)
            }
            
        } else {
            # === SUBTASK WITH ALL FEATURES ===
            
            # COLUMN 1: STATUS with colors
            if ($task.Completed) {
                [void]$sb.Append("■    ")  # Filled square + 4 spaces
            } else {
                [void]$sb.Append("☐    ")  # Open square + 4 spaces
            }
            
            # COLUMN 2: PRIORITY with colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "priority") {
                $fieldValue = $screen.EditingValue.PadRight(2)
                [void]$sb.Append($screen.EditHighlight + $fieldValue + " ".PadRight(11) + $screen.NormalColor)
            } else {
                $priorityChar = switch ($task.Priority) {
                    "High" { "H" }
                    "Medium" { "M" }
                    "Low" { "L" }
                    "Today" { "T" }
                    default { " " }
                }
                $priorityColor = switch ($task.Priority) {
                    "High" { $screen.HighColor }
                    "Medium" { $screen.MediumColor }
                    "Low" { $screen.LowColor }
                    "Today" { $screen.TodayColor }
                    default { $screen.TagColor }
                }
                [void]$sb.Append($priorityColor + $priorityChar + $screen.NormalColor + " ".PadRight(13))
            }
            
            # COLUMN 3: CREATED DATE with subtask colors
            $createdText = if ($task.CreatedDate -eq [datetime]::MinValue) { " ".PadRight(10) } else { $task.CreatedDate.ToString("yyyy-MM-dd") }
            [void]$sb.Append($screen.SubtaskColor + $createdText + "  " + $screen.NormalColor)
            
            # COLUMN 4: DUE DATE with colors
            if ($task.DueDate -ne [datetime]::MinValue) {
                $dueDateText = $task.DueDate.ToString("yyyy-MM-dd")
                $dateColor = $screen.GetDateColor($task.DueDate)
                [void]$sb.Append($dateColor + $dueDateText.PadRight(10) + "  " + $screen.NormalColor)
            } else {
                [void]$sb.Append(" ".PadRight(12))
            }
            
            # COLUMN 5: TREE CONNECTORS
            if ($isSelected) {
                [void]$sb.Append("       ")  # Hide connectors for pillbox
            } else {
                if ($isLast) {
                    [void]$sb.Append("    └─ ")
                } else {
                    [void]$sb.Append("    ├─ ")
                }
            }
            
            # COLUMN 6: TITLE with subtask theme colors and editing
            if ($isEditingThis -and $screen.EditingField -eq "title") {
                $minWidth = 20
                $fieldWidth = [Math]::Max($minWidth, [Math]::Max($screen.EditingValue.Length + 2, $task.Title.Length + 2))
                $displayValue = if ($screen.EditingValue -ne "") { $screen.EditingValue.PadRight($fieldWidth) } else { " ".PadRight($fieldWidth) }
                [void]$sb.Append($screen.EditHighlight + $displayValue + $screen.NormalColor)
            } else {
                $subtaskColor = $screen.GetSubtaskColor($task.ColorTheme)
                [void]$sb.Append($subtaskColor + $task.Title + $screen.NormalColor)
            }
        }
        
        return $sb.ToString()
    }
    
    # Basic template fallback without screen colors/editing
    [string] BuildBasicContentLineFromTemplate([SimpleTask]$task, [int]$level, [bool]$isLast, [bool]$isSelected = $false) {
        if ($level -eq 0) {
            # Parent task template
            $template = [FastLineBuilder]::Templates['parent_task']
            $id1 = if ($task.ID1) { $task.ID1.PadRight(3) } else { "   " }
            $id2 = if ($task.ID2) { $task.ID2.PadRight(12) } else { " ".PadRight(12) }
            $created = $this.FormatDate($task.CreatedDate)
            $due = $this.FormatDate($task.DueDate)
            $arrow = if ($task.Subtasks.Count -gt 0) { "▼" } else { " " }
            return $template -f $id1, $id2, $created, $due, $arrow, $task.Title
        } else {
            # Subtask template
            $template = if ($isLast) { [FastLineBuilder]::Templates['subtask_last'] } else { [FastLineBuilder]::Templates['subtask_branch'] }
            $status = if ($task.Completed) { "■" } else { "☐" }
            $priority = switch ($task.Priority) { "High" { "H" }; "Medium" { "M" }; "Low" { "L" }; "Today" { "T" }; default { " " } }
            $created = $this.FormatDate($task.CreatedDate)
            return $template -f $status, $priority, $created, $task.Title
        }
    }
    
    # Template-based tag line builders with ALL FEATURES: colors, editing, tree connectors
    [string] BuildTagLineFromTemplate([SimpleTask]$task, [int]$level, [bool]$isLast, [bool]$isSelected = $false, [object]$screen = $null) {
        # If no screen reference, fall back to basic template
        if (-not $screen) { return " " + $this.BuildBasicTagLineFromTemplate($task, $level, $isLast, $isSelected) }
        
        $sb = [System.Text.StringBuilder]::new()
        
        # MOVE EVERYTHING RIGHT BY ONE SPACE FOR PILLBOX
        [void]$sb.Append(" ")
        
        $columnSpacing = " ".PadRight(46)  # Match column spacing from content line
        $isEditingThis = ($screen.EditingTask -and $screen.EditingTask.Id -eq $task.Id)
        
        # Handle tag editing with ALL features
        if ($isEditingThis -and $screen.EditingField -eq "tags") {
            # Show active tags field with reverse video highlighting
            $indentSize = 46  # Column spacing
            if ($level -eq 1) {
                $indentSize += 7  # "    └─ "
            }
            [void]$sb.Append(" " * $indentSize)
            $existingTags = ($task.Tags -join ", ")
            $minWidth = 15
            $fieldWidth = [Math]::Max($minWidth, [Math]::Max($screen.EditingValue.Length + 2, $existingTags.Length + 2))
            $displayValue = if ($screen.EditingValue -ne "") { $screen.EditingValue.PadRight($fieldWidth) } else { " ".PadRight($fieldWidth) }
            [void]$sb.Append("⟨" + $screen.EditHighlight + $displayValue + $screen.NormalColor + "⟩")
            return $sb.ToString()
        }
        
        # Normal tag rendering with colors
        $tagText = if ($task.Tags.Count -gt 0) {
            $screen.TagColor + "⟨" + ($task.Tags -join ", ") + "⟩" + $screen.NormalColor
        } else {
            ""
        }
        
        if ($level -eq 0) {
            # Parent task tag line - just spacing + tags or continuation line
            if ($task.Subtasks.Count -gt 0 -and -not $isSelected -and -not ($screen.GlobalCollapseSubtasks -or $task.SubtasksCollapsed)) {
                # Show continuation line to subtasks with proper colors (one extra space before │)
                [void]$sb.Append($columnSpacing + " " + $screen.TagColor + "│  " + $screen.NormalColor + $tagText)
            } else {
                # Normal parent task: just spacing + tags
                [void]$sb.Append($columnSpacing + $tagText)
            }
        } else {
            # Subtask tag line - tree connectors only for non-last subtasks
            if ($isSelected) {
                # Hide connectors when pillbox is selected
                [void]$sb.Append($columnSpacing + "       " + $tagText)
            } else {
                # Only show connectors for non-last subtasks (maintains tree structure)
                if ($isLast) {
                    # Last subtask: no connector on tag line, align with parent continuation
                    [void]$sb.Append($columnSpacing + "        " + $tagText)
                } else {
                    # Non-last subtask: continue vertical line on tag line
                    [void]$sb.Append($columnSpacing + " " + $screen.TagColor + "│  " + $screen.NormalColor + $tagText)
                }
            }
        }
        
        return $sb.ToString()
    }
    
    # Basic tag line template fallback without screen colors/editing
    [string] BuildBasicTagLineFromTemplate([SimpleTask]$task, [int]$level, [bool]$isLast, [bool]$isSelected = $false) {
        $tagText = if ($task.Tags.Count -gt 0) { "⟨" + ($task.Tags -join ", ") + "⟩" } else { "" }
        $columnSpacing = " ".PadRight(46)
        
        if ($level -eq 0) {
            # Parent task tag line
            if ($task.Subtasks.Count -gt 0 -and -not $isSelected) {
                return $columnSpacing + " │  " + $tagText
            } else {
                return $columnSpacing + $tagText
            }
        } else {
            # Subtask tag line
            if ($isSelected) {
                return $columnSpacing + "       " + $tagText
            } else {
                if ($isLast) {
                    return $columnSpacing + "        " + $tagText
                } else {
                    return $columnSpacing + " │  " + $tagText
                }
            }
        }
    }
    
    # Build spacing/empty lines using templates
    [string] BuildEmptyLine([int]$level, [bool]$isLast, [bool]$hasParentSubtasks = $false) {
        if ($level -eq 0) {
            # Parent empty line
            if ($hasParentSubtasks) {
                return [FastLineBuilder]::Templates['parent_empty_with_continuation']
            } else {
                return [FastLineBuilder]::Templates['parent_empty']
            }
        } else {
            # Subtask empty line
            if ($isLast) {
                return [FastLineBuilder]::Templates['subtask_empty_last']
            } else {
                return [FastLineBuilder]::Templates['subtask_empty_branch']
            }
        }
    }
    
    # Template-based rendering with ALL FEATURES: colors, editing, collapse/expand
    [List[string]] BuildAllLinesFromTemplates([SimpleTask[]]$tasks, [int]$selectedIndex = -1, [object]$screen = $null) {
        $lines = [List[string]]::new()
        $flatList = $this.FlattenTasks($tasks)
        
        for ($i = 0; $i -lt $flatList.Count; $i++) {
            $item = $flatList[$i]
            $task = $item.Task
            $level = $item.Level
            $isLast = $item.IsLast
            $isSelected = ($i -eq $selectedIndex)
            
            # Add content line from template with ALL features
            $contentLine = $this.BuildContentLineFromTemplate($task, $level, $isLast, $isSelected, $screen)
            [void]$lines.Add($contentLine)
            
            # Add tag line from template with ALL features
            $tagLine = $this.BuildTagLineFromTemplate($task, $level, $isLast, $isSelected, $screen)
            [void]$lines.Add($tagLine)
        }
        
        return $lines
    }
    
    # Basic template rendering without screen features (for performance testing)
    [List[string]] BuildAllLinesFromBasicTemplates([SimpleTask[]]$tasks, [int]$selectedIndex = -1) {
        $lines = [List[string]]::new()
        $flatList = $this.FlattenTasks($tasks)
        
        for ($i = 0; $i -lt $flatList.Count; $i++) {
            $item = $flatList[$i]
            $task = $item.Task
            $level = $item.Level
            $isLast = $item.IsLast
            $isSelected = ($i -eq $selectedIndex)
            
            # Add basic content line from template
            $contentLine = $this.BuildBasicContentLineFromTemplate($task, $level, $isLast, $isSelected)
            [void]$lines.Add($contentLine)
            
            # Add basic tag line from template
            $tagLine = $this.BuildBasicTagLineFromTemplate($task, $level, $isLast, $isSelected)
            [void]$lines.Add($tagLine)
        }
        
        return $lines
    }
    
    # Template-based content length calculation with ALL features
    [int] GetContentLengthFromTemplate([SimpleTask]$task, [int]$level, [object]$screen = $null) {
        if (-not $screen) { return $this.GetBasicContentLength($task, $level) }
        
        $length = 0
        
        if ($level -eq 0) {
            # Parent task: ID1(5) + ID2(14) + Created(12) + Due(12) + Arrow(3) + Title
            $length = 5 + 14 + 12 + 12 + 3
            $length += $task.Title.Length
        } else {
            # Subtask: Status(5) + Priority(14) + Created(12) + Due(12) + Connector(7) + Title
            $length = 5 + 14 + 12 + 12 + 7
            $length += $task.Title.Length
        }
        
        return $length
    }
    
    # Template-based cursor positioning with ALL editing features
    [hashtable] GetEditingCursorPositionFromTemplate([SimpleTask]$task, [int]$level, [string]$editingField, [int]$editingCursor, [int]$startY = 3) {
        $cursorX = 0
        $cursorY = $startY
        
        if ($level -eq 0) {
            # Parent task cursor positions
            switch ($editingField) {
                "id1" { 
                    $cursorX = $editingCursor
                }
                "id2" { 
                    $cursorX = 5 + $editingCursor  # After ID1 column
                }
                "created" { 
                    $cursorX = 5 + 14 + $editingCursor  # After ID1 + ID2
                }
                "date" { 
                    $cursorX = 5 + 14 + 12 + $editingCursor  # After ID1 + ID2 + Created
                }
                "title" { 
                    $cursorX = 5 + 14 + 12 + 12 + 3 + $editingCursor  # After all columns
                }
            }
        } else {
            # Subtask cursor positions
            switch ($editingField) {
                "priority" { 
                    $cursorX = 5 + $editingCursor  # After status column
                }
                "title" { 
                    $cursorX = 5 + 14 + 12 + 12 + 7 + $editingCursor  # After all columns + connector
                }
            }
        }
        
        # Tags are always on the second line
        if ($editingField -eq "tags") {
            $cursorY = $startY + 1
            $cursorX = 5 + 14 + 12 + 12 + 3  # Column spacing
            if ($level -eq 1) {
                $cursorX += 7  # "    └─ "
            }
            $cursorX += 1 + $editingCursor  # "⟨" + cursor position
        }
        
        return @{
            X = $cursorX
            Y = $cursorY
        }
    }
    
    # Advanced field editing with GapBuffer support (COMPLETE ORIGINAL FUNCTIONALITY)
    [hashtable] CreateFieldEditor([SimpleTask]$task, [string]$fieldName, [object]$screen = $null) {
        if (-not $screen) { return @{} }
        
        # Get current field value
        $currentValue = switch ($fieldName) {
            "title" { $task.Title }
            "id1" { $task.ID1 }
            "id2" { $task.ID2 }
            "priority" { 
                switch ($task.Priority) {
                    "High" { "h" }
                    "Medium" { "m" }
                    "Low" { "l" }
                    "Today" { "t" }
                    default { "" }
                }
            }
            "date" { if ($task.DueDate -ne [datetime]::MinValue) { $task.DueDate.ToString("yyyy-MM-dd") } else { "" } }
            "created" { if ($task.CreatedDate -ne [datetime]::MinValue) { $task.CreatedDate.ToString("yyyy-MM-dd") } else { "" } }
            "tags" { if ($task.Tags.Count -gt 0) { ($task.Tags -join ", ") } else { "" } }
            default { "" }
        }
        
        # Create GapBuffer with current value
        $gapBuffer = [GapBuffer]::new($currentValue)
        # Position cursor at end of field (original behavior)
        $gapBuffer.MoveGapTo($gapBuffer.GetLength())
        
        # Get field constraints
        $constraints = switch ($fieldName) {
            "id1" { @{ MaxLength = 3; Type = "text" } }
            "id2" { @{ MaxLength = 12; Type = "text" } }
            "priority" { @{ MaxLength = 1; Type = "priority" } }
            "date" { @{ MaxLength = 10; Type = "date" } }
            "created" { @{ MaxLength = 10; Type = "date" } }
            "title" { @{ MaxLength = 100; Type = "text" } }
            "tags" { @{ MaxLength = 200; Type = "tags" } }
            default { @{ MaxLength = 50; Type = "text" } }
        }
        
        return @{
            GapBuffer = $gapBuffer
            Field = $fieldName
            Task = $task
            Screen = $screen
            Constraints = $constraints
            CursorPosition = $gapBuffer.GetLength()  # Start at end
        }
    }
    
    # Handle ALL keyboard input for field editing (COMPLETE ORIGINAL FUNCTIONALITY)
    [bool] HandleFieldEditingInput([hashtable]$editor, [System.ConsoleKeyInfo]$key) {
        if (-not $editor -or -not $editor.GapBuffer) { return $false }
        
        $gapBuffer = $editor.GapBuffer
        $constraints = $editor.Constraints
        $task = $editor.Task
        $screen = $editor.Screen
        
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                # Apply field value and save
                $finalValue = $gapBuffer.GetText()
                $this.ApplyFieldValue($task, $editor.Field, $finalValue)
                return $false  # End editing
            }
            ([System.ConsoleKey]::Escape) {
                # Cancel editing without saving
                return $false  # End editing
            }
            ([System.ConsoleKey]::Tab) {
                # Move to next field
                $this.ApplyFieldValue($task, $editor.Field, $gapBuffer.GetText())
                # Let parent handle field switching
                return $false
            }
            ([System.ConsoleKey]::Backspace) {
                # Delete character before cursor
                if ($editor.CursorPosition -gt 0) {
                    $gapBuffer.Delete($editor.CursorPosition - 1, 1)
                    $editor.CursorPosition = [Math]::Max(0, $editor.CursorPosition - 1)
                }
                return $true
            }
            ([System.ConsoleKey]::Delete) {
                # Delete character at cursor
                if ($editor.CursorPosition -lt $gapBuffer.GetLength()) {
                    $gapBuffer.Delete($editor.CursorPosition, 1)
                }
                return $true
            }
            ([System.ConsoleKey]::LeftArrow) {
                # Move cursor left
                if ($editor.CursorPosition -gt 0) {
                    $editor.CursorPosition--
                    $gapBuffer.MoveGapTo($editor.CursorPosition)
                }
                return $true
            }
            ([System.ConsoleKey]::RightArrow) {
                # Move cursor right
                if ($editor.CursorPosition -lt $gapBuffer.GetLength()) {
                    $editor.CursorPosition++
                    $gapBuffer.MoveGapTo($editor.CursorPosition)
                }
                return $true
            }
            ([System.ConsoleKey]::Home) {
                # Move cursor to start
                $editor.CursorPosition = 0
                $gapBuffer.MoveGapTo(0)
                return $true
            }
            ([System.ConsoleKey]::End) {
                # Move cursor to end
                $editor.CursorPosition = $gapBuffer.GetLength()
                $gapBuffer.MoveGapTo($gapBuffer.GetLength())
                return $true
            }
            default {
                # Handle character input with field-specific validation
                if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                    $newChar = $key.KeyChar.ToString()
                    
                    # Check length constraint
                    if ($gapBuffer.GetLength() -ge $constraints.MaxLength) {
                        return $true  # Ignore if at max length
                    }
                    
                    # Field-specific validation
                    $isValid = $false
                    switch ($constraints.Type) {
                        "priority" {
                            # Only allow h, m, l, t (case insensitive)
                            $isValid = $newChar -match '^[hmltHMLT]$'
                            if ($isValid) { $newChar = $newChar.ToLower() }
                        }
                        "date" {
                            # Allow digits and dashes for date format
                            $isValid = $newChar -match '^[0-9\-]$'
                        }
                        "text" {
                            # Allow all printable characters
                            $isValid = $true
                        }
                        "tags" {
                            # Allow alphanumeric, spaces, commas, hyphens
                            $isValid = $newChar -match '^[a-zA-Z0-9\s,\-_]$'
                        }
                        default {
                            $isValid = $true
                        }
                    }
                    
                    if ($isValid) {
                        $gapBuffer.Insert($editor.CursorPosition, $newChar)
                        $editor.CursorPosition++
                    }
                }
                return $true
            }
        }
        
        return $false  # Default return for all other cases
    }
    
    # Apply field value to task (COMPLETE ORIGINAL FUNCTIONALITY)
    [void] ApplyFieldValue([SimpleTask]$task, [string]$fieldName, [string]$value) {
        switch ($fieldName) {
            "title" {
                $task.Title = $value.Trim()
            }
            "id1" {
                $task.ID1 = $value.Trim().Substring(0, [Math]::Min(3, $value.Trim().Length))
            }
            "id2" {
                $task.ID2 = $value.Trim().Substring(0, [Math]::Min(12, $value.Trim().Length))
            }
            "priority" {
                $cleanValue = $value.Trim().ToLower()
                switch ($cleanValue) {
                    "h" { $task.Priority = "High" }
                    "m" { $task.Priority = "Medium" }
                    "l" { $task.Priority = "Low" }
                    "t" { $task.Priority = "Today" }
                    default { $task.Priority = "Medium" }
                }
            }
            "date" {
                if ($value.Trim() -eq "" -or $value.Trim() -eq "clear") {
                    $task.DueDate = [datetime]::MinValue
                } else {
                    try {
                        $task.DueDate = [datetime]::Parse($value.Trim())
                    } catch {
                        # Try common formats
                        if ($value -match '^\d{4}-\d{2}-\d{2}$') {
                            $task.DueDate = [datetime]::ParseExact($value, "yyyy-MM-dd", $null)
                        } elseif ($value -match '^\d{2}-\d{2}$') {
                            $year = [datetime]::Now.Year
                            $task.DueDate = [datetime]::ParseExact("$year-$value", "yyyy-MM-dd", $null)
                        }
                    }
                }
            }
            "created" {
                if ($value.Trim() -ne "" -and $value.Trim() -ne "clear") {
                    try {
                        $task.CreatedDate = [datetime]::Parse($value.Trim())
                    } catch {
                        if ($value -match '^\d{4}-\d{2}-\d{2}$') {
                            $task.CreatedDate = [datetime]::ParseExact($value, "yyyy-MM-dd", $null)
                        }
                    }
                }
            }
            "tags" {
                if ($value.Trim() -eq "" -or $value.Trim() -eq "clear") {
                    $task.Tags = @()
                } else {
                    # Parse comma-separated tags
                    $tags = $value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
                    $task.Tags = $tags
                }
            }
        }
        
        # Update modification date
        $task.ModifiedDate = Get-Date
    }
    
    # Advanced color picker integration (COMPLETE ORIGINAL FUNCTIONALITY)
    [void] OpenAdvancedColorPicker([SimpleTask]$task, [bool]$isSubtask = $false, [object]$screen = $null) {
        if (-not $screen) { return }
        
        # Call the screen's theme editor (preserves all original functionality)
        $screen.OpenThemeEditor()
    }
    
    # Get field display width for fixed column layouts (COMPLETE ORIGINAL FUNCTIONALITY)
    [hashtable] GetFieldDisplayWidths() {
        return @{
            "id1" = 3
            "id2" = 12  
            "created" = 10
            "date" = 10
            "priority" = 1
            "title" = -1  # Variable width
            "tags" = -1   # Variable width
        }
    }
    
    # Validate field input with original constraints (COMPLETE ORIGINAL FUNCTIONALITY)
    [bool] ValidateFieldInput([string]$fieldName, [string]$input) {
        switch ($fieldName) {
            "id1" { return $input.Length -le 3 }
            "id2" { return $input.Length -le 12 }
            "priority" { return $input -match '^[hmltHMLT]?$' }
            "date" { 
                if ($input.Trim() -eq "" -or $input.Trim() -eq "clear") { return $true }
                # Use advanced date conversion to validate
                $result = $this.ConvertDateInput($input)
                return $result -ne [datetime]::MinValue
            }
            "created" {
                if ($input.Trim() -eq "" -or $input.Trim() -eq "clear") { return $true }
                # Use advanced date conversion to validate
                $result = $this.ConvertDateInput($input)
                return $result -ne [datetime]::MinValue
            }
            "title" { return $input.Length -le 100 }
            "tags" { return $input.Length -le 200 }
            default { return $true }
        }
        
        return $true  # Fallback return
    }
    
    # MISSING FUNCTIONALITY: Advanced priority input conversion (COMPLETE ORIGINAL)
    [string] ConvertPriorityInput([string]$input) {
        # Convert h/m/l/t input to High/Medium/Low/Today (only accept single letters)
        $cleanInput = $input.ToLower().Trim()
        switch ($cleanInput) {
            "h" { return "High" }
            "m" { return "Medium" }
            "l" { return "Low" }
            "t" { return "Today" }
            default { 
                return ""  # Return empty if invalid input
            }
        }
        return ""  # Fallback return (should never be reached)
    }
    
    # MISSING FUNCTIONALITY: Advanced date input conversion with shortcuts (COMPLETE ORIGINAL)
    [datetime] ConvertDateInput([string]$input) {
        # Enhanced date input with quick entry shortcuts
        $input = $input.Trim().ToLower()
        if ($input -eq "" -or $input -eq "clear") {
            return [datetime]::MinValue
        }
        
        $today = [datetime]::Today
        
        # Quick date shortcuts
        switch ($input) {
            "t" { return $today }
            "today" { return $today }
            "tom" { return $today.AddDays(1) }
            "tomorrow" { return $today.AddDays(1) }
            "mon" { return $this.GetNextWeekday([DayOfWeek]::Monday) }
            "tue" { return $this.GetNextWeekday([DayOfWeek]::Tuesday) }
            "wed" { return $this.GetNextWeekday([DayOfWeek]::Wednesday) }
            "thu" { return $this.GetNextWeekday([DayOfWeek]::Thursday) }
            "fri" { return $this.GetNextWeekday([DayOfWeek]::Friday) }
            "sat" { return $this.GetNextWeekday([DayOfWeek]::Saturday) }
            "sun" { return $this.GetNextWeekday([DayOfWeek]::Sunday) }
            default { }  # Continue to next parsing logic
        }
        
        # Relative date shortcuts (+3, +1w, etc.)
        if ($input -match '^\+(\d+)$') {
            $days = [int]$matches[1]
            return $today.AddDays($days)
        }
        if ($input -match '^\+(\d+)w$') {
            $weeks = [int]$matches[1]
            return $today.AddDays($weeks * 7)
        }
        if ($input -match '^\+(\d+)m$') {
            $months = [int]$matches[1]
            return $today.AddMonths($months)
        }
        
        try {
            if ($input.Length -eq 8) {
                # yyyymmdd format
                $year = [int]$input.Substring(0, 4)
                $month = [int]$input.Substring(4, 2)
                $day = [int]$input.Substring(6, 2)
                return [datetime]::new($year, $month, $day)
            } elseif ($input.Length -eq 4) {
                # mmdd format - use current year
                $year = [datetime]::Now.Year
                $month = [int]$input.Substring(0, 2)
                $day = [int]$input.Substring(2, 2)
                return [datetime]::new($year, $month, $day)
            } else {
                # Try to parse as regular date
                return [datetime]::Parse($input)
            }
        } catch {
            return [datetime]::MinValue
        }
    }
    
    # MISSING FUNCTIONALITY: Calculate next weekday helper (COMPLETE ORIGINAL)
    [datetime] GetNextWeekday([DayOfWeek]$targetDay) {
        $today = [datetime]::Today
        $daysUntilTarget = ([int]$targetDay - [int]$today.DayOfWeek + 7) % 7
        if ($daysUntilTarget -eq 0) {
            $daysUntilTarget = 7  # Next week if today is the target day
        }
        return $today.AddDays($daysUntilTarget)
    }
}