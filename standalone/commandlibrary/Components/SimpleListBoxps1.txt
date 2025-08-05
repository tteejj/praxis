# SimpleListBox.ps1 - Enhanced list component for CommandLibrary
# Based on SearchableListBox with TaskPro's pillbox selection and theming

class SimpleListBox {
    # Properties
    [int]$X = 0
    [int]$Y = 0
    [int]$Width = 80
    [int]$Height = 20
    [string]$Title = ""
    [bool]$ShowBorder = $true
    [string]$SearchPrompt = "Search..."
    
    # Data
    [System.Collections.ArrayList]$Items
    [System.Collections.ArrayList]$FilteredItems
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    
    # Search
    [string]$SearchText = ""
    [bool]$SearchMode = $false
    
    # Events
    [scriptblock]$OnSelectionChanged
    [scriptblock]$ItemRenderer
    [scriptblock]$SearchFilter
    
    # Visual enhancements
    [bool]$UsePillboxSelection = $true
    [string]$CurrentTheme = "default"
    
    SimpleListBox() {
        $this.Items = [System.Collections.ArrayList]::new()
        $this.FilteredItems = [System.Collections.ArrayList]::new()
        
        # Default item renderer
        $this.ItemRenderer = { param($item) return $item.ToString() }
        
        # Default search filter
        $this.SearchFilter = { 
            param($item, $query) 
            if ([string]::IsNullOrWhiteSpace($query)) { return $true }
            return $item.ToString().ToLower().Contains($query.ToLower())
        }
    }
    
    [void] SetBounds([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
    }
    
    [void] SetItems([array]$items) {
        $this.Items.Clear()
        $this.FilteredItems.Clear()
        
        foreach ($item in $items) {
            $this.Items.Add($item) | Out-Null
            $this.FilteredItems.Add($item) | Out-Null
        }
        
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
        $this.ApplyFilter()
    }
    
    [void] ApplyFilter() {
        $this.FilteredItems.Clear()
        
        foreach ($item in $this.Items) {
            if ($this.SearchFilter.Invoke($item, $this.SearchText)) {
                $this.FilteredItems.Add($item) | Out-Null
            }
        }
        
        # Adjust selection if needed
        if ($this.SelectedIndex -ge $this.FilteredItems.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FilteredItems.Count - 1)
        }
        
        $this.EnsureVisible()
    }
    
