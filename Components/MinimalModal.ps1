# MinimalModal.ps1 - Clean, minimal modal dialog system

class MinimalModal : Screen {
    [string]$Title = ""
    [UIElement]$Content
    [int]$ModalWidth = 60
    [int]$ModalHeight = 20
    [BorderType]$BorderType = [BorderType]::Rounded
    [bool]$ShowOverlay = $true
    [bool]$CenterContent = $true
    
    # Buttons
    [System.Collections.Generic.List[ModalButton]]$Buttons
    [int]$SelectedButtonIndex = 0
    
    # Actions
    [scriptblock]$OnClose = {}
    
    # Internal
    hidden [Container]$ModalContainer
    hidden [Container]$ButtonContainer
    hidden [hashtable]$_colors = @{}
    hidden [int]$_modalX
    hidden [int]$_modalY
    
    MinimalModal() : base() {
        $this.Buttons = [System.Collections.Generic.List[ModalButton]]::new()
        $this.DrawBackground = $true
    }
    
    [void] OnInitialize() {
        ([Screen]$this).OnInitialize()
        
        # Set dark overlay background
        if ($this.ShowOverlay -and $this.Theme) {
            $overlayColor = [VT]::RGBBG(0, 0, 0)  # Black overlay
            $this.SetBackgroundColor($overlayColor)
        }
        
        # Update colors
        $this.UpdateColors()
        if ($this.Theme) {
            # Subscribe to theme changes via EventBus
            $eventBus = $this.ServiceContainer.GetService('EventBus')
            if ($eventBus) {
                $eventBus.Subscribe('theme.changed', {
                    param($sender, $eventData)
                    $this.UpdateColors()
                }.GetNewClosure())
            }
        }
        
        # Create modal container
        $this.ModalContainer = [Container]::new()
        $this.ModalContainer.DrawBackground = $true
        
        # Calculate centered position
        $this._modalX = [Math]::Max(1, ($this.Width - $this.ModalWidth) / 2)
        $this._modalY = [Math]::Max(1, ($this.Height - $this.ModalHeight) / 2)
        
        $this.ModalContainer.SetBounds(
            $this.X + $this._modalX,
            $this.Y + $this._modalY,
            $this.ModalWidth,
            $this.ModalHeight
        )
        
        # Add content if provided
        if ($this.Content) {
            $this.ModalContainer.AddChild($this.Content)
            $this.Content.Initialize($this.ServiceContainer)
        }
        
        # Create button container
        if ($this.Buttons.Count -gt 0) {
            $this.CreateButtonContainer()
        }
        
        $this.AddChild($this.ModalContainer)
        
        # Focus first button or content
        $this.FocusFirst()
    }
    
    [void] UpdateColors() {
        if ($this.Theme) {
            $this._colors = @{
                modalBg = $this.Theme.GetBgColor('menu.background')
                border = $this.Theme.GetColor('border.focused')
                title = $this.Theme.GetColor('accent')
                text = $this.Theme.GetColor('normal')
            }
            
            if ($this.ModalContainer) {
                $this.ModalContainer.SetBackgroundColor($this._colors.modalBg)
            }
        }
    }
    
