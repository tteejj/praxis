# Screen.ps1 - Base class for all screens
# Simplified from ALCAR with focus on speed

class Screen : Container {
    [string]$Title = "Screen"
    [bool]$Active = $true
    hidden [hashtable]$_keyBindings = @{}
    hidden [ThemeManager]$Theme
    
    Screen() : base() {
        $this.IsFocusable = $true
        $this.DrawBackground = $true
    }
    
    # Initialize with services
    [void] Initialize([ServiceContainer]$services) {
        $this.Theme = $services.GetService("ThemeManager")
        $this.Theme.Subscribe({ $this.OnThemeChanged() })
        $this.OnThemeChanged()
        $this.OnInitialize()
    }
    
    # Override for custom initialization
    [void] OnInitialize() {}
    
    # Theme change handler
    [void] OnThemeChanged() {
        $this.SetBackgroundColor($this.Theme.GetColor("background"))
        $this.Invalidate()
    }
    
    # Key binding management
    [void] BindKey([object]$key, [scriptblock]$action) {
        if ($key -is [System.ConsoleKey]) {
            $this._keyBindings[$key] = $action
        } elseif ($key -is [char]) {
            $this._keyBindings[[int]$key] = $action
        } elseif ($key -is [string] -and $key.Length -eq 1) {
            $this._keyBindings[[int]$key[0]] = $action
        } else {
            throw "Invalid key type for binding"
        }
    }
    
    # Input handling
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($global:Logger) {
            $global:Logger.Debug("Screen.HandleInput: Key=$($keyInfo.Key) Char='$($keyInfo.KeyChar)'")
        }
        
        # Check key bindings
        if ($this._keyBindings.ContainsKey($keyInfo.Key)) {
            if ($global:Logger) {
                $global:Logger.Debug("Screen: Found key binding for $($keyInfo.Key)")
            }
            & $this._keyBindings[$keyInfo.Key]
            return $true
        }
        
        # Check char bindings
        if ($keyInfo.KeyChar) {
            $charCode = [int]$keyInfo.KeyChar
            if ($this._keyBindings.ContainsKey($charCode)) {
                if ($global:Logger) {
                    $global:Logger.Debug("Screen: Found char binding for '$($keyInfo.KeyChar)'")
                }
                & $this._keyBindings[$charCode]
                return $true
            }
        }
        
        # Let base class handle it
        return ([Container]$this).HandleInput($keyInfo)
    }
    
    # Lifecycle methods
    [void] OnActivated() {
        # Force a render when screen is activated
        $this.Invalidate()
    }
    [void] OnDeactivated() {}
    
    # Request a re-render
    [void] RequestRender() {
        $this.Invalidate()
        # The ScreenManager will handle the actual rendering
    }
}