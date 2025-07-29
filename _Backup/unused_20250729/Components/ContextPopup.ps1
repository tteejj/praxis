# ContextPopup.ps1 - Context-aware popup menu for quick actions

class ContextPopup : BaseDialog {
    [string[]]$MenuItems
    [int]$SelectedIndex = 0
    [scriptblock[]]$Actions
    [string]$Context
    [int]$SourceX
    [int]$SourceY
    
    ContextPopup([string]$context, [hashtable[]]$items) : base() {
        $this.Context = $context
        $this.MenuItems = @()
        $this.Actions = @()
        
        # Extract items and actions
        foreach ($item in $items) {
            $this.MenuItems += $item.Text
            $this.Actions += $item.Action
        }
        
        $this.Title = "Actions"
        $this.ShowBorder = $true
        $this.BorderType = [BorderType]::Single
    }
    
    [void] SetSourcePosition([int]$x, [int]$y) {
        $this.SourceX = $x
        $this.SourceY = $y
    }
    
    [void] OnInitialize() {
        ([BaseDialog]$this).OnInitialize()
        
        # Calculate popup size based on content
        $maxWidth = ($this.MenuItems | Measure-Object -Property Length -Maximum).Maximum + 4
        $height = $this.MenuItems.Count + 2  # +2 for borders
        
        # Position popup to the right of source position
        $popupX = [Math]::Min($this.SourceX + 2, [Console]::WindowWidth - $maxWidth - 1)
        $popupY = [Math]::Min($this.SourceY, [Console]::WindowHeight - $height - 1)
        
        # Ensure minimum bounds
        $popupX = [Math]::Max(0, $popupX)
        $popupY = [Math]::Max(0, $popupY)
        
        $this.SetBounds($popupX, $popupY, $maxWidth, $height)
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                $this.SelectedIndex = ($this.SelectedIndex - 1 + $this.MenuItems.Count) % $this.MenuItems.Count
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                $this.SelectedIndex = ($this.SelectedIndex + 1) % $this.MenuItems.Count
                $this.Invalidate()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Actions.Count) {
                    $action = $this.Actions[$this.SelectedIndex]
                    if ($action) {
                        & $action
                    }
                }
                $this.Close()
                return $true
            }
            ([System.ConsoleKey]::Escape) {
                $this.Close()
                return $true
            }
            ([System.ConsoleKey]::Spacebar) {
                # Close popup if Space pressed again
                $this.Close()
                return $true
            }
        }
        
        # Check for number key shortcuts (1-9)
        if ($key.KeyChar -ge '1' -and $key.KeyChar -le '9') {
            $index = [int]::Parse($key.KeyChar.ToString()) - 1
            if ($index -ge 0 -and $index -lt $this.Actions.Count) {
                $action = $this.Actions[$index]
                if ($action) {
                    & $action
                }
                $this.Close()
                return $true
            }
        }
        
        return ([BaseDialog]$this).HandleInput($key)
    }
    
    [string] OnRender() {
        if (-not $this.ThemeManager) { return "" }
        
        $theme = $this.ThemeManager.GetCurrentTheme()
        $sb = Get-PooledStringBuilder 512
        
        # Get colors
        $bgColor = $theme.GetColor("dialog.background")
        $fgColor = $theme.GetColor("dialog.foreground") 
        $selectedBg = $theme.GetColor("selection.background")
        $selectedFg = $theme.GetColor("selection.foreground")
        $borderColor = $theme.GetColor("dialog.border")
        
        # Draw border
        if ($this.ShowBorder) {
            # Top border
            $sb.Append([VT]::SetCursor($this.Y + 1, $this.X + 1))
            $sb.Append($borderColor)
            $sb.Append("┌")
            for ($i = 0; $i -lt $this.Width - 2; $i++) {
                $sb.Append("─")
            }
            $sb.Append("┐")
            
            # Bottom border  
            $sb.Append([VT]::SetCursor($this.Y + $this.Height, $this.X + 1))
            $sb.Append($borderColor)
            $sb.Append("└")
            for ($i = 0; $i -lt $this.Width - 2; $i++) {
                $sb.Append("─")
            }
            $sb.Append("┘")
        }
        
        # Draw menu items
        for ($i = 0; $i -lt $this.MenuItems.Count; $i++) {
            $item = $this.MenuItems[$i]
            $y = $this.Y + $i + 2  # +1 for 1-based, +1 for top border
            
            $sb.Append([VT]::SetCursor($y, $this.X + 1))
            
            if ($this.ShowBorder) {
                $sb.Append($borderColor)
                $sb.Append("│")
            }
            
            # Apply selection highlighting
            if ($i -eq $this.SelectedIndex) {
                $sb.Append($selectedBg)
                $sb.Append($selectedFg)
            } else {
                $sb.Append($bgColor)
                $sb.Append($fgColor)
            }
            
            # Add number prefix for quick selection
            $prefix = "$(($i + 1)) "
            $sb.Append($prefix)
            $sb.Append($item)
            
            # Pad to width
            $contentWidth = $this.Width - 2  # -2 for borders
            $usedWidth = $prefix.Length + $item.Length
            for ($j = $usedWidth; $j -lt $contentWidth; $j++) {
                $sb.Append(" ")
            }
            
            if ($this.ShowBorder) {
                $sb.Append($borderColor)
                $sb.Append("│")
            }
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] Close() {
        if ($global:ScreenManager) {
            $global:ScreenManager.Pop()
        }
    }
}