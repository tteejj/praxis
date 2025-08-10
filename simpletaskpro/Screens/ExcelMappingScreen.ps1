# ExcelMappingScreen.ps1 - Excel field mapping management screen
# Complete TaskListScreen-quality implementation with all sophisticated components

class ExcelMappingScreen {
    [ExcelMappingService]$MappingService
    [System.Collections.Generic.List[object]]$FlatList
    [int]$SelectedIndex = 0
    [int]$ScrollTop = 0
    [int]$Width = 80
    [int]$Height = 25
    
    # Status messages (TaskListScreen pattern)
    [string]$StatusMessage = ""
    [datetime]$StatusMessageTime = [DateTime]::MinValue
    
    # Inline editing state (complete TaskListScreen compatibility)
    [int]$EditingIndex = -1
    [string]$EditingField = ""  # "DisplayName", "SourceCell", "DestinationCell", "T2020Name"
    [string]$EditingValue = ""
    [int]$EditingCursor = 0
    [object]$EditingMapping = $null
    [bool]$IsNewMapping = $false
    
    # TaskListScreen-quality column system (wider spacing for better readability)
    [int]$DisplayNameCol = 25  # Increased from 22 for longer field names
    [int]$SourceCellCol = 8    # Excel cells are short (W23, G17, etc)
    [int]$ArrowCol = 3         # " → " column
    [int]$DestCellCol = 8      # Excel cells are short
    [int]$T2020NameCol = 25    # Increased from 20 for longer T2020 names  
    [int]$IncludeCol = 5       # " [X] "
    
    # TaskListScreen-quality color system (using AppThemeManager)
    [string]$HeaderColor = ""
    [string]$SelectedBg = ""
    [string]$TagColor = "" 
    [string]$NormalColor = ""
    [string]$EditHighlight = ""
    [string]$FieldColor = ""
    [string]$ValueColor = ""
    [string]$BrowserColor = ""
    
    ExcelMappingScreen() {
        "DEBUG: ExcelMappingScreen constructor START $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.MappingService = [ExcelMappingService]::new()
        $this.FlatList = [System.Collections.Generic.List[object]]::new()
        $this.InitializeColors()
        $this.LoadMappings()
        "DEBUG: ExcelMappingScreen constructor COMPLETE $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
    }
    
    [void] InitializeColors() {
        # Use AppThemeManager for consistent TaskListScreen-quality theming
        $this.HeaderColor = [AppThemeManager]::GetColor("Header")
        $this.TagColor = [AppThemeManager]::GetColor("Text")  # Use Text instead of Tag
        $this.FieldColor = [AppThemeManager]::GetColor("Field")
        $this.ValueColor = [AppThemeManager]::GetColor("Value")
        $this.BrowserColor = [AppThemeManager]::GetColor("Browser")
        $this.NormalColor = [VT]::Reset()
        $this.EditHighlight = "`e[47;30m"  # Simple white background, black text
        $this.SelectedBg = [AppThemeManager]::GetBackgroundColor("Selected")
    }
    
    [void] Initialize([int]$width, [int]$height) {
        "DEBUG: ExcelMappingScreen Initialize ${width}x${height} $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        $this.Width = $width
        $this.Height = $height
    }
    
    [void] LoadMappings() {
        $this.FlatList.Clear()
        $mappings = $this.MappingService.GetMappings()
        
        # Group by Category for better organization (TaskListScreen pattern)
        $groupedMappings = $mappings | Group-Object Category | Sort-Object Name
        
        foreach ($group in $groupedMappings) {
            # Add category header
            $this.FlatList.Add(@{
                Type = "Category"
                CategoryName = $group.Name
                MappingCount = $group.Group.Count
                IsLast = $false
            })
            
            # Add mappings in category
            $categoryMappings = $group.Group | Sort-Object SortOrder, DisplayName
            for ($i = 0; $i -lt $categoryMappings.Count; $i++) {
                $this.FlatList.Add(@{
                    Type = "Mapping"
                    Mapping = $categoryMappings[$i]
                    IsLast = ($i -eq ($categoryMappings.Count - 1))
                    CategoryName = $group.Name
                })
            }
        }
        
        # Update final IsLast flag
        if ($this.FlatList.Count -gt 0) {
            $this.FlatList[-1].IsLast = $true
        }
    }
    
