# CommandPalette.ps1 - Fast command palette overlay

class CommandPalette : Container {
    [string]$SearchText = ""
    [ListBox]$ResultsList
    [System.Collections.ArrayList]$AllCommands
    [System.Collections.ArrayList]$FilteredCommands
    [scriptblock]$OnCommandSelected = {}
    [bool]$IsVisible = $false
    
    # Layout
    hidden [int]$PaletteWidth = 60
    hidden [int]$PaletteHeight = 20
    hidden [int]$MaxResults = 15
    
    CommandPalette() : base() {
        $this.AllCommands = [System.Collections.ArrayList]::new()
        $this.FilteredCommands = [System.Collections.ArrayList]::new()
        $this.DrawBackground = $true
        
        # Create results list
        $this.ResultsList = [ListBox]::new()
        $this.ResultsList.ShowBorder = $false
        $this.ResultsList.ShowScrollbar = $true
        $this.ResultsList.ItemRenderer = {
            param($cmd)
            $name = $cmd.Name.PadRight(20)
            $desc = if ($cmd.Description.Length -gt 35) {
                $cmd.Description.Substring(0, 32) + "..."
            } else {
                $cmd.Description
            }
            return "$name $desc"
        }
        $this.AddChild($this.ResultsList)
    }
    
    [void] Initialize([ServiceContainer]$services) {
        # Call base initialization
        ([Container]$this).Initialize($services)
        
        # Initialize child components
        if ($this.ResultsList) {
            $this.ResultsList.Initialize($services)
        }
        
        # Set palette background if theme is available
        if ($this.Theme) {
            $this.SetBackgroundColor($this.Theme.GetBgColor("menu.background"))
        }
        
        # Load default commands
        $this.LoadDefaultCommands()
    }
    
    [void] LoadDefaultCommands() {
        # Add some default commands
        $this.AddCommand("new project", "Create a new project", { 
            # Switch to projects tab and trigger new project
            if ($this.Parent -and $this.Parent.GetType().Name -eq "MainScreen") {
                $this.Parent.TabContainer.ActivateTab(0)  # Projects is first tab
                # TODO: Trigger new project dialog
            }
        })
        $this.AddCommand("new task", "Create a new task", { 
            # TODO: Implement new task
        })
        $this.AddCommand("search", "Search in files", { 
            # TODO: Implement search
        })
        $this.AddCommand("settings", "Open settings", { 
            # TODO: Implement settings
        })
        $this.AddCommand("reload", "Reload configuration", { 
            # TODO: Implement reload
        })
        $this.AddCommand("theme dark", "Switch to dark theme", { 
            # TODO: Implement theme switching
        })
        $this.AddCommand("theme light", "Switch to light theme", { 
            # TODO: Implement theme switching
        })
        $this.AddCommand("quit", "Exit application", { 
            if ($global:ScreenManager) {
                $screen = $global:ScreenManager.GetActiveScreen()
                if ($screen) { $screen.Active = $false }
            }
        })
    }
    
    [void] AddCommand([string]$name, [string]$description, [scriptblock]$action) {
        $this.AllCommands.Add(@{
            Name = $name
            Description = $description
            Action = $action
        })
    }
    
    [void] Show() {
        $this.IsVisible = $true
        $this.SearchText = ""
        $this.UpdateFilter()
        $this.Invalidate()
        
        # Focus on results
        $this.ResultsList.Focus()
    }
    
    [void] Hide() {
        $this.IsVisible = $false
        $this.Invalidate()
        
        # Return focus to parent's active tab
        if ($this.Parent -and $this.Parent.GetType().Name -eq "MainScreen") {
            $activeTab = $this.Parent.TabContainer.GetActiveTab()
            if ($activeTab -and $activeTab.Content) {
                $activeTab.Content.Focus()
            }
        }
    }
    
    [void] UpdateFilter() {
        $this.FilteredCommands.Clear()
        
        if ([string]::IsNullOrEmpty($this.SearchText)) {
            $this.FilteredCommands.AddRange($this.AllCommands)
        } else {
            # Simple fuzzy search
            $searchLower = $this.SearchText.ToLower()
            foreach ($cmd in $this.AllCommands) {
                if ($cmd.Name.ToLower().Contains($searchLower) -or 
                    $cmd.Description.ToLower().Contains($searchLower)) {
                    $this.FilteredCommands.Add($cmd)
                }
            }
        }
        
        # Update list
        $this.ResultsList.SetItems($this.FilteredCommands.ToArray())
    }
    
