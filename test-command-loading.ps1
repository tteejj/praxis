#!/usr/bin/env pwsh
# test-command-loading.ps1 - Test command loading from unified data

Write-Host "Testing command loading from unified data..." -ForegroundColor Cyan

try {
    # Load dependencies
    . "./TaskPro/Core/StringCache.ps1"
    . "./TaskPro/Components/Shared/VT100.ps1"
    . "./TaskPro/Services/PraxisDataService.ps1"
    . "./TaskPro/Models/External/Command.ps1"
    . "./TaskPro/Services/External/CommandService.ps1"
    
    Write-Host "Dependencies loaded successfully" -ForegroundColor Green
    
    # Initialize PraxisDataService
    $dataFile = Join-Path (Get-Location) "_ProjectData/praxis-unified.json"
    [PraxisDataService]::Initialize($dataFile)
    
    Write-Host "PraxisDataService initialized" -ForegroundColor Green
    
    # Create CommandService
    $commandService = [CommandService]::new()
    
    Write-Host "CommandService created" -ForegroundColor Green
    
    # Test getting all commands
    $commands = $commandService.GetAllCommands()
    
    Write-Host "Commands loaded: $($commands.Count)" -ForegroundColor Yellow
    
    if ($commands.Count -gt 0) {
        Write-Host "First command details:" -ForegroundColor Green
        $firstCommand = $commands[0]
        Write-Host "  Type: $($firstCommand.GetType().Name)" -ForegroundColor DarkGray
        Write-Host "  Title: $($firstCommand.Title)" -ForegroundColor DarkGray
        Write-Host "  CommandText: $($firstCommand.CommandText)" -ForegroundColor DarkGray
        Write-Host "  Tags: $($firstCommand.Tags -join ', ')" -ForegroundColor DarkGray
        
        # Test GetDisplayText method
        try {
            $displayText = $firstCommand.GetDisplayText()
            Write-Host "  DisplayText: $displayText" -ForegroundColor DarkGray
            Write-Host "  DisplayText Length: $($displayText.Length)" -ForegroundColor DarkGray
        } catch {
            Write-Host "  GetDisplayText Error: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "No commands found!" -ForegroundColor Red
        
        # Check unified data directly
        $data = [PraxisDataService]::GetCommands()
        Write-Host "Raw commands from PraxisDataService: $($data.Count)" -ForegroundColor Yellow
        
        if ($data.Count -gt 0) {
            Write-Host "First raw command:" -ForegroundColor Yellow
            $rawCmd = $data[0]
            Write-Host "  Title: $($rawCmd.Title)" -ForegroundColor DarkGray
            Write-Host "  CommandText: $($rawCmd.CommandText)" -ForegroundColor DarkGray
        }
    }
    
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Exception type: $($_.Exception.GetType().FullName)" -ForegroundColor DarkGray
    Write-Host "Stack trace:" -ForegroundColor DarkGray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
}