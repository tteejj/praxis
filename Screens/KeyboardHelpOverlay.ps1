# KeyboardHelpOverlay.ps1 - Minimal keyboard shortcut help overlay

class KeyboardHelpOverlay : MinimalModal {
    hidden [string]$Context = ""
    hidden [MinimalListBox]$CategoryList
    hidden [UIElement]$ShortcutDisplay
    hidden [KeyboardShortcutManager]$ShortcutManager
    hidden [hashtable]$CategorizedShortcuts = @{}
    
    KeyboardHelpOverlay([string]$context = "") : base() {
        $this.Title = "Keyboard Shortcuts"
        $this.Context = $context
        $this.ModalWidth = 70
        $this.ModalHeight = 24
        $this.BorderType = [BorderType]::Rounded
        
        # Add close hint
        $this.AddButton("Close (ESC/F1)", { $this.Close() }, $true)
    }
    
    [void] OnInitialize() {
        # Get shortcut manager
        $this.ShortcutManager = $this.ServiceContainer.GetService('KeyboardShortcutManager')
        if (-not $this.ShortcutManager) {
            $this.ShortcutManager = [KeyboardShortcutManager]::new()
            $this.ShortcutManager.Initialize($this.ServiceContainer)
        }
        
        # Create main container with horizontal split
        $mainSplit = [HorizontalSplit]::new()
        $mainSplit.SplitPosition = 30  # 30% for categories
        
        # Left: Category list
        $this.CategoryList = [MinimalListBox]::new()
        $this.CategoryList.ShowBorder = $false
        $this.CategoryList.OnSelectionChanged = {
            $this.UpdateShortcutDisplay()
        }.GetNewClosure()
        
        # Right: Shortcut display
        $this.ShortcutDisplay = [UIElement]::new()
        $this.ShortcutDisplay.OnRender = {
            $this.Parent.Parent.RenderShortcuts()
        }.GetNewClosure()
        
        $mainSplit.SetLeftChild($this.CategoryList)
        $mainSplit.SetRightChild($this.ShortcutDisplay)
        
        $this.Content = $mainSplit
        
        # Load shortcuts
        $this.LoadShortcuts()
        
        ([MinimalModal]$this).OnInitialize()
    }
    
    [void] LoadShortcuts() {
        # Get all shortcuts for context
        $allShortcuts = $this.ShortcutManager.GetShortcuts($this.Context)
        
        # Add some additional help shortcuts
        $this.AddHelpShortcuts($allShortcuts)
        
        # Categorize shortcuts
        $this.CategorizedShortcuts.Clear()
        foreach ($shortcut in $allShortcuts) {
            $category = $shortcut.Category
            if (-not $this.CategorizedShortcuts.ContainsKey($category)) {
                $this.CategorizedShortcuts[$category] = @()
            }
            $this.CategorizedShortcuts[$category] += $shortcut
        }
        
        # Populate category list
        $categories = $this.CategorizedShortcuts.Keys | Sort-Object
        $this.CategoryList.SetItems($categories)
        
        if ($categories.Count -gt 0) {
            $this.CategoryList.SelectedIndex = 0
        }
    }
    
