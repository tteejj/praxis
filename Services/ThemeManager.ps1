# ThemeManager.ps1 - Fast theme management with pre-cached ANSI sequences
# All colors are pre-computed to avoid runtime lookups

class ThemeManager {
    hidden [hashtable]$_themes = @{}
    hidden [string]$_currentTheme = "default"
    hidden [hashtable]$_cache = @{}
    hidden [string]$_cachedThemeReset = ""
    hidden [System.Collections.Generic.List[scriptblock]]$_listeners
    hidden [EventBus]$EventBus
    
    ThemeManager() {
        $this._listeners = [System.Collections.Generic.List[scriptblock]]::new()
        $this.InitializeDefaultTheme()
        
        # EventBus will be set later via SetEventBus
    }
    
    [void] InitializeDefaultTheme() {
        # Define default theme with ONLY standardized keys
        $defaultTheme = @{
            # Standardized text colors
            "text.primary" = @(204, 204, 204)   # Primary text
            "text.secondary" = @(170, 170, 170) # Secondary text
            "text.disabled" = @(128, 128, 128)  # Disabled text
            "text.heading" = @(0, 150, 255)     # Headings/titles
            "text.placeholder" = @(100, 100, 100) # Placeholder text
            
            # Standardized surface colors
            "surface.background" = @(24, 24, 24) # Main background
            "surface.elevated" = @(32, 32, 32)   # Elevated surfaces
            "surface.dialog" = @(40, 40, 40)     # Dialog backgrounds
            
            # Standardized color palette
            "color.primary" = @(0, 150, 255)     # Primary brand color
            "color.secondary" = @(128, 0, 255)   # Secondary accent
            
            # Standardized status colors
            "status.success" = @(0, 200, 83)     # Success green
            "status.warning" = @(255, 195, 0)    # Warning yellow
            "status.error" = @(255, 85, 85)      # Error red
            "status.info" = @(0, 150, 255)       # Info blue
            
            # Standardized border colors
            "border.normal" = @(68, 68, 68)     # Normal borders
            "border.focused" = @(0, 150, 255)   # Focused borders
            "border.dialog" = @(68, 68, 68)     # Dialog borders
            "border.input" = @(68, 68, 68)      # Input borders
            "border.input.focused" = @(0, 150, 255) # Focused input borders
            
            # Standardized interaction states
            "state.selected" = @(60, 60, 60)    # Selected items
            "state.hover" = @(48, 48, 48)       # Hover state
            "state.pressed" = @(32, 32, 32)     # Pressed state
            "state.focused" = @(0, 150, 255)    # Focus indicator
            
            # Button states
            "button.background" = @(48, 48, 48)
            "button.text" = @(204, 204, 204)
            "button.background.hover" = @(64, 64, 64)
            "button.background.pressed" = @(32, 32, 32)
            "button.background.focused" = @(0, 150, 255)
            "button.text.focused" = @(255, 255, 255)
            
            # Input fields
            "input.background" = @(32, 32, 32)
            "input.text" = @(204, 204, 204)
            "input.placeholder" = @(100, 100, 100)
            
            # Menu colors
            "menu.background" = @(32, 32, 32)
            "menu.text" = @(204, 204, 204)
            "menu.background.selected" = @(0, 150, 255)
            "menu.text.selected" = @(255, 255, 255)
            
            # Tab colors
            "tab.background" = @(48, 48, 48)
            "tab.text" = @(170, 170, 170)
            "tab.background.active" = @(24, 24, 24)
            "tab.text.active" = @(255, 255, 255)
            "tab.border.active" = @(0, 150, 255)
            
            # List/Grid components
            "list.header.background" = @(48, 48, 48)
            "list.header.text" = @(0, 150, 255)
            "list.background" = @(24, 24, 24)
            "list.background.alternate" = @(32, 32, 32)
            "scrollbar.track" = @(68, 68, 68)
            "scrollbar.thumb" = @(128, 128, 128)
            
            # Checkbox/Radio
            "checkbox.background" = @(32, 32, 32)
            "checkbox.border" = @(68, 68, 68)
            "checkbox.check" = @(0, 150, 255)
            
            # Search/Highlight
            "search.background" = @(255, 195, 0)
            "search.text" = @(0, 0, 0)
            "highlight.background" = @(255, 255, 0)
            "highlight.text" = @(0, 0, 0)
            
            # File browser
            "file.directory" = @(0, 150, 255)
            "file.normal" = @(204, 204, 204)
            "file.executable" = @(0, 200, 83)
            "file.symlink" = @(255, 195, 0)
            
            # Progress indicators
            "progress.background" = @(48, 48, 48)
            "progress.bar" = @(0, 150, 255)
            "progress.bar.complete" = @(0, 200, 83)
            "progress.text" = @(204, 204, 204)
            
            # Editor specific
            "editor.background" = @(24, 24, 24)
            "editor.linenumber" = @(100, 100, 100)
            "editor.cursor" = @(255, 255, 255)
            "editor.cursor.text" = @(0, 0, 0)
            "editor.selection" = @(60, 60, 60)
            "editor.selection.text" = @(255, 255, 255)
            "editor.status.background" = @(32, 32, 32)
            "editor.status.text" = @(204, 204, 204)
            
            # Gradient endpoints
            "gradient.border.start" = @(0, 150, 255)      # Blue
            "gradient.border.end" = @(68, 68, 68)         # Dark gray
            "gradient.bg.start" = @(48, 48, 48)           # Light gray
            "gradient.bg.end" = @(24, 24, 24)             # Dark gray
        }
        
        $this.RegisterTheme("default", $defaultTheme)
        
        # Define matrix theme - ONLY standardized keys
        $matrixTheme = @{
            # Standardized text colors
            "text.primary" = @(0, 255, 0)         # Bright green text
            "text.secondary" = @(0, 200, 0)       # Slightly dimmer green
            "text.disabled" = @(0, 128, 0)        # Medium green
            "text.heading" = @(0, 255, 0)         # Bright green headings
            "text.placeholder" = @(0, 100, 0)     # Dark green placeholder
            
            # Standardized surface colors
            "surface.background" = @(0, 0, 0)     # Pure black background
            "surface.elevated" = @(0, 20, 0)      # Very dark green
            "surface.dialog" = @(0, 30, 0)        # Slightly lighter for dialogs
            
            # Standardized color palette
            "color.primary" = @(0, 255, 0)        # Matrix green
            "color.secondary" = @(0, 200, 0)      # Darker green
            
            # Standardized status colors
            "status.success" = @(0, 255, 0)       # Bright green
            "status.warning" = @(255, 255, 0)     # Yellow
            "status.error" = @(255, 0, 0)         # Red
            "status.info" = @(0, 200, 255)        # Cyan
            
            # Standardized border colors
            "border.normal" = @(0, 100, 0)        # Dark green borders
            "border.focused" = @(0, 255, 0)       # Bright green when focused
            "border.dialog" = @(0, 150, 0)        # Medium green for dialogs
            "border.input" = @(0, 100, 0)         # Dark green for inputs
            "border.input.focused" = @(0, 255, 0) # Bright green when focused
            
            # Standardized interaction states
            "state.selected" = @(0, 100, 0)       # Dark green selection
            "state.hover" = @(0, 80, 0)           # Slightly darker
            "state.pressed" = @(0, 60, 0)         # Even darker when pressed
            "state.focused" = @(0, 255, 0)        # Bright green focus
            
            # Button states
            "button.background" = @(0, 20, 0)
            "button.text" = @(0, 255, 0)
            "button.background.hover" = @(0, 40, 0)
            "button.background.pressed" = @(0, 60, 0)
            "button.background.focused" = @(0, 100, 0)
            "button.text.focused" = @(0, 255, 0)
            
            # Input fields
            "input.background" = @(0, 10, 0)
            "input.text" = @(0, 255, 0)
            "input.placeholder" = @(0, 100, 0)
            
            # Menu colors
            "menu.background" = @(0, 0, 0)
            "menu.text" = @(0, 200, 0)
            "menu.background.selected" = @(0, 80, 0)
            "menu.text.selected" = @(0, 255, 0)
            
            # Tab colors
            "tab.background" = @(0, 30, 0)
            "tab.text" = @(0, 150, 0)
            "tab.background.active" = @(0, 0, 0)
            "tab.text.active" = @(0, 255, 0)
            "tab.border.active" = @(0, 255, 0)
            
            # List/Grid components
            "list.header.background" = @(0, 30, 0)
            "list.header.text" = @(0, 255, 0)
            "list.background" = @(0, 0, 0)
            "list.background.alternate" = @(0, 10, 0)
            "scrollbar.track" = @(0, 100, 0)
            "scrollbar.thumb" = @(0, 150, 0)
            
            # Checkbox/Radio
            "checkbox.background" = @(0, 10, 0)
            "checkbox.border" = @(0, 100, 0)
            "checkbox.check" = @(0, 255, 0)
            
            # Search/Highlight
            "search.background" = @(255, 255, 0)
            "search.text" = @(0, 0, 0)
            "highlight.background" = @(255, 255, 0)
            "highlight.text" = @(0, 0, 0)
            
            # File browser
            "file.directory" = @(0, 255, 0)
            "file.normal" = @(0, 200, 0)
            "file.executable" = @(0, 255, 100)
            "file.symlink" = @(255, 255, 0)
            
            # Progress indicators
            "progress.background" = @(0, 30, 0)
            "progress.bar" = @(0, 255, 0)
            "progress.bar.complete" = @(0, 255, 0)
            "progress.text" = @(0, 200, 0)
            
            # Editor specific
            "editor.background" = @(0, 0, 0)
            "editor.linenumber" = @(0, 100, 0)
            "editor.cursor" = @(0, 255, 0)
            "editor.cursor.text" = @(0, 0, 0)
            "editor.selection" = @(0, 100, 0)
            "editor.selection.text" = @(0, 0, 0)
            "editor.status.background" = @(0, 20, 0)
            "editor.status.text" = @(0, 200, 0)
            
            # Gradient endpoints
            "gradient.border.start" = @(0, 255, 0)        # Bright green
            "gradient.border.end" = @(0, 50, 0)           # Very dark green
            "gradient.bg.start" = @(0, 40, 0)             # Dark green
            "gradient.bg.end" = @(0, 0, 0)                # Black
        }
        
        $this.RegisterTheme("matrix", $matrixTheme)
        
        # Define amber theme - ONLY standardized keys
        $amberTheme = @{
            # Standardized text colors
            "text.primary" = @(255, 204, 0)       # Amber text
            "text.secondary" = @(204, 163, 0)     # Darker amber
            "text.disabled" = @(102, 82, 0)       # Dim amber
            "text.heading" = @(255, 230, 77)      # Bright amber headings
            "text.placeholder" = @(153, 122, 0)   # Medium amber placeholder
            
            # Standardized surface colors
            "surface.background" = @(51, 34, 0)   # Dark amber background
            "surface.elevated" = @(61, 49, 0)     # Slightly lighter amber
            "surface.dialog" = @(71, 57, 0)       # Even lighter for dialogs
            
            # Standardized color palette
            "color.primary" = @(255, 230, 77)     # Bright amber
            "color.secondary" = @(255, 204, 0)    # Standard amber
            
            # Standardized status colors
            "status.success" = @(0, 255, 0)       # Green
            "status.warning" = @(255, 255, 0)     # Yellow
            "status.error" = @(255, 85, 85)       # Red
            "status.info" = @(100, 200, 255)      # Light blue
            
            # Standardized border colors
            "border.normal" = @(153, 102, 0)      # Darker amber borders
            "border.focused" = @(255, 230, 77)    # Bright amber when focused
            "border.dialog" = @(204, 136, 0)      # Medium amber for dialogs
            "border.input" = @(153, 102, 0)       # Same as normal border
            "border.input.focused" = @(255, 230, 77) # Bright when focused
            
            # Standardized interaction states
            "state.selected" = @(102, 68, 0)      # Dark amber selection
            "state.hover" = @(82, 55, 0)          # Slightly darker
            "state.pressed" = @(61, 41, 0)        # Even darker when pressed
            "state.focused" = @(255, 230, 77)     # Bright amber focus
            
            # Button states
            "button.background" = @(41, 33, 0)
            "button.text" = @(255, 204, 0)
            "button.background.hover" = @(61, 49, 0)
            "button.background.pressed" = @(31, 25, 0)
            "button.background.focused" = @(255, 230, 77)
            "button.text.focused" = @(20, 18, 12)
            
            # Input fields
            "input.background" = @(31, 25, 0)
            "input.text" = @(255, 204, 0)
            "input.placeholder" = @(153, 122, 0)
            
            # Menu colors
            "menu.background" = @(31, 25, 0)
            "menu.text" = @(255, 204, 0)
            "menu.background.selected" = @(102, 68, 0)
            "menu.text.selected" = @(255, 230, 77)
            
            # Tab colors
            "tab.background" = @(61, 49, 0)
            "tab.text" = @(204, 163, 0)
            "tab.background.active" = @(51, 34, 0)
            "tab.text.active" = @(255, 230, 77)
            "tab.border.active" = @(255, 230, 77)
            
            # List/Grid components
            "list.header.background" = @(41, 33, 0)
            "list.header.text" = @(255, 230, 77)
            "list.background" = @(51, 34, 0)
            "list.background.alternate" = @(41, 33, 0)
            "scrollbar.track" = @(102, 82, 0)
            "scrollbar.thumb" = @(153, 122, 0)
            
            # Checkbox/Radio
            "checkbox.background" = @(31, 25, 0)
            "checkbox.border" = @(153, 102, 0)
            "checkbox.check" = @(255, 230, 77)
            
            # Search/Highlight
            "search.background" = @(255, 255, 0)
            "search.text" = @(0, 0, 0)
            "highlight.background" = @(255, 255, 102)
            "highlight.text" = @(0, 0, 0)
            
            # File browser
            "file.directory" = @(255, 230, 77)
            "file.normal" = @(255, 204, 0)
            "file.executable" = @(255, 255, 102)
            "file.symlink" = @(255, 255, 0)
            
            # Progress indicators
            "progress.background" = @(41, 33, 0)
            "progress.bar" = @(255, 230, 77)
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
            "gradient.border.start" = @(255, 230, 77)     # Bright amber
            "gradient.border.end" = @(102, 82, 0)         # Dim amber
            "gradient.bg.start" = @(31, 25, 0)            # Dark amber
            "gradient.bg.end" = @(10, 8, 0)               # Almost black
        }
        
        $this.RegisterTheme("amber", $amberTheme)
        
        # Define amber-black theme - ONLY standardized keys
        $amberBlackTheme = @{
            # Standardized text colors
            "text.primary" = @(255, 204, 0)       # Amber text
            "text.secondary" = @(204, 163, 0)     # Darker amber
            "text.disabled" = @(102, 82, 0)       # Dim amber
            "text.heading" = @(255, 230, 77)      # Bright amber headings
            "text.placeholder" = @(153, 122, 0)   # Medium amber placeholder
            
            # Standardized surface colors
            "surface.background" = @(0, 0, 0)     # Pure black background
            "surface.elevated" = @(10, 8, 0)      # Very dark amber
            "surface.dialog" = @(20, 16, 0)       # Slightly lighter
            
            # Standardized color palette
            "color.primary" = @(255, 230, 77)     # Bright amber
            "color.secondary" = @(255, 204, 0)    # Standard amber
            
            # Standardized status colors
            "status.success" = @(0, 255, 0)       # Green
            "status.warning" = @(255, 255, 0)     # Yellow
            "status.error" = @(255, 85, 85)       # Red
            "status.info" = @(100, 200, 255)      # Light blue
            
            # Standardized border colors
            "border.normal" = @(153, 102, 0)      # Darker amber borders
            "border.focused" = @(255, 230, 77)    # Bright amber when focused
            "border.dialog" = @(204, 136, 0)      # Medium amber for dialogs
            "border.input" = @(153, 102, 0)       # Same as normal border
            "border.input.focused" = @(255, 230, 77) # Bright when focused
            
            # Standardized interaction states
            "state.selected" = @(51, 34, 0)       # Dark amber selection
            "state.hover" = @(41, 27, 0)          # Slightly darker
            "state.pressed" = @(31, 20, 0)        # Even darker when pressed
            "state.focused" = @(255, 230, 77)     # Bright amber focus
            
            # Button states
            "button.background" = @(10, 8, 0)
            "button.text" = @(255, 204, 0)
            "button.background.hover" = @(20, 16, 0)
            "button.background.pressed" = @(5, 4, 0)
            "button.background.focused" = @(255, 230, 77)
            "button.text.focused" = @(0, 0, 0)
            
            # Input fields
            "input.background" = @(10, 8, 0)
            "input.text" = @(255, 204, 0)
            "input.placeholder" = @(153, 122, 0)
            
            # Menu colors
            "menu.background" = @(0, 0, 0)
            "menu.text" = @(255, 204, 0)
            "menu.background.selected" = @(102, 68, 0)
            "menu.text.selected" = @(0, 0, 0)
            
            # Tab colors
            "tab.background" = @(20, 16, 0)
            "tab.text" = @(204, 163, 0)
            "tab.background.active" = @(0, 0, 0)
            "tab.text.active" = @(255, 230, 77)
            "tab.border.active" = @(255, 230, 77)
            
            # List/Grid components
            "list.header.background" = @(20, 16, 0)
            "list.header.text" = @(255, 230, 77)
            "list.background" = @(0, 0, 0)
            "list.background.alternate" = @(10, 8, 0)
            "scrollbar.track" = @(102, 82, 0)
            "scrollbar.thumb" = @(153, 122, 0)
            
            # Checkbox/Radio
            "checkbox.background" = @(10, 8, 0)
            "checkbox.border" = @(153, 102, 0)
            "checkbox.check" = @(255, 230, 77)
            
            # Search/Highlight
            "search.background" = @(255, 255, 0)
            "search.text" = @(0, 0, 0)
            "highlight.background" = @(255, 255, 102)
            "highlight.text" = @(0, 0, 0)
            
            # File browser
            "file.directory" = @(255, 230, 77)
            "file.normal" = @(255, 204, 0)
            "file.executable" = @(255, 255, 102)
            "file.symlink" = @(255, 255, 0)
            
            # Progress indicators
            "progress.background" = @(20, 16, 0)
            "progress.bar" = @(255, 230, 77)
            "progress.bar.complete" = @(255, 204, 0)
            "progress.text" = @(255, 204, 0)
            
            # Editor specific
            "editor.background" = @(0, 0, 0)
            "editor.linenumber" = @(102, 82, 0)
            "editor.cursor" = @(255, 204, 0)
            "editor.cursor.text" = @(0, 0, 0)
            "editor.selection" = @(51, 34, 0)
            "editor.selection.text" = @(255, 255, 102)
            "editor.status.background" = @(20, 16, 0)
            "editor.status.text" = @(255, 204, 0)
            
            # Gradient endpoints
            "gradient.border.start" = @(255, 230, 77)     # Bright amber
            "gradient.border.end" = @(102, 82, 0)         # Dim amber
            "gradient.bg.start" = @(20, 16, 0)            # Very dark amber
            "gradient.bg.end" = @(0, 0, 0)                # Black
        }
        
        $this.RegisterTheme("amber-black", $amberBlackTheme)
        
        # Define matrix-rain theme - ONLY standardized keys
        $matrixRainTheme = @{
            # Standardized text colors
            "text.primary" = @(0, 255, 0)         # Bright green text
            "text.secondary" = @(0, 200, 0)       # Slightly dimmer green
            "text.disabled" = @(0, 100, 0)        # Dim green
            "text.heading" = @(150, 255, 150)     # Light green headings
            "text.placeholder" = @(0, 80, 0)      # Dark green placeholder
            
            # Standardized surface colors
            "surface.background" = @(0, 0, 0)     # Pure black background
            "surface.elevated" = @(0, 30, 0)      # Dark green
            "surface.dialog" = @(0, 40, 0)        # Slightly lighter for dialogs
            
            # Standardized color palette
            "color.primary" = @(150, 255, 150)    # Light green
            "color.secondary" = @(0, 255, 0)      # Bright green
            
            # Standardized status colors
            "status.success" = @(0, 255, 0)       # Bright green
            "status.warning" = @(255, 255, 0)     # Yellow
            "status.error" = @(255, 0, 0)         # Red
            "status.info" = @(0, 200, 255)        # Cyan
            
            # Standardized border colors
            "border.normal" = @(0, 150, 0)        # Medium green borders
            "border.focused" = @(150, 255, 150)   # Light green when focused
            "border.dialog" = @(0, 200, 0)        # Bright green for dialogs
            "border.input" = @(0, 150, 0)         # Medium green for inputs
            "border.input.focused" = @(150, 255, 150) # Light green when focused
            
            # Standardized interaction states
            "state.selected" = @(0, 80, 0)        # Dark green selection
            "state.hover" = @(0, 100, 0)          # Slightly lighter
            "state.pressed" = @(0, 120, 0)        # Even lighter when pressed
            "state.focused" = @(150, 255, 150)    # Light green focus
            
            # Button states
            "button.background" = @(0, 30, 0)
            "button.text" = @(0, 255, 0)
            "button.background.hover" = @(0, 50, 0)
            "button.background.pressed" = @(0, 70, 0)
            "button.background.focused" = @(0, 150, 0)
            "button.text.focused" = @(150, 255, 150)
            
            # Input fields
            "input.background" = @(0, 20, 0)
            "input.text" = @(0, 255, 0)
            "input.placeholder" = @(0, 100, 0)
            
            # Menu colors
            "menu.background" = @(0, 0, 0)
            "menu.text" = @(0, 200, 0)
            "menu.background.selected" = @(0, 100, 0)
            "menu.text.selected" = @(150, 255, 150)
            
            # Tab colors
            "tab.background" = @(0, 40, 0)
            "tab.text" = @(0, 180, 0)
            "tab.background.active" = @(0, 0, 0)
            "tab.text.active" = @(150, 255, 150)
            "tab.border.active" = @(0, 255, 0)
            
            # List/Grid components
            "list.header.background" = @(0, 40, 0)
            "list.header.text" = @(150, 255, 150)
            "list.background" = @(0, 0, 0)
            "list.background.alternate" = @(0, 20, 0)
            "scrollbar.track" = @(0, 100, 0)
            "scrollbar.thumb" = @(0, 200, 0)
            
            # Checkbox/Radio
            "checkbox.background" = @(0, 20, 0)
            "checkbox.border" = @(0, 150, 0)
            "checkbox.check" = @(150, 255, 150)
            
            # Search/Highlight
            "search.background" = @(255, 255, 0)
            "search.text" = @(0, 0, 0)
            "highlight.background" = @(255, 255, 0)
            "highlight.text" = @(0, 0, 0)
            
            # File browser
            "file.directory" = @(150, 255, 150)
            "file.normal" = @(0, 200, 0)
            "file.executable" = @(0, 255, 100)
            "file.symlink" = @(255, 255, 0)
            
            # Progress indicators
            "progress.background" = @(0, 40, 0)
            "progress.bar" = @(150, 255, 150)
            "progress.bar.complete" = @(0, 255, 0)
            "progress.text" = @(0, 200, 0)
            
            # Editor specific
            "editor.background" = @(0, 0, 0)
            "editor.linenumber" = @(0, 100, 0)
            "editor.cursor" = @(0, 255, 0)
            "editor.cursor.text" = @(0, 0, 0)
            "editor.selection" = @(0, 100, 0)
            "editor.selection.text" = @(150, 255, 150)
            "editor.status.background" = @(0, 30, 0)
            "editor.status.text" = @(0, 200, 0)
            
            # Gradient endpoints - for matrix rain effect
            "gradient.border.start" = @(150, 255, 150)    # Light green
            "gradient.border.end" = @(0, 100, 0)          # Dark green
            "gradient.bg.start" = @(0, 60, 0)             # Medium dark green
            "gradient.bg.end" = @(0, 0, 0)                # Black
            "gradient.rain.start" = @(200, 255, 200)      # Almost white green
            "gradient.rain.mid" = @(0, 255, 0)            # Bright green
            "gradient.rain.end" = @(0, 100, 0)            # Dark green
        }
        
        $this.RegisterTheme("matrix-rain", $matrixRainTheme)
        
        if ($global:Logger) {
            $global:Logger.Info("ThemeManager: Registered themes: default, matrix, amber, amber-black, matrix-rain")
        }
        
        $this.SetTheme("default")
    }
    
