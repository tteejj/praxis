#!/usr/bin/env pwsh
# Force default theme to BE amber theme

Write-Host "REPLACING DEFAULT THEME WITH AMBER!" -ForegroundColor Red

$themeManagerPath = "Services/ThemeManager.ps1"
$content = Get-Content $themeManagerPath -Raw

# Find where default theme is registered and replace it with amber colors
$newDefaultTheme = @'
        # Define default theme - validate it to ensure it's complete
        $defaultTheme = @{
            # Standardized text colors - AMBER ONLY!
            "text.primary" = @(255, 204, 0)       # Amber text
            "text.secondary" = @(204, 163, 0)     # Darker amber
            "text.disabled" = @(102, 82, 0)       # Dim amber
            "text.heading" = @(255, 230, 0)       # Bright amber headings
            "text.placeholder" = @(153, 122, 0)   # Medium amber placeholder
            
            # Standardized surface colors - AMBER ONLY!
            "surface.background" = @(51, 34, 0)   # Dark amber background
            "surface.elevated" = @(61, 49, 0)     # Slightly lighter amber
            "surface.dialog" = @(71, 57, 0)       # Even lighter for dialogs
            
            # Standardized color palette - AMBER ONLY!
            "color.primary" = @(255, 230, 0)      # Bright amber
            "color.secondary" = @(255, 204, 0)    # Standard amber
            
            # Standardized status colors
            "status.success" = @(0, 255, 0)       # Green
            "status.warning" = @(255, 255, 0)     # Yellow
            "status.error" = @(255, 85, 85)       # Red
            "status.info" = @(100, 200, 255)      # Light blue
            
            # Standardized border colors - AMBER ONLY!
            "border.normal" = @(153, 102, 0)      # Darker amber borders
            "border.focused" = @(255, 230, 0)     # Bright amber when focused
            "border.dialog" = @(204, 136, 0)      # Medium amber for dialogs
            "border.input" = @(153, 102, 0)       # Same as normal border
            "border.input.focused" = @(255, 230, 0) # Bright when focused
            
            # Standardized interaction states - AMBER ONLY!
            "state.selected" = @(102, 68, 0)      # Dark amber selection
            "state.hover" = @(82, 55, 0)          # Slightly darker
            "state.pressed" = @(61, 41, 0)        # Even darker when pressed
            "state.focused" = @(255, 230, 0)      # Bright amber focus
            
            # Focus reverse highlighting - AMBER ONLY!
            "focus.reverse.background" = @(255, 230, 0)   # Bright amber focus background
            "focus.reverse.text" = @(20, 18, 12)          # Dark brown text on amber background
            
            # Button states - ALL AMBER!
            "button.background" = @(61, 49, 0)            # Dark amber button background
            "button.text" = @(255, 204, 0)                # Amber button text
            "button.background.hover" = @(82, 66, 0)      # Lighter amber on hover
            "button.background.pressed" = @(41, 33, 0)    # Darker amber when pressed
            "button.background.focused" = @(255, 230, 0)  # Bright amber when focused
            "button.text.focused" = @(20, 18, 12)         # Dark brown text on bright amber
            
            # Input fields - AMBER ONLY!
            "input.background" = @(31, 25, 0)
            "input.text" = @(255, 204, 0)
            "input.placeholder" = @(153, 122, 0)
            
            # Menu colors - AMBER ONLY!
            "menu.background" = @(31, 25, 0)
            "menu.text" = @(255, 204, 0)
            "menu.background.selected" = @(255, 230, 0)
            "menu.text.selected" = @(20, 18, 12)
            
            # Tab colors - AMBER ONLY!
            "tab.background" = @(61, 49, 0)
            "tab.text" = @(204, 163, 0)
            "tab.background.active" = @(51, 34, 0)
            "tab.text.active" = @(255, 230, 0)
            "tab.border.active" = @(255, 230, 0)
            
            # List/Grid components - AMBER ONLY!
            "list.header.background" = @(41, 33, 0)
            "list.header.text" = @(255, 230, 0)
            "list.background" = @(31, 25, 0)
            "list.background.alternate" = @(41, 33, 0)
            "scrollbar.track" = @(102, 82, 0)
            "scrollbar.thumb" = @(153, 122, 0)
            
            # Checkbox/Radio - AMBER ONLY!
            "checkbox.background" = @(31, 25, 0)
            "checkbox.border" = @(153, 102, 0)
            "checkbox.check" = @(255, 230, 0)
            
            # Search/Highlight
            "search.background" = @(255, 255, 0)
            "search.text" = @(0, 0, 0)
            "highlight.background" = @(255, 255, 102)
            "highlight.text" = @(0, 0, 0)
            
            # File browser - AMBER ONLY!
            "file.directory" = @(255, 230, 0)
            "file.normal" = @(255, 204, 0)
            "file.executable" = @(255, 255, 102)
            "file.symlink" = @(255, 255, 0)
            
            # Progress indicators - AMBER ONLY!
            "progress.background" = @(41, 33, 0)
            "progress.bar" = @(255, 230, 0)
            "progress.bar.complete" = @(255, 204, 0)
            "progress.text" = @(255, 204, 0)
            
            # Editor specific - AMBER ONLY!
            "editor.background" = @(51, 34, 0)
            "editor.linenumber" = @(102, 82, 0)
            "editor.cursor" = @(255, 204, 0)
            "editor.cursor.text" = @(0, 0, 0)
            "editor.selection" = @(102, 68, 0)
            "editor.selection.text" = @(255, 255, 102)
            "editor.status.background" = @(41, 33, 0)
            "editor.status.text" = @(255, 204, 0)
            
            # Gradient endpoints - AMBER ONLY!
            "gradient.border.start" = @(255, 230, 0)
            "gradient.border.end" = @(102, 82, 0)
            "gradient.bg.start" = @(31, 25, 0)
            "gradient.bg.end" = @(10, 8, 0)
        }
'@

# Replace the entire default theme definition
if ($content -match '# Define default theme[\s\S]*?\$this\.RegisterTheme\("default"') {
    $startIndex = $content.IndexOf('# Define default theme')
    $endIndex = $content.IndexOf('$this.RegisterTheme("default"')
    
    if ($startIndex -gt 0 -and $endIndex -gt $startIndex) {
        $before = $content.Substring(0, $startIndex)
        $after = $content.Substring($endIndex)
        $content = $before + $newDefaultTheme + "`n        " + $after
        
        Set-Content $themeManagerPath $content
        Write-Host "✓ Replaced default theme with amber colors!" -ForegroundColor Green
    }
}

Write-Host "`nDEFAULT THEME IS NOW AMBER!" -ForegroundColor Yellow
Write-Host "Run ./Start.ps1" -ForegroundColor Red