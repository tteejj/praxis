# MultiSelectListBox.ps1 - ListBox with multiple selection support
# Supports checkboxes, range selection, and bulk operations

class MultiSelectListBox : UIElement {
    [System.Collections.ArrayList]$Items
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$ShowBorder = $true
    [string]$Title = ""
    [scriptblock]$ItemRenderer = $null
    [scriptblock]$OnSelectionChanged = {}
    
    # Multi-selection settings
    [System.Collections.Generic.HashSet[int]]$SelectedIndices
    [bool]$ShowCheckboxes = $true
    [bool]$AllowRangeSelection = $true
    [bool]$AllowToggleAll = $true
    
    # Visual indicators
    [char]$CheckedIcon = [char]0x2611    # ☑
    [char]$UncheckedIcon = [char]0x2610  # ☐
    [char]$PartialIcon = [char]0x2612    # ☒
    
    # Selection state tracking
    hidden [int]$_lastSelectedIndex = -1  # For range selection
    hidden [bool]$_allSelected = $false
    hidden [ThemeManager]$Theme
    hidden [string]$_cachedRender = ""
    
    MultiSelectListBox() : base() {
        $this.Items = [System.Collections.ArrayList]::new()
        $this.SelectedIndices = [System.Collections.Generic.HashSet[int]]::new()
        $this.IsFocusable = $true
    }
    
    [void] Initialize([ServiceContainer]$services) {
        $this.Theme = $services.GetService("ThemeManager")
        if ($this.Theme) {
            $this.Theme.Subscribe({ $this.OnThemeChanged() })
            $this.OnThemeChanged()
        }
    }
    
    [void] OnThemeChanged() {
        $this._cachedRender = ""
        $this.Invalidate()
    }
    
    [void] Invalidate() {
        $this._cachedRender = ""
        ([UIElement]$this).Invalidate()
    }
    
    # Public API
    [void] SetItems($items) {
        $this.Items.Clear()
        $this.SelectedIndices.Clear()
        if ($items) {
            foreach ($item in $items) {
                $this.Items.Add($item) | Out-Null
            }
        }
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
        $this._lastSelectedIndex = -1
        $this._allSelected = $false
        $this.Invalidate()
    }
    
    [void] AddItem($item) {
        $this.Items.Add($item) | Out-Null
        $this.Invalidate()
    }
    
    [void] RemoveItem($item) {
        $indexToRemove = -1
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            if ($this.Items[$i] -eq $item) {
                $indexToRemove = $i
                break
            }
        }
        