    # Register a new theme
    [void] RegisterTheme([string]$name, [hashtable]$colors) {
        $this._themes[$name] = $colors
        
        # If this is the current theme, rebuild cache
        if ($name -eq $this._currentTheme) {
            $this.RebuildCache()
        }
    }
    
    # Switch to a different theme
    [void] SetTheme([string]$name) {
        if ($global:Logger) {
            $global:Logger.Info("ThemeManager.SetTheme: Attempting to set theme to '$name'")
            $global:Logger.Debug("  Available themes: $($this._themes.Keys -join ', ')")
        }
        
        if (-not $this._themes.ContainsKey($name)) {
            if ($global:Logger) {
                $global:Logger.Error("Theme '$name' not found! Available: $($this._themes.Keys -join ', ')")
            }
            throw "Theme '$name' not found"
        }
        
        $oldTheme = $this._currentTheme
        $this._currentTheme = $name
        $this.RebuildCache()
        $this.UpdateThemeResetCache()
        
        if ($global:Logger) {
            $global:Logger.Info("ThemeManager: Theme changed from '$oldTheme' to '$name'")
        }
        
        # Notify via EventBus if available
        if ($this.EventBus) {
            $this.EventBus.Publish('app.themeChanged', @{
                OldTheme = $oldTheme
                NewTheme = $name
                ThemeManager = $this
            })
        }
        
        # Also notify legacy listeners for backward compatibility
        $this.NotifyListeners()
    }
    
