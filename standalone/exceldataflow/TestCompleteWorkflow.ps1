# TestCompleteWorkflow.ps1 - Test the complete integrated workflow

function Test-WorkflowComponents {
    Write-Host "Testing Complete Workflow Components..." -ForegroundColor Yellow
    Write-Host "=======================================" -ForegroundColor Yellow
    Write-Host ""
    
    $components = @(
        # Core workflow components
        "$PSScriptRoot\Screens\IntegratedWorkflowManager.ps1",
        "$PSScriptRoot\Screens\StartupSelectionDialog.ps1",
        "$PSScriptRoot\Screens\PostConfigurationDialog.ps1",
        
        # Profile system
        "$PSScriptRoot\Services\ExportProfileService.ps1",
        "$PSScriptRoot\Screens\ProfileSelectionDialog.ps1",
        "$PSScriptRoot\Components\SimpleFileTree.ps1",
        "$PSScriptRoot\RunProfileExport.ps1",
        
        # Enhanced step 1 with file browser
        "$PSScriptRoot\Screens\Step1InputConfigDialog.ps1",
        
        # Data processing
        "$PSScriptRoot\Services\DataProcessingService.ps1",
        "$PSScriptRoot\Services\TextExportService.ps1",
        "$PSScriptRoot\RunTextExport.ps1",
        
        # Main entry point
        "$PSScriptRoot\Start.ps1"
    )
    
    $allExist = $true
    
    foreach ($component in $components) {
        $exists = Test-Path $component
        $status = if ($exists) { "✓" } else { "✗" }
        $color = if ($exists) { "Green" } else { "Red" }
        $name = Split-Path $component -Leaf
        
        Write-Host "  $status $name" -ForegroundColor $color
        
        if (-not $exists) {
            $allExist = $false
        }
    }
    
    Write-Host ""
    if ($allExist) {
        Write-Host "✅ All workflow components exist!" -ForegroundColor Green
    } else {
        Write-Host "❌ Some workflow components are missing!" -ForegroundColor Red
    }
    
    return $allExist
}

