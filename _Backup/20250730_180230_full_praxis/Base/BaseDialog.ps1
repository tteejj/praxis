# BaseDialog.ps1 - Base class for modal dialogs to eliminate code duplication

class BaseDialog : Screen {
    # Dialog properties
    [int]$DialogWidth = 50
    [int]$DialogHeight = 14
    [int]$DialogPadding = 1
    [int]$ButtonHeight = 3
    [int]$ButtonSpacing = 1
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
    hidden [hashtable]$_contentLabels = @{}
    hidden [bool]$_initialized = $false
    [EventBus]$EventBus
    
    # Layout components
    hidden [VerticalSplit]$_mainLayout
    hidden [Container]$_contentContainer
    hidden [HorizontalSplit]$_buttonLayout
    
    BaseDialog([string]$title) : base() {
        $this.Title = $title
        $this.DrawBackground = $false
        $this._contentControls = [System.Collections.ArrayList]::new()
    }
    
    BaseDialog([string]$title, [int]$width, [int]$height) : base() {
        $this.Title = $title
        $this.DrawBackground = $false
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
        
        if ($global:Logger) {
            $global:Logger.Debug("BaseDialog.OnInitialize: Starting initialization for $($this.GetType().Name)")
        }
        
        # Call parent initialization to set Theme
        ([Screen]$this).OnInitialize()
        
        if ($global:Logger) {
            $themeStatus = if ($this.Theme) { "initialized" } else { "null" }
            $global:Logger.Debug("BaseDialog.OnInitialize: Theme is $themeStatus after Screen.OnInitialize()")
        }
        
        # Get EventBus
        $this.EventBus = $global:ServiceContainer.GetService('EventBus')
        
        # Create layout structure
        $this.CreateLayoutStructure()
        
        # Create default buttons
        $this.CreateDefaultButtons()
        
        # Call derived class initialization
        $this.InitializeContent()
        
        if ($global:Logger) {
            $global:Logger.Debug("BaseDialog.OnInitialize: Completed initialization for $($this.GetType().Name)")
        }
    }
    
    # Virtual method for derived classes to override
    [void] InitializeContent() {
        # Override in derived classes
    }
    
    [void] CreateLayoutStructure() {
        # Create main vertical split (content area + button area)
        $this._mainLayout = [VerticalSplit]::new()
        $this._mainLayout.ShowBorder = $false
        
        # Calculate split based on dialog height
        # Leave 3 lines for buttons (2 for button + 1 for spacing)
        $buttonHeightLocal = 3
        $contentHeightLocal = $this.DialogHeight - 3  # -2 for borders, -2 for title
        $splitRatio = [int](($contentHeightLocal * 100) / ($contentHeightLocal + $buttonHeightLocal))
        $this._mainLayout.SplitRatio = $splitRatio
        
        # Create content container
        $this._contentContainer = [Container]::new()
        $this._contentContainer.DrawBackground = $false
        $this._mainLayout.SetTopPane($this._contentContainer)
        
        # Create button container
        $buttonContainer = [Container]::new()
        $buttonContainer.DrawBackground = $false
        
        # Create horizontal split for buttons
        $this._buttonLayout = [HorizontalSplit]::new()
        $this._buttonLayout.ShowBorder = $false
        $this._buttonLayout.SplitRatio = 50  # Equal space for both buttons
        
        $buttonContainer.AddChild($this._buttonLayout)
        $this._mainLayout.SetBottomPane($buttonContainer)
        
        # Add main layout to dialog
        $this.AddChild($this._mainLayout)
    }
    
    [void] CreateDefaultButtons() {
        # Create primary button
        $this.PrimaryButton = [MinimalButton]::new($this.PrimaryButtonText)
        $this.PrimaryButton.IsDefault = $true
        $dialog = $this  # Capture reference
        $this.PrimaryButton.OnClick = {
            $dialog.HandlePrimaryAction()
        }.GetNewClosure()
        
        # Create secondary button
        $this.SecondaryButton = [MinimalButton]::new($this.SecondaryButtonText)
        $this.SecondaryButton.OnClick = {
            $dialog.HandleSecondaryAction()
        }.GetNewClosure()
        
        # Add buttons to layout instead of directly to dialog
        if ($this._buttonLayout) {
            $this._buttonLayout.SetLeftPane($this.PrimaryButton)
            $this._buttonLayout.SetRightPane($this.SecondaryButton)
        }
    }
    
