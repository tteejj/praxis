# ValidatePhase1Architecture.ps1 - Test script to validate the new architecture
# This script tests that the converted screens and dialogs work identically to originals

param(
    [switch]$TestNew,
    [switch]$TestOriginal,
    [switch]$Compare
)

# Import required base classes and components
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$praxisRoot = Split-Path -Parent $scriptDir

# Load Praxis core
. "$praxisRoot\Start.ps1"

function Test-OriginalImplementation {
    Write-Host "Testing Original ProjectsScreen Implementation..." -ForegroundColor Yellow
    
    try {
        # Create original screen
        $screen = [ProjectsScreen]::new()
        $screen.OnInitialize()
        
        # Validate service injection
        if (-not $screen.ProjectService) {
            throw "Original: ProjectService not injected"
        }
        if (-not $screen.EventBus) {
            throw "Original: EventBus not injected"
        }
        
        # Validate grid setup
        if (-not $screen.ProjectGrid) {
            throw "Original: ProjectGrid not created"
        }
        
        # Validate shortcuts work
        $key = [System.ConsoleKeyInfo]::new('n', [System.ConsoleKey]::N, $false, $false, $false)
        $handled = $screen.HandleScreenInput($key)
        if (-not $handled) {
            throw "Original: 'n' shortcut not handled"  
        }
        
        Write-Host "✅ Original implementation working" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Original implementation failed: $_" -ForegroundColor Red
        return $false
    }
}

function Test-NewImplementation {
    Write-Host "Testing New ProjectsScreenNew Implementation..." -ForegroundColor Yellow
    
    try {
        # Create new screen
        $screen = [ProjectsScreenNew]::new()
        $screen.OnInitialize()
        
        # Validate auto service injection
        if (-not $screen.DataService) {
            throw "New: DataService not auto-injected"
        }
        if (-not $screen.EventBus) {
            throw "New: EventBus not auto-injected"
        }
        
        # Validate grid auto-setup
        if (-not $screen.DataGrid) {
            throw "New: DataGrid not auto-created"
        }
        
        # Validate auto shortcuts work
        $key = [System.ConsoleKeyInfo]::new('n', [System.ConsoleKey]::N, $false, $false, $false)
        $handled = $screen.HandleScreenInput($key)
        if (-not $handled) {
            throw "New: 'n' shortcut not auto-handled"
        }
        
        # Validate custom shortcuts work
        $key = [System.ConsoleKeyInfo]::new('v', [System.ConsoleKey]::V, $false, $false, $false)
        $handled = $screen.HandleScreenInput($key)
        if (-not $handled) {
            throw "New: 'v' custom shortcut not handled"
        }
        
        Write-Host "✅ New implementation working" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ New implementation failed: $_" -ForegroundColor Red
        return $false
    }
}

function Test-DialogImplementations {
    Write-Host "Testing Dialog Implementations..." -ForegroundColor Yellow
    
    try {
        # Test new UnifiedDialog-based dialogs
        $newProjectDialog = [NewProjectDialogNew]::new()
        $newProjectDialog.OnInitialize()
        
        if (-not $newProjectDialog._fields -or $newProjectDialog._fields.Count -eq 0) {
            throw "NewProjectDialogNew: Fields not created"
        }
        
        # Test field access
        $fieldValue = $newProjectDialog.GetFieldValue("Name")
        if ($fieldValue -eq $null) {
            throw "NewProjectDialogNew: GetFieldValue not working"
        }
        
        # Test edit dialog with mock project
        $mockProject = [Project]::new()
        $mockProject.FullProjectName = "Test Project"
        $mockProject.ID1 = "TEST1"
        
        $editDialog = [EditProjectDialogNew]::new($mockProject)
        $editDialog.OnInitialize()
        
        if (-not $editDialog._fields -or $editDialog._fields.Count -eq 0) {
            throw "EditProjectDialogNew: Fields not created"
        }
        
        # Verify pre-populated values
        $nameValue = $editDialog.GetFieldValue("Name")
        if ($nameValue -ne "Test Project") {
            throw "EditProjectDialogNew: Pre-population not working"
        }
        
        Write-Host "✅ Dialog implementations working" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Dialog implementations failed: $_" -ForegroundColor Red
        return $false
    }
}

