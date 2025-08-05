# ColorThemeService.ps1 - Manages color themes for tasks

class ColorThemeService {
    static [hashtable]$Themes = @{
        "default" = @{
            Name = "Default"
            Task = "`e[38;2;250;248;240m"      # Warm white
            Subtask = "`e[38;2;160;160;160m"   # Medium gray
            Display = "Default"
        }
        "urgent" = @{
            Name = "Urgent"
            Task = "`e[38;2;255;100;100m"      # Bright coral red
            Subtask = "`e[38;2;200;80;80m"     # Darker coral
            Display = "Urgent"
        }
        "work" = @{
            Name = "Work"
            Task = "`e[38;2;100;150;255m"      # Modern blue
            Subtask = "`e[38;2;80;120;200m"    # Darker blue
            Display = "Work"
        }
        "personal" = @{
            Name = "Personal"
            Task = "`e[38;2;80;200;120m"       # Modern green
            Subtask = "`e[38;2;60;160;100m"    # Darker green
            Display = "Personal"
        }
        "project" = @{
            Name = "Project"
            Task = "`e[38;2;200;120;255m"      # Modern purple
            Subtask = "`e[38;2;160;100;200m"   # Darker purple
            Display = "Project"
        }
        "completed" = @{
            Name = "Completed"
            Task = "`e[38;2;120;120;120m"      # Medium gray
            Subtask = "`e[38;2;90;90;90m"      # Dark gray
            Display = "Completed"
        }
        "client" = @{
            Name = "Client"
            Task = "`e[38;2;255;165;0m"        # Orange
            Subtask = "`e[38;2;200;130;0m"     # Darker orange
            Display = "Client"
        }
        "research" = @{
            Name = "Research"
            Task = "`e[38;2;100;200;200m"      # Cyan
            Subtask = "`e[38;2;80;160;160m"    # Darker cyan
            Display = "Research"
        }
        "meeting" = @{
            Name = "Meeting"
            Task = "`e[38;2;255;200;100m"      # Gold
            Subtask = "`e[38;2;200;160;80m"    # Darker gold
            Display = "Meeting"
        }
        "deadline" = @{
            Name = "Deadline"
            Task = "`e[38;2;255;80;120m"       # Hot pink
            Subtask = "`e[38;2;200;60;100m"    # Darker pink
            Display = "Deadline"
        }
    }
    
    static [string] GetTaskColor([string]$theme) {
        if ([ColorThemeService]::Themes.ContainsKey($theme)) {
            return [ColorThemeService]::Themes[$theme].Task
        }
        return [ColorThemeService]::Themes["default"].Task
    }
    
    static [string] GetSubtaskColor([string]$theme) {
        if ([ColorThemeService]::Themes.ContainsKey($theme)) {
            return [ColorThemeService]::Themes[$theme].Subtask
        }
        return [ColorThemeService]::Themes["default"].Subtask
    }
    
    static [string] GetDisplayName([string]$theme) {
        if ([ColorThemeService]::Themes.ContainsKey($theme)) {
            return [ColorThemeService]::Themes[$theme].Display
        }
        return "Default"
    }
    
    static [string[]] GetThemeNames() {
        return [ColorThemeService]::Themes.Keys
    }
    
    static [string] GetNextTheme([string]$currentTheme) {
        $themeOrder = @("default", "urgent", "work", "personal", "project", "client", "research", "meeting", "deadline", "completed")
        $currentIndex = $themeOrder.IndexOf($currentTheme)
        if ($currentIndex -eq -1) { $currentIndex = 0 }
        $nextIndex = ($currentIndex + 1) % $themeOrder.Count
        return $themeOrder[$nextIndex]
    }
}