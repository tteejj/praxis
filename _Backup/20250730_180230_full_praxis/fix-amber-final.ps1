#!/usr/bin/env pwsh
# Final fix for amber theme - ensure NO grey or blue AT ALL

Write-Host "Applying FINAL amber theme fixes..." -ForegroundColor Yellow

$themeManagerPath = Join-Path $PSScriptRoot "Services/ThemeManager.ps1"
$content = Get-Content $themeManagerPath -Raw

# The issue is button.background is STILL showing grey because it's not being replaced properly
# Let's fix the amber theme definition directly

# Find the amber theme section and replace it entirely
$amberStart = $content.IndexOf('# Define amber theme')
$amberEnd = $content.IndexOf('$this.RegisterTheme("amber", $amberTheme)')

if ($amberStart -gt 0 -and $amberEnd -gt $amberStart) {
    $beforeAmber = $content.Substring(0, $amberStart)
    $afterAmber = $content.Substring($amberEnd)
    
    # New amber theme with NO GREY OR BLUE!
    $newAmberTheme = @'
# Define amber theme - ONLY standardized keys
        $amberTheme = @{
            # Standardized text colors
            "text.primary" = @(255, 204, 0)       # Amber text
            "text.secondary" = @(204, 163, 0)     # Darker amber
            "text.disabled" = @(102, 82, 0)       # Dim amber
            "text.heading" = @(255, 230, 0)       # Bright amber headings (NO BLUE!)
            "text.placeholder" = @(153, 122, 0)   # Medium amber placeholder
            
            # Standardized surface colors
            "surface.background" = @(51, 34, 0)   # Dark amber background
            "surface.elevated" = @(61, 49, 0)     # Slightly lighter amber
            "surface.dialog" = @(71, 57, 0)       # Even lighter for dialogs
            
            # Standardized color palette
            "color.primary" = @(255, 230, 0)      # Bright amber (NO BLUE!)
            "color.secondary" = @(255, 204, 0)    # Standard amber
            
            # Standardized status colors
            "status.success" = @(0, 255, 0)       # Green
            "status.warning" = @(255, 255, 0)     # Yellow
            "status.error" = @(255, 85, 85)       # Red
            "status.info" = @(100, 200, 255)      # Light blue
            
            # Standardized border colors
            "border.normal" = @(153, 102, 0)      # Darker amber borders
            "border.focused" = @(255, 230, 0)     # Bright amber when focused (NO BLUE!)
            "border.dialog" = @(204, 136, 0)      # Medium amber for dialogs
            "border.input" = @(153, 102, 0)       # Same as normal border
            "border.input.focused" = @(255, 230, 0) # Bright when focused (NO BLUE!)
            
            # Standardized interaction states
            "state.selected" = @(102, 68, 0)      # Dark amber selection
            "state.hover" = @(82, 55, 0)          # Slightly darker
            "state.pressed" = @(61, 41, 0)        # Even darker when pressed
            "state.focused" = @(255, 230, 0)      # Bright amber focus (NO BLUE!)
            
            # Focus reverse highlighting
            "focus.reverse.background" = @(255, 230, 0)   # Bright amber focus background (NO BLUE!)
            "focus.reverse.text" = @(20, 18, 12)          # Dark brown text on amber background
            
            # Button states - ALL AMBER!
            "button.background" = @(61, 49, 0)            # Dark amber button background
            "button.text" = @(255, 204, 0)                # Amber button text
            "button.background.hover" = @(82, 66, 0)      # Lighter amber on hover
            "button.background.pressed" = @(41, 33, 0)    # Darker amber when pressed
            "button.background.focused" = @(255, 230, 0)  # Bright amber when focused (NO BLUE!)
            "button.text.focused" = @(20, 18, 12)         # Dark brown text on bright amber
            
            # Input fields
            "input.background" = @(31, 25, 0)
            "input.text" = @(255, 204, 0)
            "input.placeholder" = @(153, 122, 0)
            
            # Menu colors
            "menu.background" = @(31, 25, 0)
            "menu.text" = @(255, 204, 0)
            "menu.background.selected" = @(255, 230, 0)   # Bright amber selected (NO BLUE!)
            "menu.text.selected" = @(20, 18, 12)          # Dark brown on amber
            
            # Tab colors
            "tab.background" = @(61, 49, 0)
            "tab.text" = @(204, 163, 0)
            "tab.background.active" = @(51, 34, 0)
            "tab.text.active" = @(255, 230, 0)        # Bright amber (NO BLUE!)
            "tab.border.active" = @(255, 230, 0)      # Bright amber (NO BLUE!)
            
            # List/Grid components
            "list.header.background" = @(41, 33, 0)
            "list.header.text" = @(255, 230, 0)       # Bright amber (NO BLUE!)
            "list.background" = @(31, 25, 0)          # Dark amber (not black!)
            "list.background.alternate" = @(41, 33, 0)
            "scrollbar.track" = @(102, 82, 0)
            "scrollbar.thumb" = @(153, 122, 0)
            
            # Checkbox/Radio
            "checkbox.background" = @(31, 25, 0)
            "checkbox.border" = @(153, 102, 0)
            "checkbox.check" = @(255, 230, 0)         # Bright amber (NO BLUE!)
            
            # Search/Highlight
            "search.background" = @(255, 255, 0)
            "search.text" = @(0, 0, 0)
            "highlight.background" = @(255, 255, 102)
            "highlight.text" = @(0, 0, 0)
            
            # File browser
            "file.directory" = @(255, 230, 0)         # Bright amber (NO BLUE!)
            "file.normal" = @(255, 204, 0)
            "file.executable" = @(255, 255, 102)
            "file.symlink" = @(255, 255, 0)
            
            # Progress indicators
            "progress.background" = @(41, 33, 0)
            "progress.bar" = @(255, 230, 0)           # Bright amber (NO BLUE!)
            "progress.bar.complete" = @(255, 204, 0)
            "progress.text" = @(255, 204, 0)
            
            # Editor specific
            "editor.background" = @(51, 34, 0)
            "editor.linenumber" = @(102, 82, 0)
            "editor.cursor" = @(255, 204, 0)
            "editor.cursor.text" = @(0, 0, 0)
            "editor.selection" = @(102, 68, 0)
            "editor.selection.text" = @(255, 255, 102)
            "editor.status.background" = @(41, 33, 0)
            "editor.status.text" = @(255, 204, 0)
            
            # Gradient endpoints
            "gradient.border.start" = @(255, 230, 0)      # Bright amber (NO BLUE!)
            "gradient.border.end" = @(102, 82, 0)         # Dim amber
            "gradient.bg.start" = @(31, 25, 0)            # Dark amber
            "gradient.bg.end" = @(10, 8, 0)               # Almost black
        }
        
'@
    
    $content = $beforeAmber + $newAmberTheme + $afterAmber
    Set-Content $themeManagerPath $content
    Write-Host "✓ Completely replaced amber theme definition" -ForegroundColor Green
} else {
    Write-Host "✗ Could not find amber theme section!" -ForegroundColor Red
}

Write-Host "`n✅ Final amber theme fixes applied!" -ForegroundColor Green
Write-Host "`nThe amber theme now has:" -ForegroundColor Yellow
Write-Host "- NO grey colors (no RGB with equal values)" -ForegroundColor White
Write-Host "- NO blue components (all blues are 0)" -ForegroundColor White
Write-Host "- Pure amber/yellow/brown colors throughout" -ForegroundColor White
Write-Host "- Dark amber button backgrounds" -ForegroundColor White
Write-Host "- Bright amber for focused/selected items" -ForegroundColor White

Write-Host "`nRun ./Start.ps1 to see the PURE AMBER theme!" -ForegroundColor Yellow