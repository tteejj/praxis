#!/usr/bin/env pwsh
# CommandLibrary.ps1 - Standalone Command Library Application
# Based on the CommandLibraryScreen from the main Praxis system

param(
    [switch]$Debug,
    [string]$Command = "",    # Quick copy a command by search
    [string]$Tag = "",        # Filter by tag
    [string]$Group = "",      # Filter by group
    [switch]$List,           # List all commands
    [switch]$Tags,           # Show tag statistics
    [switch]$Help            # Show help
)

# Set location to script directory
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $PSScriptRoot

# Store debug flag globally
$global:Debug = $Debug

function Show-Help {
    Write-Host "CommandLibrary - Standalone Command Management Tool" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\CommandLibrary.ps1                    # Start interactive mode"
    Write-Host "  .\CommandLibrary.ps1 -Command 'text'    # Quick search and copy"
    Write-Host "  .\CommandLibrary.ps1 -Tag 'docker'      # Filter by tag"
    Write-Host "  .\CommandLibrary.ps1 -Group 'Git'       # Filter by group"
    Write-Host "  .\CommandLibrary.ps1 -List              # List all commands"
    Write-Host "  .\CommandLibrary.ps1 -Tags              # Show tag statistics"
    Write-Host "  .\CommandLibrary.ps1 -Help              # Show this help"
    Write-Host ""
    Write-Host "Interactive Mode Keys:" -ForegroundColor Yellow
    Write-Host "  Enter       Copy selected command to clipboard"
    Write-Host "  E           Edit selected command"
    Write-Host "  N           Create new command"
    Write-Host "  D           Delete selected command"
    Write-Host "  R           Run selected command"
    Write-Host "  T           Show tag statistics"
    Write-Host "  F3          Search mode"
    Write-Host "  Q           Quit"
    Write-Host ""
    Write-Host "Features:" -ForegroundColor Yellow
    Write-Host "  • Store and organize reusable commands"
    Write-Host "  • Search by title, description, tags, or command text"
    Write-Host "  • Group commands by category"
    Write-Host "  • Track usage statistics"
    Write-Host "  • Quick clipboard copying"
    Write-Host "  • Execute commands directly"
    Write-Host "  • Tag-based organization and filtering"
    Write-Host "  • Smart tag suggestions"
    Write-Host ""
    Write-Host "Search Syntax:" -ForegroundColor Yellow
    Write-Host "  #docker         Search for 'docker' tag"
    Write-Host "  tag:git         Search for 'git' tag"
    Write-Host "  group:Network   Search in 'Network' group"
    Write-Host "  regular text    General search across all fields"
    Write-Host ""
}