    # Get gradient colors for borders or backgrounds
    [string[]] GetGradient([string]$startKey, [string]$endKey, [int]$steps) {
        $theme = $this._themes[$this._currentTheme]
        
        # Get start and end colors
        $startColor = $theme[$startKey]
        $endColor = $theme[$endKey]
        
        if (-not $startColor -or -not $endColor) {
            # Fallback to normal color
            return @($this.GetColor($startKey)) * $steps
        }
        
        return [VT]::VerticalGradient($startColor, $endColor, $steps)
    }
    
    # Get pre-computed ANSI color sequence
    [string] GetColor([string]$key) {
        if ($this._cache.ContainsKey($key)) {
            return $this._cache[$key]
        }
        
        # Not in cache, compute it
        $rgb = $this.GetRGB($key)
        if ($rgb) {
            $ansi = [VT]::RGB($rgb[0], $rgb[1], $rgb[2])
            $this._cache[$key] = $ansi
            return $ansi
        }
        
        return ""  # No color defined
    }
    
    # Get background color sequence
    [string] GetBgColor([string]$key) {
        $bgKey = "$key.bg"
        if ($this._cache.ContainsKey($bgKey)) {
            return $this._cache[$bgKey]
        }
        
        # Not in cache, compute it
        $rgb = $this.GetRGB($key)
        if ($rgb) {
            $ansi = [VT]::RGBBG($rgb[0], $rgb[1], $rgb[2])
            $this._cache[$bgKey] = $ansi
            return $ansi
        }
        
        return ""  # No color defined
    }
    
