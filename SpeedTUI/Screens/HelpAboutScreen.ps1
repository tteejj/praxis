# SpeedTUI Help & About Screen - Documentation and information

# Load dependencies
. "$PSScriptRoot/../Core/Component.ps1"
. "$PSScriptRoot/../Core/PerformanceMonitor.ps1"
. "$PSScriptRoot/../Services/ConfigurationService.ps1"

class HelpAboutScreen : Component {
    [object]$ConfigService
    [object]$PerformanceMonitor
    [string]$ViewMode = "About"  # About, Help, KeyboardShortcuts, SystemInfo
    [int]$ScrollPosition = 0
    [DateTime]$LastRefresh
    
    HelpAboutScreen() : base() {
        $this.Initialize()
    }
    
    [void] Initialize() {
        try {
            $this.ConfigService = [ConfigurationService]::new()
            $this.PerformanceMonitor = Get-PerformanceMonitor
            $this.LastRefresh = [DateTime]::Now
            
            $this.PerformanceMonitor.RecordMetric("screen.helpabout.initialized", 1, "count")
        } catch {
            Write-Host "Error initializing help screen: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    [string[]] Render() {
        $timing = Start-PerformanceTiming "HelpAboutScreen.Render"
        
        try {
            $lines = @()
            
            # Header
            $lines += $this.RenderHeader()
            $lines += ""
            
            # Tabs
            $lines += $this.RenderTabs()
            $lines += ""
            
            switch ($this.ViewMode) {
                "About" {
                    $lines += $this.RenderAbout()
                }
                "Help" {
                    $lines += $this.RenderHelp()
                }
                "KeyboardShortcuts" {
                    $lines += $this.RenderKeyboardShortcuts()
                }
                "SystemInfo" {
                    $lines += $this.RenderSystemInfo()
                }
            }
            
            $lines += ""
            $lines += $this.RenderControls()
            
            return $lines
            
        } finally {
            Stop-PerformanceTiming $timing
        }
    }
    
    [string[]] RenderHeader() {
        $lines = @()
        $version = $this.ConfigService.GetSetting("Application.Version")
        
        $lines += "╔════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗"
        $lines += "║                                            SPEEDTUI HELP & ABOUT                                                  ║"
        $lines += "║                                            Version $($version.PadRight(40))                                                    ║"
        $lines += "╚════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝"
        
        return $lines
    }
    
    [string[]] RenderTabs() {
        $lines = @()
        $tabs = @("About", "Help", "Keyboard Shortcuts", "System Info")
        $tabLine = "┌"
        
        foreach ($tab in $tabs) {
            $marker = if ($tab.Replace(" ", "") -eq $this.ViewMode) { "►" } else { " " }
            $tabLine += "─ $marker$tab ─┬"
        }
        $tabLine = $tabLine.TrimEnd("┬") + "─" * (119 - $tabLine.Length) + "┐"
        $lines += $tabLine
        
        return $lines
    }
    
    [string[]] RenderAbout() {
        $lines = @()
        $lines += "│                                                                                                                │"
        $lines += "│  ███████╗██████╗ ███████╗███████╗██████╗ ████████╗██╗   ██╗██╗                                              │"
        $lines += "│  ██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗╚══██╔══╝██║   ██║██║                                              │"
        $lines += "│  ███████╗██████╔╝█████╗  █████╗  ██║  ██║   ██║   ██║   ██║██║                                              │"
        $lines += "│  ╚════██║██╔═══╝ ██╔══╝  ██╔══╝  ██║  ██║   ██║   ██║   ██║██║                                              │"
        $lines += "│  ███████║██║     ███████╗███████╗██████╔╝   ██║   ╚██████╔╝██║                                              │"
        $lines += "│  ╚══════╝╚═╝     ╚══════╝╚══════╝╚═════╝    ╚═╝    ╚═════╝ ╚═╝                                              │"
        $lines += "│                                                                                                                │"
        $lines += "│                            PowerShell Terminal User Interface                                                  │"
        $lines += "│                                                                                                                │"
        $lines += "│  SpeedTUI is a high-performance, feature-rich terminal interface designed for PowerShell users.              │"
        $lines += "│  Built with speed, productivity, and ease-of-use in mind.                                                     │"
        $lines += "│                                                                                                                │"
        $lines += "│  🚀 KEY FEATURES:                                                                                              │"
        $lines += "│    • Fast, responsive interface optimized for speed                                                           │"
        $lines += "│    • Comprehensive project and time tracking                                                                  │"
        $lines += "│    • Extensive command library with usage tracking                                                            │"
        $lines += "│    • Built-in text editor and file browser                                                                    │"
        $lines += "│    • Real-time system monitoring and performance metrics                                                      │"
        $lines += "│    • Configurable themes and settings                                                                         │"
        $lines += "│    • Excel import/export capabilities                                                                         │"
        $lines += "│    • Comprehensive logging and debugging tools                                                                │"
        $lines += "│                                                                                                                │"
        $lines += "│  💡 PHILOSOPHY:                                                                                                │"
        $lines += "│    SpeedTUI embraces the principle that developer tools should be fast, intuitive, and powerful.            │"
        $lines += "│    Every feature is designed to enhance productivity without compromising on performance.                    │"
        $lines += "│                                                                                                                │"
        
        return $lines
    }
    
    [string[]] RenderHelp() {
        $lines = @()
        $lines += "│                                                                                                                │"
        $lines += "│  📖 GETTING STARTED                                                                                            │"
        $lines += "│                                                                                                                │"
        $lines += "│  SpeedTUI is organized into several main sections:                                                            │"
        $lines += "│                                                                                                                │"
        $lines += "│  🕒 TIME TRACKING                                                                                              │"
        $lines += "│     Track work hours across projects and tasks. Supports fiscal year reporting and detailed analytics.      │"
        $lines += "│     • Add new time entries with project, task, and description                                               │"
        $lines += "│     • View and edit existing entries                                                                          │"
        $lines += "│     • Generate reports and export data                                                                        │"
        $lines += "│                                                                                                                │"
        $lines += "│  📋 COMMAND LIBRARY                                                                                            │"
        $lines += "│     Store and organize frequently used commands with categories and usage tracking.                          │"
        $lines += "│     • Add commands with descriptions and tags                                                                 │"
        $lines += "│     • Execute commands directly from the interface                                                            │"
        $lines += "│     • Track usage statistics and last execution                                                               │"
        $lines += "│                                                                                                                │"
        $lines += "│  📊 PROJECT MANAGEMENT                                                                                         │"   
        $lines += "│     Organize work into projects with tasks, deadlines, and progress tracking.                               │"
        $lines += "│     • Create and manage projects                                                                              │"
        $lines += "│     • Add tasks with priorities and due dates                                                                 │"
        $lines += "│     • Track project progress and completion                                                                   │"
        $lines += "│                                                                                                                │"
        $lines += "│  🔧 SYSTEM MONITORING                                                                                          │"
        $lines += "│     Real-time performance monitoring with detailed metrics and system information.                           │"
        $lines += "│     • View system resource usage                                                                              │"
        $lines += "│     • Monitor application performance                                                                          │"
        $lines += "│     • Generate performance reports                                                                             │"
        $lines += "│                                                                                                                │"
        $lines += "│  ⚙️  SETTINGS                                                                                                   │"
        $lines += "│     Customize SpeedTUI behavior, appearance, and functionality.                                              │"
        $lines += "│     • Configure themes and display options                                                                    │"
        $lines += "│     • Adjust performance and logging settings                                                                 │"
        $lines += "│     • Enable or disable advanced features                                                                     │"
        $lines += "│                                                                                                                │"
        
        return $lines
    }
    
    [string[]] RenderKeyboardShortcuts() {
        $lines = @()
        $lines += "│                                                                                                                │"
        $lines += "│  ⌨️  KEYBOARD SHORTCUTS                                                                                         │"
        $lines += "│                                                                                                                │"
        $lines += "│  🏠 GLOBAL SHORTCUTS (Available everywhere)                                                                   │"
        $lines += "│     F1               Show Help & About                                                                        │"
        $lines += "│     F11              Open System Monitor                                                                      │"
        $lines += "│     F5               Refresh current screen                                                                   │"
        $lines += "│     Ctrl+Q           Quit application                                                                         │"
        $lines += "│     Ctrl+,           Open Settings                                                                            │"
        $lines += "│     Esc              Back/Cancel                                                                              │"
        $lines += "│                                                                                                                │"
        $lines += "│  📊 DASHBOARD SHORTCUTS                                                                                        │"
        $lines += "│     1-9              Quick access to menu items                                                               │"
        $lines += "│     0                Exit application                                                                         │"
        $lines += "│     ↑/↓              Navigate menu                                                                            │"
        $lines += "│     Enter            Activate selected item                                                                   │"
        $lines += "│                                                                                                                │"
        $lines += "│  📋 LIST NAVIGATION (Tables, menus, etc.)                                                                     │"
        $lines += "│     ↑/↓              Move selection up/down                                                                   │"
        $lines += "│     Page Up/Down     Move selection by page                                                                   │"
        $lines += "│     Home/End         Move to first/last item                                                                  │"
        $lines += "│     Enter            Select/Edit item                                                                         │"
        $lines += "│                                                                                                                │"
        $lines += "│  ✏️  FORM EDITING                                                                                               │"
        $lines += "│     Tab              Next field                                                                               │"
        $lines += "│     Shift+Tab        Previous field                                                                           │"
        $lines += "│     S                Save changes                                                                             │"
        $lines += "│     C                Cancel editing                                                                           │"
        $lines += "│                                                                                                                │"
        $lines += "│  🔍 SCREEN-SPECIFIC SHORTCUTS                                                                                  │"
        $lines += "│     A                Add new item                                                                             │"
        $lines += "│     E                Edit selected item                                                                       │"
        $lines += "│     D                Delete selected item                                                                     │"
        $lines += "│     R                Refresh data                                                                             │"
        $lines += "│     F                Filter/Search                                                                            │"
        $lines += "│     X                Execute (Command Library)                                                                │"
        $lines += "│                                                                                                                │"
        
        return $lines
    }
    
    [string[]] RenderSystemInfo() {
        $lines = @()
        
        try {
            # Get system information
            $osVersion = [System.Environment]::OSVersion
            $psVersion = $PSVersionTable.PSVersion
            $currentProcess = [System.Diagnostics.Process]::GetCurrentProcess()
            $memoryMB = [Math]::Round($currentProcess.WorkingSet64 / 1MB, 1)
            $uptime = [DateTime]::Now - $currentProcess.StartTime
            $uptimeStr = $uptime.ToString("d\\.hh\\:mm\\:ss")
            
            $lines += "│                                                                                                                │"
            $lines += "│  💻 SYSTEM INFORMATION                                                                                         │"
            $lines += "│                                                                                                                │"
            $lines += "│  🖥️  OPERATING SYSTEM                                                                                          │"
            $lines += "│     Platform:        $($osVersion.Platform.ToString().PadRight(75)) │"
            $lines += "│     Version:         $($osVersion.Version.ToString().PadRight(75)) │"
            $lines += "│     Service Pack:    $($osVersion.ServicePack.PadRight(75)) │"
            $lines += "│                                                                                                                │"
            $lines += "│  ⚡ POWERSHELL                                                                                               │"
            $lines += "│     Version:         $($psVersion.ToString().PadRight(75)) │"
            $lines += "│     Edition:         $($PSVersionTable.PSEdition.PadRight(75)) │"
            $lines += "│     Host:            $($Host.Name.PadRight(75)) │"
            $lines += "│                                                                                                                │"
            $lines += "│  🚀 SPEEDTUI PROCESS                                                                                           │"
            $lines += "│     Process ID:      $($currentProcess.Id.ToString().PadRight(75)) │"
            $lines += "│     Memory Usage:    $($memoryMB.ToString('F1')) MB".PadRight(87) + "│"
            $lines += "│     Uptime:          $($uptimeStr.PadRight(75)) │"
            $lines += "│     Threads:         $($currentProcess.Threads.Count.ToString().PadRight(75)) │"
            $lines += "│     Handles:         $($currentProcess.HandleCount.ToString().PadRight(75)) │"
            $lines += "│                                                                                                                │"
            $lines += "│  🔧 CONFIGURATION                                                                                              │"
            $lines += "│     Debug Mode:      $($this.ConfigService.IsDebugMode().ToString().PadRight(75)) │"
            $lines += "│     Theme:           $($this.ConfigService.GetSetting('UI.Theme').PadRight(75)) │"
            $lines += "│     Auto-Save:       $($this.ConfigService.GetSetting('Application.AutoSave').ToString().PadRight(75)) │"
            $lines += "│     Log Level:       $($this.ConfigService.GetSetting('Application.LogLevel').PadRight(75)) │"
            $lines += "│                                                                                                                │"
            $lines += "│  📊 PERFORMANCE METRICS                                                                                        │"
            $lines += "│     GC Gen 0:        $([GC]::CollectionCount(0).ToString().PadRight(75)) │"
            $lines += "│     GC Gen 1:        $([GC]::CollectionCount(1).ToString().PadRight(75)) │"
            $lines += "│     GC Gen 2:        $([GC]::CollectionCount(2).ToString().PadRight(75)) │"
            $lines += "│     GC Memory:       $([Math]::Round([GC]::GetTotalMemory($false) / 1MB, 1).ToString('F1')) MB".PadRight(87) + "│"
            $lines += "│                                                                                                                │"
            
        } catch {
            $lines += "│ Error retrieving system information: $($_.Exception.Message.PadRight(75)) │"
        }
        
        return $lines
    }
    
    [string[]] RenderControls() {
        $lines = @()
        $lines += "┌─ Controls ─────────────────────────────────────────────────────────────────────────────────────────────────────┐"
        $lines += "│ Tab - Switch Sections │ ↑/↓ - Scroll Content │ R - Refresh │ B - Back to Dashboard │ Q - Quit              │"
        $lines += "└────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
        
        return $lines
    }
    
    [string] HandleInput([string]$key) {
        $timing = Start-PerformanceTiming "HelpAboutScreen.HandleInput" @{ key = $key }
        
        try {
            switch ($key.ToUpper()) {
                'TAB' {
                    $this.SwitchView()
                    return "REFRESH"
                }
                'R' {
                    $this.LastRefresh = [DateTime]::Now
                    return "REFRESH"
                }
                'B' {
                    return "DASHBOARD"
                }
                'Q' {
                    return "EXIT"
                }
                'UpArrow' {
                    if ($this.ScrollPosition -gt 0) {
                        $this.ScrollPosition--
                        return "REFRESH"
                    }
                    return "CONTINUE"
                }
                'DownArrow' {
                    $this.ScrollPosition++
                    return "REFRESH"
                }
                default {
                    return "CONTINUE"
                }
            }
        } finally {
            Stop-PerformanceTiming $timing
        }
        return "CONTINUE"
    }
    
    [void] SwitchView() {
        $views = @("About", "Help", "KeyboardShortcuts", "SystemInfo")
        $currentIndex = $views.IndexOf($this.ViewMode)
        $nextIndex = ($currentIndex + 1) % $views.Count
        $this.ViewMode = $views[$nextIndex]
        $this.ScrollPosition = 0
        
        $this.PerformanceMonitor.RecordMetric("screen.helpabout.view_switched", 1, "count", @{ view = $this.ViewMode })
    }
}