    [string] Render() {
        # TaskListScreen-quality rendering with StringBuilder (proper approach)
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.Append([VT]::Clear())
        
        # Header with Excel mapping info (TaskListScreen style)
        [void]$sb.Append([VT]::MoveTo(0, 0))
        [void]$sb.Append($this.HeaderColor)
        $headerText = " EXCEL FIELD MAPPING - Configuration Manager ($($this.FlatList.Count) items)"
        [void]$sb.Append($headerText.PadRight($this.Width))
        [void]$sb.Append($this.NormalColor)
        
        # Column headers with precise TaskListScreen formatting (wider spacing)
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append($this.TagColor)
        $headerLine = " Display Name             Src  → Dest T2020 Field Name         Inc  "
        [void]$sb.Append($headerLine.PadRight($this.Width))
        [void]$sb.Append($this.NormalColor)
        
        # Separator line (TaskListScreen style)
        [void]$sb.Append([VT]::MoveTo(0, 2))
        [void]$sb.Append($this.HeaderColor)
        [void]$sb.Append(" " + [StringCache]::GetRepeatedChar('─', $this.Width - 1))
        [void]$sb.Append($this.NormalColor)
        
        # Render content with TaskListScreen quality
        if ($this.FlatList.Count -gt 0) {
            $startY = 3
            $availableHeight = $this.Height - 5
            $currentY = $startY
            
            for ($i = $this.ScrollTop; $i -lt $this.FlatList.Count -and ($currentY - $startY) -lt $availableHeight; $i++) {
                $item = $this.FlatList[$i]
                $isSelected = ($i -eq $this.SelectedIndex)
                $isEditingThis = ($this.EditingIndex -eq $i)
                
                [void]$sb.Append([VT]::MoveTo(0, $currentY))
                
                if ($item.Type -eq "Category") {
                    # Category header (like TaskListScreen parent tasks)
                    if ($isSelected) {
                        $currentY = $this.RenderSelectedCategory($sb, $item, $isEditingThis, $currentY)
                    } else {
                        $currentY = $this.RenderNormalCategory($sb, $item, $currentY)
                    }
                } else {
                    # Mapping item (like TaskListScreen subtasks)
                    if ($isSelected) {
                        $currentY = $this.RenderSelectedMapping($sb, $item, $isEditingThis, $currentY)
                    } else {
                        $currentY = $this.RenderNormalMapping($sb, $item, $currentY)
                    }
                }
            }
        }
        
        # Status bar with TaskListScreen-quality function keys
        [void]$sb.Append([VT]::MoveTo(0, $this.Height - 1))
        [void]$sb.Append([AppThemeManager]::GetColor("StatusBar"))
        if ($this.EditingIndex -ge 0) {
            $statusText = " EDITING [$($this.EditingField.ToUpper())]: Tab→Next  Enter→Save  Esc→Cancel"
        } else {
            $statusText = " ↑↓→Navigate  Enter→Edit  Tab→NextField  X→Toggle  N→New  Del→Delete  F1→Open F2→Copy F3→Export F10→Tasks"
        }
        [void]$sb.Append($statusText.PadRight($this.Width))
        [void]$sb.Append($this.NormalColor)
        
        return $sb.ToString()
    }
    
    # TaskListScreen-quality rendering methods
    [int] RenderSelectedCategory([System.Text.StringBuilder]$sb, [object]$item, [bool]$isEditing, [int]$currentY) {
        # Category pillbox (like TaskListScreen parent task selection)
        $pillboxColor = [AppThemeManager]::GetPillboxColor()
        
        # Top border
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append($pillboxColor)
        [void]$sb.Append("╭" + [StringCache]::GetRepeatedChar('─', $this.Width - 2) + "╮")
        [void]$sb.Append($this.NormalColor)
        $currentY++
        
        # Content with category name and count
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append($pillboxColor)
        [void]$sb.Append("│ ")
        [void]$sb.Append($this.HeaderColor)
        $categoryText = "$($item.CategoryName) ($($item.MappingCount) mappings)"
        [void]$sb.Append($categoryText)
        [void]$sb.Append($pillboxColor)
        $paddingWidth = $this.Width - 4 - $categoryText.Length
        [void]$sb.Append([StringCache]::GetSpaces($paddingWidth) + " │")
        [void]$sb.Append($this.NormalColor)
        $currentY++
        
        # Bottom border
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append($pillboxColor)
        [void]$sb.Append("╰" + [StringCache]::GetRepeatedChar('─', $this.Width - 2) + "╯")
        [void]$sb.Append($this.NormalColor)
        $currentY++
        
        return $currentY
    }
    
