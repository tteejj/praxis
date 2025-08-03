#!/usr/bin/env pwsh

# PRAXIS NEW ARCHITECTURE DEMO
# Quick launcher to test the new CRUDScreen and UnifiedDialog implementations

param(
    [switch]$Debug,
    [switch]$Performance
)

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "PRAXIS NEW ARCHITECTURE DEMO" -ForegroundColor Yellow
Write-Host "Testing Phase 1 implementations: UnifiedDialog + CRUDScreen" -ForegroundColor Yellow
Write-Host "=" * 80 -ForegroundColor Cyan

# Load the framework
Write-Host "`nLoading PRAXIS with new architecture..." -ForegroundColor Green
try {
    . "$PSScriptRoot/Start.ps1" -LoadOnly -Debug:$Debug
    Write-Host "✓ Framework loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to load framework: $_" -ForegroundColor Red
    exit 1
}

# Quick validation that new classes are available
Write-Host "`nValidating new architecture classes..." -ForegroundColor Green
try {
    $unifiedDialogTest = [UnifiedDialog] -ne $null
    $crudScreenTest = [CRUDScreen] -ne $null
    $projectsScreenNewTest = [ProjectsScreenNew] -ne $null
    $newProjectDialogNewTest = [NewProjectDialogNew] -ne $null
    
    Write-Host "✓ UnifiedDialog class available" -ForegroundColor Green
    Write-Host "✓ CRUDScreen class available" -ForegroundColor Green
    Write-Host "✓ ProjectsScreenNew class available" -ForegroundColor Green
    Write-Host "✓ NewProjectDialogNew class available" -ForegroundColor Green
} catch {
    Write-Host "✗ Architecture validation failed: $_" -ForegroundColor Red
    Write-Host "Make sure all Phase 1 files are implemented correctly" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n" + "=" * 80 -ForegroundColor Cyan
Write-Host "DEMO MENU - Choose what to test:" -ForegroundColor Yellow
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "1. Launch NEW ProjectsScreen (CRUDScreen-based)" -ForegroundColor White
Write-Host "2. Test NEW Project Dialogs (UnifiedDialog-based)" -ForegroundColor White
Write-Host "3. Side-by-side comparison (Old vs New)" -ForegroundColor White
Write-Host "4. Launch full PRAXIS with new architecture enabled" -ForegroundColor White
Write-Host "5. Show code comparison stats" -ForegroundColor White
Write-Host "Q. Quit" -ForegroundColor White
Write-Host ""

do {
    $choice = Read-Host "Enter your choice (1-5, Q)"
    
    switch ($choice.ToUpper()) {
        "1" {
            Write-Host "`nLaunching NEW ProjectsScreen (CRUDScreen-based)..." -ForegroundColor Green
            Write-Host "Features: Auto service injection, built-in CRUD shortcuts, simplified code" -ForegroundColor DarkGray
            Write-Host ""
            
            try {
                $newProjectsScreen = [ProjectsScreenNew]::new()
                $global:ScreenManager.Push($newProjectsScreen)
                $global:ScreenManager.Run()
            } catch {
                Write-Host "Error launching new ProjectsScreen: $_" -ForegroundColor Red
                Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
            }
            break
        }
        
        "2" {
            Write-Host "`nTesting NEW Project Dialogs (UnifiedDialog-based)..." -ForegroundColor Green
            Write-Host "Features: Consistent themes, automatic layout, simplified field management" -ForegroundColor DarkGray
            Write-Host ""
            
            try {
                Write-Host "Creating New Project Dialog..." -ForegroundColor DarkGray
                $newDialog = [NewProjectDialogNew]::new()
                $global:ScreenManager.Push($newDialog)
                $result = $newDialog.ShowModal()
                
                if ($result -eq "OK") {
                    Write-Host "✓ Dialog completed successfully" -ForegroundColor Green
                    Write-Host "Project Name: $($newDialog.GetFieldValue('name'))" -ForegroundColor DarkGray
                } else {
                    Write-Host "Dialog cancelled" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "Error testing new dialogs: $_" -ForegroundColor Red
            }
            break
        }
        
        "3" {
            Write-Host "`nSide-by-side comparison not implemented yet" -ForegroundColor Yellow
            Write-Host "Use choice 5 to see code statistics" -ForegroundColor DarkGray
            break
        }
        
        "4" {
            Write-Host "`nLaunching full PRAXIS with new architecture enabled..." -ForegroundColor Green
            Write-Host "Note: Old screens still use original architecture" -ForegroundColor DarkGray
            Write-Host "New screens available in Tests/ folder" -ForegroundColor DarkGray
            Write-Host ""
            
            try {
                $global:ScreenManager.Run()
            } catch {
                Write-Host "Error launching PRAXIS: $_" -ForegroundColor Red
            }
            break
        }
        
        "5" {
            Write-Host "`nCODE REDUCTION STATISTICS" -ForegroundColor Yellow
            Write-Host "=" * 50 -ForegroundColor Yellow
            
            # Count lines in original vs new implementations
            try {
                $originalProjectsScreen = Get-Content "$PSScriptRoot/Screens/ProjectsScreen.ps1" | Measure-Object -Line
                $newProjectsScreen = Get-Content "$PSScriptRoot/Tests/ProjectsScreenNew.ps1" | Measure-Object -Line
                
                $originalNewDialog = Get-Content "$PSScriptRoot/Screens/NewProjectDialog.ps1" | Measure-Object -Line
                $newNewDialog = Get-Content "$PSScriptRoot/Tests/NewProjectDialogNew.ps1" | Measure-Object -Line
                
                $originalEditDialog = Get-Content "$PSScriptRoot/Screens/EditProjectDialog.ps1" | Measure-Object -Line
                $newEditDialog = Get-Content "$PSScriptRoot/Tests/EditProjectDialogNew.ps1" | Measure-Object -Line
                
                Write-Host "ProjectsScreen:"
                Write-Host "  Original: $($originalProjectsScreen.Lines) lines"
                Write-Host "  New:      $($newProjectsScreen.Lines) lines"
                $reduction = [math]::Round((1 - ($newProjectsScreen.Lines / $originalProjectsScreen.Lines)) * 100, 1)
                Write-Host "  Reduction: $reduction%" -ForegroundColor Green
                
                Write-Host "`nNewProjectDialog:"
                Write-Host "  Original: $($originalNewDialog.Lines) lines"
                Write-Host "  New:      $($newNewDialog.Lines) lines"
                $reduction = [math]::Round((1 - ($newNewDialog.Lines / $originalNewDialog.Lines)) * 100, 1)
                Write-Host "  Reduction: $reduction%" -ForegroundColor Green
                
                Write-Host "`nEditProjectDialog:"
                Write-Host "  Original: $($originalEditDialog.Lines) lines"
                Write-Host "  New:      $($newEditDialog.Lines) lines"
                $reduction = [math]::Round((1 - ($newEditDialog.Lines / $originalEditDialog.Lines)) * 100, 1)
                Write-Host "  Reduction: $reduction%" -ForegroundColor Green
                
                $totalOriginal = $originalProjectsScreen.Lines + $originalNewDialog.Lines + $originalEditDialog.Lines
                $totalNew = $newProjectsScreen.Lines + $newNewDialog.Lines + $newEditDialog.Lines
                $totalReduction = [math]::Round((1 - ($totalNew / $totalOriginal)) * 100, 1)
                
                Write-Host "`nTOTAL REDUCTION: $totalReduction%" -ForegroundColor Yellow
                Write-Host "($totalOriginal lines → $totalNew lines)" -ForegroundColor DarkGray
                
            } catch {
                Write-Host "Error calculating statistics: $_" -ForegroundColor Red
            }
            
            Write-Host "`nPress any key to continue..."
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            break
        }
        
        "Q" {
            Write-Host "`nExiting demo..." -ForegroundColor Cyan
            return
        }
        
        default {
            Write-Host "Invalid choice. Please enter 1-5 or Q." -ForegroundColor Red
        }
    }
} while ($true)