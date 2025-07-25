# BaseDialog.ps1 - Base class for modal dialogs to eliminate code duplication

class BaseDialog : Screen {
    # Dialog properties
    [int]$DialogWidth = 50
    [int]$DialogHeight = 14
    [int]$DialogPadding = 2
    [int]$ButtonHeight = 3
    [int]$ButtonSpacing = 2
    [int]$MaxButtonWidth = 12
    [BorderType]$BorderType = [BorderType]::Rounded
    
    # Common buttons
    [MinimalButton]$PrimaryButton
    [MinimalButton]$SecondaryButton
    [string]$PrimaryButtonText = "OK"
    [string]$SecondaryButtonText = "Cancel"
    
    # Event handlers
    [scriptblock]$OnPrimary = {}
    [scriptblock]$OnSecondary = {}
    [scriptblock]$OnCreate = {}  # Legacy support
    [scriptblock]$OnCancel = {}  # Legacy support
    
    # Internal state
    hidden [hashtable]$_dialogBounds = @{}
    hidden [System.Collections.ArrayList]$_contentControls
    hidden [bool]$_initialized = $false
    [EventBus]$EventBus
    
    BaseDialog([string]$title) : base() {
        $this.Title = $title
        $this.DrawBackground = $true
        $this._contentControls = [System.Collections.ArrayList]::new()
    }
    
    BaseDialog([string]$title, [int]$width, [int]$height) : base() {
        $this.Title = $title
        $this.DrawBackground = $true
        $this.DialogWidth = $width
        $this.DialogHeight = $height
        $this._contentControls = [System.Collections.ArrayList]::new()
    }
    
    [void] OnInitialize() {
        # Prevent double initialization
        if ($this._initialized) {
            return
        }
        $this._initialized = $true
        
        # Call parent initialization to set Theme
        ([Screen]$this).OnInitialize()
        
        # Get EventBus
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        
        # Create default buttons
        $this.CreateDefaultButtons()
        
        # Call derived class initialization
        $this.InitializeContent()
    }
    
    # Virtual method for derived classes to override
    [void] InitializeContent() {
        # Override in derived classes
    }
    
    [void] CreateDefaultButtons() {
        # Create primary button
        $this.PrimaryButton = [MinimalButton]::new($this.PrimaryButtonText)
        $this.PrimaryButton.IsDefault = $true
        $dialog = $this  # Capture reference
        $this.PrimaryButton.OnClick = {
            $dialog.HandlePrimaryAction()
        }.GetNewClosure()
        $this.AddChild($this.PrimaryButton)
        
        # Create secondary button
        $this.SecondaryButton = [MinimalButton]::new($this.SecondaryButtonText)
        $this.SecondaryButton.OnClick = {
            $dialog.HandleSecondaryAction()
        }.GetNewClosure()
        $this.AddChild($this.SecondaryButton)
    }
    
    [void] AddContentControl([UIElement]$control, [int]$tabIndex = -1) {
        if ($tabIndex -gt 0) {
            $control.TabIndex = $tabIndex
        }
        $this.AddChild($control)
        $this._contentControls.Add($control) | Out-Null
    }
    
    [void] HandlePrimaryAction() {
        # Call custom handler first
        if ($this.OnPrimary -and $this.OnPrimary.GetType().Name -eq 'ScriptBlock') {
            & $this.OnPrimary
        }
        
        # Legacy support
        if ($this.OnCreate -and $this.OnCreate.GetType().Name -eq 'ScriptBlock') {
            & $this.OnCreate
        }
        
        # Default behavior - close dialog
        $this.CloseDialog()
    }
    
    [void] HandleSecondaryAction() {
        # Call custom handler first
        if ($this.OnSecondary -and $this.OnSecondary.GetType().Name -eq 'ScriptBlock') {
            & $this.OnSecondary
        }
        
        # Legacy support  
        if ($this.OnCancel -and $this.OnCancel.GetType().Name -eq 'ScriptBlock') {
            & $this.OnCancel
        }
        
        # Default behavior - close dialog
        $this.CloseDialog()
    }
    
    [void] CloseDialog() {
        if ($global:ScreenManager) {
            $global:ScreenManager.Pop()
        }
    }
    
    # PARENT-DELEGATED INPUT MODEL (inherits from Screen)
    # Dialog shortcuts are handled via HandleScreenInput
    [bool] HandleScreenInput([System.ConsoleKeyInfo]$key) {
        # Dialog-specific shortcuts
        switch ($key.Key) {
            ([System.ConsoleKey]::Enter) {
                if (-not $key.Modifiers) {
                    # Only handle Enter if no button has focus
                    # This allows buttons to handle their own Enter key
                    $focusManager = $this.ServiceContainer.GetService('FocusManager')
                    if ($focusManager) {
                        $focused = $focusManager.GetFocused()
                        if ($global:Logger) {
                            $focusedType = if ($focused) { $focused.GetType().Name } else { "null" }
                            $global:Logger.Debug("BaseDialog.HandleScreenInput: Enter pressed, focused element: $focusedType")
                        }
                        if ($focused -and $focused -is [MinimalButton]) {
                            # Let the button handle it
                            if ($global:Logger) {
                                $global:Logger.Debug("BaseDialog: Button has focus, letting it handle Enter")
                            }
                            return $false
                        }
                    }
                    # No button focused, use default behavior
                    if ($global:Logger) {
                        $global:Logger.Debug("BaseDialog: No button focused, calling HandlePrimaryAction")
                    }
                    $this.HandlePrimaryAction()
                    return $true
                }
            }
            ([System.ConsoleKey]::Escape) {
                $this.HandleSecondaryAction()
                return $true
            }
        }
        return $false
    }
    