    [void] OnBoundsChanged() {
        # Center the palette
        $centerX = [int](($this.Width - $this.PaletteWidth) / 2)
        $centerY = [int](($this.Height - $this.PaletteHeight) / 2)
        
        # Update own bounds to be centered
        $this.X = $centerX
        $this.Y = $centerY
        $this.Width = $this.PaletteWidth
        $this.Height = $this.PaletteHeight
        
        # Layout results list (leave room for search box and border)
        $this.ResultsList.SetBounds(
            $this.X + 2,
            $this.Y + 4,
            $this.Width - 4,
            $this.Height - 6
        )
        
        # Recalculate visible items
        $this.ResultsList.VisibleItems = [Math]::Min($this.MaxResults, $this.Height - 6)
        
        ([Container]$this).OnBoundsChanged()
    }
    
    [string] OnRender() {
        if (-not $this.IsVisible) { return "" }
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Draw background first
        $sb.Append(([Container]$this).OnRender())
        
        # Draw border
        $borderColor = $this.Theme.GetColor("border.focused")
        
        # Top border with title
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($borderColor)
        $sb.Append([VT]::TL() + ([VT]::H() * 2))
        $sb.Append($this.Theme.GetColor("accent"))
        $sb.Append(" Command Palette ")
        $sb.Append($borderColor)
        $sb.Append([VT]::H() * ($this.Width - 19) + [VT]::TR())
        
        # Sides
        for ($y = 1; $y -lt $this.Height - 1; $y++) {
            $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
            $sb.Append([VT]::V())
            $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y + $y))
            $sb.Append([VT]::V())
        }
        
        # Bottom border
        $sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        $sb.Append([VT]::BL() + ([VT]::H() * ($this.Width - 2)) + [VT]::BR())
        
        # Search box
        $sb.Append([VT]::MoveTo($this.X + 2, $this.Y + 2))
        $sb.Append($this.Theme.GetColor("foreground"))
        $sb.Append("Search: ")
        $sb.Append($this.Theme.GetColor("accent"))
        $sb.Append($this.SearchText)
        $sb.Append("_")
        
        # Separator
        $sb.Append([VT]::MoveTo($this.X + 1, $this.Y + 3))
        $sb.Append($borderColor)
        $sb.Append([VT]::H() * ($this.Width - 2))
        
        # Help text
        $sb.Append([VT]::MoveTo($this.X + 2, $this.Y + $this.Height - 2))
        $sb.Append($this.Theme.GetColor("disabled"))
        $sb.Append("[Enter] Select  [Esc] Cancel")
        
        $sb.Append([VT]::Reset())
        
        return $sb.ToString()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.IsVisible) { return $false }
        
        switch ($key.Key) {
            ([System.ConsoleKey]::Escape) {
                $this.Hide()
                return $true
            }
            ([System.ConsoleKey]::Enter) {
                $selected = $this.ResultsList.GetSelectedItem()
                if ($selected) {
                    $this.Hide()
                    if ($selected.Action) {
                        & $selected.Action
                    }
                    if ($this.OnCommandSelected) {
                        & $this.OnCommandSelected $selected
                    }
                }
                return $true
            }
            ([System.ConsoleKey]::Backspace) {
                if ($this.SearchText.Length -gt 0) {
                    $this.SearchText = $this.SearchText.Substring(0, $this.SearchText.Length - 1)
                    $this.UpdateFilter()
                    $this.Invalidate()
                }
                return $true
            }
            default {
                # Let list handle navigation
                if ($this.ResultsList.HandleInput($key)) {
                    return $true
                }
                
                # Add character to search
                if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar) -or $key.KeyChar -eq ' ') {
                    $this.SearchText += $key.KeyChar
                    $this.UpdateFilter()
                    $this.Invalidate()
                    return $true
                }
            }
        }
        
        return $false
    }
}