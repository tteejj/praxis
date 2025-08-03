# MacroSelectionDialog.ps1 - Dialog for selecting a saved macro

class MacroSelectionDialog {
    [hashtable[]]$Macros
    [SimpleList]$MacroList
    [hashtable]$SelectedMacro = $null
    [bool]$IsActive = $true
    [string]$Result = $null
    [int]$Width = 70
    [int]$Height = 20
    
    # Colors
    [string]$BorderColor = "`e[38;2;100;150;255m"
    [string]$TitleColor = "`e[38;2;255;255;255m"
    [string]$NormalColor = "`e[0m"
    
    MacroSelectionDialog([hashtable[]]$macros) {
        $this.Macros = $macros
        
        # Create list component
        $this.MacroList = [SimpleList]::new()
        $this.MacroList.Title = "Available Macros"
        $this.MacroList.ItemRenderer = {
            param($macro)
            $desc = if ($macro.Description) { " - $($macro.Description)" } else { "" }
            return "$($macro.Name)$desc"
        }
        $this.MacroList.SetItems($this.Macros)
    }
    
    [void] Show() {
        [Console]::CursorVisible = $false
        
        # Calculate position
        $screenWidth = [Console]::WindowWidth
        $screenHeight = [Console]::WindowHeight
        $x = [Math]::Floor(($screenWidth - $this.Width) / 2)
        $y = [Math]::Floor(($screenHeight - $this.Height) / 2)
        
        # Set list bounds
        $this.MacroList.SetBounds($x + 2, $y + 2, $this.Width - 4, $this.Height - 6)
        
        while ($this.IsActive) {
            $this.Draw($x, $y)
            
            $key = [Console]::ReadKey($true)
            $this.HandleInput($key)
        }
    }
    
    [void] Draw([int]$x, [int]$y) {
        $sb = [System.Text.StringBuilder]::new()
        
        # Draw background
        for ($i = 0; $i -lt $this.Height; $i++) {
            $sb.Append([VT]::MoveTo($x, $y + $i))
            $sb.Append("`e[48;2;30;30;40m" + (" " * $this.Width))
        }
        
        # Draw border
        $sb.Append([VT]::MoveTo($x, $y))
        $sb.Append($this.BorderColor)
        $sb.Append("╭" + ("─" * ($this.Width - 2)) + "╮")
        
        # Draw title
        $titleText = " Open Macro "
        $titlePos = $x + [Math]::Floor(($this.Width - $titleText.Length) / 2)
        $sb.Append([VT]::MoveTo($titlePos, $y))
        $sb.Append($this.TitleColor + $titleText + $this.BorderColor)
        
        # Draw sides
        for ($i = 1; $i -lt ($this.Height - 1); $i++) {
            $sb.Append([VT]::MoveTo($x, $y + $i))
            $sb.Append($this.BorderColor + "│" + $this.NormalColor)
            $sb.Append([VT]::MoveTo($x + $this.Width - 1, $y + $i))
            $sb.Append($this.BorderColor + "│")
        }
        
        # Draw list
        Write-Host -NoNewline $sb.ToString()
        Write-Host -NoNewline $this.MacroList.Render()
        
        # Draw instructions
        $sb = [System.Text.StringBuilder]::new()
        $sb.Append([VT]::MoveTo($x, $y + $this.Height - 3))
        $sb.Append($this.BorderColor + "├" + ("─" * ($this.Width - 2)) + "┤")
        
        $sb.Append([VT]::MoveTo($x + 2, $y + $this.Height - 2))
        $sb.Append("`e[38;2;150;150;150m↑↓:Navigate | Enter:Open | Escape:Cancel`e[0m")
        
        # Draw bottom border
        $sb.Append([VT]::MoveTo($x, $y + $this.Height - 1))
        $sb.Append($this.BorderColor)
        $sb.Append("╰" + ("─" * ($this.Width - 2)) + "╯")
        $sb.Append($this.NormalColor)
        
        Write-Host -NoNewline $sb.ToString()
    }
    
    [void] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                $this.MacroList.MoveUp()
            }
            ([System.ConsoleKey]::DownArrow) {
                $this.MacroList.MoveDown()
            }
            ([System.ConsoleKey]::Enter) {
                $this.SelectedMacro = $this.MacroList.GetSelectedItem()
                $this.Result = "OK"
                $this.IsActive = $false
            }
            ([System.ConsoleKey]::Escape) {
                $this.Result = "Cancel"
                $this.IsActive = $false
            }
        }
    }
}