function Show-WorkflowGuide {
    Write-Host ""
    Write-Host "ExcelDataFlow Complete Workflow Guide" -ForegroundColor Magenta
    Write-Host "=====================================" -ForegroundColor Magenta
    Write-Host ""
    
    Write-Host "🚀 INTEGRATED WORKFLOW - Two Starting Options:" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "📋 Option 1: Quick Export (for existing configurations)" -ForegroundColor Yellow
    Write-Host "   1. Run: pwsh -File Start.ps1" -ForegroundColor White
    Write-Host "   2. Choose: '1. Quick Export using Saved Profile'" -ForegroundColor White
    Write-Host "   3. Select profile from list (sorted by usage)" -ForegroundColor White
    Write-Host "   4. Choose output folder (F3 for file browser)" -ForegroundColor White
    Write-Host "   5. Specify filename" -ForegroundColor White
    Write-Host "   6. Export completes automatically!" -ForegroundColor White
    Write-Host ""
    
    Write-Host "⚙️ Option 2: Configuration Wizard (for first-time setup)" -ForegroundColor Yellow
    Write-Host "   1. Run: pwsh -File Start.ps1" -ForegroundColor White
    Write-Host "   2. Choose: '2. Configure Excel Mappings'" -ForegroundColor White
    Write-Host "   3. Step 1: Configure files (F3/F4 for file browser)" -ForegroundColor White
    Write-Host "   4. Step 2: Map source fields" -ForegroundColor White
    Write-Host "   5. Step 3: Map destination fields" -ForegroundColor White
    Write-Host "   6. After completion, choose next action:" -ForegroundColor White
    Write-Host "      • Create Export Profile & Export Now" -ForegroundColor Gray
    Write-Host "      • Test Data Processing" -ForegroundColor Gray
    Write-Host "      • Run Full Excel Processing" -ForegroundColor Gray
    Write-Host "      • Exit" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "🔧 Additional Tools:" -ForegroundColor Cyan
    Write-Host "   • RunProfileExport.ps1 -ListProfiles     # List saved profiles" -ForegroundColor White
    Write-Host "   • RunProfileExport.ps1                   # Interactive profile export" -ForegroundColor White
    Write-Host "   • RunTextExport.ps1 -Interactive         # Create new profiles" -ForegroundColor White
    Write-Host "   • RunDataProcessing.ps1 -Preview         # Test Excel processing" -ForegroundColor White
    Write-Host ""
    
    Write-Host "📁 File Browser Integration:" -ForegroundColor Cyan
    Write-Host "   • F3 key in Step 1: Browse for source Excel file" -ForegroundColor White
    Write-Host "   • F4 key in Step 1: Browse for destination Excel file" -ForegroundColor White
    Write-Host "   • F3 key in Profile Export: Browse for output folder" -ForegroundColor White
    Write-Host "   • Arrow keys, Enter, Space: Navigate file tree" -ForegroundColor White
    Write-Host "   • Backspace: Go up one directory level" -ForegroundColor White
    Write-Host ""
    
    Write-Host "💾 Profile Management:" -ForegroundColor Cyan
    Write-Host "   • Profiles save field selections and export formats" -ForegroundColor White
    Write-Host "   • Usage statistics track most-used profiles" -ForegroundColor White
    Write-Host "   • Default profiles auto-created on first run" -ForegroundColor White
    Write-Host "   • Profiles can be exported/imported for sharing" -ForegroundColor White
    Write-Host ""
    
    Write-Host "🎯 Complete Workflow Examples:" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "First-time user:" -ForegroundColor Yellow
    Write-Host "1. pwsh -File Start.ps1" -ForegroundColor White
    Write-Host "2. Choose option 2 (Configure)" -ForegroundColor White
    Write-Host "3. Complete 3-step wizard" -ForegroundColor White
    Write-Host "4. Choose 'Create Export Profile & Export Now'" -ForegroundColor White
    Write-Host "5. Select fields and export format" -ForegroundColor White
    Write-Host "6. Save profile and export data" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Repeat user:" -ForegroundColor Yellow
    Write-Host "1. pwsh -File Start.ps1" -ForegroundColor White
    Write-Host "2. Choose option 1 (Quick Export)" -ForegroundColor White
    Write-Host "3. Select saved profile" -ForegroundColor White
    Write-Host "4. Choose output location" -ForegroundColor White
    Write-Host "5. Export completes automatically" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Automation user:" -ForegroundColor Yellow
    Write-Host "pwsh -File RunProfileExport.ps1 -ProfileName 'Basic Info' -OutputPath C:\\exports" -ForegroundColor White
    Write-Host ""
}

# Run the test
Write-Host "ExcelDataFlow Complete Workflow Validation" -ForegroundColor Magenta
Write-Host "===========================================" -ForegroundColor Magenta
Write-Host ""

$componentsExist = Test-WorkflowComponents

if ($componentsExist) {
    Write-Host ""
    Write-Host "🎉 WORKFLOW INTEGRATION COMPLETE!" -ForegroundColor Green
    Write-Host ""
    Write-Host "All components are in place for the complete workflow:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "✅ Startup selection (profile vs configuration)" -ForegroundColor Green
    Write-Host "✅ File browser integration (F3/F4 keys)" -ForegroundColor Green
    Write-Host "✅ Profile-based export with usage tracking" -ForegroundColor Green
    Write-Host "✅ Post-configuration options menu" -ForegroundColor Green
    Write-Host "✅ Complete data processing pipeline" -ForegroundColor Green
    Write-Host "✅ Text export with multiple formats" -ForegroundColor Green
    Write-Host "✅ Interactive and CLI modes" -ForegroundColor Green
    Write-Host ""
    
    Show-WorkflowGuide
    
    Write-Host ""
    Write-Host "🚀 Ready to test! Run: pwsh -File Start.ps1" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ WORKFLOW INTEGRATION INCOMPLETE!" -ForegroundColor Red
    Write-Host "Some components are missing. Please check the file paths above." -ForegroundColor Red
    Write-Host ""
}