    [void] CreateButtonContainer() {
        $this.ButtonContainer = [Container]::new()
        $buttonY = $this.ModalHeight - 4
        $this.ButtonContainer.SetBounds(0, $buttonY, $this.ModalWidth, 3)
        
        # Create button instances
        $totalWidth = 0
        $buttonInstances = @()
        
        foreach ($btn in $this.Buttons) {
            $minBtn = [MinimalButton]::new($btn.Text)
            $minBtn.OnClick = $btn.OnClick
            $minBtn.IsDefault = $btn.IsDefault
            $buttonInstances += $minBtn
            $totalWidth += $btn.Text.Length + 6  # Padding
        }
        
        # Layout buttons
        $spacing = 2
        $startX = ($this.ModalWidth - $totalWidth - ($spacing * ($this.Buttons.Count - 1))) / 2
        $x = [Math]::Max(2, $startX)
        
        for ($i = 0; $i -lt $buttonInstances.Count; $i++) {
            $btn = $buttonInstances[$i]
            $this.ButtonContainer.AddChild($btn)
            $btn.Initialize($this.ServiceContainer)
            $width = $this.Buttons[$i].Text.Length + 6
            $btn.SetBounds($x, 0, $width, 1)
            $x += $width + $spacing
        }
        
        $this.ModalContainer.AddChild($this.ButtonContainer)
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 4096
        
        # Render overlay
        if ($this.ShowOverlay) {
            # Dim the background
            for ($y = 0; $y -lt $this.Height; $y++) {
                $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
                $sb.Append([VT]::Dim())
                $sb.Append('░' * $this.Width)
            }
        }
        
        # Render modal shadow (subtle)
        if ($this.BorderType -ne [BorderType]::None) {
            $shadowX = $this.X + $this._modalX + 2
            $shadowY = $this.Y + $this._modalY + 1
            $sb.Append([VT]::RGBBG(20, 20, 20))  # Very dark shadow
            
            for ($y = 0; $y -lt $this.ModalHeight - 1; $y++) {
                $sb.Append([VT]::MoveTo($shadowX, $shadowY + $y))
                $sb.Append(' ' * ($this.ModalWidth - 2))
            }
        }
        
        # Base render (includes modal container)
        $sb.Append(([Screen]$this).OnRender())
        
        # Render border
        if ($this.BorderType -ne [BorderType]::None) {
            $sb.Append([BorderStyle]::RenderBorderWithTitle(
                $this.X + $this._modalX,
                $this.Y + $this._modalY,
                $this.ModalWidth,
                $this.ModalHeight,
                $this.BorderType,
                $this._colors.border,
                $this.Title,
                $this._colors.title
            ))
        }
        
        # Render content area
        if ($this.Content -and $this.CenterContent) {
            # Position content with padding
            $contentX = $this.X + $this._modalX + 2
            $contentY = $this.Y + $this._modalY + 2
            $contentWidth = $this.ModalWidth - 4
            $contentHeight = $this.ModalHeight - 6  # Leave room for buttons
            
            if ($this.Buttons.Count -eq 0) {
                $contentHeight = $this.ModalHeight - 4
            }
            
            $this.Content.SetBounds($contentX, $contentY, $contentWidth, $contentHeight)
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] AddButton([string]$text, [scriptblock]$onClick, [bool]$isDefault = $false) {
        $btn = [ModalButton]::new()
        $btn.Text = $text
        $btn.OnClick = $onClick
        $btn.IsDefault = $isDefault
        $this.Buttons.Add($btn)
    }
    
    [void] Close() {
        if ($this.OnClose) {
            & $this.OnClose
        }
        
        if ($global:ScreenManager) {
            [void]$global:ScreenManager.Pop()
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        # Escape closes modal
        if ($key.Key -eq [System.ConsoleKey]::Escape) {
            $this.Close()
            return $true
        }
        
        # Enter activates default button
        if ($key.Key -eq [System.ConsoleKey]::Enter -and $this.Buttons.Count -gt 0) {
            $defaultBtn = $this.Buttons | Where-Object { $_.IsDefault } | Select-Object -First 1
            if ($defaultBtn -and $defaultBtn.OnClick) {
                & $defaultBtn.OnClick
                return $true
            }
        }
        
        return ([Screen]$this).HandleInput($key)
    }
    
    [void] OnBoundsChanged() {
        # Recenter modal
        $this._modalX = [Math]::Max(1, ($this.Width - $this.ModalWidth) / 2)
        $this._modalY = [Math]::Max(1, ($this.Height - $this.ModalHeight) / 2)
        
        if ($this.ModalContainer) {
            $this.ModalContainer.SetBounds(
                $this.X + $this._modalX,
                $this.Y + $this._modalY,
                $this.ModalWidth,
                $this.ModalHeight
            )
        }
    }
}

class ModalButton {
    [string]$Text
    [scriptblock]$OnClick
    [bool]$IsDefault
}

# Common modal types
class MessageModal : MinimalModal {
    [string]$Message = ""
    
    MessageModal([string]$title, [string]$message) : base() {
        $this.Title = $title
        $this.Message = $message
        $this.ModalWidth = [Math]::Max(40, $message.Length + 10)
        $this.ModalHeight = 10
        
        # Add OK button
        $this.AddButton("OK", { $this.Close() }, $true)
    }
    
    [void] OnInitialize() {
        # Create message content
        $this.Content = [UIElement]::new()
        $this.Content.OnRender = {
            $sb = Get-PooledStringBuilder 512
            $lines = $this.Parent.Parent.Message -split "`n"
            $y = $this.Y
            
            foreach ($line in $lines) {
                $sb.Append([VT]::MoveTo($this.X, $y))
                $sb.Append($line)
                $y++
            }
            
            $result = $sb.ToString()
            Return-PooledStringBuilder $sb
            return $result
        }.GetNewClosure()
        
        ([MinimalModal]$this).OnInitialize()
    }
}

class ConfirmModal : MinimalModal {
    [string]$Message = ""
    [scriptblock]$OnConfirm = {}
    [scriptblock]$OnCancel = {}
    
    ConfirmModal([string]$title, [string]$message) : base() {
        $this.Title = $title
        $this.Message = $message
        $this.ModalWidth = [Math]::Max(50, $message.Length + 10)
        $this.ModalHeight = 10
        
        # Add buttons
        $this.AddButton("Yes", {
            if ($this.OnConfirm) { & $this.OnConfirm }
            $this.Close()
        }, $true)
        
        $this.AddButton("No", {
            if ($this.OnCancel) { & $this.OnCancel }
            $this.Close()
        }, $false)
    }
    
    [void] OnInitialize() {
        # Create message content
        $this.Content = [UIElement]::new()
        $this.Content.OnRender = {
            $sb = Get-PooledStringBuilder 512
            $theme = $this.ServiceContainer.GetService('ThemeManager')
            $lines = $this.Parent.Parent.Message -split "`n"
            $y = $this.Y
            
            $sb.Append($theme.GetColor('warning'))
            foreach ($line in $lines) {
                $sb.Append([VT]::MoveTo($this.X, $y))
                $sb.Append($line)
                $y++
            }
            $sb.Append([VT]::Reset())
            
            $result = $sb.ToString()
            Return-PooledStringBuilder $sb
            return $result
        }.GetNewClosure()
        
        ([MinimalModal]$this).OnInitialize()
    }
}