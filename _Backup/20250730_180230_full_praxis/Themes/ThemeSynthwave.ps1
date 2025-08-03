# ThemeSynthwave.ps1 - Retro 80s synthwave inspired theme with neon colors and gradients

class ThemeSynthwave {
    static [void] CreateSynthwave84() {
        [ThemeBuilder]::new("synthwave-84").
            BasedOn("dark").
            
            # Standardized text colors
            WithColor("text.primary", 255, 100, 200).     # Pink-tinted white (main text)
            WithColor("text.secondary", 200, 150, 255).   # Light purple (secondary text)
            WithColor("text.disabled", 100, 50, 120).     # Dim purple (disabled text)
            WithColor("text.heading", 255, 0, 144).       # Hot pink (headings/titles)
            WithColor("text.placeholder", 120, 60, 140).  # Dim pink (placeholder text)
            
            # Standardized surface colors
            WithColor("surface.background", 15, 0, 25).   # Deep purple-black
            WithColor("surface.elevated", 35, 15, 55).    # Dark purple
            WithColor("surface.dialog", 45, 20, 65).      # Lighter purple for dialogs
            
            # Standardized color palette
            WithColor("color.primary", 255, 0, 144).      # Hot pink
            WithColor("color.secondary", 0, 255, 255).    # Electric cyan
            
            # Standardized status colors
            WithColor("status.success", 0, 255, 127).     # Neon green
            WithColor("status.warning", 255, 255, 0).     # Neon yellow
            WithColor("status.error", 255, 30, 70).       # Neon red
            WithColor("status.info", 0, 191, 255).        # Electric blue
            
            # Standardized border colors
            WithColor("border.normal", 255, 0, 144).      # Hot pink borders
            WithColor("border.focused", 0, 255, 255).     # Cyan when focused
            WithColor("border.dialog", 255, 0, 144).      # Hot pink for dialogs
            WithColor("border.input", 150, 0, 100).       # Darker pink for inputs
            WithColor("border.input.focused", 0, 255, 255). # Cyan when input focused
            
            # Standardized interaction states
            WithColor("state.selected", 100, 0, 150).     # Deep pink for selected items
            WithColor("state.hover", 80, 30, 100).        # Purple for hover
            WithColor("state.pressed", 120, 40, 140).     # Brighter purple for pressed
            WithColor("state.focused", 0, 255, 255).      # Cyan for focused
            
            # Button states
            WithColor("button.background", 50, 20, 70).
            WithColor("button.text", 255, 100, 200).
            WithColor("button.background.hover", 70, 30, 90).
            WithColor("button.background.pressed", 90, 40, 110).
            WithColor("button.background.focused", 100, 0, 150).
            WithColor("button.text.focused", 0, 255, 255).
            
            # Input fields
            WithColor("input.background", 20, 10, 30).
            WithColor("input.text", 255, 100, 200).
            WithColor("input.placeholder", 120, 60, 140).
            
            # Menu colors
            WithColor("menu.background", 15, 0, 25).
            WithColor("menu.text", 200, 150, 255).
            WithColor("menu.background.selected", 100, 0, 150).
            WithColor("menu.text.selected", 0, 255, 255).
            
            # Tab colors
            WithColor("tab.background", 30, 10, 50).
            WithColor("tab.text", 150, 100, 200).
            WithColor("tab.background.active", 50, 0, 80).
            WithColor("tab.text.active", 255, 0, 144).
            WithColor("tab.border.active", 0, 255, 255).
            
            # List/Grid components
            WithColor("list.header.background", 50, 20, 70).
            WithColor("list.header.text", 255, 0, 144).
            WithColor("list.background", 15, 0, 25).
            WithColor("list.background.alternate", 25, 5, 35).
            WithColor("scrollbar.track", 100, 50, 120).
            WithColor("scrollbar.thumb", 255, 0, 144).
            
            # Checkbox/Radio
            WithColor("checkbox.background", 20, 10, 30).
            WithColor("checkbox.border", 150, 0, 100).
            WithColor("checkbox.check", 0, 255, 255).
            
            # Search/Highlight
            WithColor("search.background", 255, 255, 0).
            WithColor("search.text", 0, 0, 0).
            WithColor("highlight.background", 255, 255, 0).
            WithColor("highlight.text", 0, 0, 0).
            
            # File browser
            WithColor("file.directory", 0, 255, 255).
            WithColor("file.normal", 200, 150, 255).
            
            # File browser
            WithColor("file.executable", 0, 255, 127).
            WithColor("file.symlink", 255, 255, 0).
            
            # Progress indicators
            WithColor("progress.background", 50, 20, 70).
            WithColor("progress.bar", 0, 255, 255).
            WithColor("progress.bar.complete", 255, 0, 144).
            WithColor("progress.text", 255, 100, 200).
            
            # Editor specific
            WithColor("editor.background", 15, 0, 25).
            WithColor("editor.linenumber", 100, 50, 120).
            WithColor("editor.cursor", 255, 255, 255).
            WithColor("editor.cursor.text", 0, 0, 0).
            WithColor("editor.selection", 100, 0, 150).
            WithColor("editor.selection.text", 255, 255, 255).
            WithColor("editor.status.background", 35, 15, 55).
            WithColor("editor.status.text", 200, 150, 255).
            
            # Input field colors
            WithColor("input.text", 255, 100, 200).              # Pink-tinted white
            WithColor("input.placeholder", 120, 60, 140).        # Dim pink placeholders
            
            # Focus system colors
            WithColor("focus.reverse.background", 0, 255, 255).  # Cyan reverse background
            WithColor("focus.reverse.text", 15, 0, 25).          # Dark text on cyan
            
            # Menu system colors
            WithColor("menu.background", 35, 15, 55).            # Dark purple menu
            WithColor("menu.background.selected", 100, 0, 150).  # Deep pink selection
            WithColor("menu.text", 255, 100, 200).               # Pink menu text
            WithColor("menu.text.selected", 255, 255, 255).      # White selected text
            
            # List system colors
            WithColor("list.header.text", 255, 0, 144).          # Hot pink headers
            WithColor("list.header.background", 50, 20, 70).     # Dark purple header bg
            
            # Gradient endpoints for neon effects
            WithColor("gradient.border.start", 255, 0, 144).     # Hot pink
            WithColor("gradient.border.end", 0, 255, 255).       # Electric cyan
            WithColor("gradient.bg.start", 50, 0, 80).           # Purple
            WithColor("gradient.bg.end", 15, 0, 25).             # Deep purple-black
            WithColor("gradient.accent.start", 0, 255, 255).     # Cyan
            WithColor("gradient.accent.end", 255, 0, 144).       # Pink
            
            Build()
    }
    
