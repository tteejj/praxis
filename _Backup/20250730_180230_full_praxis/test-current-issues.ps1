# Test current visual issues

Write-Host "=== TESTING CURRENT VISUAL ISSUES ===" -ForegroundColor Green
Write-Host ""

# Load the framework
. "$PSScriptRoot/Start.ps1" -LoadOnly

# Initialize services
$serviceContainer = [ServiceContainer]::new()
$logger = [Logger]::new()
$serviceContainer.Register("Logger", $logger)

$eventBus = [EventBus]::new()
$eventBus.Initialize($serviceContainer)
$serviceContainer.Register("EventBus", $eventBus)

$themeManager = [ThemeManager]::new()
$themeManager.SetEventBus($eventBus)
$serviceContainer.Register("ThemeManager", $themeManager)

$focusManager = [FocusManager]::new()
$focusManager.Initialize($serviceContainer)
$serviceContainer.Register("FocusManager", $focusManager)

$configService = [ConfigurationService]::new()
$configService.Initialize($serviceContainer)
$serviceContainer.Register("ConfigurationService", $configService)

Write-Host "1. Testing theme background colors:" -ForegroundColor Yellow
$surfaceColor = [VT]::RGBBG(24, 24, 24)
Write-Host "   surface.background color: $surfaceColor (this causes grey)" -ForegroundColor Gray

Write-Host ""
Write-Host "2. Testing SearchableListBox (left panel component):" -ForegroundColor Yellow
$searchableList = [SearchableListBox]::new()
$searchableList.Initialize($serviceContainer)
$searchableList.SetBounds(5, 5, 30, 8)
$searchableList.SetItems(@("Item 1", "Item 2", "Item 3"))

try {
    $output = $searchableList.OnRender()
    Write-Host "   ✅ Rendered successfully (${output.Length} chars)" -ForegroundColor Green
    
    # Check if it still contains background
    if ($output -match [regex]::Escape($surfaceColor)) {
        Write-Host "   ❌ Still contains grey background!" -ForegroundColor Red
    } else {
        Write-Host "   ✅ No grey background detected!" -ForegroundColor Green
    }
} catch {
    Write-Host "   ❌ Failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "3. Testing FastFileTree (another list component):" -ForegroundColor Yellow
$fileTree = [FastFileTree]::new()
$fileTree.Initialize($serviceContainer)
$fileTree.SetBounds(5, 5, 40, 8)

try {
    $output = $fileTree.OnRender()
    Write-Host "   ✅ Rendered successfully (${output.Length} chars)" -ForegroundColor Green
    
    # Check if it still contains background
    if ($output -match [regex]::Escape($surfaceColor)) {
        Write-Host "   ❌ Still contains grey background!" -ForegroundColor Red
    } else {
        Write-Host "   ✅ No grey background detected!" -ForegroundColor Green
    }
} catch {
    Write-Host "   ❌ Failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "4. Testing NewProjectDialog layout:" -ForegroundColor Yellow
$dialog = [NewProjectDialog]::new()
$dialog.Initialize($serviceContainer)
$dialog.SetBounds(0, 0, 80, 24)  # Full screen size

try {
    $output = $dialog.OnRender()
    Write-Host "   ✅ Dialog rendered successfully (${output.Length} chars)" -ForegroundColor Green
    
    # Check if layout components are being used
    if ($dialog._mainLayout) {
        Write-Host "   ✅ Using VerticalSplit layout" -ForegroundColor Green
    } else {
        Write-Host "   ❌ No main layout found!" -ForegroundColor Red
    }
    
    if ($dialog._buttonLayout) {
        Write-Host "   ✅ Using HorizontalSplit for buttons" -ForegroundColor Green
    } else {
        Write-Host "   ❌ No button layout found!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "   ❌ Dialog failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== DIAGNOSIS ===" -ForegroundColor Cyan
Write-Host "If grey backgrounds still appear:" -ForegroundColor Yellow
Write-Host "  • Check components that weren't migrated yet" -ForegroundColor Gray
Write-Host "  • Verify theme surface.background isn't being used elsewhere" -ForegroundColor Gray
Write-Host "  • Look for hardcoded RGB(24,24,24) colors" -ForegroundColor Gray
Write-Host ""
Write-Host "If dialog layout is messy:" -ForegroundColor Yellow
Write-Host "  • Verify layout components are properly initialized" -ForegroundColor Gray
Write-Host "  • Check if DialogField positioning is correct" -ForegroundColor Gray
Write-Host "  • Look for bounds/positioning conflicts" -ForegroundColor Gray
Write-Host ""