    # Get raw RGB values
    [int[]] GetRGB([string]$key) {
        $theme = $this._themes[$this._currentTheme]
        
        if ($theme.ContainsKey($key)) {
            return $theme[$key]
        }
        
        # Try parent keys (e.g., "button" for "button.focused.background")
        $parts = $key -split '\.'
        for ($i = $parts.Count - 1; $i -gt 0; $i--) {
            $parentKey = $parts[0..($i-1)] -join '.'
            if ($theme.ContainsKey($parentKey)) {
                return $theme[$parentKey]
            }
        }
        
        return $null
    }
    
    # Rebuild the entire cache
    hidden [void] RebuildCache() {
        $this._cache.Clear()
        $theme = $this._themes[$this._currentTheme]
        
        # Pre-compute all theme colors
        foreach ($key in $theme.Keys) {
            $rgb = $theme[$key]
            if ($rgb -is [array] -and $rgb.Count -eq 3) {
                # Foreground
                $this._cache[$key] = [VT]::RGB($rgb[0], $rgb[1], $rgb[2])
                # Background
                $this._cache["$key.bg"] = [VT]::RGBBG($rgb[0], $rgb[1], $rgb[2])
            }
        }
        
        # Add common combinations
        $this._cache["reset"] = 
        $this._cache["clear"] = [VT]::Clear()
        $this._cache["clearline"] = [VT]::ClearLine()
        
        # Update theme reset cache
        $this.UpdateThemeResetCache()
    }
    
