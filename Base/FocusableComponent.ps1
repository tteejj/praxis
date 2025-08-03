# FocusableComponent.ps1 - Base class for focusable UI components with minimalist styling
# Provides standardized focus handling and visual feedback

class FocusableComponent : Container {
    # Focus visual style
    [string]$FocusStyle = 'minimal'  # minimal, border, highlight
    [bool]$ShowFocusIndicator = $true
    
    # Pre-cached focus strings
    hidden [string]$_focusPrefix = ""
    hidden [string]$_focusSuffix = ""
    hidden [string]$_focusBorder = ""
    
    FocusableComponent() : base() {
        $this.IsFocusable = $true
    }
    
    [void] OnInitialize() {
        # Get theme manager for colors
        $this.Theme = $this.ServiceContainer.GetService('ThemeManager')
        if ($this.Theme) {
            $this.ApplyCompleteTheme()
            # Subscribe to theme changes via EventBus
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $eventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $this.ApplyCompleteTheme()
                }.GetNewClosure())
            }
        }
    }
    
    [void] UpdateFocusStyle() {
        if (-not $this.Theme -or -not $this.ShowFocusIndicator) { return }
        
        $focusColor = $this.Theme.GetColor('state.focused')
        $focusBg = $this.Theme.GetColor('focus.background')
        
        switch ($this.FocusStyle) {
            'minimal' {
                # Subtle underline effect
                $this._focusPrefix = [VT]::Underline() + $focusColor
                $this._focusSuffix = [VT]::NoUnderline() 
            }
            'border' {
                # Clean border (handled in render)
                $this._focusPrefix = $focusColor
                $this._focusSuffix = "" 
            }
            'highlight' {
                # Background highlight
                $this._focusPrefix = $focusBg + $focusColor
                $this._focusSuffix = "" 
            }
        }
    }
    
    # Island Components Theme Interface - Standard method for complete theme application
    [void] ApplyCompleteTheme() {
        if (-not $this.Theme) { return }
        
        # Update focus styling first
        $this.UpdateFocusStyle()
        
        # Pre-cache all theme colors that this component might use
        $this.CacheThemeColors()
        
        # Mark for complete re-render
        $this.Invalidate()
        
        # Propagate to children for island components
        foreach ($child in $this.Children) {
            if ($child -is [FocusableComponent]) {
                $child.ApplyCompleteTheme()
            }
        }
    }
    
    # Override in derived classes to cache component-specific theme colors
    [void] CacheThemeColors() {
        # Base implementation - derived classes should override
        # Example implementation pattern:
        # $this._colors = @{
        #     primary = $this.Theme.GetColor('text.primary')
        #     secondary = $this.Theme.GetColor('text.secondary')
        #     background = $this.Theme.GetBgColor('surface.background')
        #     border = $this.Theme.GetColor('border.normal')
        # }
    }
    
    # Render with focus indication - CLEAN approach like DialogField
    [string] OnRender() {
        # Let components handle their own focus styling
        # No automatic borders or styling from base class
        return $this.RenderContent()
    }
    
    # Override in derived classes to provide content
    [string] RenderContent() {
        return ""
    }
    
    # Render minimal focus border
    [void] RenderFocusBorder([System.Text.StringBuilder]$sb) {
        if ($this.Width -lt 2 -or $this.Height -lt 2) { return }
        
        # Top border
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append($this._focusPrefix)
        $sb.Append(' ' * $this.Width)
        
        # Side borders (minimal - just corners)
        $sb.Append([VT]::MoveTo($this.X, $this.Y))
        $sb.Append('┌')
        $sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y))
        $sb.Append('┐')
        
        # Bottom border
        $sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        $sb.Append('└')
        $sb.Append(' ' * ($this.Width - 2))
        $sb.Append('┘')
        $sb.Append($this._focusSuffix)
        
        # Render content inside border
        $sb.Append($this.RenderContent())
    }
    
    # Focus state changes
    [void] OnGotFocus() {
        $this.InvalidateFocusOnly()
    }
    
    [void] OnLostFocus() {
        $this.InvalidateFocusOnly()
    }
    
    # Handle common navigation keys
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Let derived classes handle first
        if ($this.OnHandleInput($key)) { return $true }
        
        # Tab navigation is now handled by Container base class
        # to use centralized FocusManager
        return $false
    }
    
    # Override in derived classes for custom input
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        return $false
    }
}