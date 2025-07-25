# BaseDialog.ps1 - Base class for modal dialogs to eliminate code duplication

class BaseDialog : Screen {
    # Dialog properties
    [int]$DialogWidth = 50
    [int]$DialogHeight = 14
    [int]$DialogPadding = 2
    [int]$ButtonHeight = 3
    [int]$ButtonSpacing = 2
    [int]$MaxButtonWidth = 12
    
    # Common buttons
    [Button]$PrimaryButton
    [Button]$SecondaryButton
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
        $this.PrimaryButton = [Button]::new($this.PrimaryButtonText)
        $this.PrimaryButton.IsDefault = $true
        $dialog = $this  # Capture reference
        $this.PrimaryButton.OnClick = {
            $dialog.HandlePrimaryAction()
        }.GetNewClosure()
        $this.PrimaryButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.PrimaryButton)
        
        # Create secondary button
        $this.SecondaryButton = [Button]::new($this.SecondaryButtonText)
        $this.SecondaryButton.OnClick = {
            $dialog.HandleSecondaryAction()
        }.GetNewClosure()
        $this.SecondaryButton.Initialize($global:ServiceContainer)
        $this.AddChild($this.SecondaryButton)
    }
    
    [void] AddContentControl([UIElement]$control, [int]$tabIndex = -1) {
        if ($tabIndex -gt 0) {
            $control.TabIndex = $tabIndex
        }
        $control.Initialize($global:ServiceContainer)
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
        
        # Focus first content control
        if ($this._contentControls.Count -gt 0) {
            $this._contentControls[0].Focus()
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
        # Dark overlay background
        $overlayBg = [VT]::RGBBG(16, 16, 16)  # Dark gray overlay
        for ($y = 0; $y -lt $this.Height; $y++) {
            $sb.Append([VT]::MoveTo(0, $y))
            $sb.Append($overlayBg)
            $sb.Append([StringCache]::GetSpaces($this.Width))
        }
    }
    
    [void] RenderDialogBox([System.Text.StringBuilder]$sb) {
        $borderColor = $this.Theme.GetColor("dialog.border")
        $bgColor = $this.Theme.GetBgColor("dialog.background")
        
        $x = $this._dialogBounds.X
        $y = $this._dialogBounds.Y
        $w = $this._dialogBounds.Width
        $h = $this._dialogBounds.Height
        
        # Fill background
        for ($i = 0; $i -lt $h; $i++) {
            $sb.Append([VT]::MoveTo($x, $y + $i))
            $sb.Append($bgColor)
            $sb.Append([StringCache]::GetSpaces($w))
        }
        
        # Draw border
        $sb.Append([VT]::MoveTo($x, $y))
        $sb.Append($borderColor)
        $sb.Append([VT]::TL() + [StringCache]::GetVTHorizontal($w - 2) + [VT]::TR())
        
        for ($i = 1; $i -lt $h - 1; $i++) {
            $sb.Append([VT]::MoveTo($x, $y + $i))
            $sb.Append([VT]::V())
            $sb.Append([VT]::MoveTo($x + $w - 1, $y + $i))
            $sb.Append([VT]::V())
        }
        
        $sb.Append([VT]::MoveTo($x, $y + $h - 1))
        $sb.Append([VT]::BL() + [StringCache]::GetVTHorizontal($w - 2) + [VT]::BR())
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
}