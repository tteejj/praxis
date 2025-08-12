# BaseListScreen.ps1 - Base class for list-based screens with inline editing
# Extracts core patterns from TaskListScreen for reuse across different data types

class BaseListScreen {
    # Core list management properties
    [System.Collections.Generic.List[object]]$FlatList
    [int]$SelectedIndex = 0
    [int]$ScrollTop = 0
    [int]$Width
    [int]$Height
    
    # Status messages
    [string]$StatusMessage = ""
    [datetime]$StatusMessageTime = [DateTime]::MinValue
    
    # Inline editing state
    [int]$EditingIndex = -1
    [string]$EditingField = ""
    [string]$EditingValue = ""
    [int]$EditingCursor = 0
    [object]$EditingItem = $null
    [bool]$IsNewItem = $false
    
    # Rendering components
    [FastLineBuilder]$LineBuilder
    [UnifiedRenderer]$Renderer
    
    # Color scheme - consistent with TaskListScreen
    [string]$SelectedBg = "`e[48;2;45;45;55m"
    [string]$EvenRowBg = "`e[48;2;25;25;30m"
    [string]$HeaderColor = "`e[38;2;100;150;255m"
    [string]$NormalColor = "`e[0m"
    [string]$EditHighlight = "`e[47;30m"
    
    # Pillbox drawing characters
    [string]$PillboxTopLeft = "╭"
    [string]$PillboxTopRight = "╮"
    [string]$PillboxBottomLeft = "╰"
    [string]$PillboxBottomRight = "╯"
    [string]$PillboxHorizontal = "─"
    [string]$PillboxVertical = "│"
    
    BaseListScreen() {
        $this.FlatList = [System.Collections.Generic.List[object]]::new()
        
        # Initialize rendering system (optional - derived classes can override)
        try {
            # Only initialize if the classes are available and needed
            # ExcelMappingScreen doesn't need these TaskListScreen-specific components
            if ([type]::GetType("FastLineBuilder") -and [type]::GetType("UnifiedRenderer")) {
                $this.LineBuilder = [FastLineBuilder]::new()
                $this.Renderer = [UnifiedRenderer]::new()
            }
        } catch {
            # Non-critical - derived classes handle their own rendering
            Write-Verbose "Advanced rendering components not available - using basic rendering"
        }
    }
    
    [void] Initialize([int]$width, [int]$height) {
        $this.Width = $width
        $this.Height = $height
    }
    
    # === ABSTRACT METHODS - Must be implemented by derived classes ===
    
    [void] LoadData() {
        throw "LoadData() must be implemented by derived class"
    }
    
    [void] BuildFlatList() {
        throw "BuildFlatList() must be implemented by derived class"
    }
    