    [void] EnsureVisible() {
        $listHeight = $this.Height - 4  # Account for border and search
        
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this.ScrollOffset + $listHeight)) {
            $this.ScrollOffset = $this.SelectedIndex - $listHeight + 1
        }
        
        $this.ScrollOffset = [Math]::Max(0, [Math]::Min($this.ScrollOffset, $this.FilteredItems.Count - $listHeight))
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear area
        for ($localY = 0; $localY -lt $this.Height; $localY++) {
            [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $localY))
            [void]$sb.Append(" " * $this.Width)
        }
        
        $currentY = $this.Y
        
        # Title
        if (-not [string]::IsNullOrWhiteSpace($this.Title)) {
            [void]$sb.Append([VT]::MoveTo($this.X, $currentY))
            [void]$sb.Append([VT]::Bold() + $this.Title + [VT]::Reset())
            $currentY++
        }
        
        # Search box
        [void]$sb.Append([VT]::MoveTo($this.X, $currentY))
        if ($this.SearchMode) {
            [void]$sb.Append([VT]::Reverse())
            [void]$sb.Append("Search: $($this.SearchText)_")
            [void]$sb.Append([VT]::Reset())
        } else {
            [void]$sb.Append([VT]::Gray())
            [void]$sb.Append($this.SearchPrompt)
            [void]$sb.Append([VT]::Reset())
        }
        $currentY++
        
        # Separator
        if ($this.ShowBorder) {
            [void]$sb.Append([VT]::MoveTo($this.X, $currentY))
            [void]$sb.Append([VT]::BoxHorizontal() * $this.Width)
            $currentY++
        }
        
        # Items
        $listHeight = $this.Height - ($currentY - $this.Y) - 1
        $endIndex = [Math]::Min($this.ScrollOffset + $listHeight, $this.FilteredItems.Count)
        
        for ($i = $this.ScrollOffset; $i -lt $endIndex; $i++) {
            $item = $this.FilteredItems[$i]
            $isSelected = ($i -eq $this.SelectedIndex)
            
            [void]$sb.Append([VT]::MoveTo($this.X, $currentY))
            
            if ($isSelected) {
                [void]$sb.Append([VT]::Reverse())
            }
            
            $displayText = $this.ItemRenderer.Invoke($item)
            if ($displayText.Length -gt $this.Width) {
                $displayText = $displayText.Substring(0, $this.Width - 3) + "..."
            }
            
            [void]$sb.Append($displayText.PadRight($this.Width))
            
            if ($isSelected) {
                [void]$sb.Append([VT]::Reset())
            }
            
            $currentY++
        }
        
        # Status line
        $statusY = $this.Y + $this.Height - 1
        [void]$sb.Append([VT]::MoveTo($this.X, $statusY))
        [void]$sb.Append([VT]::Gray())
        
        if ($this.FilteredItems.Count -eq 0) {
            [void]$sb.Append("No items found")
        } else {
            $status = "[$($this.SelectedIndex + 1)/$($this.FilteredItems.Count)]"
            if ($this.FilteredItems.Count -ne $this.Items.Count) {
                $status += " (filtered from $($this.Items.Count))"
            }
            [void]$sb.Append($status)
        }
        [void]$sb.Append([VT]::Reset())
        
        return $sb.ToString()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($this.SearchMode) {
            return $this.HandleSearchInput($key)
        } else {
            return $this.HandleNavigationInput($key)
        }
    }
    
    [bool] HandleNavigationInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.EnsureVisible()
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt ($this.FilteredItems.Count - 1)) {
                    $this.SelectedIndex++
                    $this.EnsureVisible()
                }
                return $true
            }
            ([System.ConsoleKey]::PageUp) {
                $pageSize = $this.Height - 4
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
                $this.EnsureVisible()
                return $true
            }
            ([System.ConsoleKey]::PageDown) {
                $pageSize = $this.Height - 4
                $this.SelectedIndex = [Math]::Min($this.FilteredItems.Count - 1, $this.SelectedIndex + $pageSize)
                $this.EnsureVisible()
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $this.EnsureVisible()
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.SelectedIndex = $this.FilteredItems.Count - 1
                $this.EnsureVisible()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.OnSelectionChanged -and $this.FilteredItems.Count -gt 0) {
                    $this.OnSelectionChanged.Invoke($this.GetSelectedItem())
                }
                return $true
            }
            ([System.ConsoleKey]::F3) {
                $this.SearchMode = $true
                return $true
            }
        }
        
        # Check for character input to start search
        if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar)) {
            $this.SearchMode = $true
            $this.SearchText = $key.KeyChar
            $this.ApplyFilter()
            return $true
        }
        
        return $false
    }
    
    [bool] HandleSearchInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                $this.SearchMode = $false
                $this.SearchText = ""
                $this.ApplyFilter()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                $this.SearchMode = $false
                if ($this.OnSelectionChanged -and $this.FilteredItems.Count -gt 0) {
                    $this.OnSelectionChanged.Invoke($this.GetSelectedItem())
                }
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.SearchText.Length -gt 0) {
                    $this.SearchText = $this.SearchText.Substring(0, $this.SearchText.Length - 1)
                    $this.ApplyFilter()
                }
                return $true
            }
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $this.EnsureVisible()
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt ($this.FilteredItems.Count - 1)) {
                    $this.SelectedIndex++
                    $this.EnsureVisible()
                }
                return $true
            }
        }
        
        # Add character to search
        if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
            $this.SearchText += $key.KeyChar
            $this.ApplyFilter()
            return $true
        }
        
        return $false
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.FilteredItems.Count) {
            return $this.FilteredItems[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] SetSearchText([string]$text) {
        $this.SearchText = $text
        $this.ApplyFilter()
    }
}