    # Update cached theme reset sequence for performance
    [void] UpdateThemeResetCache() {
        # Get theme colors
        $fgRgb = $this.GetRGB("text.primary")
        $bgRgb = $this.GetRGB("surface.background")
        
        if ($fgRgb -and $bgRgb) {
            # Pre-build the reset sequence
            $this._cachedThemeReset = [VT]::RGB($fgRgb[0], $fgRgb[1], $fgRgb[2]) + [VT]::RGBBG($bgRgb[0], $bgRgb[1], $bgRgb[2])
        } else {
            $this._cachedThemeReset = ""
        }
    }
    
    # Get cached theme reset sequence (FAST - no computation)
    [string] GetThemeReset() {
        return $this._cachedThemeReset
    }
    
    # Subscribe to theme changes (legacy method - use EventBus instead)
    [void] Subscribe([scriptblock]$callback) {
        # Always use legacy listeners for now to avoid initialization order issues
        # EventBus subscription happens too early
        $this._listeners.Add($callback)
    }
    
    # Notify all listeners of theme change (legacy method)
    hidden [void] NotifyListeners() {
        # ALWAYS notify legacy listeners - components still use Subscribe()
        foreach ($listener in $this._listeners) {
            try {
                & $listener
            } catch {
                # Ignore listener errors
            }
        }
    }
    
    # Set EventBus after initialization (called by ServiceContainer)
    [void] SetEventBus([EventBus]$eventBus) {
        $this.EventBus = $eventBus
    }
    
    # Get list of available themes
    [string[]] GetThemeNames() {
        return $this._themes.Keys | Sort-Object
    }
    
    # Get current theme name
    [string] GetCurrentTheme() {
        return $this._currentTheme
    }
}