    [void] OnActivated() {
        # Publish dialog opened event
        if ($this.EventBus) {
            $this.EventBus.Publish([EventNames]::DialogOpened, @{ 
                Dialog = $this.GetType().Name
            })
        }
        
        if ($global:Logger) {
            $global:Logger.Debug("BaseDialog.OnActivated: Dialog=$($this.GetType().Name) ContentControls=$($this._contentControls.Count)")
        }
        
        # Focus first content control
        if ($this._contentControls.Count -gt 0) {
            $firstControl = $this._contentControls[0]
            if ($global:Logger) {
                $global:Logger.Debug("BaseDialog: Focusing first control: $($firstControl.GetType().Name)")
            }
            $firstControl.Focus()
            
            # Verify focus was set
            if ($global:Logger) {
                $focusManager = $this.ServiceContainer.GetService('FocusManager')
                if ($focusManager) {
                    $focused = $focusManager.GetFocused()
                    if ($focused) {
                        $global:Logger.Debug("BaseDialog: FocusManager reports focused: $($focused.GetType().Name)")
                    } else {
                        $global:Logger.Warning("BaseDialog: FocusManager reports NO focused element!")
                    }
                } else {
                    $global:Logger.Warning("BaseDialog: No FocusManager available!")
                }
            }
        } else {
            if ($global:Logger) {
                $global:Logger.Warning("BaseDialog: No content controls to focus!")
            }
        }
    }
    
    [void] OnBoundsChanged() {
        # Calculate dialog position (centered)
        $centerX = [int](($this.Width - $this.DialogWidth) / 2)
        $centerY = [int](($this.Height - $this.DialogHeight) / 2)
        
        # Store dialog bounds for rendering
        $this._dialogBounds = @{
            X = $centerX
            Y = $centerY
            Width = $this.DialogWidth
            Height = $this.DialogHeight
        }
        
        # Position content controls
        $this.PositionContentControls($centerX, $centerY)
        
        # Position buttons
        $this.PositionButtons($centerX, $centerY)
    }
    
    # Virtual method for derived classes to override content positioning
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # Default implementation - stack controls vertically
        $currentY = $dialogY + $this.DialogPadding
        $controlWidth = $this.DialogWidth - ($this.DialogPadding * 2)
        $controlHeight = 3
        
