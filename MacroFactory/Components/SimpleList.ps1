# SimpleList.ps1 - Simple list component for MacroFactory

class SimpleList {
    [string]$Title = ""
    [System.Collections.ArrayList]$Items
    [int]$SelectedIndex = 0
    [int]$ScrollTop = 0
    [int]$X = 0
    [int]$Y = 0
    [int]$Width = 20
    [int]$Height = 10
    [scriptblock]$ItemRenderer = { param($item) $item.ToString() }
    
    # Colors
    [string]$BorderColor = "`e[38;2;100;150;255m"
    [string]$TitleColor = "`e[38;2;255;255;255m"
    [string]$ItemColor = "`e[38;2;200;200;200m"
    [string]$SelectedColor = "`e[48;2;45;45;55m"
    [string]$NormalColor = "`e[0m"
    
    SimpleList() {
        $this.Items = [System.Collections.ArrayList]::new()
    }
    
    [void] SetItems([object[]]$items) {
        $this.Items.Clear()
        foreach ($item in $items) {
            $this.Items.Add($item) | Out-Null
        }
        if ($this.SelectedIndex -ge $this.Items.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.Items.Count - 1)
        }
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] SetBounds([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Draw border
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($this.BorderColor)
        $sb.Append("╭" + ("─" * ($this.Width - 2)) + "╮")
        
        # Draw title if present
        if ($this.Title) {
            $titleText = " $($this.Title) "
            $titlePos = $this.X + [Math]::Floor(($this.Width - $titleText.Length) / 2)
            $sb.Append([VT]::MoveTo($titlePos, $this.Y))
            $sb.Append($this.TitleColor + $titleText + $this.BorderColor)
        }
        
        # Draw sides and content
        $contentHeight = $this.Height - 2
        $visibleItems = $this.GetVisibleItems()
        
        for ($i = 0; $i -lt $contentHeight; $i++) {
            $sb.Append([VT]::MoveTo($this.X, $this.Y + $i + 1))
            $sb.Append($this.BorderColor + "│" + $this.NormalColor)
            
            if ($i -lt $visibleItems.Count) {
                $itemIndex = $this.ScrollTop + $i
                $item = $visibleItems[$i]
                $text = & $this.ItemRenderer $item
                
                # Truncate if too long
                if ($text.Length -gt ($this.Width - 4)) {
                    $text = $text.Substring(0, $this.Width - 7) + "..."
                }
                
                # Apply selection highlight
                if ($itemIndex -eq $this.SelectedIndex) {
                    $sb.Append($this.SelectedColor)
                }
                
                $sb.Append(" " + $text.PadRight($this.Width - 3))
                $sb.Append($this.NormalColor)
            } else {
                $sb.Append(" " * ($this.Width - 2))
            }
            
            $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y + $i + 1))
            $sb.Append($this.BorderColor + "│" + $this.NormalColor)
        }
        
        # Draw bottom border
        $sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        $sb.Append($this.BorderColor)
        $sb.Append("╰" + ("─" * ($this.Width - 2)) + "╯")
        $sb.Append($this.NormalColor)
        
        return $sb.ToString()
    }
    
    [object[]] GetVisibleItems() {
        $contentHeight = $this.Height - 2
        $endIndex = [Math]::Min($this.ScrollTop + $contentHeight, $this.Items.Count)
        
        if ($this.ScrollTop -ge $this.Items.Count) {
            return @()
        }
        
        return $this.Items[$this.ScrollTop..($endIndex - 1)]
    }
    
    [void] MoveUp() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this.EnsureVisible()
        }
    }
    
    [void] MoveDown() {
        if ($this.SelectedIndex -lt ($this.Items.Count - 1)) {
            $this.SelectedIndex++
            $this.EnsureVisible()
        }
    }
    
    [void] EnsureVisible() {
        $contentHeight = $this.Height - 2
        
        if ($this.SelectedIndex -lt $this.ScrollTop) {
            $this.ScrollTop = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this.ScrollTop + $contentHeight)) {
            $this.ScrollTop = $this.SelectedIndex - $contentHeight + 1
        }
    }
}