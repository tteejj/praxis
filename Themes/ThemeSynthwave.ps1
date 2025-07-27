# ThemeSynthwave.ps1 - Retro 80s synthwave inspired theme with neon colors and gradients

class ThemeSynthwave {
    static [void] CreateSynthwave84() {
        [ThemeBuilder]::new("synthwave-84").
            BasedOn("dark").
            # Core synthwave colors
            WithPrimary(255, 0, 144).         # Hot pink/magenta - main accent
            WithSecondary(0, 255, 255).       # Electric cyan - secondary accent
            WithBackground(15, 0, 25).        # Deep purple-black - night sky
            WithSurface(35, 15, 55).          # Dark purple - elevated surfaces
            WithError(255, 30, 70).           # Neon red
            WithWarning(255, 255, 0).         # Neon yellow
            WithSuccess(0, 255, 127).         # Neon green
            WithColor("info", 0, 191, 255).   # Electric blue
            
            # Text colors for contrast
            WithColor("on-primary", 255, 255, 255).      # White on pink
            WithColor("on-secondary", 0, 0, 0).          # Black on cyan
            WithColor("on-background", 255, 100, 200).   # Pink-tinted white
            WithColor("on-surface", 200, 150, 255).      # Light purple
            WithColor("on-error", 255, 255, 255).        # White on red
            
            # UI element colors
            WithColor("border", 255, 0, 144).             # Hot pink borders
            WithColor("border.focused", 0, 255, 255).     # Cyan when focused
            WithColor("selection", 255, 0, 144).          # Pink selection
            WithColor("disabled", 100, 50, 120).          # Dim purple
            
            # Focus system colors with neon glow
            WithColor("focus", 0, 255, 255).              # Cyan focus
            WithColor("focus.background", 50, 0, 80).     # Purple glow background
            WithColor("focus.accent", 255, 100, 200).     # Pink accent
            
            # Component specific - neon styling
            WithColor("title", 255, 0, 144).              # Hot pink titles
            WithColor("normal", 200, 150, 255).           # Light purple text
            WithColor("selected", 255, 0, 144).           # Pink selected
            
            # Buttons with gradient potential
            WithColor("button.background", 50, 20, 70).
            WithColor("button.foreground", 255, 100, 200).
            WithColor("button.focused.background", 100, 0, 150).
            WithColor("button.focused.foreground", 0, 255, 255).
            WithColor("button.hover.background", 80, 30, 100).
            WithColor("button.pressed.background", 120, 40, 140).
            
            # Inputs with neon borders
            WithColor("input.background", 20, 10, 30).
            WithColor("input.foreground", 255, 100, 200).
            WithColor("input.focused.border", 0, 255, 255).
            WithColor("input.border", 100, 50, 120).
            WithColor("input.placeholder", 100, 70, 130).
            
            # Menus with synthwave styling
            WithColor("menu.background", 15, 0, 25).
            WithColor("menu.foreground", 200, 150, 255).
            WithColor("menu.selected.background", 100, 0, 150).
            WithColor("menu.selected.foreground", 0, 255, 255).
            
            # Tabs with gradient potential
            WithColor("tab.background", 30, 10, 50).
            WithColor("tab.foreground", 150, 100, 200).
            WithColor("tab.active.background", 50, 0, 80).
            WithColor("tab.active.foreground", 255, 0, 144).
            WithColor("tab.active.accent", 0, 255, 255).
            
            # DataGrid with neon styling
            WithColor("header.background", 50, 20, 70).
            WithColor("header.foreground", 255, 0, 144).
            WithColor("scrollbar", 100, 50, 120).
            WithColor("scrollbar.thumb", 255, 0, 144).
            
            # Additional neon effects
            WithColor("checkbox", 0, 255, 255).
            WithColor("checkbox.selected", 255, 0, 144).
            WithColor("search", 255, 255, 0).
            WithColor("highlight", 255, 255, 0).
            WithColor("directory", 0, 255, 255).
            WithColor("file", 200, 150, 255).
            
            # Progress bars with neon
            WithColor("progress.active", 0, 255, 255).
            WithColor("progress.complete", 255, 0, 144).
            WithColor("progress.text", 255, 100, 200).
            
            # Dialog neon borders
            WithColor("dialog.background", 25, 10, 40).
            WithColor("dialog.border", 255, 0, 144).
            WithColor("dialog.title", 0, 255, 255).
            
            # Additional border states
            WithColor("border.normal", 255, 0, 144).
            
            # GRADIENT ENDPOINTS for amazing neon effects
            # Border gradients - hot pink to cyan for that neon glow
            WithColor("gradient.border.start", 255, 0, 144).     # Hot pink
            WithColor("gradient.border.end", 0, 255, 255).       # Electric cyan
            
            # Background gradients - deep purple fade
            WithColor("gradient.bg.start", 50, 0, 80).           # Purple
            WithColor("gradient.bg.end", 15, 0, 25).             # Deep purple-black
            
            # Special neon glow gradients
            WithColor("gradient.glow.start", 255, 100, 200).     # Light pink
            WithColor("gradient.glow.end", 100, 0, 150).         # Deep purple
            
            # Accent gradients for special effects
            WithColor("gradient.accent.start", 0, 255, 255).     # Cyan
            WithColor("gradient.accent.end", 255, 0, 144).       # Pink
            
            # Status gradients
            WithColor("gradient.error.start", 255, 30, 70).      # Neon red
            WithColor("gradient.error.end", 150, 0, 50).         # Dark red
            
            WithColor("gradient.success.start", 0, 255, 127).    # Neon green
            WithColor("gradient.success.end", 0, 150, 80).       # Dark green
            
            # State modifiers would need to be stored differently
            # For now, we'll use predefined color variations
            
            Build()
    }
    
