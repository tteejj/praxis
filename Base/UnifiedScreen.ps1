# UnifiedScreen.ps1 - Unified base class for all screens with consistent rendering
# Combines the best practices from UnifiedDialog and Screen classes
# Enhanced with auto-injection patterns from CRUDScreen

class UnifiedScreen : Screen {
    # Visual properties
    [bool]$ShowBorder = $true
    [bool]$ShowTitle = $true
    [BorderStyle]$BorderStyle
    
    # Layout properties
    [int]$ContentPadding = 1
    [hashtable]$Layout = @{
        TitleY = 0
        ContentY = 2
        ContentHeight = 0
    }
    
    # Service references - auto-injected
    [EventBus]$EventBus
    [ThemeManager]$Theme
    [FocusManager]$FocusManager
    
    # Theme caching
    hidden [hashtable]$_colors = @{}
    hidden [string]$_cachedBorder = ""
    hidden [int]$_lastWidth = 0
    hidden [int]$_lastHeight = 0
    
    # Event management
    hidden [hashtable]$_eventSubscriptions = @{}
    
    UnifiedScreen() : base() {
        $this.DrawBackground = $true
    }
    
    UnifiedScreen([string]$title) : base() {
        $this.Title = $title
        $this.DrawBackground = $true
    }
    