        foreach ($control in $this._contentControls) {
            $control.SetBounds(
                $dialogX + $this.DialogPadding,
                $currentY,
                $controlWidth,
                $controlHeight
            )
            $currentY += $controlHeight + 1
        }
    }
    
    [void] PositionButtons([int]$dialogX, [int]$dialogY) {
        # Calculate button positioning
        $buttonY = $dialogY + $this.DialogHeight - $this.ButtonHeight - 1
        $totalButtonWidth = ($this.MaxButtonWidth * 2) + $this.ButtonSpacing
        
        # Center buttons if dialog is wide enough
        if ($this.DialogWidth -gt $totalButtonWidth) {
            $buttonStartX = $dialogX + [int](($this.DialogWidth - $totalButtonWidth) / 2)
            $buttonWidth = $this.MaxButtonWidth
        } else {
            $buttonStartX = $dialogX + $this.DialogPadding
            $buttonWidth = [int](($this.DialogWidth - ($this.DialogPadding * 2) - $this.ButtonSpacing) / 2)
        }
        
        # Position primary button
        $this.PrimaryButton.SetBounds(
            $buttonStartX,
            $buttonY,
            $buttonWidth,
            $this.ButtonHeight
        )
        
        # Position secondary button
        $this.SecondaryButton.SetBounds(
            $buttonStartX + $buttonWidth + $this.ButtonSpacing,
            $buttonY,
            $buttonWidth,
            $this.ButtonHeight
        )
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 1024  # Dialogs need moderate capacity
        
        # Render overlay background
        $this.RenderOverlay($sb)
        
        # Render dialog box
        if ($this._dialogBounds.Count -gt 0) {
            $this.RenderDialogBox($sb)
            $this.RenderTitle($sb)
        }
        
        # Render children (content controls and buttons) only within dialog bounds
        $this.RenderDialogChildren($sb)
        
        $sb.Append([VT]::Reset())
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb  # Return to pool for reuse
        return $result
    }
    
    [void] RenderOverlay([System.Text.StringBuilder]$sb) {
        # Use theme background with slight transparency effect
        $themeBg = $this.Theme.GetBgColor("background")
        if ($global:Logger) {
            $global:Logger.Debug("BaseDialog.RenderOverlay: Theme background color: '$themeBg'")
        }
        # For dialogs, darken the background slightly
        for ($y = 0; $y -lt $this.Height; $y++) {
            $sb.Append([VT]::MoveTo(0, $y))
            $sb.Append($themeBg)
            $sb.Append([StringCache]::GetSpaces($this.Width))
        }
    }
    
    [void] RenderDialogBox([System.Text.StringBuilder]$sb) {
        $x = $this._dialogBounds.X
        $y = $this._dialogBounds.Y
        $w = $this._dialogBounds.Width
        $h = $this._dialogBounds.Height
        
        # Check if gradients are enabled
        $useGradients = $false
        $configService = $this.ServiceContainer.GetService('ConfigurationService')
        if ($configService) {
            $useGradients = $configService.Get("UI.UseGradients", $false)
        }
        
        if ($useGradients) {
            # Get gradient colors
            $bgGradient = $this.Theme.GetGradient("gradient.bg.start", "gradient.bg.end", $h)
            
            # Fill background with gradient
            for ($i = 0; $i -lt $h; $i++) {
                $sb.Append([VT]::MoveTo($x, $y + $i))
                # Extract RGB values from gradient color
                $gradientColor = $this.Theme._themes[$this.Theme._currentTheme]["gradient.bg.start"]
                $endColor = $this.Theme._themes[$this.Theme._currentTheme]["gradient.bg.end"]
                $position = $i / [double]($h - 1)
                $r = [int]($gradientColor[0] + ($endColor[0] - $gradientColor[0]) * $position)
                $g = [int]($gradientColor[1] + ($endColor[1] - $gradientColor[1]) * $position)
                $b = [int]($gradientColor[2] + ($endColor[2] - $gradientColor[2]) * $position)
                $sb.Append([VT]::RGBBG($r, $g, $b))
                $sb.Append([StringCache]::GetSpaces($w))
            }
            
            # Draw border with gradient (vertical gradient on sides)
            $borderGradient = $this.Theme.GetGradient("gradient.border.start", "gradient.border.end", $h)
            $this.RenderGradientBorder($sb, $x, $y, $w, $h, $borderGradient)
        } else {
            # Standard rendering
            $borderColor = $this.Theme.GetColor("dialog.border")
            $bgColor = $this.Theme.GetBgColor("dialog.background")
            
            # Fill background
            for ($i = 0; $i -lt $h; $i++) {
                $sb.Append([VT]::MoveTo($x, $y + $i))
                $sb.Append($bgColor)
                $sb.Append([StringCache]::GetSpaces($w))
            }
            
            # Draw border using BorderStyle system
            $sb.Append([BorderStyle]::RenderBorder($x, $y, $w, $h, $this.BorderType, $borderColor))
        }
    }
    
    [void] RenderGradientBorder([System.Text.StringBuilder]$sb, [int]$x, [int]$y, [int]$w, [int]$h, [string[]]$gradient) {
        # Top border
        $sb.Append([VT]::MoveTo($x, $y))
        $sb.Append($gradient[0])
        $sb.Append([VT]::TL())
        $sb.Append([StringCache]::GetHorizontalLine($w - 2))
        $sb.Append([VT]::TR())
        
        # Sides with gradient
        for ($i = 1; $i -lt $h - 1; $i++) {
            $color = $gradient[$i]
            # Left side
            $sb.Append([VT]::MoveTo($x, $y + $i))
            $sb.Append($color)
            $sb.Append([VT]::V())
            
            # Right side
            $sb.Append([VT]::MoveTo($x + $w - 1, $y + $i))
            $sb.Append($color)
            $sb.Append([VT]::V())
        }
        
        # Bottom border
        $sb.Append([VT]::MoveTo($x, $y + $h - 1))
        $sb.Append($gradient[$h - 1])
        $sb.Append([VT]::BL())
        $sb.Append([StringCache]::GetHorizontalLine($w - 2))
        $sb.Append([VT]::BR())
    }
    
    [void] RenderTitle([System.Text.StringBuilder]$sb) {
        if (-not [string]::IsNullOrEmpty($this.Title)) {
            $titleColor = $this.Theme.GetColor("dialog.title")
            $x = $this._dialogBounds.X
            $y = $this._dialogBounds.Y
            $w = $this._dialogBounds.Width
            
            # Calculate title position (centered)
            $titleText = " $($this.Title) "
            $titleX = $x + [int](($w - $titleText.Length) / 2)
            
            $sb.Append([VT]::MoveTo($titleX, $y))
            $sb.Append($titleColor)
            $sb.Append($titleText)
        }
    }
    
    [void] RenderDialogChildren([System.Text.StringBuilder]$sb) {
        # Render all visible children - they should be positioned correctly by OnBoundsChanged
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $sb.Append($child.Render())
            }
        }
    }
    
    # Tab navigation is now handled by Container base class via FocusManager
    # No need to override HandleInput for Tab anymore
}