    static [void] CreateSynthwaveOutrun() {
        # Alternative synthwave theme with more orange/purple tones
        [ThemeBuilder]::new("synthwave-outrun").
            BasedOn("dark").
            # Outrun variant colors
            WithPrimary(255, 106, 0).         # Orange - sunset accent
            WithSecondary(138, 43, 226).      # Blue violet - secondary
            WithBackground(10, 0, 20).        # Almost black with purple tint
            WithSurface(40, 10, 60).          # Dark purple surface
            WithError(255, 0, 60).            # Hot red
            WithWarning(255, 200, 0).         # Golden yellow
            WithSuccess(0, 255, 100).         # Lime green
            WithColor("info", 100, 149, 237). # Cornflower blue
            
            # UI element colors needed before AutoGenerateTextColors
            WithColor("border", 255, 106, 0).             # Orange borders
            WithColor("border.focused", 138, 43, 226).    # Purple when focused
            WithColor("selection", 255, 106, 0).          # Orange selection
            WithColor("disabled", 80, 40, 100).           # Dim purple
            
            # Focus system colors
            WithColor("focus", 138, 43, 226).             # Purple focus
            WithColor("focus.background", 60, 20, 80).    # Purple glow background
            WithColor("focus.accent", 255, 150, 50).      # Orange accent
            
            # Component specific
            WithColor("title", 255, 106, 0).              # Orange titles
            WithColor("normal", 200, 150, 255).           # Light purple text
            WithColor("selected", 255, 106, 0).           # Orange selected
            
            # Buttons
            WithColor("button.background", 50, 20, 70).
            WithColor("button.foreground", 255, 150, 100).
            WithColor("button.focused.background", 100, 40, 150).
            WithColor("button.focused.foreground", 138, 43, 226).
            WithColor("button.hover.background", 80, 30, 100).
            WithColor("button.pressed.background", 120, 50, 140).
            
            # Inputs
            WithColor("input.background", 20, 10, 30).
            WithColor("input.foreground", 255, 150, 100).
            WithColor("input.focused.border", 138, 43, 226).
            WithColor("input.border", 100, 50, 120).
            WithColor("input.placeholder", 100, 70, 130).
            
            # Menus
            WithColor("menu.background", 10, 0, 20).
            WithColor("menu.foreground", 200, 150, 255).
            WithColor("menu.selected.background", 100, 40, 150).
            WithColor("menu.selected.foreground", 255, 106, 0).
            
            # Tabs
            WithColor("tab.background", 30, 10, 50).
            WithColor("tab.foreground", 150, 100, 200).
            WithColor("tab.active.background", 50, 20, 80).
            WithColor("tab.active.foreground", 255, 106, 0).
            WithColor("tab.active.accent", 138, 43, 226).
            
            # DataGrid
            WithColor("header.background", 50, 20, 70).
            WithColor("header.foreground", 255, 106, 0).
            WithColor("scrollbar", 100, 50, 120).
            WithColor("scrollbar.thumb", 255, 106, 0).
            
            # Additional
            WithColor("checkbox", 138, 43, 226).
            WithColor("checkbox.selected", 255, 106, 0).
            WithColor("search", 255, 200, 0).
            WithColor("highlight", 255, 255, 0).
            WithColor("directory", 138, 43, 226).
            WithColor("file", 200, 150, 255).
            
            # Progress bars
            WithColor("progress.active", 138, 43, 226).
            WithColor("progress.complete", 255, 106, 0).
            WithColor("progress.text", 255, 150, 100).
            
            # Dialogs
            WithColor("dialog.background", 25, 10, 40).
            WithColor("dialog.border", 255, 106, 0).
            WithColor("dialog.title", 138, 43, 226).
            
            # Border states
            WithColor("border.normal", 255, 106, 0).
            
            # Gradient endpoints for sunset effect
            WithColor("gradient.border.start", 255, 106, 0).     # Orange
            WithColor("gradient.border.end", 138, 43, 226).      # Purple
            WithColor("gradient.bg.start", 60, 20, 90).          # Purple
            WithColor("gradient.bg.end", 10, 0, 20).             # Almost black
            
            # Special sunset gradient
            WithColor("gradient.sunset.start", 255, 94, 77).     # Coral
            WithColor("gradient.sunset.mid", 255, 0, 144).       # Hot pink
            WithColor("gradient.sunset.end", 138, 43, 226).      # Blue violet
            
            # Gradient effects
            WithColor("gradient.glow.start", 255, 150, 100).     # Light orange
            WithColor("gradient.glow.end", 100, 40, 150).        # Deep purple
            WithColor("gradient.accent.start", 138, 43, 226).    # Purple
            WithColor("gradient.accent.end", 255, 106, 0).       # Orange
            WithColor("gradient.error.start", 255, 0, 60).       # Hot red
            WithColor("gradient.error.end", 150, 0, 30).         # Dark red
            WithColor("gradient.success.start", 0, 255, 100).    # Lime green
            WithColor("gradient.success.end", 0, 150, 60).       # Dark green
            
            Build()
    }
}