function Show-CommandList {
    param([CommandService]$service)
    
    $commands = $service.GetAllCommands()
    
    if ($commands.Count -eq 0) {
        Write-Host "No commands found. Run without parameters to add commands." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Command Library ($($commands.Count) commands)" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Gray
    
    $groups = $commands | Group-Object Group | Sort-Object Name
    
    foreach ($group in $groups) {
        $groupName = if ([string]::IsNullOrWhiteSpace($group.Name)) { "(No Group)" } else { $group.Name }
        Write-Host ""
        Write-Host $groupName -ForegroundColor Yellow
        Write-Host ("-" * $groupName.Length) -ForegroundColor Gray
        
        foreach ($command in ($group.Group | Sort-Object Title)) {
            $title = if ([string]::IsNullOrWhiteSpace($command.Title)) { 
                $command.CommandText.Substring(0, [Math]::Min(40, $command.CommandText.Length))
            } else {
                $command.Title
            }
            
            $usageInfo = if ($command.UseCount -gt 0) { " (used $($command.UseCount) times)" } else { "" }
            
            Write-Host "  $title$usageInfo" -ForegroundColor White
            if (-not [string]::IsNullOrWhiteSpace($command.Description)) {
                Write-Host "    $($command.Description)" -ForegroundColor Gray
            }
            Write-Host "    Command: $($command.CommandText)" -ForegroundColor Green
            
            if ($command.Tags.Count -gt 0) {
                Write-Host "    Tags: $($command.Tags -join ', ')" -ForegroundColor Magenta
            }
        }
    }
}

function Quick-SearchAndCopy {
    param([CommandService]$service, [string]$searchText)
    
    $commands = $service.SearchCommands($searchText)
    
    if ($commands.Count -eq 0) {
        Write-Host "No commands found matching '$searchText'" -ForegroundColor Yellow
        return
    }
    
    if ($commands.Count -eq 1) {
        # Single match - copy directly
        $command = $commands[0]
        $service.CopyToClipboard($command.Id)
        Write-Host "Copied to clipboard: $($command.CommandText)" -ForegroundColor Green
        return
    }
    
    # Multiple matches - show options
    Write-Host "Multiple commands found matching '$searchText':" -ForegroundColor Yellow
    Write-Host ""
    
    for ($i = 0; $i -lt $commands.Count; $i++) {
        $command = $commands[$i]
        Write-Host "  $($i + 1). $($command.GetDisplayText())" -ForegroundColor White
        Write-Host "      $($command.CommandText)" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Enter number to copy (1-$($commands.Count)), or press Enter to cancel: " -NoNewline -ForegroundColor Yellow
    $choice = Read-Host
    
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $commands.Count) {
        $selectedCommand = $commands[[int]$choice - 1]
        $service.CopyToClipboard($selectedCommand.Id)
        Write-Host "Copied to clipboard: $($selectedCommand.CommandText)" -ForegroundColor Green
    }
}

function Show-TagStatistics {
    param([CommandService]$service)
    
    $tagStats = $service.GetTagStatistics()
    $allTags = $service.GetTags()
    
    if ($allTags.Count -eq 0) {
        Write-Host "No tags found in command library." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Tag Statistics" -ForegroundColor Cyan
    Write-Host ("=" * 40) -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Total unique tags: $($allTags.Count)" -ForegroundColor White
    Write-Host ""
    
    # Show popular tags
    Write-Host "Most popular tags:" -ForegroundColor Yellow
    $popularTags = $service.GetPopularTags(10)
    foreach ($tag in $popularTags) {
        $count = $tagStats[$tag]
        Write-Host "  #$tag ($count commands)" -ForegroundColor Magenta
    }
    
    Write-Host ""
    Write-Host "All tags:" -ForegroundColor Yellow
    $sortedTags = $allTags | Sort-Object
    $tagLine = ""
    foreach ($tag in $sortedTags) {
        $count = $tagStats[$tag]
        $tagLine += "#$tag($count) "
        if ($tagLine.Length -gt 60) {
            Write-Host "  $tagLine" -ForegroundColor Magenta
            $tagLine = ""
        }
    }
    if ($tagLine) {
        Write-Host "  $tagLine" -ForegroundColor Magenta
    }
}

function Show-CommandsByTag {
    param([CommandService]$service, [string]$tag)
    
    $commands = $service.GetCommandsByTag($tag)
    
    if ($commands.Count -eq 0) {
        Write-Host "No commands found with tag '#$tag'" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Commands with tag '#$tag' ($($commands.Count) found)" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Gray
    Write-Host ""
    
    foreach ($command in ($commands | Sort-Object Title)) {
        $title = if ([string]::IsNullOrWhiteSpace($command.Title)) { 
            $command.CommandText.Substring(0, [Math]::Min(50, $command.CommandText.Length))
        } else {
            $command.Title
        }
        
        $usageInfo = if ($command.UseCount -gt 0) { " (used $($command.UseCount) times)" } else { "" }
        $group = if ($command.Group) { " [$($command.Group)]" } else { "" }
        
        Write-Host "$title$group$usageInfo" -ForegroundColor White
        Write-Host "  Command: $($command.CommandText)" -ForegroundColor Green
        
        if (-not [string]::IsNullOrWhiteSpace($command.Description)) {
            Write-Host "  Description: $($command.Description)" -ForegroundColor Gray
        }
        
        if ($command.Tags.Count -gt 1) {
            $otherTags = $command.Tags | Where-Object { $_ -ne $tag }
            if ($otherTags.Count -gt 0) {
                Write-Host "  Other tags: #$($otherTags -join ' #')" -ForegroundColor Magenta
            }
        }
        Write-Host ""
    }
}

function Show-CommandsByGroup {
    param([CommandService]$service, [string]$group)
    
    $commands = $service.GetCommandsByGroup($group)
    
    if ($commands.Count -eq 0) {
        Write-Host "No commands found in group '$group'" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Commands in group '$group' ($($commands.Count) found)" -ForegroundColor Cyan
    Write-Host ("=" * 50) -ForegroundColor Gray
    Write-Host ""
    
    foreach ($command in ($commands | Sort-Object Title)) {
        $title = if ([string]::IsNullOrWhiteSpace($command.Title)) { 
            $command.CommandText.Substring(0, [Math]::Min(50, $command.CommandText.Length))
        } else {
            $command.Title
        }
        
        $usageInfo = if ($command.UseCount -gt 0) { " (used $($command.UseCount) times)" } else { "" }
        
        Write-Host "$title$usageInfo" -ForegroundColor White
        Write-Host "  Command: $($command.CommandText)" -ForegroundColor Green
        
        if (-not [string]::IsNullOrWhiteSpace($command.Description)) {
            Write-Host "  Description: $($command.Description)" -ForegroundColor Gray
        }
        
        if ($command.Tags.Count -gt 0) {
            Write-Host "  Tags: #$($command.Tags -join ' #')" -ForegroundColor Magenta
        }
        Write-Host ""
    }
}

# Load required files
try {
    . "$PSScriptRoot\Core\VT100.ps1"
    . "$PSScriptRoot\Models\Command.ps1"
    . "$PSScriptRoot\Services\ColorThemeService.ps1"
    . "$PSScriptRoot\Services\CommandService.ps1"
    . "$PSScriptRoot\Components\SimpleListBox.ps1"
    . "$PSScriptRoot\Components\SimpleDialog.ps1"
    . "$PSScriptRoot\Screens\CommandEditDialog.ps1"
    . "$PSScriptRoot\Screens\CommandLibraryScreen.ps1"
} catch {
    Write-Host "Error loading required files: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Initialize console (defensive)
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    # Console operations may not be supported in all environments
}

# Save initial console state (defensive)
try {
    $initialCursor = [Console]::CursorVisible
} catch {
    $initialCursor = $true
}

# Error handler
trap {
    [Console]::CursorVisible = $initialCursor
    Write-Host "`nFatal error: $_" -ForegroundColor Red
    if ($global:Debug) {
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    }
    exit 1
}

# Main execution
try {
    if ($Help) {
        Show-Help
        exit 0
    }
    
    # Create service
    $commandService = [CommandService]::new()
    
    if ($List) {
        Show-CommandList $commandService
        exit 0
    }
    
    if ($Tags) {
        Show-TagStatistics $commandService
        exit 0
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Tag)) {
        Show-CommandsByTag $commandService $Tag
        exit 0
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Group)) {
        Show-CommandsByGroup $commandService $Group
        exit 0
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Command)) {
        Quick-SearchAndCopy $commandService $Command
        exit 0
    }
    
    # Interactive mode
    Write-Host "CommandLibrary - Loading..." -ForegroundColor Cyan
    Start-Sleep -Milliseconds 500
    
    $screen = [CommandLibraryScreen]::new($commandService)
    $screen.Run()
    
} catch {
    [Console]::CursorVisible = $initialCursor
    Write-Host "`nApplication error: $_" -ForegroundColor Red
    if ($global:Debug) {
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    }
    exit 1
} finally {
    [Console]::CursorVisible = $initialCursor
    Show-Cursor
}

Write-Host "Thanks for using CommandLibrary!" -ForegroundColor Green