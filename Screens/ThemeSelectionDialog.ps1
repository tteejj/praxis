# ThemeSelectionDialog.ps1 - Simple theme picker

class ThemeSelectionDialog : BaseDialog {
    [MinimalListBox]$ThemeList
    [ThemeManager]$ThemeManager
    [string]$SelectedTheme
    
    ThemeSelectionDialog() : base() {
        $this.Title = "Select Theme"
        $this.Width = 40
        $this.Height = 12
    }
    
    [void] OnInitialize() {
        ([BaseDialog]$this).OnInitialize()
        
        $this.ThemeManager = $this.ServiceContainer.GetService('ThemeManager')
        
        # Create list box
        $this.ThemeList = [MinimalListBox]::new()
        $this.ThemeList.Title = "Available Themes"
        $this.ThemeList.ShowBorder = $false
        
        # Add theme names
        $themes = $this.ThemeManager.GetThemeNames()
        foreach ($theme in $themes) {
            $this.ThemeList.AddItem($theme)
        }
        
        # Select current theme
        $currentTheme = $this.ThemeManager.GetCurrentTheme()
        $index = $themes.IndexOf($currentTheme)
        if ($index -ge 0) {
            $this.ThemeList.SetSelectedIndex($index)
        }
        
        $this.AddContentControl($this.ThemeList)
        $this.ThemeList.Focus()
    }
    
    [void] OnBoundsChanged() {
        ([BaseDialog]$this).OnBoundsChanged()
        
        if ($this.ThemeList) {
            # Give list full dialog content area
            $this.ThemeList.SetBounds(
                $this.ContentX,
                $this.ContentY,
                $this.ContentWidth,
                $this.ContentHeight
            )
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                # Apply theme
                $this.SelectedTheme = $this.ThemeList.GetSelectedItem()
                if ($this.SelectedTheme) {
                    $this.ThemeManager.SetTheme($this.SelectedTheme)
                }
                $this.DialogResult = [DialogResult]::OK
                $this.Close()
                return $true
            }
            ([System.ConsoleKey]::Escape) {
                $this.DialogResult = [DialogResult]::Cancel
                $this.Close()
                return $true
            }
        }
        
        # Let base handle it
        return ([BaseDialog]$this).HandleInput($key)
    }
}