    [string] RenderItem([object]$item, [int]$index, [bool]$isSelected) {
        throw "RenderItem() must be implemented by derived class"
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
    
    # NEW: Field cursor positioning - override in derived classes
    [hashtable] GetFieldScreenPosition([string]$field, [int]$cursor, [object]$item) {
        # Default implementation - just position at start of line
        return @{ X = 2 + $cursor; Y = 3 }
    }
    
    # === CORE LIST NAVIGATION ===
    
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
    
    # === INLINE EDITING SYSTEM ===
    
    [void] StartEdit([string]$field) {
        if ($this.FlatList.Count -eq 0) { return }
        
        $this.EditingIndex = $this.SelectedIndex
        $this.EditingField = $field
        $this.EditingItem = $this.FlatList[$this.SelectedIndex]
        $this.IsNewItem = $false
        
        # Get current field value for editing
        $this.EditingValue = $this.GetFieldValue($this.EditingItem, $field)
        $this.EditingCursor = $this.EditingValue.Length
    }
    
    [void] StartNewItem() {
        $newItem = $this.CreateNewItem()
        $this.FlatList.Add($newItem)
        $this.SelectedIndex = $this.FlatList.Count - 1
        $this.EnsureVisible()
        
        $this.EditingIndex = $this.SelectedIndex
        $this.EditingItem = $newItem
        $this.IsNewItem = $true
        
        # Start with first editable field
        $fields = $this.GetEditableFields($newItem)
        if ($fields.Count -gt 0) {
            $this.EditingField = $fields[0]
            $this.EditingValue = ""
            $this.EditingCursor = 0
        }
    }
    
    [void] SaveInlineEdit() {
        if ($this.EditingItem -eq $null) { return }
        
        # Update the field value
        $this.SetFieldValue($this.EditingItem, $this.EditingField, $this.EditingValue)
        
        # Save to service
        $this.SaveItem($this.EditingItem)
        
        # Clear editing state
        $this.CancelInlineEdit()
        
        # Reload data to reflect changes
        $this.LoadData()
        
        $this.SetStatusMessage("Saved successfully", 2000)
    }
    
    [void] CancelInlineEdit() {
        if ($this.IsNewItem -and $this.EditingItem) {
            # Remove the new item that was added
            $this.FlatList.Remove($this.EditingItem)
            if ($this.SelectedIndex -ge $this.FlatList.Count) {
                $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
            }
        }
        
        $this.EditingIndex = -1
        $this.EditingField = ""
        $this.EditingValue = ""
        $this.EditingCursor = 0
        $this.EditingItem = $null
        $this.IsNewItem = $false
    }
    
    [void] NextEditField() {
        if ($this.EditingItem -eq $null) { return }
        
        $fields = $this.GetEditableFields($this.EditingItem)
        $currentIndex = $fields.IndexOf($this.EditingField)
        
        if ($currentIndex -ge 0 -and $currentIndex -lt ($fields.Count - 1)) {
            # Move to next field
            $this.EditingField = $fields[$currentIndex + 1]
            $this.EditingValue = $this.GetFieldValue($this.EditingItem, $this.EditingField)
            $this.EditingCursor = $this.EditingValue.Length
        }
    }
    
    [void] PreviousEditField() {
        if ($this.EditingItem -eq $null) { return }
        
        $fields = $this.GetEditableFields($this.EditingItem)
        $currentIndex = $fields.IndexOf($this.EditingField)
        
        if ($currentIndex -gt 0) {
            # Move to previous field
            $this.EditingField = $fields[$currentIndex - 1]
            $this.EditingValue = $this.GetFieldValue($this.EditingItem, $this.EditingField)
            $this.EditingCursor = $this.EditingValue.Length
        }
    }
    
    # === FIELD VALUE ACCESS - Override in derived classes for type-specific handling ===
    
    [string] GetFieldValue([object]$item, [string]$field) {
        # Default implementation using reflection
        try {
            $property = $item.GetType().GetProperty($field)
            if ($property) {
                $value = $property.GetValue($item)
                return if ($value -ne $null) { $value.ToString() } else { "" }
            }
        } catch {
            # Fallback for hashtables/PSObjects
            if ($item.$field -ne $null) {
                return $item.$field.ToString()
            }
        }
        return ""
    }
    
    [void] SetFieldValue([object]$item, [string]$field, [string]$value) {
        # Default implementation using reflection
        try {
            $property = $item.GetType().GetProperty($field)
            if ($property -and $property.CanWrite) {
                # Convert value to appropriate type
                $targetType = $property.PropertyType
                $convertedValue = $this.ConvertValue($value, $targetType)
                $property.SetValue($item, $convertedValue)
                return
            }
        } catch {
            # Fallback for hashtables/PSObjects
            $item.$field = $value
        }
    }
    
    [object] ConvertValue([string]$value, [Type]$targetType) {
        if ($targetType -eq [string]) { return $value }
        if ($targetType -eq [int]) { return if ($value) { [int]$value } else { 0 } }
        if ($targetType -eq [bool]) { return [bool]$value }
        if ($targetType -eq [datetime]) { 
            return if ($value) { [datetime]::Parse($value) } else { [datetime]::MinValue }
        }
        return $value  # Default fallback
    }
    
    # === RENDERING CORE ===
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear screen
        [void]$sb.Append([VT]::Clear())
        [void]$sb.Append([VT]::MoveTo(0, 0))
        
        # Header
        $this.RenderHeader($sb)
        
        # Content area
        $this.RenderContent($sb)
        
        # Footer with function keys
        $this.RenderFooter($sb)
        
        # Status bar
        $this.RenderStatus($sb)
        
        return $sb.ToString()
    }
    
    [void] RenderHeader([System.Text.StringBuilder]$sb) {
        # Default header - override in derived classes
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append("BaseListScreen - Override RenderHeader()")
        [void]$sb.Append($this.NormalColor)
    }
    
