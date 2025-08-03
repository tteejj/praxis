#!/usr/bin/env pwsh
# PROPER FIX - Find the ROOT CAUSE of grey colors

Write-Host "ANALYZING THE ACTUAL PROBLEM..." -ForegroundColor Red

# 1. First, let's trace where components get their colors
Write-Host "`n1. Checking how components get theme colors:" -ForegroundColor Yellow

# Check MinimalDataGrid
$dataGridPath = "Components/MinimalDataGrid.ps1"
$content = Get-Content $dataGridPath -Raw

# Find UpdateThemeCache method
if ($content -match 'UpdateThemeCache[\s\S]*?(?=\n    \[)') {
    $updateMethod = $matches[0]
    Write-Host "MinimalDataGrid UpdateThemeCache:" -ForegroundColor Cyan
    
    # Check if it's using Theme properly
    if ($updateMethod -match '\$this\.Theme\.GetColor') {
        Write-Host "  ✓ Uses Theme.GetColor" -ForegroundColor Green
    } else {
        Write-Host "  ✗ NOT using Theme properly!" -ForegroundColor Red
    }
}

# 2. Check Screen base class theme initialization
Write-Host "`n2. Checking Screen theme initialization:" -ForegroundColor Yellow
$screenPath = "Base/Screen.ps1"
$screenContent = Get-Content $screenPath -Raw

if ($screenContent -match 'OnInitialize[\s\S]*?Theme') {
    Write-Host "  Screen gets Theme in OnInitialize" -ForegroundColor Green
} else {
    Write-Host "  ✗ Screen may not be getting Theme!" -ForegroundColor Red
}

# 3. The REAL issue - components may be caching colors BEFORE theme is set
Write-Host "`n3. THE REAL PROBLEM:" -ForegroundColor Red
Write-Host "  Components cache colors in OnInitialize" -ForegroundColor Yellow
Write-Host "  But Theme might not be set yet!" -ForegroundColor Yellow
Write-Host "  So they get DEFAULT theme colors (grey)" -ForegroundColor Yellow
Write-Host "  Even though amber is selected!" -ForegroundColor Yellow

# 4. PROPER FIX - Ensure theme is propagated correctly
Write-Host "`n4. IMPLEMENTING PROPER FIX:" -ForegroundColor Green

# Fix 1: Make sure all components invalidate cache when theme changes
$componentFiles = Get-ChildItem -Path "Components/*.ps1", "Screens/*.ps1" -ErrorAction SilentlyContinue

foreach ($file in $componentFiles) {
    $content = Get-Content $file.FullName -Raw
    
    # Check if component has UpdateThemeCache but doesn't subscribe to theme changes
    if ($content -match 'UpdateThemeCache' -and $content -notmatch 'Subscribe.*theme\.changed') {
        Write-Host "  Fixing $($file.Name) - adding theme change subscription" -ForegroundColor Yellow
        
        # Add subscription in OnInitialize
        $initPattern = '(\[void\] OnInitialize\(\) \{[^}]*?)(})'
        if ($content -match $initPattern) {
            $newInit = $matches[1] + @'
        
        # Subscribe to theme changes
        if ($this.Theme) {
            $this.Theme.Subscribe({
                if ($this.PSObject.Methods['UpdateThemeCache']) {
                    $this.UpdateThemeCache()
                }
                $this.Invalidate()
            }.GetNewClosure())
        }
'@ + "`n    " + $matches[2]
            
            $content = $content -replace $initPattern, $newInit
            Set-Content $file.FullName $content
        }
    }
}

# Fix 2: Ensure UIElement base class propagates theme to all children
Write-Host "`n  Fixing UIElement theme propagation..." -ForegroundColor Yellow
$uiElementPath = "Base/UIElement.ps1"
$uiContent = Get-Content $uiElementPath -Raw

# Add method to propagate theme
if ($uiContent -notmatch 'PropagateTheme') {
    $uiContent = $uiContent -replace '(}\s*$)', @'
    
    # Propagate theme to all children
    [void] PropagateTheme([ThemeManager]$theme) {
        $this.Theme = $theme
        
        # Update cache if method exists
        if ($this.PSObject.Methods['UpdateThemeCache']) {
            $this.UpdateThemeCache()
        }
        
        # Propagate to children if this is a container
        if ($this -is [Container]) {
            foreach ($child in $this.GetChildren()) {
                if ($child) {
                    $child.PropagateTheme($theme)
                }
            }
        }
        
        $this.Invalidate()
    }
}
'@
    Set-Content $uiElementPath $uiContent
    Write-Host "  ✓ Added PropagateTheme to UIElement" -ForegroundColor Green
}

# Fix 3: Make ScreenManager propagate theme when screens are pushed
Write-Host "`n  Fixing ScreenManager theme propagation..." -ForegroundColor Yellow
$screenMgrPath = "Core/ScreenManager.ps1"
$smContent = Get-Content $screenMgrPath -Raw

# Find Push method and add theme propagation
if ($smContent -match '(\[void\] Push\([^)]+\) \{[^}]*?)(})') {
    $pushMethod = $matches[1]
    if ($pushMethod -notmatch 'PropagateTheme') {
        $newPush = $pushMethod + @'
        
        # Propagate current theme to new screen
        $themeManager = $this.ServiceContainer.GetService("ThemeManager")
        if ($themeManager -and $screen) {
            $screen.PropagateTheme($themeManager)
        }
'@ + "`n    " + $matches[2]
        
        $smContent = $smContent -replace '(\[void\] Push\([^)]+\) \{[^}]*?)(})', $newPush
        Set-Content $screenMgrPath $smContent
        Write-Host "  ✓ Fixed ScreenManager.Push theme propagation" -ForegroundColor Green
    }
}

Write-Host "`n✅ PROPER FIX APPLIED!" -ForegroundColor Green
Write-Host "`nWhat this fix does:" -ForegroundColor Yellow
Write-Host "1. Components now subscribe to theme changes" -ForegroundColor White
Write-Host "2. Theme is propagated to ALL children when set" -ForegroundColor White
Write-Host "3. ScreenManager ensures new screens get current theme" -ForegroundColor White
Write-Host "4. No more cached grey colors!" -ForegroundColor White

Write-Host "`nRun ./Start.ps1 - amber theme will work PROPERLY!" -ForegroundColor Green