    [void] AddContentControl([UIElement]$control, [int]$tabIndex = -1) {
        # Initialize the control if it hasn't been initialized
        if ($control -and -not $control._initialized -and $this.ServiceContainer) {
            $control.Initialize($this.ServiceContainer)
        }
        
        if ($tabIndex -gt 0) {
            $control.TabIndex = $tabIndex
        }
        
        # Position controls vertically based on their order
        $yOffset = 0
        foreach ($existing in $this._contentControls) {
            $yOffset += $existing.Height + 1  # +1 for spacing between fields
        }
        
        # Set control bounds within content container (relative positioning)
        # Controls will be positioned relative to their container, not absolute screen position
        $control.SetBounds(2, $yOffset, $this.DialogWidth - 6, $control.Height)
        
        # Add to content container instead of directly to dialog
        if ($this._contentContainer) {
            $this._contentContainer.AddChild($control)
        }
        $this._contentControls.Add($control) | Out-Null
    }
    
    [void] AddContentLabel([string]$text, [int]$section = 0) {
        # Store label for rendering in the dialog
        if (-not $this._contentLabels) {
            $this._contentLabels = @{}
        }
        $this._contentLabels[$section] = $text
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
            # Get the parent screen before popping
            $parentScreen = $null
            if ($global:ScreenManager.ScreenStack.Count -gt 1) {
                $parentScreen = $global:ScreenManager.ScreenStack[$global:ScreenManager.ScreenStack.Count - 2]
            }
            
            # Pop the dialog
            $global:ScreenManager.Pop()
            
            # Force parent to refresh and restore focus using memory system
            if ($parentScreen) {
                $parentScreen.Invalidate()
                
                # Try to restore focus using focus memory system
                $focusManager = $this.ServiceContainer.GetService('FocusManager')
                $focusRestored = $false
                
                if ($focusManager) {
                    $focusRestored = $focusManager.RestoreFocusContext()
                    if ($global:Logger) {
                        $status = if ($focusRestored) { "succeeded" } else { "failed" }
                        $global:Logger.Debug("BaseDialog.CloseDialog: Focus memory restore $status")
                    }
                }
                
                # Fallback focus restoration if memory system fails
                if (-not $focusRestored) {
                    if ($parentScreen.GetType().Name -eq 'MainScreen') {
                        # For MainScreen, switch focus back to content to restore highlighting
                        $parentScreen.SwitchFocusToContent()
                    } elseif ($parentScreen.GetType().GetProperty('SelectedIndex')) {
                        # If parent has a SelectedIndex (like a list), ensure it's visible
                        $parentScreen.OnActivated()
                    }
                }
                
                # Force a complete render refresh to restore visual state
                if ($parentScreen.PSObject.Methods['OnActivated']) {
                    $parentScreen.OnActivated()
                }
            }
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
                            $focusedType = if ($focused) { $focused.GetType().Name } else { "null" }                        }
                        if ($focused -and ($focused -is [MinimalButton] -or $focused -is [MinimalListBox])) {
                            # Let the button or list handle it
                            return $false
                        }
                    }
                    # No button focused, use default behavior
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
        ([Screen]$this).OnActivated()
        
        # Save focus context of parent screen before taking focus
        $focusManager = $this.ServiceContainer.GetService('FocusManager')
        if ($focusManager) {
            $focusManager.SaveFocusContext("Dialog_$($this.GetType().Name)")
        }
        
        # Publish dialog opened event
        if ($this.EventBus) {
            $this.EventBus.Publish([EventNames]::DialogOpened, @{ 
                Dialog = $this.GetType().Name
            })
        }
        
        # Ensure dialog is properly positioned
        $this.OnBoundsChanged()
        
        # Focus first focusable element in dialog (content controls or buttons)
        if ($focusManager) {
            $success = $focusManager.FocusFirst($this)
            if ($global:Logger) {
                $status = if ($success) { "succeeded" } else { "failed - no focusable elements" }
                $global:Logger.Debug("BaseDialog.OnActivated: Focus first element $status")
            }
            
            # Force render to show cursor
            $this.Invalidate()
        } else {
            if ($global:Logger) {
                $global:Logger.Warning("BaseDialog: FocusManager not available!")
            }
        }
    }
    
    [void] OnBoundsChanged() {
        # Get actual console dimensions
        $consoleWidth = [Console]::WindowWidth
        $consoleHeight = [Console]::WindowHeight
        
        # Constrain dialog size to fit within console
        $actualWidth = [Math]::Min($this.DialogWidth, $consoleWidth - 2)  # Leave margin
        $actualHeight = [Math]::Min($this.DialogHeight, $consoleHeight - 2)
        
        # Calculate dialog position (centered) using constrained dimensions
        $centerX = [int](($consoleWidth - $actualWidth) / 2)
        $centerY = [int](($consoleHeight - $actualHeight) / 2)
        
        # Ensure dialog stays on screen with proper bounds
        $centerX = [Math]::Max(0, $centerX)
        $centerY = [Math]::Max(0, $centerY)
        
        if ($global:Logger) {
            $dialogW = $this.DialogWidth
            $dialogH = $this.DialogHeight
            $global:Logger.Debug("BaseDialog.OnBoundsChanged: Console=${consoleWidth}x${consoleHeight}, Dialog=${dialogW}x${dialogH}, Actual=${actualWidth}x${actualHeight}, Position=${centerX},${centerY}")
        }
        
        # Store dialog bounds for rendering (use actual constrained size)
        $this._dialogBounds = @{
            X = $centerX
            Y = $centerY
            Width = $actualWidth
            Height = $actualHeight
        }
        
        # Update main layout bounds to fit inside dialog border
        if ($this._mainLayout) {
            $contentX = $centerX + 1  # Inside border
            $contentY = $centerY + 2  # Below title
            $contentWidth = $actualWidth - 2  # Account for borders (use actual width)
            $contentHeight = $actualHeight - 3  # Account for title and border (use actual height)
            
            $this._mainLayout.SetBounds($contentX, $contentY, $contentWidth, $contentHeight)
        }
    }
    
    # Virtual method for derived classes to override if they need custom layout
    [void] PositionContentControls([int]$dialogX, [int]$dialogY) {
        # NOW HANDLED BY LAYOUT COMPONENTS - Override only if needed
    }
    
    [void] PositionButtons([int]$dialogX, [int]$dialogY) {
        # NOW HANDLED BY LAYOUT COMPONENTS - Override only if needed
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

        $result = $sb.ToString()
        Return-PooledStringBuilder $sb  # Return to pool for reuse
        return $result
    }
    
    [void] RenderOverlay([System.Text.StringBuilder]$sb) {
        # Use theme background - NO FALLBACKS!
        if (-not $this.Theme) {
            if ($global:Logger) {
                $global:Logger.Error("BaseDialog.RenderOverlay: Theme is null!")
            }
            return
        }
        
        # Use theme overlay color - NO HARDCODED COLORS!
        $overlayColor = $this.Theme.GetBgColor('surface.background')
        
        # Fill entire screen with theme overlay
        for ($y = 0; $y -lt $this.Height; $y++) {
            $sb.Append([VT]::MoveTo(0, $y))
            $sb.Append($overlayColor)
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
        
        if ($useGradients -and $this.Theme) {
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
            # Standard rendering - NO FALLBACKS, theme MUST be valid
            if (-not $this.Theme) {
                if ($global:Logger) {
                    $global:Logger.Error("BaseDialog.RenderDialogBox: Theme is null!")
                }
                return
            }
            $borderColor = $this.Theme.GetColor("border.dialog")
            $bgColor = $this.Theme.GetBgColor("surface.dialog")
            
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
            if (-not $this.Theme) {
                if ($global:Logger) {
                    $global:Logger.Error("BaseDialog.RenderTitle: Theme is null!")
                }
                return
            }
            $titleColor = $this.Theme.GetColor("text.heading")
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
        # CRITICAL: Only render children within dialog bounds!
        $dialogX = $this._dialogBounds.X
        $dialogY = $this._dialogBounds.Y
        $dialogW = $this._dialogBounds.Width
        $dialogH = $this._dialogBounds.Height
        
        # Set clip bounds for all child rendering
        [RenderHelper]::SetClipBounds($dialogX, $dialogY, $dialogW, $dialogH)
        
        # The layout component will render all children automatically
        # Just render the main layout which contains everything
        if ($this._mainLayout -and $this._mainLayout.Visible) {
            $sb.Append($this._mainLayout.Render())
        }
        
        # Reset clip bounds after dialog rendering
        [RenderHelper]::ResetClipBounds()
    }
    
    [void] RenderContentLabels([System.Text.StringBuilder]$sb) {
        if (-not $this._contentLabels -or $this._contentLabels.Count -eq 0) { 
            return 
        }
        
        $labelColor = $this.Theme.GetColor('text.primary')
        
        # Find content controls and render labels above them
        foreach ($section in $this._contentLabels.Keys) {
            $label = $this._contentLabels[$section]
            
            # Find the corresponding content control  
            $contentControl = $null
            foreach ($control in $this._contentControls) {
                if ($control.TabIndex -eq $section) {
                    $contentControl = $control
                    break
                }
            }
            if ($contentControl) {
                # Position label one line above the control
                $labelX = $contentControl.X + 2  # Slight indent from control
                $labelY = $contentControl.Y - 1  # One line above control
                
                # Ensure label is within dialog bounds
                if ($labelY -gt $this._dialogBounds.Y) {
                    $sb.Append([VT]::MoveTo($labelX, $labelY))
                    $sb.Append($labelColor)
                    $sb.Append($label)
                    $sb.Append([VT]::Reset())
                }
            }
        }
    }
    
    # Tab navigation is now handled by Container base class via FocusManager
    # No need to override HandleInput for Tab anymore
}