    [void] AddHelpShortcuts([System.Collections.Generic.List[KeyboardShortcut]]$shortcuts) {
        # Add context-specific shortcuts based on current screen
        $currentScreen = $null
        if ($global:ScreenManager) {
            $currentScreen = $global:ScreenManager.GetActiveScreen()
        }
        
        if ($currentScreen) {
            # Add screen-specific shortcuts
            switch ($currentScreen.GetType().Name) {
                "ProjectsScreen" {
                    $this.AddShortcut($shortcuts, "N", "New project", "Projects")
                    $this.AddShortcut($shortcuts, "E", "Edit project", "Projects")
                    $this.AddShortcut($shortcuts, "D", "Delete project", "Projects")
                    $this.AddShortcut($shortcuts, "Enter", "View project details", "Projects")
                }
                "TaskScreen" {
                    $this.AddShortcut($shortcuts, "N", "New task", "Tasks")
                    $this.AddShortcut($shortcuts, "E", "Edit task", "Tasks")
                    $this.AddShortcut($shortcuts, "D", "Delete task", "Tasks")
                    $this.AddShortcut($shortcuts, "Space", "Toggle task completion", "Tasks")
                }
                "FileBrowserScreen" {
                    $this.AddShortcut($shortcuts, "H/←", "Parent directory", "File Browser")
                    $this.AddShortcut($shortcuts, "L/→", "Enter directory", "File Browser")
                    $this.AddShortcut($shortcuts, "J/↓", "Next file", "File Browser")
                    $this.AddShortcut($shortcuts, "K/↑", "Previous file", "File Browser")
                }
            }
        }
        
        # Add application-wide shortcuts
        $this.AddShortcut($shortcuts, "Ctrl+P", "Command palette", "Application")
        $this.AddShortcut($shortcuts, "Ctrl+Q", "Quit application", "Application")
        $this.AddShortcut($shortcuts, "1-9", "Switch tabs", "Application")
        $this.AddShortcut($shortcuts, "Ctrl+Tab", "Next tab", "Application")
        $this.AddShortcut($shortcuts, "Ctrl+Shift+Tab", "Previous tab", "Application")
    }
    
    [void] AddShortcut($shortcuts, [string]$keyDisplay, [string]$description, [string]$category) {
        $shortcut = [KeyboardShortcut]::new()
        $shortcut.Key = [System.ConsoleKey]::F1  # Dummy key
        $shortcut.Description = $description
        $shortcut.Category = $category
        
        # Override display text
        $shortcut | Add-Member -MemberType ScriptMethod -Name GetDisplayText -Value {
            return $keyDisplay
        }.GetNewClosure() -Force
        
        $shortcuts.Add($shortcut)
    }
    
    [string] RenderShortcuts() {
        $selectedCategory = $this.CategoryList.GetSelectedItem()
        if (-not $selectedCategory -or -not $this.CategorizedShortcuts.ContainsKey($selectedCategory)) {
            return ""
        }
        
        $sb = Get-PooledStringBuilder 2048
        $shortcuts = $this.CategorizedShortcuts[$selectedCategory]
        
        # Header
        $sb.Append([VT]::MoveTo($this.ShortcutDisplay.X + 2, $this.ShortcutDisplay.Y))
        $sb.Append($this.Theme.GetColor('accent'))
        $sb.Append("═══ $selectedCategory ═══")
        $sb.Append([VT]::Reset())
        
        # Shortcuts
        $y = $this.ShortcutDisplay.Y + 2
        $maxY = $this.ShortcutDisplay.Y + $this.ShortcutDisplay.Height - 1
        
        foreach ($shortcut in $shortcuts) {
            if ($y -ge $maxY) { break }
            
            $sb.Append([VT]::MoveTo($this.ShortcutDisplay.X + 2, $y))
            
            # Key combination
            $keyText = $shortcut.GetDisplayText()
            $sb.Append($this.Theme.GetColor('accent'))
            $sb.Append($keyText.PadRight(20))
            
            # Description
            $sb.Append($this.Theme.GetColor('normal'))
            $desc = $shortcut.Description
            if ($desc.Length -gt 40) {
                $desc = $desc.Substring(0, 37) + "..."
            }
            $sb.Append($desc)
            
            $sb.Append([VT]::Reset())
            $y++
        }
        
        # Footer hint
        if ($y -lt $maxY - 2) {
            $sb.Append([VT]::MoveTo($this.ShortcutDisplay.X + 2, $maxY - 2))
            $sb.Append($this.Theme.GetColor('disabled'))
            $sb.Append("Use ↑/↓ to browse categories")
            $sb.Append([VT]::Reset())
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] UpdateShortcutDisplay() {
        $this.ShortcutDisplay.Invalidate()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # F1 also closes help
        if ($key.Key -eq [System.ConsoleKey]::F1) {
            $this.Close()
            return $true
        }
        
        return ([MinimalModal]$this).HandleInput($key)
    }
}

# Quick help function for screens
class HelpManager {
    static [void] ShowHelp([string]$context = "") {
        $help = [KeyboardHelpOverlay]::new($context)
        if ($global:ScreenManager) {
            $global:ScreenManager.Push($help)
        }
    }
}