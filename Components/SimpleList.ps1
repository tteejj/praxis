# SimpleList.ps1 - A focused, simple list component for menus and basic selections
# Replaces the overly complex UnifiedList for simple menu scenarios

class SimpleList : FocusableComponent {
    # Core properties
    [System.Collections.Generic.List[object]]$Items
    [int]$SelectedIndex = 0
    [string]$Title = ""
    
    # Callbacks
    [scriptblock]$OnSelectionChanged = {}
    [scriptblock]$OnItemActivated = {}
    
    # Display options
    [scriptblock]$ItemFormatter = $null  # Custom formatter for items
    [bool]$ShowBorder = $true
    [bool]$ShowTitle = $true
    
    # Internal state
    hidden [int]$_scrollOffset = 0
    hidden [int]$_viewportHeight = 0
    hidden [hashtable]$_colors = @{}
    
    SimpleList() : base() {
        $this.Items = [System.Collections.Generic.List[object]]::new()
        $this.IsFocusable = $true
        $this.FocusStyle = 'border'
    }
    
    [void] OnInitialize() {
        ([FocusableComponent]$this).OnInitialize()
        
        # Get theme and subscribe to changes
        $theme = $this.ServiceContainer.GetService('ThemeManager')
        if ($theme) {
            $this.ApplyTheme()
            
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $list = $this
                $eventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $list.ApplyTheme()
                    $list.Invalidate()
                }.GetNewClosure())
            }
        }
    }
    
    [void] ApplyTheme() {
        $theme = $this.ServiceContainer.GetService('ThemeManager')
        if ($theme) {
            $this._colors = @{
                border = $theme.GetColor('border.normal')
                borderFocus = $theme.GetColor('border.focused')
                title = $theme.GetColor('text.title')
                text = $theme.GetColor('text.primary')
                selectedBg = $theme.GetBgColor('list.selected.background')
                selectedText = $theme.GetColor('list.selected.text')
                background = $theme.GetBgColor('surface.background')
            }
        }
    }
    
    [void] SetItems([array]$items) {
        $this.Items.Clear()
        if ($items) {
            foreach ($item in $items) {
                $this.Items.Add($item)
            }
        }
        
        # Adjust selection
        if ($this.Items.Count -eq 0) {
            $this.SelectedIndex = -1
        } elseif ($this.SelectedIndex -ge $this.Items.Count) {
            $this.SelectedIndex = $this.Items.Count - 1
        } elseif ($this.SelectedIndex -lt 0 -and $this.Items.Count -gt 0) {
            $this.SelectedIndex = 0
        }
        
        $this.Invalidate()
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] OnBoundsChanged() {
        ([FocusableComponent]$this).OnBoundsChanged()
        
        # Calculate viewport
        $contentPadding = if ($this.ShowBorder) { 2 } else { 0 }
        $titleSpace = if ($this.ShowTitle -and $this.Title) { 1 } else { 0 }
        $this._viewportHeight = $this.Height - $contentPadding - $titleSpace
        
        # Ensure selected item is visible
        $this.EnsureSelectedVisible()
    }
    
    [string] RenderContent() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Draw border
        if ($this.ShowBorder) {
            $borderColor = if ($this.IsFocused) { $this._colors.borderFocus } else { $this._colors.border }
            $this.RenderBorder($sb, $borderColor)
        }
        
        # Draw title
        if ($this.ShowTitle -and $this.Title) {
            $titleY = if ($this.ShowBorder) { $this.Y + 1 } else { $this.Y }
            $titleX = $this.X + [Math]::Max(2, ($this.Width - $this.Title.Length) / 2)
            [void]$sb.Append([VT]::MoveTo($titleX, $titleY))
            [void]$sb.Append($this._colors.title)
            [void]$sb.Append($this.Title)
        }
        
        # Draw items
        $this.RenderItems($sb)
        
        return $sb.ToString()
    }
    
    [void] RenderBorder([System.Text.StringBuilder]$sb, [string]$color) {
        if ($this.Width -lt 2 -or $this.Height -lt 2) { return }
        
        [void]$sb.Append($color)
        
        # Top border
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y))
        [void]$sb.Append("┌" + ("─" * ($this.Width - 2)) + "┐")
        
        # Side borders
        for ($i = 1; $i -lt ($this.Height - 1); $i++) {
            [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $i))
            [void]$sb.Append("│")
            [void]$sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y + $i))
            [void]$sb.Append("│")
        }
        
        # Bottom border
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        [void]$sb.Append("└" + ("─" * ($this.Width - 2)) + "┘")
    }
    
    [void] RenderItems([System.Text.StringBuilder]$sb) {
        if ($this.Items.Count -eq 0) {
            return
        }
        
        # Calculate content area
        $contentX = $this.X + $(if ($this.ShowBorder) { 1 } else { 0 })
        $contentY = $this.Y + $(if ($this.ShowBorder) { 1 } else { 0 })
        $contentWidth = $this.Width - $(if ($this.ShowBorder) { 2 } else { 0 })
        
        if ($this.ShowTitle -and $this.Title) {
            $contentY += 1
        }
        
        # Determine visible range
        $startIdx = $this._scrollOffset
        $endIdx = [Math]::Min($startIdx + $this._viewportHeight, $this.Items.Count)
        
        # Render visible items
        for ($i = $startIdx; $i -lt $endIdx; $i++) {
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            $rowY = $contentY + ($i - $startIdx)
            
            [void]$sb.Append([VT]::MoveTo($contentX, $rowY))
            
            # Apply selection highlighting
            if ($isSelected) {
                if ($this.IsFocused) {
                    [void]$sb.Append($this._colors.selectedBg)
                    [void]$sb.Append($this._colors.selectedText)
                    # Add arrow indicator for focused selection
                    [void]$sb.Append("▸ ")
                } else {
                    # Show selection even when not focused (dimmer)
                    if ($this._colors.background) { [void]$sb.Append($this._colors.background) }
                    [void]$sb.Append($this._colors.textSecondary)
                    [void]$sb.Append("  ")  # Space instead of arrow
                }
            } else {
                if ($this._colors.background) { [void]$sb.Append($this._colors.background) }
                [void]$sb.Append($this._colors.text)
                [void]$sb.Append("  ")  # Consistent spacing
            }
            
            # Format item text
            $itemText = if ($this.ItemFormatter) {
                & $this.ItemFormatter $item
            } else {
                $item.ToString()
            }
            
            # Truncate if needed (account for 2-char indicator)
            $availableWidth = $contentWidth - 2
            if ($itemText.Length -gt $availableWidth) {
                $itemText = $itemText.Substring(0, $availableWidth - 1) + "…"
            } else {
                $itemText = $itemText.PadRight($availableWidth)
            }
            
            [void]$sb.Append($itemText)
            
            # Reset colors
            [void]$sb.Append([VT]::Reset())
        }
    }
    
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        $handled = $false
        
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.EnsureSelectedVisible()
                    $this.Invalidate()
                    if ($this.OnSelectionChanged) {
                        & $this.OnSelectionChanged
                    }
                }
                $handled = $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
                    $this.SelectedIndex++
                    $this.EnsureSelectedVisible()
                    $this.Invalidate()
                    if ($this.OnSelectionChanged) {
                        & $this.OnSelectionChanged
                    }
                }
                $handled = $true
            }
            ([System.ConsoleKey]::Home) {
                if ($this.Items.Count -gt 0) {
                    $this.SelectedIndex = 0
                    $this.EnsureSelectedVisible()
                    $this.Invalidate()
                    if ($this.OnSelectionChanged) {
                        & $this.OnSelectionChanged
                    }
                }
                $handled = $true
            }
            ([System.ConsoleKey]::End) {
                if ($this.Items.Count -gt 0) {
                    $this.SelectedIndex = $this.Items.Count - 1
                    $this.EnsureSelectedVisible()
                    $this.Invalidate()
                    if ($this.OnSelectionChanged) {
                        & $this.OnSelectionChanged
                    }
                }
                $handled = $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.OnItemActivated -and $this.SelectedIndex -ge 0) {
                    $item = $this.GetSelectedItem()
                    if ($item) {
                        & $this.OnItemActivated $item
                    }
                }
                $handled = $true
            }
        }
        
        return $handled
    }
    
    [void] EnsureSelectedVisible() {
        if ($this.SelectedIndex -lt $this._scrollOffset) {
            $this._scrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this._scrollOffset + $this._viewportHeight)) {
            $this._scrollOffset = $this.SelectedIndex - $this._viewportHeight + 1
        }
        
        # Bounds check
        $this._scrollOffset = [Math]::Max(0, $this._scrollOffset)
        $maxScroll = [Math]::Max(0, $this.Items.Count - $this._viewportHeight)
        $this._scrollOffset = [Math]::Min($this._scrollOffset, $maxScroll)
    }
    
    [void] SelectItem([object]$item) {
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            if ($this.Items[$i] -eq $item) {
                $this.SelectedIndex = $i
                $this.EnsureSelectedVisible()
                $this.Invalidate()
                if ($this.OnSelectionChanged) {
                    & $this.OnSelectionChanged
                }
                break
            }
        }
    }
}