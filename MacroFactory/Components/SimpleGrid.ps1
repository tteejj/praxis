# SimpleGrid.ps1 - Simple data grid component for MacroFactory

class SimpleGrid {
    [string]$Title = ""
    [hashtable[]]$Columns = @()
    [hashtable[]]$Rows = @()
    [int]$SelectedIndex = 0
    [int]$ScrollTop = 0
    [int]$X = 0
    [int]$Y = 0
    [int]$Width = 50
    [int]$Height = 10
    
    # Colors
    [string]$BorderColor = "`e[38;2;100;150;255m"
    [string]$TitleColor = "`e[38;2;255;255;255m"
    [string]$HeaderColor = "`e[38;2;150;150;255m"
    [string]$ItemColor = "`e[38;2;200;200;200m"
    [string]$SelectedColor = "`e[48;2;45;45;55m"
    [string]$NormalColor = "`e[0m"
    
    [void] SetColumns([hashtable[]]$columns) {
        $this.Columns = $columns
    }
    
    [void] SetRows([hashtable[]]$rows) {
        $this.Rows = $rows
        if ($this.SelectedIndex -ge $this.Rows.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.Rows.Count - 1)
        }
    }
    
    [void] SetBounds([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Draw top border
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
        
        $currentY = $this.Y + 1
        
        # Draw header row
        $sb.Append([VT]::MoveTo($this.X, $currentY))
        $sb.Append($this.BorderColor + "│" + $this.HeaderColor)
        
        $headerText = ""
        foreach ($col in $this.Columns) {
            $colText = $col.Name
            if ($colText.Length -gt $col.Width) {
                $colText = $colText.Substring(0, $col.Width - 1)
            }
            $headerText += $colText.PadRight($col.Width)
        }
        
        # Truncate header if too wide
        if ($headerText.Length -gt ($this.Width - 3)) {
            $headerText = $headerText.Substring(0, $this.Width - 3)
        }
        
        $sb.Append(" " + $headerText.PadRight($this.Width - 3))
        $sb.Append($this.NormalColor)
        $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $currentY))
        $sb.Append($this.BorderColor + "│")
        $currentY++
        
        # Draw separator line
        $sb.Append([VT]::MoveTo($this.X, $currentY))
        $sb.Append($this.BorderColor + "├" + ("─" * ($this.Width - 2)) + "┤")
        $currentY++
        
        # Draw data rows
        $contentHeight = $this.Height - 4  # Top border, header, separator, bottom border
        $visibleRows = $this.GetVisibleRows()
        
        for ($i = 0; $i -lt $contentHeight; $i++) {
            $sb.Append([VT]::MoveTo($this.X, $currentY))
            $sb.Append($this.BorderColor + "│" + $this.NormalColor)
            
            if ($i -lt $visibleRows.Count) {
                $rowIndex = $this.ScrollTop + $i
                $row = $visibleRows[$i]
                
                # Apply selection highlight
                if ($rowIndex -eq $this.SelectedIndex) {
                    $sb.Append($this.SelectedColor)
                }
                
                $rowText = ""
                foreach ($col in $this.Columns) {
                    $value = $row[$col.Name]
                    if ($null -eq $value) { $value = "" }
                    $cellText = $value.ToString()
                    
                    # Apply formatter if present
                    if ($col.Formatter) {
                        $cellText = & $col.Formatter $value
                    }
                    
                    # Remove ANSI codes for length calculation
                    $plainText = $cellText -replace '\e\[[0-9;]*m', ''
                    
                    if ($plainText.Length -gt $col.Width) {
                        $plainText = $plainText.Substring(0, $col.Width - 1)
                        $cellText = $plainText
                    }
                    
                    $rowText += $cellText + (" " * ($col.Width - $plainText.Length))
                }
                
                # Truncate row if too wide
                $plainRowText = $rowText -replace '\e\[[0-9;]*m', ''
                if ($plainRowText.Length -gt ($this.Width - 3)) {
                    $rowText = $rowText.Substring(0, $this.Width - 3)
                }
                
                $sb.Append(" " + $rowText.PadRight($this.Width - 3))
                $sb.Append($this.NormalColor)
            } else {
                $sb.Append(" " * ($this.Width - 2))
            }
            
            $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $currentY))
            $sb.Append($this.BorderColor + "│" + $this.NormalColor)
            $currentY++
        }
        
        # Draw bottom border
        $sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        $sb.Append($this.BorderColor)
        $sb.Append("╰" + ("─" * ($this.Width - 2)) + "╯")
        $sb.Append($this.NormalColor)
        
        return $sb.ToString()
    }
    
    [hashtable[]] GetVisibleRows() {
        $contentHeight = $this.Height - 4
        $endIndex = [Math]::Min($this.ScrollTop + $contentHeight, $this.Rows.Count)
        
        if ($this.ScrollTop -ge $this.Rows.Count) {
            return @()
        }
        
        return $this.Rows[$this.ScrollTop..($endIndex - 1)]
    }
    
    [void] MoveUp() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this.EnsureVisible()
        }
    }
    
    [void] MoveDown() {
        if ($this.SelectedIndex -lt ($this.Rows.Count - 1)) {
            $this.SelectedIndex++
            $this.EnsureVisible()
        }
    }
    
    [void] EnsureVisible() {
        $contentHeight = $this.Height - 4
        
        if ($this.SelectedIndex -lt $this.ScrollTop) {
            $this.ScrollTop = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge ($this.ScrollTop + $contentHeight)) {
            $this.ScrollTop = $this.SelectedIndex - $contentHeight + 1
        }
    }
}