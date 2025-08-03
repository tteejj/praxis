# CommandLibraryScreen.ps1 - Main command library screen
# Simplified standalone version based on the original CommandLibraryScreen

class CommandLibraryScreen {
    # Properties
    [int]$Width = 80
    [int]$Height = 25
    [string]$Title = "Command Library"
    
    # Components
    [SimpleListBox]$CommandList
    [CommandService]$CommandService
    
    # State
    [bool]$Running = $true
    [string]$StatusMessage = ""
    
    CommandLibraryScreen([CommandService]$commandService) {
        $this.CommandService = $commandService
        $this.InitializeComponents()
    }
    
    [void] InitializeComponents() {
        # Get console size
        $this.Width = [Console]::WindowWidth
        $this.Height = [Console]::WindowHeight
        
        # Create command list
        $this.CommandList = [SimpleListBox]::new()
        $this.CommandList.SetBounds(0, 2, $this.Width, $this.Height - 4)
        $this.CommandList.Title = ""
        $this.CommandList.SearchPrompt = "Search commands... (Type to search, F3 for search mode)"
        
        # Set up search filter for commands
        $service = $this.CommandService
        $this.CommandList.SearchFilter = {
            param($command, $query)
            if ([string]::IsNullOrWhiteSpace($query)) { return $true }
            
            $query = $query.ToLower()
            return $command.Title.ToLower().Contains($query) -or
                   $command.Description.ToLower().Contains($query) -or
                   $command.CommandText.ToLower().Contains($query) -or
                   $command.Group.ToLower().Contains($query) -or
                   ($command.Tags | Where-Object { $_.ToLower().Contains($query) }).Count -gt 0
        }.GetNewClosure()
        
        # Custom renderer for commands with tags
        $this.CommandList.ItemRenderer = {
            param($command)
            if (-not $command) { return "" }
            
            $displayText = $command.GetDisplayText()
            
            # Add usage count if > 0
            if ($command.UseCount -gt 0) {
                $displayText += " ★$($command.UseCount)"
            }
            
            # Add tags with color (simplified for now)
            if ($command.Tags.Count -gt 0) {
                $tagDisplay = " #" + ($command.Tags -join " #")
                $displayText += $tagDisplay
            }
            
            return $displayText
        }
        
        # Handle selection changes (Enter key)
        $screen = $this
        $this.CommandList.OnSelectionChanged = {
            param($command)
            $screen.CopySelectedCommand()
        }.GetNewClosure()
        
        $this.LoadCommands()
    }
    
    [void] LoadCommands() {
        $commands = $this.CommandService.GetAllCommands()
        $this.CommandList.SetItems($commands)
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Clear screen
        [void]$sb.Append([VT]::Clear())
        
        # Title bar
        [void]$sb.Append([VT]::MoveTo(0, 0))
        [void]$sb.Append([VT]::Bold() + [VT]::Cyan())
        [void]$sb.Append($this.Title.PadRight($this.Width))
        [void]$sb.Append([VT]::Reset())
        
        # Separator
        [void]$sb.Append([VT]::MoveTo(0, 1))
        [void]$sb.Append("═" * $this.Width)
        
        # Command list
        [void]$sb.Append($this.CommandList.Render())
        
        # Status bar
        $statusY = $this.Height - 2
        [void]$sb.Append([VT]::MoveTo(0, $statusY))
        [void]$sb.Append("─" * $this.Width)
        
        [void]$sb.Append([VT]::MoveTo(0, $statusY + 1))
        [void]$sb.Append([VT]::Gray())
        
        if (-not [string]::IsNullOrWhiteSpace($this.StatusMessage)) {
            [void]$sb.Append($this.StatusMessage.PadRight($this.Width))
        } else {
            [void]$sb.Append("Enter:Copy  E:Edit  N:New  D:Delete  R:Run  T:Tags  Q:Quit  F3:Search")
        }
        [void]$sb.Append([VT]::Reset())
        
        return $sb.ToString()
    }
    