        if ($indexToRemove -ge 0) {
            $this.RemoveItemAt($indexToRemove)
        }
    }
    
    [void] RemoveItemAt([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Items.Count) {
            $this.Items.RemoveAt($index)
            
            # Update selected indices
            $newSelectedIndices = [System.Collections.Generic.HashSet[int]]::new()
            foreach ($selectedIndex in $this.SelectedIndices) {
                if ($selectedIndex -lt $index) {
                    $newSelectedIndices.Add($selectedIndex) | Out-Null
                } elseif ($selectedIndex -gt $index) {
                    $newSelectedIndices.Add($selectedIndex - 1) | Out-Null
                }
                # Skip the removed index
            }
            $this.SelectedIndices = $newSelectedIndices
            
            # Update current selection
            if ($this.SelectedIndex -eq $index) {
                $this.SelectedIndex = [Math]::Min($index, $this.Items.Count - 1)
            } elseif ($this.SelectedIndex -gt $index) {
                $this.SelectedIndex--
            }
            
            $this.EnsureSelectionValid()
            $this.UpdateAllSelectedState()
            $this.Invalidate()
        }
    }
    
    # Selection management
    [bool] IsSelected([int]$index) {
        return $this.SelectedIndices.Contains($index)
    }
    
    [void] SetSelected([int]$index, [bool]$selected) {
        if ($index -ge 0 -and $index -lt $this.Items.Count) {
            if ($selected) {
                $this.SelectedIndices.Add($index) | Out-Null
            } else {
                $this.SelectedIndices.Remove($index) | Out-Null
            }
            $this.UpdateAllSelectedState()
            $this.FireSelectionChanged()
        }
    }
    
    [void] ToggleSelected([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Items.Count) {
            if ($this.IsSelected($index)) {
                $this.SelectedIndices.Remove($index) | Out-Null
            } else {
                $this.SelectedIndices.Add($index) | Out-Null
            }
            $this.UpdateAllSelectedState()
            $this.FireSelectionChanged()
        }
    }
    
    [void] SelectRange([int]$startIndex, [int]$endIndex) {
        if (-not $this.AllowRangeSelection) {
            return
        }
        
        $start = [Math]::Min($startIndex, $endIndex)
        $end = [Math]::Max($startIndex, $endIndex)
        
        for ($i = $start; $i -le $end -and $i -lt $this.Items.Count; $i++) {
            $this.SelectedIndices.Add($i) | Out-Null
        }
        
        $this.UpdateAllSelectedState()
        $this.FireSelectionChanged()
    }
    
    [void] SelectAll() {
        $this.SelectedIndices.Clear()
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            $this.SelectedIndices.Add($i) | Out-Null
        }
        $this._allSelected = $true
        $this.FireSelectionChanged()
    }
    
    [void] SelectNone() {
        $this.SelectedIndices.Clear()
        $this._allSelected = $false
        $this.FireSelectionChanged()
    }
    
    [void] InvertSelection() {
        $newSelected = [System.Collections.Generic.HashSet[int]]::new()
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            if (-not $this.IsSelected($i)) {
                $newSelected.Add($i) | Out-Null
            }
        }
        $this.SelectedIndices = $newSelected
        $this.UpdateAllSelectedState()
        $this.FireSelectionChanged()
    }
    
    [System.Collections.ArrayList] GetSelectedItems() {
        $selectedItems = [System.Collections.ArrayList]::new()
        foreach ($index in $this.SelectedIndices) {
            if ($index -ge 0 -and $index -lt $this.Items.Count) {
                $selectedItems.Add($this.Items[$index]) | Out-Null
            }
        }
        return $selectedItems
    }
    
    [System.Collections.Generic.List[int]] GetSelectedIndicesList() {
        $result = [System.Collections.Generic.List[int]]::new()
        $sortedIndices = $this.SelectedIndices | Sort-Object
        foreach ($index in $sortedIndices) {
            $result.Add($index)
        }
        return $result
    }
    
    [int] GetSelectedCount() {
        return $this.SelectedIndices.Count
    }
    
    # Navigation
    [void] SelectIndex([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Items.Count) {
            $this.SelectedIndex = $index
            $this.EnsureVisible()
            $this.Invalidate()
        }
    }
    
    # Internal methods
    [void] UpdateAllSelectedState() {
        $this._allSelected = ($this.SelectedIndices.Count -eq $this.Items.Count -and $this.Items.Count -gt 0)
    }
    
    [void] EnsureSelectionValid() {
        if ($this.SelectedIndex -ge $this.Items.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.Items.Count - 1)
        }
        if ($this.SelectedIndex -lt 0 -and $this.Items.Count -gt 0) {
            $this.SelectedIndex = 0
        }
    }
    
    [void] EnsureVisible() {
        $visibleLines = $this.Height - ($this.ShowBorder ? 2 : 0) - ($this.Title ? 1 : 0)
        
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $visibleLines) {
            $this.ScrollOffset = $this.SelectedIndex - $visibleLines + 1
        }
        
        $this.ScrollOffset = [Math]::Max(0, $this.ScrollOffset)
    }
    
    [void] FireSelectionChanged() {
        if ($this.OnSelectionChanged) {
            & $this.OnSelectionChanged
        }
        $this.Invalidate()
    }
    
    # Rendering
    [string] OnRender() {
        if ([string]::IsNullOrEmpty($this._cachedRender)) {
            $this.RebuildCache()
        }
        return $this._cachedRender
    }
    
    [void] RebuildCache() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Colors
        $borderColor = if ($this.Theme) { $this.Theme.GetColor("border") } else { "" }
        $titleColor = if ($this.Theme) { $this.Theme.GetColor("title") } else { "" }
        $selectedBg = if ($this.Theme) { $this.Theme.GetBgColor("selected") } else { "" }
        $normalColor = if ($this.Theme) { $this.Theme.GetColor("normal") } else { "" }
        $checkboxColor = if ($this.Theme) { $this.Theme.GetColor("checkbox") } else { $normalColor }
        $selectedCheckboxColor = if ($this.Theme) { $this.Theme.GetColor("checkbox.selected") } else { "`e[38;2;0;255;0m" }
        $focusBorder = if ($this.Theme) { $this.Theme.GetColor("border.focused") } else { $borderColor }
        
        $currentBorderColor = if ($this.IsFocused) { $focusBorder } else { $borderColor }
        
        # Calculate content area
        $contentY = $this.Y
        $contentHeight = $this.Height
        $contentWidth = $this.Width - ($this.ShowBorder ? 2 : 0)
        
        if ($this.ShowBorder) {
            # Top border
            $sb.Append([VT]::MoveTo($this.X, $this.Y))
            $sb.Append($currentBorderColor)
            $sb.Append([VT]::TL() + ([VT]::H() * ($this.Width - 2)) + [VT]::TR())
            $contentY++
            $contentHeight--
            
            # Title with selection info
            if ($this.Title) {
                $sb.Append([VT]::MoveTo($this.X + 1, $contentY))
                $sb.Append($titleColor)
                
                $selectionInfo = ""
                if ($this.SelectedIndices.Count -gt 0) {
                    $selectionInfo = " ($($this.SelectedIndices.Count) selected)"
                }
                $titleText = "$($this.Title)$selectionInfo"
                $titleLine = $titleText.PadRight($contentWidth).Substring(0, $contentWidth)
                $sb.Append($titleLine)
                $contentY++
                $contentHeight--
            }
        } else {
            # Title without border
            if ($this.Title) {
                $sb.Append([VT]::MoveTo($this.X, $contentY))
                $sb.Append($titleColor)
                
                $selectionInfo = ""
                if ($this.SelectedIndices.Count -gt 0) {
                    $selectionInfo = " ($($this.SelectedIndices.Count) selected)"
                }
                $titleText = "$($this.Title)$selectionInfo"
                $titleLine = $titleText.PadRight($this.Width).Substring(0, $this.Width)
                $sb.Append($titleLine)
                $contentY++
                $contentHeight--
            }
        }
        
        # List content
        $visibleLines = $contentHeight - ($this.ShowBorder ? 1 : 0)  # Reserve bottom border
        $startIndex = $this.ScrollOffset
        $endIndex = [Math]::Min($startIndex + $visibleLines, $this.Items.Count)
        
        for ($i = $startIndex; $i -lt $endIndex; $i++) {
            $item = $this.Items[$i]
            $y = $contentY + ($i - $startIndex)
            $isCurrentSelection = ($i -eq $this.SelectedIndex)
            $isSelected = $this.IsSelected($i)
            
            $sb.Append([VT]::MoveTo($this.X + ($this.ShowBorder ? 1 : 0), $y))
            
            # Background for current item
            if ($isCurrentSelection) {
                $sb.Append($selectedBg)
            } else {
                $sb.Append($normalColor)
            }
            
            # Build display line
            $line = ""
            
            # Checkbox
            if ($this.ShowCheckboxes) {
                $checkboxIcon = if ($isSelected) { $this.CheckedIcon } else { $this.UncheckedIcon }
                $checkboxColorToUse = if ($isSelected) { $selectedCheckboxColor } else { $checkboxColor }
                
                $line += "$checkboxIcon "
            }
            
            # Item content
            $itemText = if ($this.ItemRenderer) {
                & $this.ItemRenderer $item
            } else {
                if ($item -eq $null) {
                    "<null>"
                } else {
                    $item.ToString()
                }
            }
            
            $line += $itemText
            
            # Adjust content width for checkbox
            $availableWidth = if ($this.ShowCheckboxes) { $contentWidth - 2 } else { $contentWidth }
            
            # Truncate if too long
            if ($line.Length -gt $availableWidth) {
                $line = $line.Substring(0, $availableWidth - 3) + "..."
            }
            
            # Pad to full width
            $line = $line.PadRight($contentWidth).Substring(0, $contentWidth)
            $sb.Append($line)
            
            # Side borders
            if ($this.ShowBorder) {
                $sb.Append([VT]::MoveTo($this.X, $y))
                $sb.Append($currentBorderColor)
                $sb.Append([VT]::V())
                
                $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $y))
                $sb.Append($currentBorderColor)
                $sb.Append([VT]::V())
            }
        }
        
        # Fill empty lines
        for ($i = $endIndex - $startIndex; $i -lt $visibleLines; $i++) {
            $y = $contentY + $i
            $sb.Append([VT]::MoveTo($this.X + ($this.ShowBorder ? 1 : 0), $y))
            $sb.Append($normalColor)
            $sb.Append(" ".PadRight($contentWidth))
            
            if ($this.ShowBorder) {
                $sb.Append([VT]::MoveTo($this.X, $y))
                $sb.Append($currentBorderColor)
                $sb.Append([VT]::V())
                
                $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $y))
                $sb.Append($currentBorderColor)
                $sb.Append([VT]::V())
            }
        }
        
        if ($this.ShowBorder) {
            # Bottom border
            $bottomY = $this.Y + $this.Height - 1
            $sb.Append([VT]::MoveTo($this.X, $bottomY))
            $sb.Append($currentBorderColor)
            $sb.Append([VT]::BL() + ([VT]::H() * ($this.Width - 2)) + [VT]::BR())
        }
        
        $sb.Append([VT]::Reset())
        $this._cachedRender = $sb.ToString()
    }
    
    # Input handling
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        $handled = $false
        $oldSelectedIndex = $this.SelectedIndex
        
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    
                    # Shift+Up for range selection
                    if (($key.Modifiers -band [System.ConsoleModifiers]::Shift) -and $this.AllowRangeSelection) {
                        if ($this._lastSelectedIndex -ge 0) {
                            $this.SelectRange($this._lastSelectedIndex, $this.SelectedIndex)
                        } else {
                            $this.SetSelected($this.SelectedIndex, $true)
                        }
                    }
                    
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                    $this.SelectedIndex++
                    
                    # Shift+Down for range selection
                    if (($key.Modifiers -band [System.ConsoleModifiers]::Shift) -and $this.AllowRangeSelection) {
                        if ($this._lastSelectedIndex -ge 0) {
                            $this.SelectRange($this._lastSelectedIndex, $this.SelectedIndex)
                        } else {
                            $this.SetSelected($this.SelectedIndex, $true)
                        }
                    }
                    
                    $handled = $true
                }
            }
            ([System.ConsoleKey]::PageUp) {
                $pageSize = $this.Height - 3
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
                $handled = $true
            }
            ([System.ConsoleKey]::PageDown) {
                $pageSize = $this.Height - 3
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $pageSize)
                $handled = $true
            }
            ([System.ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $handled = $true
            }
            ([System.ConsoleKey]::End) {
                $this.SelectedIndex = [Math]::Max(0, $this.Items.Count - 1)
                $handled = $true
            }
            ([System.ConsoleKey]::Spacebar) {
                # Toggle selection of current item
                $this.ToggleSelected($this.SelectedIndex)
                $this._lastSelectedIndex = $this.SelectedIndex
                $handled = $true
            }
            ([System.ConsoleKey]::Enter) {
                # Toggle selection and move down
                $this.ToggleSelected($this.SelectedIndex)
                if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                    $this.SelectedIndex++
                }
                $this._lastSelectedIndex = $this.SelectedIndex - 1
                $handled = $true
            }
        }
        
        # Keyboard shortcuts
        if (($key.Modifiers -band [System.ConsoleModifiers]::Control)) {
            switch ($key.Key) {
                ([System.ConsoleKey]::A) {
                    if ($this.AllowToggleAll) {
                        if ($this._allSelected) {
                            $this.SelectNone()
                        } else {
                            $this.SelectAll()
                        }
                    }
                    $handled = $true
                }
                ([System.ConsoleKey]::I) {
                    $this.InvertSelection()
                    $handled = $true
                }
                ([System.ConsoleKey]::D) {
                    $this.SelectNone()
                    $handled = $true
                }
            }
        }
        
        if ($handled) {
            $this.EnsureVisible()
            $this.Invalidate()
            
            # Update last selected index for range operations
            if (-not ($key.Modifiers -band [System.ConsoleModifiers]::Shift)) {
                $this._lastSelectedIndex = $this.SelectedIndex
            }
        }
        
        return $handled
    }
    
    [void] OnGotFocus() {
        $this._cachedRender = ""
        $this.Invalidate()
    }
    
    [void] OnLostFocus() {
        $this._cachedRender = ""
        $this.Invalidate()
    }
}