    [int] RenderNormalCategory([System.Text.StringBuilder]$sb, [object]$item, [int]$currentY) {
        # Simple category line
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append($this.HeaderColor)
        $categoryText = " ■ $($item.CategoryName) ($($item.MappingCount) mappings)"
        [void]$sb.Append($categoryText.PadRight($this.Width))
        [void]$sb.Append($this.NormalColor)
        $currentY++
        
        return $currentY
    }
    
    [int] RenderSelectedMapping([System.Text.StringBuilder]$sb, [object]$item, [bool]$isEditing, [int]$currentY) {
        # Mapping pillbox (like TaskListScreen subtask selection)
        $mapping = $item.Mapping
        $pillboxColor = [AppThemeManager]::GetPillboxColor()
        
        # Top border
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append($pillboxColor)
        [void]$sb.Append("╭" + [StringCache]::GetRepeatedChar('─', $this.Width - 2) + "╮")
        [void]$sb.Append($this.NormalColor)
        $currentY++
        
        # Content with mapping details
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append($pillboxColor)
        [void]$sb.Append("│ ")
        $this.RenderMappingFields($sb, $mapping, $isEditing, $true)
        # Calculate padding to fill to right border
        $usedWidth = 2 + $this.DisplayNameCol + $this.SourceCellCol + $this.ArrowCol + $this.DestCellCol + $this.T2020NameCol + $this.IncludeCol
        $paddingWidth = $this.Width - $usedWidth - 2
        if ($paddingWidth -gt 0) {
            [void]$sb.Append([StringCache]::GetSpaces($paddingWidth))
        }
        [void]$sb.Append($pillboxColor)
        [void]$sb.Append(" │")
        [void]$sb.Append($this.NormalColor)
        $currentY++
        
        # Bottom border
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append($pillboxColor)
        [void]$sb.Append("╰" + [StringCache]::GetRepeatedChar('─', $this.Width - 2) + "╯")
        [void]$sb.Append($this.NormalColor)
        $currentY++
        
        return $currentY
    }
    
    [int] RenderNormalMapping([System.Text.StringBuilder]$sb, [object]$item, [int]$currentY) {
        # Simple mapping line with tree connector
        $mapping = $item.Mapping
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append(" ")
        if ($item.IsLast) {
            [void]$sb.Append($this.TagColor)
            [void]$sb.Append(" └─ ")
        } else {
            [void]$sb.Append($this.TagColor)
            [void]$sb.Append(" ├─ ")
        }
        [void]$sb.Append($this.NormalColor)
        $this.RenderMappingFields($sb, $mapping, $false, $false)
        $currentY++
        
        return $currentY
    }
    
