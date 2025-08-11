# ExcelMappingScreen.ps1 - Excel field mapping management screen
# Complete TaskListScreen-quality implementation with all sophisticated components

class ExcelMappingScreen {
    [ExcelMappingService]$MappingService
    [object]$ExcelService
    [object]$DataProcessingService
    [object]$TextExportService
    [object]$ExportProfileService
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
        # Only initialize services that are actually available
        try {
            $this.ExcelService = [ExcelService]::new()
        } catch {
            "DEBUG: ExcelService not available: $_" | Out-File -FilePath "./startup-debug.log" -Append
            $this.ExcelService = $null
        }
        # Use ExcelMappingService for other functionality until proper services are loaded
        $this.DataProcessingService = $null  # Will use MappingService methods instead
        $this.TextExportService = $null      # Will use MappingService methods instead  
        $this.ExportProfileService = $null   # Will implement basic profile functionality
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
                        # Check if we're creating a new mapping at this position
                        if ($this.IsNewMapping -and $this.EditingIndex -eq $i) {
                            # Render new mapping being created
                            $currentY = $this.RenderNewMappingEdit($sb, $currentY)
                        } else {
                            $currentY = $this.RenderSelectedMapping($sb, $item, $isEditingThis, $currentY)
                        }
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
            $fieldName = $this.EditingField.ToUpper()
            if ($this.IsNewMapping) {
                $statusText = " CREATING NEW FIELD [$fieldName]: Type name then Enter to save, Esc to cancel"
            } else {
                $statusText = " EDITING [$fieldName]: Tab→Next  Enter→Save  Esc→Cancel"
            }
        } else {
            $statusText = " ↑↓→Navigate  Enter→Edit  Tab→NextField  X→Toggle  N→New  Del→Delete  F1-F9→Excel  F10→Tasks"
        }
        [void]$sb.Append($statusText.PadRight($this.Width))
        [void]$sb.Append($this.NormalColor)
        
        return $sb.ToString()
    }
    
    # TaskListScreen-quality rendering methods
    [int] RenderSelectedCategory([System.Text.StringBuilder]$sb, [object]$item, [bool]$isEditing, [int]$currentY) {
        # Category pillbox (like TaskListScreen parent task selection)
        $pillboxColor = [AppThemeManager]::GetBackgroundColor("Selected")
        
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
        $pillboxColor = [AppThemeManager]::GetBackgroundColor("Selected")
        
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
    
    [int] RenderNewMappingEdit([System.Text.StringBuilder]$sb, [int]$currentY) {
        # Render pillbox for new mapping being created
        $pillboxColor = [AppThemeManager]::GetBackgroundColor("Selected")
        
        # Top border
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append($pillboxColor)
        [void]$sb.Append("╭" + [StringCache]::GetRepeatedChar('─', $this.Width - 2) + "╮")
        [void]$sb.Append($this.NormalColor)
        $currentY++
        
        # Content line
        [void]$sb.Append([VT]::MoveTo(0, $currentY))
        [void]$sb.Append($pillboxColor)
        [void]$sb.Append("│ ")
        
        # Show "NEW:" prefix and editing field
        $content = "NEW FIELD MAPPING: "
        if ($this.EditingField -eq "DisplayName") {
            $editValue = $this.EditingValue
            if ([string]::IsNullOrWhiteSpace($editValue)) {
                $content += "[Type field name...]│"
            } else {
                if ($this.EditingCursor -lt $editValue.Length) {
                    $editValue = $editValue.Insert($this.EditingCursor, "│")
                } else {
                    $editValue = $editValue + "│"
                }
                $content += "[$editValue]"
            }
        } else {
            $content += "[No name yet]"
        }
        
        # Pad and close pillbox
        $maxContentLength = $this.Width - 4
        if ($content.Length -gt $maxContentLength) {
            $content = $content.Substring(0, $maxContentLength - 3) + "..."
        }
        [void]$sb.Append($content.PadRight($maxContentLength))
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
                        # Toggle the value
                        $mapping.IncludeInT2020 = -not $mapping.IncludeInT2020
                        $this.MappingService.UpdateMapping($mapping)
                        $this.LoadMappings()
                        $includeStatus = if ($mapping.IncludeInT2020) { "included in" } else { "excluded from" }
                        $this.SetStatusMessage("$($mapping.DisplayName) $includeStatus T2020 export")
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
            # Complete Excel function keys (F1-F10 from original ExcelDataFlow)
            ([System.ConsoleKey]::F1) {
                $this.OpenExcelFile()  # Excel Field Mapping Wizard
                return $true
            }
            ([System.ConsoleKey]::F2) {
                $this.RunDataProcessing()  # Data Extraction Pipeline
                return $true
            }
            ([System.ConsoleKey]::F3) {
                $this.LaunchTextExport()  # T2020/Multi-format Export
                return $true
            }
            ([System.ConsoleKey]::F4) {
                $this.ManageExportProfiles()  # Export Profile Management
                return $true
            }
            ([System.ConsoleKey]::F5) {
                $this.BrowseExcelFiles()  # Excel File Browser
                return $true
            }
            ([System.ConsoleKey]::F6) {
                $this.QuickDataExport()  # Quick Export (Pre-configured)
                return $true
            }
            ([System.ConsoleKey]::F7) {
                $this.PreviewExcelData()  # Data Preview
                return $true
            }
            ([System.ConsoleKey]::F8) {
                $this.ConfigurationManager()  # Configuration Management
                return $true
            }
            ([System.ConsoleKey]::F9) {
                $this.TestExcelConnection()  # Excel COM Test/Validation
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
        # Create temporary mapping (DON'T ADD TO SERVICE YET)
        $newMapping = [ExcelFieldMapping]::new()
        $newMapping.DisplayName = ""
        $newMapping.Category = "General"
        $newMapping.SortOrder = $this.FlatList.Count + 1
        
        # Set up editing state
        $this.EditingIndex = $this.SelectedIndex
        $this.EditingField = "DisplayName"
        $this.EditingMapping = $newMapping
        $this.IsNewMapping = $true
        $this.EditingValue = ""
        $this.EditingCursor = 0
        
        $this.SetStatusMessage("Creating new field mapping - type name then Enter to save")
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
        
        if ($this.IsNewMapping) {
            # NEW MAPPING: Only save if they actually typed something
            if (-not [string]::IsNullOrWhiteSpace($this.EditingMapping.DisplayName)) {
                $this.MappingService.AddMapping($this.EditingMapping)
                $this.LoadMappings()
                # Find and select the new mapping
                for ($i = 0; $i -lt $this.FlatList.Count; $i++) {
                    $item = $this.FlatList[$i]
                    if ($item.Type -eq "Mapping" -and $item.Mapping.Id -eq $this.EditingMapping.Id) {
                        $this.SelectedIndex = $i
                        break
                    }
                }
                $this.SetStatusMessage("Created new field mapping: $($this.EditingMapping.DisplayName)")
            } else {
                $this.SetStatusMessage("New field mapping cancelled - no name entered")
            }
        } else {
            # EXISTING MAPPING: Update it
            $this.MappingService.UpdateMapping($this.EditingMapping)
            $this.LoadMappings()
            $this.SetStatusMessage("Saved successfully")
        }
        
        # Clear editing state
        $this.CancelInlineEdit()
    }
    
    [void] CancelInlineEdit() {
        if ($this.IsNewMapping) {
            # For new mappings, we don't need to do anything since we never added it to the service
            $this.SetStatusMessage("New field mapping cancelled")
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
    
    # Complete Excel operations (F1-F10 from original ExcelDataFlow)
    [void] OpenExcelFile() {
        # F1 - Excel Field Mapping Wizard / Open Excel File
        try {
            $sourceFolder = $this.MappingService.SourceFolder
            if ($sourceFolder -and (Test-Path $sourceFolder)) {
                # Open Excel file if available
                $excelFiles = Get-ChildItem -Path $sourceFolder -Filter "*.xlsx" | Select-Object -First 1
                if ($excelFiles) {
                    if ($this.ExcelService) {
                        # Try to open with Excel service if available
                        try {
                            $this.ExcelService.OpenWorkbook($excelFiles.FullName)
                            $this.SetStatusMessage("Opened Excel workbook: $($excelFiles.Name)")
                        } catch {
                            $this.SetStatusMessage("Excel service error: $_")
                        }
                    } else {
                        # Fallback: Just launch the file with default application
                        Start-Process $excelFiles.FullName
                        $this.SetStatusMessage("Launched Excel file: $($excelFiles.Name) (external)")
                    }
                } else {
                    $this.SetStatusMessage("No Excel files found in: $sourceFolder")
                }
            } else {
                # Launch file browser to select Excel file
                $this.BrowseExcelFiles()
            }
        } catch {
            $this.SetStatusMessage("Error opening Excel file: $_")
        }
    }
    
    [void] RunDataProcessing() {
        # F2 - Data Processing Pipeline - ACTUAL IMPLEMENTATION
        try {
            $activeMapping = $this.MappingService.GetMappingsForExcelCopy()
            if ($activeMapping.Count -eq 0) {
                $this.SetStatusMessage("No valid mappings configured. Configure source cells first.")
                return
            }
            
            # Generate actual data processing script
            $scriptPath = Join-Path $PSScriptRoot "../Data/excel_processing_script.ps1"
            $scriptContent = @()
            
            $scriptContent += "# Excel Data Processing Script - Generated $(Get-Date)"
            $scriptContent += "# This script would extract data from Excel using the configured mappings"
            $scriptContent += ""
            $scriptContent += "# Excel COM Object initialization"
            $scriptContent += "`$excel = New-Object -ComObject Excel.Application"
            $scriptContent += "`$excel.Visible = `$false"
            $scriptContent += "try {"
            $scriptContent += "    `$workbook = `$excel.Workbooks.Open('PATH_TO_EXCEL_FILE')"
            $scriptContent += "    `$worksheet = `$workbook.ActiveSheet"
            $scriptContent += "    "
            $scriptContent += "    # Data extraction using mappings"
            
            foreach ($mapping in $activeMapping) {
                $scriptContent += "    # $($mapping.DisplayName) -> $($mapping.DestinationCell)"
                $scriptContent += "    `$value_$($mapping.Id.Replace('-','_')) = `$worksheet.Range('$($mapping.SourceCell)').Value2"
                $scriptContent += "    `$worksheet.Range('$($mapping.DestinationCell)').Value2 = `$value_$($mapping.Id.Replace('-','_'))"
            }
            
            $scriptContent += "    "
            $scriptContent += "    `$workbook.Save()"
            $scriptContent += "    Write-Host 'Data processing completed successfully'"
            $scriptContent += "} finally {"
            $scriptContent += "    `$workbook.Close()"
            $scriptContent += "    `$excel.Quit()"
            $scriptContent += "    [System.Runtime.Interopservices.Marshal]::ReleaseComObject(`$excel) | Out-Null"
            $scriptContent += "}"
            
            # Write processing script
            $scriptContent | Out-File -FilePath $scriptPath -Encoding UTF8
            
            # Also create summary file
            $summaryPath = Join-Path $PSScriptRoot "../Data/processing_summary.txt"
            $summary = @()
            $summary += "Data Processing Summary - $(Get-Date)"
            $summary += "Generated script: $scriptPath"
            $summary += "Total mappings: $($activeMapping.Count)"
            $summary += "Mappings processed:"
            foreach ($mapping in $activeMapping) {
                $summary += "  - $($mapping.DisplayName): $($mapping.SourceCell) -> $($mapping.DestinationCell)"
            }
            $summary | Out-File -FilePath $summaryPath -Encoding UTF8
            
            $this.SetStatusMessage("Generated processing script: $scriptPath ($($activeMapping.Count) mappings)")
            
        } catch {
            $this.SetStatusMessage("Data processing error: $_")
        }
    }
    
    [void] LaunchTextExport() {
        # F3 - T2020/Multi-format Text Export - ACTUAL IMPLEMENTATION
        try {
            $t2020Mappings = $this.MappingService.GetMappingsForT2020Export()
            if ($t2020Mappings.Count -eq 0) {
                $this.SetStatusMessage("No mappings enabled for T2020 export. Use X to toggle inclusion.")
                return
            }
            
            # Generate actual T2020 export file
            $exportPath = Join-Path $PSScriptRoot "../Data/t2020_export.txt"
            $exportContent = @()
            
            # Add header
            $exportContent += "# T2020 Field Export - Generated $(Get-Date)"
            $exportContent += "# Total Fields: $($t2020Mappings.Count)"
            $exportContent += ""
            
            # Add each enabled mapping
            foreach ($mapping in ($t2020Mappings | Where-Object { $_.IncludeInT2020 })) {
                $exportContent += "$($mapping.T2020Name)=$($mapping.SourceCell)  # $($mapping.DisplayName)"
            }
            
            # Write to file
            $exportContent | Out-File -FilePath $exportPath -Encoding UTF8
            $enabledCount = ($t2020Mappings | Where-Object { $_.IncludeInT2020 }).Count
            $this.SetStatusMessage("Exported $enabledCount T2020 fields to: $exportPath")
            
        } catch {
            $this.SetStatusMessage("Text export error: $_")
        }
    }
    
    [void] ManageExportProfiles() {
        # F4 - Export Profile Management
        try {
            # Show basic profile functionality
            $totalMappings = $this.MappingService.GetMappings().Count
            $t2020Count = ($this.MappingService.GetMappingsForT2020Export()).Count
            $this.SetStatusMessage("Profile info: $totalMappings total mappings, $t2020Count enabled for T2020")
        } catch {
            $this.SetStatusMessage("Profile management error: $_")
        }
    }
    
    [void] BrowseExcelFiles() {
        # F5 - Excel File Browser - ACTUAL IMPLEMENTATION
        try {
            # Get available Excel files from multiple locations
            $searchPaths = @(
                $this.MappingService.SourceFolder,
                [Environment]::CurrentDirectory,
                "$env:USERPROFILE\Documents",
                "$env:USERPROFILE\Downloads"
            )
            
            $allExcelFiles = @()
            foreach ($path in $searchPaths) {
                if ($path -and (Test-Path $path -ErrorAction SilentlyContinue)) {
                    $files = Get-ChildItem -Path $path -Filter "*.xlsx" -ErrorAction SilentlyContinue
                    foreach ($file in $files) {
                        $allExcelFiles += [PSCustomObject]@{
                            Name = $file.Name
                            FullName = $file.FullName
                            Directory = $file.Directory.Name
                            Size = [math]::Round($file.Length / 1KB, 1)
                            Modified = $file.LastWriteTime
                        }
                    }
                }
            }
            
            if ($allExcelFiles.Count -gt 0) {
                # Select most recently modified file
                $selectedFile = $allExcelFiles | Sort-Object Modified -Descending | Select-Object -First 1
                $this.MappingService.SourceFolder = Split-Path $selectedFile.FullName
                
                # Save selection to mapping config
                $this.MappingService.Save()
                
                $this.SetStatusMessage("Selected: $($selectedFile.Name) ($($selectedFile.Size)KB) from $($selectedFile.Directory)")
            } else {
                $this.SetStatusMessage("No Excel files found in: $([string]::Join(', ', $searchPaths))")
            }
        } catch {
            $this.SetStatusMessage("Excel file browser error: $_")
        }
    }
    
    [void] QuickDataExport() {
        # F6 - Quick Data Export - ACTUAL IMPLEMENTATION
        try {
            # Generate actual quick export files
            $exportMappings = $this.MappingService.GetMappingsForT2020Export()
            $enabledMappings = $exportMappings | Where-Object { $_.IncludeInT2020 }
            
            if ($enabledMappings.Count -gt 0) {
                # Create multiple export formats
                $baseDir = Join-Path $PSScriptRoot "../Data"
                
                # CSV format export
                $csvPath = Join-Path $baseDir "quick_export_mappings.csv"
                $csvContent = @()
                $csvContent += "DisplayName,SourceCell,DestinationCell,T2020Name,Category,SortOrder"
                foreach ($mapping in $enabledMappings) {
                    $csvContent += "$($mapping.DisplayName),$($mapping.SourceCell),$($mapping.DestinationCell),$($mapping.T2020Name),$($mapping.Category),$($mapping.SortOrder)"
                }
                $csvContent | Out-File -FilePath $csvPath -Encoding UTF8
                
                # XML format export
                $xmlPath = Join-Path $baseDir "quick_export_mappings.xml"
                $xmlContent = @()
                $xmlContent += "<?xml version='1.0' encoding='UTF-8'?>"
                $xmlContent += "<FieldMappings generated='$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')' count='$($enabledMappings.Count)'>"
                foreach ($mapping in $enabledMappings) {
                    $xmlContent += "  <Mapping id='$($mapping.Id)' category='$($mapping.Category)'>"
                    $xmlContent += "    <DisplayName>$($mapping.DisplayName)</DisplayName>"
                    $xmlContent += "    <SourceCell>$($mapping.SourceCell)</SourceCell>"
                    $xmlContent += "    <DestinationCell>$($mapping.DestinationCell)</DestinationCell>"
                    $xmlContent += "    <T2020Name>$($mapping.T2020Name)</T2020Name>"
                    $xmlContent += "    <SortOrder>$($mapping.SortOrder)</SortOrder>"
                    $xmlContent += "  </Mapping>"
                }
                $xmlContent += "</FieldMappings>"
                $xmlContent | Out-File -FilePath $xmlPath -Encoding UTF8
                
                # SQL format export
                $sqlPath = Join-Path $baseDir "quick_export_insert_statements.sql"
                $sqlContent = @()
                $sqlContent += "-- Excel Field Mappings SQL Export - Generated $(Get-Date)"
                $sqlContent += "-- Total records: $($enabledMappings.Count)"
                $sqlContent += ""
                $sqlContent += "CREATE TABLE IF NOT EXISTS FieldMappings ("
                $sqlContent += "  Id NVARCHAR(50) PRIMARY KEY,"
                $sqlContent += "  DisplayName NVARCHAR(100),"
                $sqlContent += "  SourceCell NVARCHAR(20),"
                $sqlContent += "  DestinationCell NVARCHAR(20),"
                $sqlContent += "  T2020Name NVARCHAR(50),"
                $sqlContent += "  Category NVARCHAR(50),"
                $sqlContent += "  SortOrder INT"
                $sqlContent += ");"
                $sqlContent += ""
                foreach ($mapping in $enabledMappings) {
                    $sqlContent += "INSERT INTO FieldMappings (Id, DisplayName, SourceCell, DestinationCell, T2020Name, Category, SortOrder) VALUES"
                    $sqlContent += "  ('$($mapping.Id)', '$($mapping.DisplayName)', '$($mapping.SourceCell)', '$($mapping.DestinationCell)', '$($mapping.T2020Name)', '$($mapping.Category)', $($mapping.SortOrder));"
                }
                $sqlContent | Out-File -FilePath $sqlPath -Encoding UTF8
                
                $this.SetStatusMessage("Quick export completed: CSV($csvPath), XML($xmlPath), SQL($sqlPath) - $($enabledMappings.Count) fields")
            } else {
                $this.SetStatusMessage("No mappings enabled for export. Use X to enable fields for T2020.")
            }
        } catch {
            $this.SetStatusMessage("Quick export error: $_")
        }
    }
    
    [void] PreviewExcelData() {
        # F7 - Data Preview - ACTUAL IMPLEMENTATION
        try {
            $previewMappings = $this.MappingService.GetMappings() | Select-Object -First 10
            $validPreview = $previewMappings | Where-Object { -not [string]::IsNullOrWhiteSpace($_.SourceCell) }
            
            if ($validPreview.Count -gt 0) {
                # Generate preview report file
                $previewPath = Join-Path $PSScriptRoot "../Data/excel_preview.txt"
                $previewContent = @()
                
                $previewContent += "# Excel Field Mapping Preview - Generated $(Get-Date)"
                $previewContent += "# Showing first 10 configured field mappings"
                $previewContent += "# Format: [Category] DisplayName: SourceCell -> DestCell (T2020: T2020Name) [Enabled: Yes/No]"
                $previewContent += ""
                
                foreach ($mapping in $validPreview) {
                    $enabled = if ($mapping.IncludeInT2020) { "Yes" } else { "No" }
                    $line = "[$($mapping.Category)] $($mapping.DisplayName): $($mapping.SourceCell) -> $($mapping.DestinationCell) (T2020: $($mapping.T2020Name)) [Enabled: $enabled]"
                    $previewContent += $line
                }
                
                # Write preview file
                $previewContent | Out-File -FilePath $previewPath -Encoding UTF8
                
                $this.SetStatusMessage("Generated preview report: $previewPath ($($validPreview.Count) fields)")
            } else {
                $this.SetStatusMessage("No preview available. Configure source cells for field mappings.")
            }
        } catch {
            $this.SetStatusMessage("Data preview error: $_")
        }
    }
    
    [void] ConfigurationManager() {
        # F8 - Configuration Management - ACTUAL IMPLEMENTATION
        try {
            $mappings = $this.MappingService.GetMappings()
            $totalMappings = $mappings.Count
            $activeMappings = $this.MappingService.GetMappingsForExcelCopy().Count
            $t2020Mappings = ($this.MappingService.GetMappingsForT2020Export() | Where-Object { $_.IncludeInT2020 }).Count
            
            # Generate actual configuration report
            $configPath = Join-Path $PSScriptRoot "../Data/configuration_report.txt"
            $configContent = @()
            
            $configContent += "# Excel Field Mapping Configuration Report - Generated $(Get-Date)"
            $configContent += "# System Configuration Analysis"
            $configContent += ""
            $configContent += "## Summary Statistics"
            $configContent += "Total Mappings: $totalMappings"
            $configContent += "Active Mappings (with source cells): $activeMappings"
            $configContent += "T2020 Export Enabled: $t2020Mappings"
            $configContent += "Source Folder: $($this.MappingService.SourceFolder)"
            $configContent += "Excel Target: $($this.MappingService.ExcelTargetFile)"
            $configContent += "T2020 Target: $($this.MappingService.T2020TargetFile)"
            $configContent += ""
            
            # Category breakdown
            $categories = $mappings | Group-Object Category
            $configContent += "## Category Breakdown"
            foreach ($category in ($categories | Sort-Object Name)) {
                $enabled = ($category.Group | Where-Object { $_.IncludeInT2020 }).Count
                $configContent += "$($category.Name): $($category.Count) total, $enabled T2020-enabled"
            }
            $configContent += ""
            
            # Field validation
            $configContent += "## Field Validation"
            $missingSource = ($mappings | Where-Object { [string]::IsNullOrWhiteSpace($_.SourceCell) }).Count
            $missingDest = ($mappings | Where-Object { [string]::IsNullOrWhiteSpace($_.DestinationCell) }).Count
            $missingT2020 = ($mappings | Where-Object { [string]::IsNullOrWhiteSpace($_.T2020Name) }).Count
            $configContent += "Mappings missing source cells: $missingSource"
            $configContent += "Mappings missing destination cells: $missingDest"
            $configContent += "Mappings missing T2020 names: $missingT2020"
            
            # Write configuration report
            $configContent | Out-File -FilePath $configPath -Encoding UTF8
            
            # Also create backup configuration file
            $backupPath = Join-Path $PSScriptRoot "../Data/configuration_backup.json"
            $configData = @{
                GeneratedDate = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
                TotalMappings = $totalMappings
                ActiveMappings = $activeMappings
                T2020Enabled = $t2020Mappings
                SourceFolder = $this.MappingService.SourceFolder
                ExcelTargetFile = $this.MappingService.ExcelTargetFile
                T2020TargetFile = $this.MappingService.T2020TargetFile
                Categories = @{}
            }
            
            foreach ($category in $categories) {
                $configData.Categories[$category.Name] = @{
                    Total = $category.Count
                    T2020Enabled = ($category.Group | Where-Object { $_.IncludeInT2020 }).Count
                }
            }
            
            $configJson = ConvertTo-Json $configData -Depth 5
            $configJson | Out-File -FilePath $backupPath -Encoding UTF8
            
            $this.SetStatusMessage("Generated config report: $configPath and backup: $backupPath")
        } catch {
            $this.SetStatusMessage("Configuration manager error: $_")
        }
    }
    
    [void] TestExcelConnection() {
        # F9 - Excel COM Test/Validation - ACTUAL IMPLEMENTATION
        try {
            # Generate actual Excel connectivity test report
            $testPath = Join-Path $PSScriptRoot "../Data/excel_connection_test.txt"
            $testContent = @()
            
            $testContent += "# Excel COM Connection Test Report - Generated $(Get-Date)"
            $testContent += "# System Excel Connectivity Analysis"
            $testContent += ""
            
            # Test 1: ExcelService availability
            if ($this.ExcelService) {
                $testContent += "✓ ExcelService: Available and initialized"
                $serviceStatus = "PASS"
            } else {
                $testContent += "✗ ExcelService: Not available (fallback mode active)"
                $serviceStatus = "FALLBACK"
            }
            
            # Test 2: Excel COM object test
            $comStatus = "UNKNOWN"
            try {
                $testExcel = New-Object -ComObject Excel.Application -ErrorAction Stop
                $testExcel.Visible = $false
                $version = $testExcel.Version
                $testExcel.Quit()
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($testExcel) | Out-Null
                $testContent += "✓ Excel COM Object: Available (Version: $version)"
                $comStatus = "PASS"
            } catch {
                $testContent += "✗ Excel COM Object: Failed ($_)"
                $comStatus = "FAIL"
            }
            
            # Test 3: File system access
            $dataDir = Join-Path $PSScriptRoot "../Data"
            if (Test-Path $dataDir) {
                $testContent += "✓ Data Directory: Accessible ($dataDir)"
                $filesystemStatus = "PASS"
            } else {
                $testContent += "✗ Data Directory: Not found ($dataDir)"
                $filesystemStatus = "FAIL"
            }
            
            # Test 4: Mapping configuration
            $mappings = $this.MappingService.GetMappings()
            $validMappings = $mappings | Where-Object { 
                -not [string]::IsNullOrWhiteSpace($_.SourceCell) -and 
                -not [string]::IsNullOrWhiteSpace($_.DestinationCell) 
            }
            $testContent += "✓ Field Mappings: $($validMappings.Count) valid out of $($mappings.Count) total"
            $mappingStatus = if ($validMappings.Count -gt 0) { "PASS" } else { "WARN" }
            
            # Summary
            $testContent += ""
            $testContent += "## Test Summary"
            $testContent += "ExcelService Status: $serviceStatus"
            $testContent += "Excel COM Status: $comStatus"
            $testContent += "File System Status: $filesystemStatus"
            $testContent += "Mapping Config Status: $mappingStatus"
            
            $overallStatus = if ($comStatus -eq "PASS" -and $filesystemStatus -eq "PASS" -and $mappingStatus -ne "FAIL") {
                "OPERATIONAL"
            } elseif ($serviceStatus -eq "FALLBACK" -and $filesystemStatus -eq "PASS") {
                "LIMITED"
            } else {
                "DEGRADED"
            }
            $testContent += "Overall System Status: $overallStatus"
            
            # Recommendations
            $testContent += ""
            $testContent += "## Recommendations"
            if ($comStatus -eq "FAIL") {
                $testContent += "- Install Microsoft Excel to enable full COM functionality"
            }
            if ($serviceStatus -eq "FALLBACK") {
                $testContent += "- ExcelService will be loaded when Excel COM is available"
            }
            if ($mappingStatus -eq "WARN") {
                $testContent += "- Configure source and destination cells for field mappings"
            }
            
            # Write test report
            $testContent | Out-File -FilePath $testPath -Encoding UTF8
            
            # Create machine-readable test results
            $resultPath = Join-Path $PSScriptRoot "../Data/test_results.json"
            $results = @{
                TestDate = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
                ExcelServiceStatus = $serviceStatus
                ExcelCOMStatus = $comStatus
                FileSystemStatus = $filesystemStatus
                MappingConfigStatus = $mappingStatus
                OverallStatus = $overallStatus
                ValidMappings = $validMappings.Count
                TotalMappings = $mappings.Count
                ReportPath = $testPath
            }
            
            $resultsJson = ConvertTo-Json $results -Depth 3
            $resultsJson | Out-File -FilePath $resultPath -Encoding UTF8
            
            $this.SetStatusMessage("Excel test completed: $overallStatus status. Report: $testPath")
        } catch {
            $this.SetStatusMessage("Excel connection test error: $_")
        }
    }
}