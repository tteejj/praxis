#!/usr/bin/env pwsh
# MacroFactoryStandalone.ps1 - Standalone MacroFactory without complex Praxis dependencies

param(
    [switch]$Debug
)

# Set location to script directory
Set-Location $PSScriptRoot

# Set window title
$Host.UI.RawUI.WindowTitle = "MacroFactory - Visual IDEA Macro Builder"

# Initialize console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false

# Welcome message
Clear-Host
Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║                    MACROFACTORY v1.0                          ║
║              Visual IDEA Macro Builder                        ║
║                                                                ║
║  Build powerful IDEA automation macros visually!              ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host "`nStarting MacroFactory..." -ForegroundColor Gray
Start-Sleep -Milliseconds 500

# Simple action model
class SimpleAction {
    [string]$Name
    [string]$Description  
    [string]$Category
    
    SimpleAction([string]$name, [string]$description, [string]$category) {
        $this.Name = $name
        $this.Description = $description
        $this.Category = $category
    }
}

# MacroFactory Screen
class MacroFactoryScreen {
    [System.Collections.ArrayList]$AvailableActions
    [System.Collections.ArrayList]$MacroSequence
    [hashtable]$Context
    [int]$FocusedPane = 0  # 0=Library, 1=Sequence, 2=Context
    [int]$SelectedLibraryIndex = 0
    [int]$SelectedSequenceIndex = 0
    [int]$Width = 80
    [int]$Height = 24
    
    MacroFactoryScreen() {
        $this.AvailableActions = [System.Collections.ArrayList]::new()
        $this.MacroSequence = [System.Collections.ArrayList]::new()
        $this.Context = @{}
        $this.LoadAvailableActions()
    }
    
    [void] LoadAvailableActions() {
        $this.AvailableActions.Add([SimpleAction]::new("Summarize Data", "Summarize database by field with statistics", "Analysis")) | Out-Null
        $this.AvailableActions.Add([SimpleAction]::new("Append Field", "Append a new field to the database", "Data")) | Out-Null  
        $this.AvailableActions.Add([SimpleAction]::new("Export to Excel", "Export data to Excel format", "Export")) | Out-Null
        $this.AvailableActions.Add([SimpleAction]::new("Custom IDEA Command", "Execute custom IDEA command", "Transform")) | Out-Null
        $this.AvailableActions.Add([SimpleAction]::new("Filter Records", "Filter database records by criteria", "Data")) | Out-Null
        $this.AvailableActions.Add([SimpleAction]::new("Calculate Field", "Calculate derived field values", "Transform")) | Out-Null
        $this.AvailableActions.Add([SimpleAction]::new("Group Data", "Group records by field values", "Analysis")) | Out-Null
        $this.AvailableActions.Add([SimpleAction]::new("Export to CSV", "Export data to CSV format", "Export")) | Out-Null
    }
    