function Compare-Implementations {
    Write-Host "Comparing Original vs New Implementations..." -ForegroundColor Yellow
    
    # Line count comparison
    $originalScreen = Get-Content "$praxisRoot\Screens\ProjectsScreen.ps1" | Measure-Object -Line
    $newScreen = Get-Content "$praxisRoot\Tests\ProjectsScreenNew.ps1" | Measure-Object -Line
    
    $originalDialog1 = Get-Content "$praxisRoot\Screens\NewProjectDialog.ps1" | Measure-Object -Line  
    $newDialog1 = Get-Content "$praxisRoot\Tests\NewProjectDialogNew.ps1" | Measure-Object -Line
    
    $originalDialog2 = Get-Content "$praxisRoot\Screens\EditProjectDialog.ps1" | Measure-Object -Line
    $newDialog2 = Get-Content "$praxisRoot\Tests\EditProjectDialogNew.ps1" | Measure-Object -Line
    
    Write-Host ""
    Write-Host "=== CODE REDUCTION ANALYSIS ===" -ForegroundColor Cyan
    Write-Host ""
    
    $screenReduction = [Math]::Round((1 - ($newScreen.Lines / $originalScreen.Lines)) * 100, 1)
    Write-Host "ProjectsScreen: $($originalScreen.Lines) → $($newScreen.Lines) lines ($screenReduction% reduction)" -ForegroundColor Green
    
    $dialog1Reduction = [Math]::Round((1 - ($newDialog1.Lines / $originalDialog1.Lines)) * 100, 1)
    Write-Host "NewProjectDialog: $($originalDialog1.Lines) → $($newDialog1.Lines) lines ($dialog1Reduction% reduction)" -ForegroundColor Green
    
    $dialog2Reduction = [Math]::Round((1 - ($newDialog2.Lines / $originalDialog2.Lines)) * 100, 1)
    Write-Host "EditProjectDialog: $($originalDialog2.Lines) → $($newDialog2.Lines) lines ($dialog2Reduction% reduction)" -ForegroundColor Green
    
    $totalOriginal = $originalScreen.Lines + $originalDialog1.Lines + $originalDialog2.Lines
    $totalNew = $newScreen.Lines + $newDialog1.Lines + $newDialog2.Lines
    $totalReduction = [Math]::Round((1 - ($totalNew / $totalOriginal)) * 100, 1)
    
    Write-Host ""
    Write-Host "TOTAL: $totalOriginal → $totalNew lines ($totalReduction% reduction)" -ForegroundColor Magenta
    Write-Host "Boilerplate eliminated: $($totalOriginal - $totalNew) lines" -ForegroundColor Magenta
    
    # Success criteria check
    Write-Host ""
    Write-Host "=== SUCCESS CRITERIA ===" -ForegroundColor Cyan
    $screenTarget = $screenReduction -ge 75
    $dialog1Target = $dialog1Reduction -ge 65
    $dialog2Target = $dialog2Reduction -ge 60
    $totalTarget = $totalReduction -ge 70
    
    Write-Host "Screen reduction ≥75%: $(if($screenTarget){'✅'}else{'❌'}) ($screenReduction%)" -ForegroundColor $(if($screenTarget){'Green'}else{'Red'})
    Write-Host "Dialog1 reduction ≥65%: $(if($dialog1Target){'✅'}else{'❌'}) ($dialog1Reduction%)" -ForegroundColor $(if($dialog1Target){'Green'}else{'Red'})
    Write-Host "Dialog2 reduction ≥60%: $(if($dialog2Target){'✅'}else{'❌'}) ($dialog2Reduction%)" -ForegroundColor $(if($dialog2Target){'Green'}else{'Red'})
    Write-Host "Total reduction ≥70%: $(if($totalTarget){'✅'}else{'❌'}) ($totalReduction%)" -ForegroundColor $(if($totalTarget){'Green'}else{'Red'})
    
    return ($screenTarget -and $dialog1Target -and $dialog2Target -and $totalTarget)
}

# Main execution
Write-Host "=== PHASE 1.3 ARCHITECTURE VALIDATION ===" -ForegroundColor Cyan
Write-Host ""

$results = @{}

if ($TestOriginal -or (-not $TestNew -and -not $Compare)) {
    $results['Original'] = Test-OriginalImplementation
    Write-Host ""
}

if ($TestNew -or (-not $TestOriginal -and -not $Compare)) {
    $results['New'] = Test-NewImplementation
    $results['Dialogs'] = Test-DialogImplementations
    Write-Host ""
}

if ($Compare -or (-not $TestNew -and -not $TestOriginal)) {
    $results['Comparison'] = Compare-Implementations
    Write-Host ""
}

# Final summary
Write-Host "=== VALIDATION SUMMARY ===" -ForegroundColor Cyan
$allPassed = $true
foreach ($test in $results.Keys) {
    $status = if ($results[$test]) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($results[$test]) { "Green" } else { "Red" }
    Write-Host "$test`: $status" -ForegroundColor $color
    if (-not $results[$test]) { $allPassed = $false }
}

Write-Host ""
if ($allPassed) {
    Write-Host "🎉 PHASE 1.3 VALIDATION: COMPLETE SUCCESS" -ForegroundColor Green
    Write-Host "Architecture ready for production migration!" -ForegroundColor Green
} else {
    Write-Host "⚠️  PHASE 1.3 VALIDATION: ISSUES FOUND" -ForegroundColor Red
    Write-Host "Review failures before proceeding" -ForegroundColor Red
}

exit $(if ($allPassed) { 0 } else { 1 })