    [void] RenderContent([System.Text.StringBuilder]$sb) {
        $startY = 3
        $currentY = $startY
        $availableHeight = $this.Height - 6
        
        for ($i = $this.ScrollTop; $i -lt $this.FlatList.Count -and ($currentY - $startY) -lt $availableHeight; $i++) {
            $item = $this.FlatList[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            
            [void]$sb.Append([VT]::MoveTo(0, $currentY))
            
            if ($isSelected) {
                # Render selected item with pillbox
                $this.RenderSelectedItem($sb, $item, $i, $currentY)
                $currentY += 3  # Selected items take 3 lines (top, content, bottom)
            } else {
                # Render normal item
                $content = $this.RenderItem($item, $i, $false)
                [void]$sb.Append($content)
                [void]$sb.Append([VT]::ClearLine())
                $currentY++
            }
        }
    }
    
    [void] RenderSelectedItem([System.Text.StringBuilder]$sb, [object]$item, [int]$index, [int]$y) {
        $content = $this.RenderItem($item, $index, $true)
        $pillboxWidth = [Math]::Min($this.Width - 4, [Math]::Max(40, $content.Length + 4))
        
        # Top border
        [void]$sb.Append([VT]::MoveTo(0, $y))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append($this.PillboxTopLeft)
        [void]$sb.Append($this.PillboxHorizontal * ($pillboxWidth - 2))
        [void]$sb.Append($this.PillboxTopRight)
        [void]$sb.Append($this.NormalColor)
        
        # Content with side borders
        [void]$sb.Append([VT]::MoveTo(0, $y + 1))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append($this.PillboxVertical)
        [void]$sb.Append($this.NormalColor)
        [void]$sb.Append(" ")
        [void]$sb.Append($content)
        
        # Right border (calculate position)
        $rightBorderX = $pillboxWidth - 1
        [void]$sb.Append([VT]::MoveTo($rightBorderX, $y + 1))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append($this.PillboxVertical)
        [void]$sb.Append($this.NormalColor)
        
        # Bottom border
        [void]$sb.Append([VT]::MoveTo(0, $y + 2))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append($this.PillboxBottomLeft)
        [void]$sb.Append($this.PillboxHorizontal * ($pillboxWidth - 2))
        [void]$sb.Append($this.PillboxBottomRight)
        [void]$sb.Append($this.NormalColor)
    }
    
    [void] RenderFooter([System.Text.StringBuilder]$sb) {
        # Default footer - override in derived classes for F-key functions
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 3))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append("F1-F10: Functions | Enter: Edit | N: New | Del: Delete")
        [void]$sb.Append($this.NormalColor)
    }
    
    [void] RenderStatus([System.Text.StringBuilder]$sb) {
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 1))
        
        if ($this.StatusMessage -and ((Get-Date) - $this.StatusMessageTime).TotalMilliseconds -lt 3000) {
            [void]$sb.Append($this.StatusMessage)
        } else {
            $count = if ($this.FlatList) { $this.FlatList.Count } else { 0 }
            $current = if ($count -gt 0) { $this.SelectedIndex + 1 } else { 0 }
            [void]$sb.Append("Items: $count | Selected: $current")
            
            if ($this.EditingItem) {
                [void]$sb.Append(" | Editing: $($this.EditingField)")
            }
        }
        
        [void]$sb.Append([VT]::ClearLine())
    }
    
    [void] SetStatusMessage([string]$message, [int]$durationMs = 3000) {
        $this.StatusMessage = $message
        $this.StatusMessageTime = Get-Date
    }
    
    # === INPUT HANDLING CORE ===
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Handle inline editing first
        if ($this.EditingItem -ne $null) {
            return $this.HandleEditingInput($key)
        }
        
        # Handle navigation and commands
        return $this.HandleNavigationInput($key)
    }
    
    [bool] HandleEditingInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                $this.SaveInlineEdit()
                return $true
            }
            ([System.ConsoleKey]::Escape) {
                $this.CancelInlineEdit()
                return $true
            }
            ([System.ConsoleKey]::Tab) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Shift) {
                    $this.PreviousEditField()
                } else {
                    $this.NextEditField()
                }
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
            default {
                # Add character to editing value
                if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                    $this.EditingValue = $this.EditingValue.Insert($this.EditingCursor, $key.KeyChar)
                    $this.EditingCursor++
                    return $true
                }
            }
        }
        return $false
    }
    
    [bool] HandleNavigationInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                $this.MoveUp()
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                $this.MoveDown()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                # Start editing first field of selected item
                if ($this.FlatList.Count -gt 0) {
                    $item = $this.FlatList[$this.SelectedIndex]
                    $fields = $this.GetEditableFields($item)
                    if ($fields.Count -gt 0) {
                        $this.StartEdit($fields[0])
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::N) {
                $this.StartNewItem()
                return $true
            }
            ([System.ConsoleKey]::Delete) {
                if ($this.FlatList.Count -gt 0) {
                    $this.DeleteCurrentItem()
                }
                return $true
            }
            default {
                # Let derived classes handle additional keys
                return $this.HandleDerivedInput($key)
            }
        }
        return $false  # Should never reach here, but PowerShell requires it
    }
    
    [bool] HandleDerivedInput([System.ConsoleKeyInfo]$key) {
        # Override in derived classes for additional key handling
        return $false
    }
    
    [void] DeleteCurrentItem() {
        if ($this.FlatList.Count -eq 0) { return }
        
        # Override in derived classes for proper deletion logic
        $this.FlatList.RemoveAt($this.SelectedIndex)
        
        if ($this.SelectedIndex -ge $this.FlatList.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
        }
        
        $this.SetStatusMessage("Item deleted", 2000)
    }
}