    [string] Render() {
        $this.Width = [Console]::WindowWidth
        $this.Height = [Console]::WindowHeight
        
        $sb = [System.Text.StringBuilder]::new()
        
        # Calculate pane widths (30% | 40% | 30%)
        $leftWidth = [int]($this.Width * 0.3) - 1
        $centerWidth = [int]($this.Width * 0.4) - 1  
        $rightWidth = $this.Width - $leftWidth - $centerWidth - 2
        
        # Ensure minimum widths
        $leftWidth = [Math]::Max($leftWidth, 20)
        $centerWidth = [Math]::Max($centerWidth, 25)
        $rightWidth = [Math]::Max($rightWidth, 15)
        
        $leftSep = $leftWidth
        $rightSep = $leftWidth + 1 + $centerWidth
        $contentHeight = $this.Height - 2  # Reserve status bar
        
        # Draw outer border and separators
        $sb.AppendLine("┌" + ("─" * ($leftWidth - 1)) + "┬" + ("─" * $centerWidth) + "┬" + ("─" * ($rightWidth - 1)) + "┐")
        
        for ($y = 1; $y -lt $contentHeight; $y++) {
            $sb.Append("│" + (" " * ($leftWidth - 1)) + "│" + (" " * $centerWidth) + "│" + (" " * ($rightWidth - 1)) + "│`n")
        }
        
        $sb.AppendLine("└" + ("─" * ($leftWidth - 1)) + "┴" + ("─" * $centerWidth) + "┴" + ("─" * ($rightWidth - 1)) + "┘")
        
        # Position cursor and draw content
        $content = $sb.ToString()
        [Console]::SetCursorPosition(0, 0)
        Write-Host -NoNewline $content
        
        # Pane titles with focus indicators
        $leftTitle = if ($this.FocusedPane -eq 0) { "`e[33m► 📚 Component Library`e[0m" } else { "📚 Component Library" }
        $centerTitle = if ($this.FocusedPane -eq 1) { "`e[33m► 🔧 Macro Sequence`e[0m" } else { "🔧 Macro Sequence" }
        $rightTitle = if ($this.FocusedPane -eq 2) { "`e[33m► 🎯 Context`e[0m" } else { "🎯 Context" }
        
        [Console]::SetCursorPosition(1, 1)
        Write-Host -NoNewline $leftTitle
        [Console]::SetCursorPosition($leftSep + 1, 1)
        Write-Host -NoNewline $centerTitle
        [Console]::SetCursorPosition($rightSep + 1, 1)
        Write-Host -NoNewline $rightTitle
        
        # Left pane: Component Library content
        $displayCount = [Math]::Min(($contentHeight - 3), $this.AvailableActions.Count)
        for ($i = 0; $i -lt $displayCount; $i++) {
            $action = $this.AvailableActions[$i]
            [Console]::SetCursorPosition(1, 3 + $i)
            
            $icon = switch ($action.Category) {
                "Analysis" { "📊" }
                "Data" { "📋" }
                "Export" { "📤" }
                "Transform" { "🔄" }
                default { "⚙️" }
            }
            
            $displayText = "$icon $($action.Name)"
            $highlight = if ($this.FocusedPane -eq 0 -and $i -eq $this.SelectedLibraryIndex) { "`e[43m`e[30m" } else { "" }
            $reset = if ($highlight) { "`e[0m" } else { "" }
            
            if ($displayText.Length -gt ($leftWidth - 2)) {
                $displayText = $displayText.Substring(0, $leftWidth - 5) + "..."
            }
            
            Write-Host -NoNewline "$highlight$displayText$reset"
        }
        
        # Center pane: Macro Sequence content
        [Console]::SetCursorPosition($leftSep + 1, 3)
        Write-Host -NoNewline "Steps: $($this.MacroSequence.Count)"
        
        if ($this.MacroSequence.Count -gt 0) {
            $seqDisplayCount = [Math]::Min(($contentHeight - 5), $this.MacroSequence.Count)
            for ($i = 0; $i -lt $seqDisplayCount; $i++) {
                $action = $this.MacroSequence[$i]
                [Console]::SetCursorPosition($leftSep + 1, 4 + $i)
                
                $highlight = if ($this.FocusedPane -eq 1 -and $i -eq $this.SelectedSequenceIndex) { "`e[43m`e[30m" } else { "" }
                $reset = if ($highlight) { "`e[0m" } else { "" }
                
                $stepText = "$($i + 1). $($action.Name)"
                if ($stepText.Length -gt ($centerWidth - 1)) {
                    $stepText = $stepText.Substring(0, $centerWidth - 4) + "..."
                }
                
                Write-Host -NoNewline "$highlight$stepText$reset"
            }
        } else {
            [Console]::SetCursorPosition($leftSep + 1, 4)
            Write-Host -NoNewline "No actions added"
            [Console]::SetCursorPosition($leftSep + 1, 5)
            Write-Host -NoNewline "Press Enter to add"
        }
        
        # Right pane: Context content  
        [Console]::SetCursorPosition($rightSep + 1, 3)
        Write-Host -NoNewline "Variables: $($this.Context.Keys.Count)"
        
        if ($this.Context.Keys.Count -gt 0) {
            $varCount = 0
            foreach ($varName in $this.Context.Keys) {
                if ($varCount -ge ($contentHeight - 5)) { break }
                [Console]::SetCursorPosition($rightSep + 1, 4 + $varCount)
                $value = $this.Context[$varName]
                if ($value.Length -gt ($rightWidth - 10)) {
                    $value = $value.Substring(0, $rightWidth - 13) + "..."
                }
                Write-Host -NoNewline "$varName=$value"
                $varCount++
            }
        } else {
            [Console]::SetCursorPosition($rightSep + 1, 4)
            Write-Host -NoNewline "No variables"
        }
        
        # Status bar
        [Console]::SetCursorPosition(0, $this.Height - 1)
        Write-Host -NoNewline ("`e[48;2;40;40;50m" + (" " * $this.Width))
        [Console]::SetCursorPosition(2, $this.Height - 1)
        
        $shortcuts = switch ($this.FocusedPane) {
            0 { "↑↓:Navigate | Enter:Add Action | Tab:Switch Pane | Q:Quit" }
            1 { "↑↓:Navigate | Enter:Edit | Del:Remove | Tab:Switch Pane | F5:Preview | Q:Quit" }
            2 { "Tab:Switch Pane | Q:Quit" }
        }
        
        $focusIndicator = switch ($this.FocusedPane) {
            0 { "[LIBRARY]" }
            1 { "[SEQUENCE]" } 
            2 { "[CONTEXT]" }
        }
        
        Write-Host -NoNewline "`e[38;2;200;200;200m$focusIndicator $shortcuts`e[0m"
        
        return ""
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::Tab) {
                $this.FocusedPane = ($this.FocusedPane + 1) % 3
                return $true
            }
            ([System.ConsoleKey]::UpArrow) {
                if ($this.FocusedPane -eq 0 -and $this.SelectedLibraryIndex -gt 0) {
                    $this.SelectedLibraryIndex--
                    return $true
                }
                if ($this.FocusedPane -eq 1 -and $this.SelectedSequenceIndex -gt 0) {
                    $this.SelectedSequenceIndex--
                    return $true
                }
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.FocusedPane -eq 0 -and $this.SelectedLibraryIndex -lt ($this.AvailableActions.Count - 1)) {
                    $this.SelectedLibraryIndex++
                    return $true
                }
                if ($this.FocusedPane -eq 1 -and $this.SelectedSequenceIndex -lt ($this.MacroSequence.Count - 1)) {
                    $this.SelectedSequenceIndex++
                    return $true
                }
            }
            ([System.ConsoleKey]::Enter) {
                if ($this.FocusedPane -eq 0) {
                    $this.AddActionToSequence()
                    return $true
                }
                if ($this.FocusedPane -eq 1) {
                    $this.EditSelectedAction()
                    return $true
                }
            }
            ([System.ConsoleKey]::Delete) {
                if ($this.FocusedPane -eq 1 -and $this.MacroSequence.Count -gt 0) {
                    $this.RemoveSelectedAction()
                    return $true
                }
            }
            ([System.ConsoleKey]::F5) {
                $this.PreviewScript()
                return $true
            }
        }
        
        switch ($key.KeyChar) {
            'q' { return $false }
            'Q' { return $false }
            'h' { $this.ShowHelp(); return $true }
        }
        
        return $true
    }
    
    [void] AddActionToSequence() {
        if ($this.SelectedLibraryIndex -ge 0 -and $this.SelectedLibraryIndex -lt $this.AvailableActions.Count) {
            $selectedAction = $this.AvailableActions[$this.SelectedLibraryIndex]
            $this.MacroSequence.Add($selectedAction) | Out-Null
            
            # Add to context
            $this.Context["step_$($this.MacroSequence.Count)_result"] = "output_$($selectedAction.Name.Replace(' ', '_').ToLower())"
        }
    }
    
    [void] RemoveSelectedAction() {
        if ($this.SelectedSequenceIndex -ge 0 -and $this.SelectedSequenceIndex -lt $this.MacroSequence.Count) {
            $this.MacroSequence.RemoveAt($this.SelectedSequenceIndex)
            if ($this.SelectedSequenceIndex -ge $this.MacroSequence.Count -and $this.MacroSequence.Count -gt 0) {
                $this.SelectedSequenceIndex = $this.MacroSequence.Count - 1
            }
        }
    }
    
    [void] EditSelectedAction() {
        if ($this.SelectedSequenceIndex -ge 0 -and $this.SelectedSequenceIndex -lt $this.MacroSequence.Count) {
            $action = $this.MacroSequence[$this.SelectedSequenceIndex]
            [Console]::SetCursorPosition(0, $this.Height - 2)
            Write-Host "Edit action: $($action.Name) - Press Enter to continue" -ForegroundColor Yellow
            [Console]::ReadKey($true) | Out-Null
        }
    }
    
    [void] PreviewScript() {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "                     GENERATED IDEASCRIPT PREVIEW             " -ForegroundColor White
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        
        if ($this.MacroSequence.Count -eq 0) {
            Write-Host "No actions in sequence. Add some actions first." -ForegroundColor Yellow
        } else {
            foreach ($action in $this.MacroSequence) {
                Write-Host "' $($action.Description)" -ForegroundColor Green
                Write-Host "Call $($action.Name.Replace(' ', ''))" -ForegroundColor Blue
                Write-Host ""
            }
        }
        
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "Press any key to return to MacroFactory..." -ForegroundColor White
        [Console]::ReadKey($true) | Out-Null
    }
    
    [void] ShowHelp() {
        Clear-Host
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "                        MACROFACTORY HELP                     " -ForegroundColor White
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "NAVIGATION:" -ForegroundColor Yellow
        Write-Host "  Tab           - Switch between panes" -ForegroundColor Gray
        Write-Host "  ↑↓            - Navigate within panes" -ForegroundColor Gray
        Write-Host "  Enter         - Add action (Library) / Edit action (Sequence)" -ForegroundColor Gray
        Write-Host "  Delete        - Remove selected action from sequence" -ForegroundColor Gray
        Write-Host "  F5            - Preview generated script" -ForegroundColor Gray
        Write-Host "  h             - Show this help" -ForegroundColor Gray
        Write-Host "  q, Esc        - Quit application" -ForegroundColor Gray
        Write-Host ""
        Write-Host "PANES:" -ForegroundColor Yellow
        Write-Host "  📚 Component Library - Available actions to add" -ForegroundColor Gray
        Write-Host "  🔧 Macro Sequence   - Your macro sequence" -ForegroundColor Gray
        Write-Host "  🎯 Context          - Variables and state" -ForegroundColor Gray
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "Press any key to return..." -ForegroundColor White
        [Console]::ReadKey($true) | Out-Null
    }
}

# Create and run application
try {
    Write-Host "Creating MacroFactory screen..." -ForegroundColor Gray
    $app = [MacroFactoryScreen]::new()
    
    Write-Host "MacroFactory ready!" -ForegroundColor Green
    Start-Sleep -Milliseconds 500
    
    # Hide cursor and setup console
    [Console]::CursorVisible = $false
    
    # Main interactive loop
    $running = $true
    
    while ($running) {
        $app.Render()
        
        # Handle input
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            
            if ($key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q' -or $key.Key -eq [System.ConsoleKey]::Escape) {
                $running = $false
            } else {
                $result = $app.HandleInput($key)
                if (-not $result) {
                    $running = $false
                }
            }
        }
        
        Start-Sleep -Milliseconds 50
    }
    
} catch {
    [Console]::CursorVisible = $true
    Write-Host "Application error: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    exit 1
}

# Cleanup
[Console]::CursorVisible = $true
Clear-Host
Write-Host "Thank you for using MacroFactory!" -ForegroundColor Green