    static [void] CreateSynthwaveOutrun() {
        # Alternative synthwave theme with sunset orange/purple tones
        [ThemeBuilder]::new("synthwave-outrun").
            BasedOn("dark").
            
            # Standardized text colors
            WithColor("text.primary", 255, 180, 120).     # Orange-tinted white (main text)
            WithColor("text.secondary", 200, 150, 255).   # Light purple (secondary text)
            WithColor("text.disabled", 80, 40, 100).      # Dim purple (disabled text)
            WithColor("text.heading", 255, 106, 0).       # Orange (headings/titles)
            WithColor("text.placeholder", 120, 80, 140).  # Dim orange (placeholder text)
            
            # Standardized surface colors
            WithColor("surface.background", 10, 0, 20).   # Almost black with purple tint
            WithColor("surface.elevated", 40, 10, 60).    # Dark purple surface
            WithColor("surface.dialog", 50, 20, 70).      # Lighter purple for dialogs
            
            # Standardized color palette
            WithColor("color.primary", 255, 106, 0).      # Orange
            WithColor("color.secondary", 138, 43, 226).   # Blue violet
            
            # Standardized status colors
            WithColor("status.success", 0, 255, 100).     # Lime green
            WithColor("status.warning", 255, 200, 0).     # Golden yellow
            WithColor("status.error", 255, 0, 60).        # Hot red
            WithColor("status.info", 100, 149, 237).      # Cornflower blue
            
            # Standardized border colors
            WithColor("border.normal", 255, 106, 0).      # Orange borders
            WithColor("border.focused", 138, 43, 226).    # Purple when focused
            WithColor("border.dialog", 255, 106, 0).      # Orange for dialogs
            WithColor("border.input", 200, 80, 0).        # Darker orange for inputs
            WithColor("border.input.focused", 138, 43, 226). # Purple when input focused
            
            # Standardized interaction states
            WithColor("state.selected", 180, 60, 0).      # Deep orange for selected items
            WithColor("state.hover", 100, 40, 150).       # Purple for hover
            WithColor("state.pressed", 120, 50, 140).     # Brighter purple for pressed
            WithColor("state.focused", 138, 43, 226).     # Purple for focused
            
            # Button states
            WithColor("button.background", 50, 20, 70).
            WithColor("button.text", 255, 150, 100).
            WithColor("button.background.hover", 70, 30, 90).
            WithColor("button.background.pressed", 90, 40, 110).
            WithColor("button.background.focused", 100, 40, 150).
            WithColor("button.text.focused", 138, 43, 226).
            
            # Input fields
            WithColor("input.background", 20, 10, 30).
            WithColor("input.text", 255, 150, 100).
            WithColor("input.placeholder", 120, 80, 140).
            
            # Menu colors
            WithColor("menu.background", 10, 0, 20).
            WithColor("menu.text", 200, 150, 255).
            WithColor("menu.background.selected", 100, 40, 150).
            WithColor("menu.text.selected", 255, 106, 0).
            
            # Tab colors
            WithColor("tab.background", 30, 10, 50).
            WithColor("tab.text", 150, 100, 200).
            WithColor("tab.background.active", 50, 20, 80).
            WithColor("tab.text.active", 255, 106, 0).
            WithColor("tab.border.active", 138, 43, 226).
            
            # List/Grid components
            WithColor("list.header.background", 50, 20, 70).
            WithColor("list.header.text", 255, 106, 0).
            WithColor("list.background", 10, 0, 20).
            WithColor("list.background.alternate", 20, 5, 30).
            WithColor("scrollbar.track", 100, 50, 120).
            WithColor("scrollbar.thumb", 255, 106, 0).
            
            # Checkbox/Radio
            WithColor("checkbox.background", 20, 10, 30).
            WithColor("checkbox.border", 200, 80, 0).
            WithColor("checkbox.check", 138, 43, 226).
            
            # Search/Highlight
            WithColor("search.background", 255, 200, 0).
            WithColor("search.text", 0, 0, 0).
            WithColor("highlight.background", 255, 255, 0).
            WithColor("highlight.text", 0, 0, 0).
            
            # File browser
            WithColor("file.directory", 138, 43, 226).
            WithColor("file.normal", 200, 150, 255).
            
            # File browser
            WithColor("file.executable", 0, 255, 100).
            WithColor("file.symlink", 255, 200, 0).
            
            # Progress indicators
            WithColor("progress.background", 50, 20, 70).
            WithColor("progress.bar", 138, 43, 226).
            WithColor("progress.bar.complete", 255, 106, 0).
            WithColor("progress.text", 255, 150, 100).
            
            # Editor specific
            WithColor("editor.background", 10, 0, 20).
            WithColor("editor.linenumber", 80, 40, 100).
            WithColor("editor.cursor", 255, 255, 255).
            WithColor("editor.cursor.text", 0, 0, 0).
            WithColor("editor.selection", 180, 60, 0).
            WithColor("editor.selection.text", 255, 255, 255).
            WithColor("editor.status.background", 40, 10, 60).
            WithColor("editor.status.text", 200, 150, 255).
            
            # Input field colors  
            WithColor("input.text", 255, 150, 100).              # Orange-tinted white
            WithColor("input.placeholder", 120, 60, 80).         # Dim orange placeholders
            
            # Focus system colors
            WithColor("focus.reverse.background", 255, 106, 0).  # Orange reverse background
            WithColor("focus.reverse.text", 10, 0, 20).          # Dark text on orange
            
            # Menu system colors
            WithColor("menu.background", 40, 10, 60).            # Dark purple menu
            WithColor("menu.background.selected", 180, 60, 0).   # Orange selection
            WithColor("menu.text", 255, 150, 100).               # Orange menu text
            WithColor("menu.text.selected", 255, 255, 255).      # White selected text
            
            # List system colors
            WithColor("list.header.text", 255, 106, 0).          # Orange headers
            WithColor("list.header.background", 50, 20, 70).     # Dark purple header bg
            
            # Gradient endpoints for sunset effect
            WithColor("gradient.border.start", 255, 106, 0).     # Orange
            WithColor("gradient.border.end", 138, 43, 226).      # Purple
            WithColor("gradient.bg.start", 60, 20, 90).          # Purple
            WithColor("gradient.bg.end", 10, 0, 20).             # Almost black
            WithColor("gradient.accent.start", 138, 43, 226).    # Purple
            WithColor("gradient.accent.end", 255, 106, 0).       # Orange
            
            Build()
    }
}