    [void] RenderMappingFields([System.Text.StringBuilder]$sb, [object]$mapping, [bool]$isEditing, [bool]$isPillbox) {
        # Display Name field (20 chars)
        if ($isEditing -and $this.EditingField -eq "DisplayName") {
            [void]$sb.Append($this.EditHighlight)
            $editValue = $this.EditingValue
            if ($this.EditingCursor -lt $editValue.Length) {
                $editValue = $editValue.Insert($this.EditingCursor, "│")
            } else {
                $editValue = $editValue + "│"
            }
            [void]$sb.Append($editValue.PadRight($this.DisplayNameCol))
            [void]$sb.Append($this.NormalColor)
        } else {
            [void]$sb.Append($this.ValueColor)
            [void]$sb.Append($mapping.DisplayName.PadRight($this.DisplayNameCol))
            [void]$sb.Append($this.NormalColor)
        }
        
        # Source Cell field (8 chars)
        if ($isEditing -and $this.EditingField -eq "SourceCell") {
            [void]$sb.Append($this.EditHighlight)
            $editValue = $this.EditingValue
            if ($this.EditingCursor -lt $editValue.Length) {
                $editValue = $editValue.Insert($this.EditingCursor, "│")
            } else {
                $editValue = $editValue + "│"
            }
            [void]$sb.Append($editValue.PadRight($this.SourceCellCol))
            [void]$sb.Append($this.NormalColor)
        } else {
            [void]$sb.Append($this.FieldColor)
            [void]$sb.Append($mapping.SourceCell.PadRight($this.SourceCellCol))
            [void]$sb.Append($this.NormalColor)
        }
        
        # Arrow (3 chars)
        [void]$sb.Append($this.TagColor)
        [void]$sb.Append(" → ")
        [void]$sb.Append($this.NormalColor)
        
        # Destination Cell field (8 chars)
        if ($isEditing -and $this.EditingField -eq "DestinationCell") {
            [void]$sb.Append($this.EditHighlight)
            $editValue = $this.EditingValue
            if ($this.EditingCursor -lt $editValue.Length) {
                $editValue = $editValue.Insert($this.EditingCursor, "│")
            } else {
                $editValue = $editValue + "│"
            }
            [void]$sb.Append($editValue.PadRight($this.DestCellCol))
            [void]$sb.Append($this.NormalColor)
        } else {
            [void]$sb.Append($this.BrowserColor)
            [void]$sb.Append($mapping.DestinationCell.PadRight($this.DestCellCol))
            [void]$sb.Append($this.NormalColor)
        }
        
        # T2020 Name field (18 chars)
        if ($isEditing -and $this.EditingField -eq "T2020Name") {
            [void]$sb.Append($this.EditHighlight)
            $editValue = $this.EditingValue
            if ($this.EditingCursor -lt $editValue.Length) {
                $editValue = $editValue.Insert($this.EditingCursor, "│")
            } else {
                $editValue = $editValue + "│"
            }
            [void]$sb.Append($editValue.PadRight($this.T2020NameCol))
            [void]$sb.Append($this.NormalColor)
        } else {
            [void]$sb.Append($this.ValueColor)
            [void]$sb.Append($mapping.T2020Name.PadRight($this.T2020NameCol))
            [void]$sb.Append($this.NormalColor)
        }
        
        # Include checkbox (4 chars)
        [void]$sb.Append($this.TagColor)
        if ($mapping.IncludeInT2020) {
            [void]$sb.Append(" [X]")
        } else {
            [void]$sb.Append(" [ ]")
        }
        [void]$sb.Append($this.NormalColor)
        
        # Pad to fill remaining space if not in pillbox
        if (-not $isPillbox) {
            $usedWidth = $this.DisplayNameCol + $this.SourceCellCol + $this.ArrowCol + $this.DestCellCol + $this.T2020NameCol + $this.IncludeCol + 6  # Tree connector
            $remainingWidth = $this.Width - $usedWidth
            if ($remainingWidth -gt 0) {
                [void]$sb.Append([StringCache]::GetSpaces($remainingWidth))
            }
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        "DEBUG: ExcelMappingScreen HandleInput: $($key.Key) $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
        
        # Handle inline editing input first
        if ($this.EditingIndex -ge 0) {
            return $this.HandleEditingInput($key)
        }
        
        # Handle navigation and commands
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    # Ctrl+Up: Move mapping up (TaskListScreen pattern)
                    if ($this.FlatList.Count -gt 0) {
                        $currentItem = $this.FlatList[$this.SelectedIndex]
                        if ($currentItem.Type -eq "Mapping") {
                            $mapping = $currentItem.Mapping
                            $this.MappingService.MoveUp($mapping.Id)
                            $this.LoadMappings()
                            $this.SetStatusMessage("Moved $($mapping.DisplayName) up")
                        }
                    }
                } else {
                    # Normal up navigation (TaskListScreen quality)
                    if ($this.SelectedIndex -gt 0) {
                        $this.SelectedIndex--
                        $this.EnsureVisible()
                        # Show current item info
                        $currentItem = $this.FlatList[$this.SelectedIndex]
                        if ($currentItem.Type -eq "Category") {
                            $this.SetStatusMessage("Category: $($currentItem.CategoryName) ($($currentItem.MappingCount) mappings)")
                        } else {
                            $mapping = $currentItem.Mapping
                            $this.SetStatusMessage("$($mapping.DisplayName): $($mapping.SourceCell) → $($mapping.DestinationCell)")
                        }
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($key.Modifiers -band [System.ConsoleModifiers]::Control) {
                    # Ctrl+Down: Move mapping down (TaskListScreen pattern)
                    if ($this.FlatList.Count -gt 0) {
                        $currentItem = $this.FlatList[$this.SelectedIndex]
                        if ($currentItem.Type -eq "Mapping") {
                            $mapping = $currentItem.Mapping
                            $this.MappingService.MoveDown($mapping.Id)
                            $this.LoadMappings()
                            $this.SetStatusMessage("Moved $($mapping.DisplayName) down")
                        }
                    }
                } else {
                    # Normal down navigation (TaskListScreen quality)
                    if ($this.SelectedIndex -lt ($this.FlatList.Count - 1)) {
                        $this.SelectedIndex++
                        $this.EnsureVisible()
                        # Show current item info
                        $currentItem = $this.FlatList[$this.SelectedIndex]
                        if ($currentItem.Type -eq "Category") {
                            $this.SetStatusMessage("Category: $($currentItem.CategoryName) ($($currentItem.MappingCount) mappings)")
                        } else {
                            $mapping = $currentItem.Mapping
                            $this.SetStatusMessage("$($mapping.DisplayName): $($mapping.SourceCell) → $($mapping.DestinationCell)")
                        }
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                # Start editing first field (TaskListScreen pattern)
                if ($this.FlatList.Count -gt 0) {
                    $currentItem = $this.FlatList[$this.SelectedIndex]
                    if ($currentItem.Type -eq "Mapping") {
                        $this.StartEdit("DisplayName")
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::Tab) {
                # Start editing first field (TaskListScreen pattern)
                if ($this.FlatList.Count -gt 0) {
                    $currentItem = $this.FlatList[$this.SelectedIndex]
                    if ($currentItem.Type -eq "Mapping") {
                        $this.StartEdit("DisplayName")
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::X) {
                # Toggle T2020 inclusion (TaskListScreen pattern)
                if ($this.FlatList.Count -gt 0) {
                    $currentItem = $this.FlatList[$this.SelectedIndex]
                    if ($currentItem.Type -eq "Mapping") {
                        $mapping = $currentItem.Mapping
                        $this.MappingService.ToggleT2020Include($mapping.Id)
                        $this.LoadMappings()
                        $includeStatus = if ($mapping.IncludeInT2020) { "included" } else { "excluded" }
                        $this.SetStatusMessage("$($mapping.DisplayName) $includeStatus from T2020 export")
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::N) {
                $this.StartNewMapping()
                return $true
            }
            ([System.ConsoleKey]::Delete) {
                # Delete mapping (TaskListScreen pattern)
                if ($this.FlatList.Count -gt 0) {
                    $currentItem = $this.FlatList[$this.SelectedIndex]
                    if ($currentItem.Type -eq "Mapping") {
                        $mapping = $currentItem.Mapping
                        $mappingName = $mapping.DisplayName
                        $this.MappingService.DeleteMapping($mapping.Id)
                        $this.LoadMappings()
                        if ($this.SelectedIndex -ge $this.FlatList.Count) {
                            $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
                        }
                        $this.SetStatusMessage("Deleted mapping: $mappingName")
                    }
                }
                return $true
            }
            # Excel function keys (TaskListScreen quality)
            ([System.ConsoleKey]::F1) {
                $this.OpenExcelFile()
                return $true
            }
            ([System.ConsoleKey]::F2) {
                $this.CopyExcelData()
                return $true
            }
            ([System.ConsoleKey]::F3) {
                $this.ExportT2020Data()
                return $true
            }
            ([System.ConsoleKey]::F4) {
                $this.ConfigurePaths()
                return $true
            }
            default {
                return $true
            }
        }
        return $true
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
                # Move to next field
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
        return $true
    }
    
    # Inline editing methods (like TaskListScreen)
    [void] StartEdit([string]$field) {
        if ($this.FlatList.Count -eq 0) { return }
        
        $currentItem = $this.FlatList[$this.SelectedIndex]
        if ($currentItem.Type -ne "Mapping") { return }  # Only edit mappings, not categories
        
        $this.EditingIndex = $this.SelectedIndex
        $this.EditingField = $field
        $this.EditingMapping = $currentItem.Mapping
        $this.IsNewMapping = $false
        
        # Get current field value with TaskListScreen-quality field handling
        switch ($field) {
            "DisplayName" { $this.EditingValue = $this.EditingMapping.DisplayName }
            "SourceCell" { $this.EditingValue = $this.EditingMapping.SourceCell }
            "DestinationCell" { $this.EditingValue = $this.EditingMapping.DestinationCell }
            "T2020Name" { $this.EditingValue = $this.EditingMapping.T2020Name }
            default { $this.EditingValue = "" }
        }
        
        $this.EditingCursor = $this.EditingValue.Length
        $this.SetStatusMessage("Editing $field - Tab:Next  Enter:Save  Esc:Cancel")
    }
    
    [void] StartNewMapping() {
        $newMapping = [ExcelFieldMapping]::new()
        $newMapping.DisplayName = "New Field"
        $newMapping.Category = "General"
        $newMapping.SortOrder = $this.FlatList.Count + 1
        
        # Add to service temporarily
        $this.MappingService.AddMapping($newMapping)
        $this.LoadMappings()
        
        # Select the new item
        $this.SelectedIndex = $this.FlatList.Count - 1
        $this.EnsureVisible()
        
        # Start editing it
        $this.EditingIndex = $this.SelectedIndex
        $this.EditingField = "DisplayName"
        $this.EditingMapping = $newMapping
        $this.IsNewMapping = $true
        $this.EditingValue = "New Field"
        $this.EditingCursor = $this.EditingValue.Length
    }
    
    [void] SaveInlineEdit() {
        if ($this.EditingMapping -eq $null) { return }
        
        # Update the field value
        switch ($this.EditingField) {
            "DisplayName" { $this.EditingMapping.DisplayName = $this.EditingValue }
            "SourceCell" { $this.EditingMapping.SourceCell = $this.EditingValue }
            "DestinationCell" { $this.EditingMapping.DestinationCell = $this.EditingValue }
            "T2020Name" { $this.EditingMapping.T2020Name = $this.EditingValue }
        }
        
        # Save to service
        $this.MappingService.UpdateMapping($this.EditingMapping)
        
        # Clear editing state
        $this.CancelInlineEdit()
        
        # Reload data
        $this.LoadMappings()
        
        $this.SetStatusMessage("Saved successfully")
    }
    
    [void] CancelInlineEdit() {
        if ($this.IsNewMapping -and $this.EditingMapping) {
            # Remove the new mapping that was added
            $this.MappingService.DeleteMapping($this.EditingMapping.Id)
            $this.LoadMappings()
            if ($this.SelectedIndex -ge $this.FlatList.Count) {
                $this.SelectedIndex = [Math]::Max(0, $this.FlatList.Count - 1)
            }
        }
        
        $this.EditingIndex = -1
        $this.EditingField = ""
        $this.EditingValue = ""
        $this.EditingCursor = 0
        $this.EditingMapping = $null
        $this.IsNewMapping = $false
    }
    
    [void] NextEditField() {
        $fields = @("DisplayName", "SourceCell", "DestinationCell", "T2020Name")
        $currentIndex = $fields.IndexOf($this.EditingField)
        
        if ($currentIndex -ge 0 -and $currentIndex -lt ($fields.Count - 1)) {
            # Save current field first
            switch ($this.EditingField) {
                "DisplayName" { $this.EditingMapping.DisplayName = $this.EditingValue }
                "SourceCell" { $this.EditingMapping.SourceCell = $this.EditingValue }
                "DestinationCell" { $this.EditingMapping.DestinationCell = $this.EditingValue }
                "T2020Name" { $this.EditingMapping.T2020Name = $this.EditingValue }
            }
            
            # Move to next field
            $this.EditingField = $fields[$currentIndex + 1]
            switch ($this.EditingField) {
                "DisplayName" { $this.EditingValue = $this.EditingMapping.DisplayName }
                "SourceCell" { $this.EditingValue = $this.EditingMapping.SourceCell }
                "DestinationCell" { $this.EditingValue = $this.EditingMapping.DestinationCell }
                "T2020Name" { $this.EditingValue = $this.EditingMapping.T2020Name }
            }
            $this.EditingCursor = $this.EditingValue.Length
        }
    }
    
    [void] PreviousEditField() {
        $fields = @("DisplayName", "SourceCell", "DestinationCell", "T2020Name")
        $currentIndex = $fields.IndexOf($this.EditingField)
        
        if ($currentIndex -gt 0) {
            # Save current field first
            switch ($this.EditingField) {
                "DisplayName" { $this.EditingMapping.DisplayName = $this.EditingValue }
                "SourceCell" { $this.EditingMapping.SourceCell = $this.EditingValue }
                "DestinationCell" { $this.EditingMapping.DestinationCell = $this.EditingValue }
                "T2020Name" { $this.EditingMapping.T2020Name = $this.EditingValue }
            }
            
            # Move to previous field
            $this.EditingField = $fields[$currentIndex - 1]
            switch ($this.EditingField) {
                "DisplayName" { $this.EditingValue = $this.EditingMapping.DisplayName }
                "SourceCell" { $this.EditingValue = $this.EditingMapping.SourceCell }
                "DestinationCell" { $this.EditingValue = $this.EditingMapping.DestinationCell }
                "T2020Name" { $this.EditingValue = $this.EditingMapping.T2020Name }
            }
            $this.EditingCursor = $this.EditingValue.Length
        }
    }
    
    [void] EnsureVisible() {
        $visibleHeight = $this.Height - 6  # Account for header, separator, status
        if ($this.SelectedIndex -lt $this.ScrollTop) {
            $this.ScrollTop = $this.SelectedIndex
        }
        elseif ($this.SelectedIndex -ge ($this.ScrollTop + $visibleHeight)) {
            $this.ScrollTop = $this.SelectedIndex - $visibleHeight + 1
        }
        $maxScroll = [Math]::Max(0, $this.FlatList.Count - $visibleHeight)
        $this.ScrollTop = [Math]::Max(0, [Math]::Min($this.ScrollTop, $maxScroll))
    }
    
    [void] SetStatusMessage([string]$message) {
        $this.StatusMessage = $message
        $this.StatusMessageTime = Get-Date
        # Optional: Log to debug file like TaskListScreen
        "DEBUG: ExcelMappingScreen Status: $message $(Get-Date)" | Out-File -FilePath "./startup-debug.log" -Append
    }
    
    # TaskListScreen-quality Excel operations with proper feedback
    [void] OpenExcelFile() {
        try {
            $sourceFolder = $this.MappingService.SourceFolder
            if ($sourceFolder -and (Test-Path $sourceFolder)) {
                # Open Excel file if available
                $excelFiles = Get-ChildItem -Path $sourceFolder -Filter "*.xlsx" | Select-Object -First 1
                if ($excelFiles) {
                    Start-Process $excelFiles.FullName
                    $this.SetStatusMessage("Opened Excel file: $($excelFiles.Name)")
                } else {
                    $this.SetStatusMessage("No Excel files found in: $sourceFolder")
                }
            } else {
                $this.SetStatusMessage("Source folder not configured. Use F4 to set path.")
            }
        } catch {
            $this.SetStatusMessage("Error opening Excel file: $_")
        }
    }
    
    [void] CopyExcelData() {
        $readyCount = ($this.MappingService.GetMappingsForExcelCopy()).Count
        $totalCount = $this.MappingService.Mappings.Count
        if ($readyCount -gt 0) {
            $this.SetStatusMessage("Ready to copy $readyCount/$totalCount mappings from Excel")
        } else {
            $this.SetStatusMessage("No mappings ready for Excel copy. Configure source cells first.")
        }
    }
    
    [void] ExportT2020Data() {
        $activeCount = ($this.MappingService.GetMappingsForT2020Export()).Count
        $totalCount = $this.MappingService.Mappings.Count
        if ($activeCount -gt 0) {
            $this.SetStatusMessage("Ready to export $activeCount/$totalCount mappings to T2020")
        } else {
            $this.SetStatusMessage("No mappings enabled for T2020 export. Use X to toggle inclusion.")
        }
    }
    
    [void] ConfigurePaths() {
        $this.SetStatusMessage("Path configuration not yet implemented. Use project settings.")
    }
}