    [void] OnInitialize() {
        # Initialize border style
        $this.BorderStyle = [BorderStyle]::new()
        
        # Auto-inject common services
        $this.InjectServices()
        
        # Apply theme if available
        if ($this.Theme) {
            $this.ApplyCompleteTheme()
            
            # Subscribe to theme changes
            if ($this.EventBus) {
                $screen = $this
                $this._eventSubscriptions['theme.changed'] = $this.EventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $screen.ApplyCompleteTheme()
                }.GetNewClosure())
            }
        }
        
        # Let derived classes initialize
        $this.OnScreenInitialize()
    }
    
    [void] InjectServices() {
        # Auto-inject commonly needed services
        $this.EventBus = $this.GetService('EventBus')
        $this.Theme = $this.GetService('ThemeManager')
        $this.FocusManager = $this.GetService('FocusManager')
    }
    
    # Override in derived classes
    [void] OnScreenInitialize() {
        # Derived classes implement their initialization here
    }
    
    [void] ApplyCompleteTheme() {
        if (-not $this.Theme) { return }
        
        # Cache all theme colors
        $this._colors = @{
            border = $this.Theme.GetColor('border.normal')
            borderFocus = $this.Theme.GetColor('border.focused')
            title = $this.Theme.GetColor('text.title')
            background = $this.Theme.GetBgColor('surface.background')
            content = $this.Theme.GetBgColor('surface.content')
            text = $this.Theme.GetColor('text.primary')
        }
        
        # Update background color
        $this.SetBackgroundColor($this._colors.background)
        
        # Invalidate cached border
        $this._cachedBorder = ""
        
        # BorderStyle doesn't need color updates - it uses theme colors during render
        
        # Propagate to children
        foreach ($child in $this.Children) {
            if ($child.PSObject.Methods['ApplyCompleteTheme']) {
                $child.ApplyCompleteTheme()
            }
        }
        
        $this.Invalidate()
    }
    
    [void] OnBoundsChanged() {
        # Calculate layout
        $this.CalculateLayout()
        
        # Invalidate cached border if size changed
        if ($this.Width -ne $this._lastWidth -or $this.Height -ne $this._lastHeight) {
            $this._cachedBorder = ""
            $this._lastWidth = $this.Width
            $this._lastHeight = $this.Height
        }
        
        # Update background
        if ($this.DrawBackground) {
            $this.InvalidateBackground()
        }
        
        # Let derived classes layout their content
        $this.LayoutContent()
        
        # Call base to trigger render
        ([Screen]$this).OnBoundsChanged()
    }
    
    [void] CalculateLayout() {
        if ($this.ShowBorder) {
            $this.Layout.TitleY = $this.Y + 1
            $this.Layout.ContentY = $this.Y + 2
            $this.Layout.ContentHeight = $this.Height - 3
        } else {
            $this.Layout.TitleY = $this.Y
            $this.Layout.ContentY = $this.Y + 1
            $this.Layout.ContentHeight = $this.Height - 1
        }
        
        if (-not $this.ShowTitle) {
            $this.Layout.ContentY = $this.Layout.TitleY
            $this.Layout.ContentHeight += 1
        }
    }
    
    # Override in derived classes to layout content
    [void] LayoutContent() {
        # Derived classes implement their layout logic here
    }
    
    [string] OnRender() {
        $sb = [System.Text.StringBuilder]::new(8192)
        
        # Draw background first
        if ($this.DrawBackground -and $this._cachedBackground) {
            $sb.Append($this._cachedBackground)
        }
        
        # Draw border if enabled
        if ($this.ShowBorder) {
            if (-not $this._cachedBorder) {
                $this.CacheBorder()
            }
            $sb.Append($this._cachedBorder)
        }
        
        # Draw title if enabled
        if ($this.ShowTitle -and $this.Title) {
            $titleX = $this.X + [Math]::Max(2, ($this.Width - $this.Title.Length) / 2)
            $sb.Append([VT]::MoveTo($titleX, $this.Layout.TitleY))
            $sb.Append($this._colors.title)
            $sb.Append($this.Title)
        }
        
        # Render content
        $content = $this.RenderContent()
        if ($content) {
            $sb.Append($content)
        }
        
        # Render children
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $sb.Append($child.Render())
            }
        }
        
        return $sb.ToString()
    }
    
    # Override in derived classes to render custom content
    [string] RenderContent() {
        return ""
    }
    
    [void] CacheBorder() {
        if (-not $this.BorderStyle -or $this.Width -lt 2 -or $this.Height -lt 2) {
            $this._cachedBorder = ""
            return
        }
        
        $sb = [System.Text.StringBuilder]::new(($this.Width + 10) * 2)
        
        # Use BorderStyle for consistent rendering
        $borderType = if ($this.BorderStyle) { [BorderType]::Single } else { [BorderType]::None }
        $borderOutput = [BorderStyle]::RenderBorder($this.X, $this.Y, $this.Width, $this.Height, $borderType, $this._colors.border)
        $sb.Append($borderOutput)
        
        $this._cachedBorder = $sb.ToString()
    }
    
    # Content area helpers
    [int] GetContentX() {
        return $this.X + $(if ($this.ShowBorder) { $this.ContentPadding } else { 0 })
    }
    
    [int] GetContentY() {
        return $this.Layout.ContentY
    }
    
    [int] GetContentWidth() {
        return $this.Width - $(if ($this.ShowBorder) { $this.ContentPadding * 2 } else { 0 })
    }
    
    [int] GetContentHeight() {
        return $this.Layout.ContentHeight
    }
    
    # Handle input with proper focus management
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Let focused child handle input first
        if ($this.FocusManager) {
            $focused = $this.FocusManager.GetFocused()
            if ($focused -and $this.ContainsElement($focused)) {
                if ($focused.HandleInput($key)) {
                    return $true
                }
            }
        }
        
        # Handle screen-level shortcuts
        return $this.HandleScreenInput($key)
    }
    
    # Override in derived classes for screen-specific shortcuts
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        return $false
    }
    
    [bool] ContainsElement([UIElement]$element) {
        $current = $element
        while ($current) {
            if ($current -eq $this) { return $true }
            if ($current.Parent -eq $this) { return $true }
            $current = $current.Parent
        }
        return $false
    }
    
    # Focus management
    [void] FocusFirst() {
        if ($this.FocusManager) {
            $this.FocusManager.FocusFirst($this)
        }
    }
    
    [void] OnActivated() {
        # Focus first focusable element
        $this.FocusFirst()
        
        # Let derived classes handle activation
        $this.OnScreenActivated()
        
        # Ensure we're rendered
        $this.Invalidate()
    }
    
    [void] OnDeactivated() {
        # Let derived classes handle deactivation
        $this.OnScreenDeactivated()
    }
    
    # Override in derived classes
    [void] OnScreenActivated() {}
    [void] OnScreenDeactivated() {}
    
    # Cleanup when screen is disposed
    [void] Dispose() {
        # Unsubscribe from all events
        if ($this.EventBus -and $this._eventSubscriptions.Count -gt 0) {
            foreach ($key in $this._eventSubscriptions.Keys) {
                $this.EventBus.Unsubscribe($key, $this._eventSubscriptions[$key])
            }
            $this._eventSubscriptions.Clear()
        }
        
        # Call base dispose if it exists
        if (([Screen]$this).PSObject.Methods['Dispose']) {
            ([Screen]$this).Dispose()
        }
    }
    
    # Helper method to subscribe to events with automatic cleanup
    [void] SubscribeToEvent([string]$eventName, [scriptblock]$handler) {
        if ($this.EventBus) {
            $this._eventSubscriptions[$eventName] = $this.EventBus.Subscribe($eventName, $handler)
        }
    }
}