    [void] Run() {
        $originalCursor = $true
        try {
            $originalCursor = [Console]::CursorVisible
            [Console]::CursorVisible = $false
        } catch {
            # Console operations not supported in this environment
        }
        
        try {
            while ($this.Running) {
                # Render screen
                Write-Host -NoNewline $this.Render()
                
                # Clear status message after display
                if (-not [string]::IsNullOrWhiteSpace($this.StatusMessage)) {
                    Start-Sleep -Milliseconds 1500
                    $this.StatusMessage = ""
                    continue
                }
                
                # Handle input (defensive)
                try {
                    if ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        $this.HandleInput($key)
                    }
                } catch {
                    # Console input not available - exit gracefully
                    $this.Running = $false
                }
                
                Start-Sleep -Milliseconds 50
            }
        } finally {
            try {
                [Console]::CursorVisible = $originalCursor
            } catch {
                # Console operations not supported
            }
        }
    }
    
    [void] HandleInput([System.ConsoleKeyInfo]$key) {
        # Let the command list handle its input first
        if ($this.CommandList.HandleInput($key)) {
            return
        }
        
        # Handle screen-level shortcuts
        switch ($key.KeyChar.ToString().ToLower()) {
            'e' { $this.EditCommand() }
            'n' { $this.NewCommand() }
            'd' { $this.DeleteCommand() }
            'r' { $this.RunCommand() }
            't' { $this.ShowTagStatistics() }
            'q' { $this.Running = $false }
        }
    }
    
    [void] CopySelectedCommand() {
        $selectedCommand = $this.CommandList.GetSelectedItem()
        if ($selectedCommand) {
            try {
                $this.CommandService.CopyToClipboard($selectedCommand.Id)
                $this.StatusMessage = "Command copied to clipboard!"
                $this.LoadCommands()  # Refresh to show updated usage count
            } catch {
                $this.StatusMessage = "Failed to copy command: $($_.Exception.Message)"
            }
        }
    }
    
    [void] RunCommand() {
        $selectedCommand = $this.CommandList.GetSelectedItem()
        if (-not $selectedCommand) {
            $this.StatusMessage = "No command selected"
            return
        }
        
        try {
            # Show confirmation
            Write-Host "`nAbout to run command:" -ForegroundColor Yellow
            Write-Host $selectedCommand.CommandText -ForegroundColor White
            Write-Host ""
            Write-Host "Press Enter to confirm, Escape to cancel" -ForegroundColor Gray
            
            try {
                $key = [Console]::ReadKey($true)
            } catch {
                # If console input not available, don't execute
                $this.StatusMessage = "Console input not available"
                return
            }
            if ($key.Key -eq [System.ConsoleKey]::Enter) {
                # Execute the command
                $result = Invoke-Expression -Command $selectedCommand.CommandText
                
                # Update usage count
                $this.CommandService.IncrementUseCount($selectedCommand.Id)
                
                # Show result
                Write-Host ""
                Write-Host "Command executed successfully!" -ForegroundColor Green
                Write-Host "Press any key to continue..." -ForegroundColor Gray
                try {
                    [Console]::ReadKey($true) | Out-Null
                } catch {
                    Start-Sleep -Seconds 2
                }
                
                $this.LoadCommands()
            }
        } catch {
            Write-Host ""
            Write-Host "Command failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            try {
                [Console]::ReadKey($true) | Out-Null
            } catch {
                Start-Sleep -Seconds 2
            }
        }
    }
    
    [void] NewCommand() {
        $dialog = [CommandEditDialog]::new($this.CommandService)
        $screen = $this
        $dialog.OnSave = {
            param($command)
            $screen.LoadCommands()
            $screen.StatusMessage = "Command created successfully!"
        }.GetNewClosure()
        
        $this.ShowDialog($dialog)
    }
    
    [void] EditCommand() {
        $selectedCommand = $this.CommandList.GetSelectedItem()
        if (-not $selectedCommand) {
            $this.StatusMessage = "No command selected"
            return
        }
        
        $dialog = [CommandEditDialog]::new($this.CommandService, $selectedCommand)
        $screen = $this
        $dialog.OnSave = {
            param($command)
            $screen.LoadCommands()
            $screen.StatusMessage = "Command updated successfully!"
        }.GetNewClosure()
        
        $this.ShowDialog($dialog)
    }
    
    [void] DeleteCommand() {
        $selectedCommand = $this.CommandList.GetSelectedItem()
        if (-not $selectedCommand) {
            $this.StatusMessage = "No command selected"
            return
        }
        
        # Simple confirmation (non-interactive fallback for unsupported consoles)
        try {
            Write-Host "`nDelete Command" -ForegroundColor Red
            Write-Host ""
            Write-Host "Are you sure you want to delete this command?" -ForegroundColor Yellow
            Write-Host ""
            Write-Host $selectedCommand.GetDisplayText() -ForegroundColor White
            Write-Host ""
            Write-Host "Press 'y' to confirm, any other key to cancel" -ForegroundColor Gray
            
            $key = [Console]::ReadKey($true)
            if ($key.KeyChar.ToString().ToLower() -eq 'y') {
                $this.CommandService.DeleteCommand($selectedCommand.Id)
                $this.LoadCommands()
                $this.StatusMessage = "Command deleted successfully!"
            }
        } catch {
            # Console input not available - use Read-Host as fallback
            Write-Host "`nDelete Command" -ForegroundColor Red
            Write-Host "Command: $($selectedCommand.GetDisplayText())" -ForegroundColor White
            $response = Read-Host "Delete this command? (y/N)"
            if ($response.ToLower() -eq 'y') {
                $this.CommandService.DeleteCommand($selectedCommand.Id)
                $this.LoadCommands()
                $this.StatusMessage = "Command deleted successfully!"
            }
        }
    }
    
    [void] ShowTagStatistics() {
        Write-Host "`n" # Clear some space
        
        Write-Host "Tag Statistics" -ForegroundColor Cyan
        Write-Host ("=" * 50) -ForegroundColor Gray
        Write-Host ""
        
        $tagStats = $this.CommandService.GetTagStatistics()
        $allTags = $this.CommandService.GetTags()
        
        if ($allTags.Count -eq 0) {
            Write-Host "No tags found in command library." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Gray
            try {
                [Console]::ReadKey($true) | Out-Null
            } catch {
                Start-Sleep -Seconds 2
            }
            return
        }
        
        Write-Host "Total unique tags: $($allTags.Count)" -ForegroundColor White
        Write-Host ""
        
        # Show popular tags
        Write-Host "Most popular tags:" -ForegroundColor Yellow
        $popularTags = $this.CommandService.GetPopularTags(10)
        foreach ($tag in $popularTags) {
            $count = $tagStats[$tag]
            $commands = $this.CommandService.GetCommandsByTag($tag)
            Write-Host "  #$tag" -ForegroundColor Magenta -NoNewline
            Write-Host " ($count commands)" -ForegroundColor Gray
            
            # Show first few commands with this tag
            $exampleCommands = $commands | Select-Object -First 3
            foreach ($cmd in $exampleCommands) {
                $cmdTitle = if ($cmd.Title) { $cmd.Title } else { $cmd.CommandText.Substring(0, [Math]::Min(40, $cmd.CommandText.Length)) }
                Write-Host "    - $cmdTitle" -ForegroundColor DarkGray
            }
            if ($commands.Count -gt 3) {
                Write-Host "    ... and $($commands.Count - 3) more" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
        
        Write-Host ""
        Write-Host "All tags (alphabetical):" -ForegroundColor Yellow
        $sortedTags = $allTags | Sort-Object
        $tagsPerLine = 5
        for ($i = 0; $i -lt $sortedTags.Count; $i += $tagsPerLine) {
            $lineTags = $sortedTags[$i..([Math]::Min($i + $tagsPerLine - 1, $sortedTags.Count - 1))]
            $tagLine = ""
            foreach ($tag in $lineTags) {
                $count = $tagStats[$tag]
                $tagLine += "#$tag($count)".PadRight(15)
            }
            Write-Host "  $tagLine" -ForegroundColor Magenta
        }
        
        Write-Host ""
        Write-Host "Search syntax examples:" -ForegroundColor Yellow
        Write-Host "  #docker          Find commands with 'docker' tag" -ForegroundColor Gray
        Write-Host "  tag:git          Find commands with 'git' tag" -ForegroundColor Gray
        Write-Host "  group:PowerShell Find commands in 'PowerShell' group" -ForegroundColor Gray
        
        Write-Host ""
        Write-Host "Press any key to continue..." -ForegroundColor Gray
        try {
            [Console]::ReadKey($true) | Out-Null
        } catch {
            Start-Sleep -Seconds 2
        }
    }
    
    [void] ShowDialog([SimpleDialog]$dialog) {
        $originalCursor = $true
        try {
            $originalCursor = [Console]::CursorVisible
            [Console]::CursorVisible = $true
        } catch {
            # Console not supported
        }
        
        try {
            while ($dialog.Visible) {
                Write-Host -NoNewline $dialog.Render()
                
                try {
                    if ([Console]::KeyAvailable) {
                        $key = [Console]::ReadKey($true)
                        if (-not $dialog.HandleInput($key)) {
                            break
                        }
                    }
                } catch {
                    # Console input not available - exit dialog
                    $dialog.Visible = $false
                    break
                }
                
                Start-Sleep -Milliseconds 50
            }
        } finally {
            try {
                [Console]::CursorVisible = $originalCursor
            } catch {
                # Console not supported
            }
        }
    }
}