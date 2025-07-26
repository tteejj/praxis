# LoadingIndicator.ps1 - Visual feedback for loading states

enum LoadingStyle {
    Spinner = 0
    Dots = 1
    Bar = 2
    Pulse = 3
    Minimal = 4
}

class LoadingIndicator : UIElement {
    [string]$Message = "Loading..."
    [LoadingStyle]$Style = [LoadingStyle]::Minimal
    [bool]$ShowProgress = $false
    [double]$Progress = 0.0  # 0.0 to 1.0
    
    # Animation state
    hidden [int]$_animationFrame = 0
    hidden [DateTime]$_lastUpdate
    hidden [System.Timers.Timer]$_animationTimer
    
    # Visual elements
    hidden [string[]]$_spinnerFrames = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    hidden [string[]]$_dotsFrames = @('.  ', '.. ', '...', '   ')
    hidden [string[]]$_pulseFrames = @('○', '◔', '◑', '◕', '●', '◕', '◑', '◔')
    
    # Colors
    hidden [hashtable]$_colors = @{}
    
    LoadingIndicator() : base() {
        $this.Height = 3
        $this._lastUpdate = [DateTime]::Now
        
        # Create animation timer
        $this._animationTimer = [System.Timers.Timer]::new(100)  # 10 FPS
        $this._animationTimer.AutoReset = $true
        
        Register-ObjectEvent -InputObject $this._animationTimer -EventName Elapsed -Action {
            $Event.MessageData.UpdateAnimation()
        } -MessageData $this | Out-Null
    }
    
    [void] OnInitialize() {
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
        
        # Start animation
        $this._animationTimer.Start()
    }
    
    [void] UpdateColors() {
        if ($this.Theme) {
            $this._colors = @{
                accent = $this.Theme.GetColor('accent')
                normal = $this.Theme.GetColor('normal')
                disabled = $this.Theme.GetColor('disabled')
                background = $this.Theme.GetBgColor('panel.background')
            }
        }
    }
    
    [void] UpdateAnimation() {
        $this._animationFrame++
        $this.Invalidate()
    }
    
    [void] SetProgress([double]$progress) {
        $this.Progress = [Math]::Max(0.0, [Math]::Min(1.0, $progress))
        $this.ShowProgress = $true
        $this.Invalidate()
    }
    
    [void] Show() {
        $this.Visible = $true
        $this._animationTimer.Start()
        $this.Invalidate()
    }
    
    [void] Hide() {
        $this.Visible = $false
        $this._animationTimer.Stop()
        $this.Invalidate()
    }
    
    [string] OnRender() {
        if (-not $this.Visible) { return "" }
        
        $sb = Get-PooledStringBuilder 512
        
        # Clear area with background
        $sb.Append($this._colors.background)
        for ($y = 0; $y -lt $this.Height; $y++) {
            $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
            $sb.Append(' ' * $this.Width)
        }
        
        # Center content
        $centerY = $this.Y + ($this.Height / 2)
        
        # Render based on style
        switch ($this.Style) {
            ([LoadingStyle]::Spinner) {
                $frame = $this._spinnerFrames[$this._animationFrame % $this._spinnerFrames.Count]
                $text = "$frame $($this.Message)"
                $centerX = $this.X + ($this.Width - $text.Length) / 2
                
                $sb.Append([VT]::MoveTo($centerX, $centerY))
                $sb.Append($this._colors.accent)
                $sb.Append($frame)
                $sb.Append(' ')
                $sb.Append($this._colors.normal)
                $sb.Append($this.Message)
            }
            
            ([LoadingStyle]::Dots) {
                $dots = $this._dotsFrames[$this._animationFrame % $this._dotsFrames.Count]
                $text = "$($this.Message)$dots"
                $centerX = $this.X + ($this.Width - $text.Length) / 2
                
                $sb.Append([VT]::MoveTo($centerX, $centerY))
                $sb.Append($this._colors.normal)
                $sb.Append($this.Message)
                $sb.Append($this._colors.accent)
                $sb.Append($dots)
            }
            
            ([LoadingStyle]::Bar) {
                # Message
                $messageX = $this.X + ($this.Width - $this.Message.Length) / 2
                $sb.Append([VT]::MoveTo($messageX, $centerY - 1))
                $sb.Append($this._colors.normal)
                $sb.Append($this.Message)
                
                # Progress bar
                $barWidth = [Math]::Min(40, $this.Width - 4)
                $barX = $this.X + ($this.Width - $barWidth) / 2
                $barY = $centerY + 1
                
                if ($this.ShowProgress) {
                    # Determinate progress
                    $filledWidth = [int]($barWidth * $this.Progress)
                    
                    $sb.Append([VT]::MoveTo($barX, $barY))
                    $sb.Append($this._colors.disabled)
                    $sb.Append('[')
                    
                    $sb.Append($this._colors.accent)
                    $sb.Append('█' * $filledWidth)
                    
                    $sb.Append($this._colors.disabled)
                    $sb.Append('░' * ($barWidth - $filledWidth))
                    $sb.Append(']')
                    
                    # Percentage
                    $percentage = [int]($this.Progress * 100)
                    $percentText = " $percentage%"
                    $sb.Append($this._colors.normal)
                    $sb.Append($percentText)
                } else {
                    # Indeterminate progress
                    $position = $this._animationFrame % ($barWidth + 10) - 5
                    
                    $sb.Append([VT]::MoveTo($barX, $barY))
                    $sb.Append($this._colors.disabled)
                    $sb.Append('[')
                    
                    for ($i = 0; $i -lt $barWidth; $i++) {
                        if ($i -ge $position -and $i -lt $position + 5) {
                            $sb.Append($this._colors.accent)
                            $sb.Append('█')
                        } else {
                            $sb.Append($this._colors.disabled)
                            $sb.Append('░')
                        }
                    }
                    
                    $sb.Append($this._colors.disabled)
                    $sb.Append(']')
                }
            }
            
            ([LoadingStyle]::Pulse) {
                $pulse = $this._pulseFrames[$this._animationFrame % $this._pulseFrames.Count]
                $text = "$pulse $($this.Message) $pulse"
                $centerX = $this.X + ($this.Width - $text.Length) / 2
                
                $sb.Append([VT]::MoveTo($centerX, $centerY))
                $sb.Append($this._colors.accent)
                $sb.Append($pulse)
                $sb.Append(' ')
                $sb.Append($this._colors.normal)
                $sb.Append($this.Message)
                $sb.Append(' ')
                $sb.Append($this._colors.accent)
                $sb.Append($pulse)
            }
            
            ([LoadingStyle]::Minimal) {
                # Simple centered message with subtle animation
                $centerX = $this.X + ($this.Width - $this.Message.Length) / 2
                
                $sb.Append([VT]::MoveTo($centerX, $centerY))
                
                # Fade effect using different colors
                $fadeIndex = $this._animationFrame % 4
                switch ($fadeIndex) {
                    0 { $sb.Append($this._colors.disabled) }
                    1 { $sb.Append($this._colors.normal) }
                    2 { $sb.Append($this._colors.accent) }
                    3 { $sb.Append($this._colors.normal) }
                }
                
                $sb.Append($this.Message)
            }
        }
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] Cleanup() {
        if ($this._animationTimer) {
            $this._animationTimer.Stop()
            $this._animationTimer.Dispose()
        }
    }
}

# Loading overlay for full-screen loading states
class LoadingOverlay : Screen {
    [LoadingIndicator]$Indicator
    [string]$Title = ""
    [bool]$Cancellable = $true
    [scriptblock]$OnCancel = {}
    
    LoadingOverlay([string]$message) : base() {
        $this.DrawBackground = $true
        
        # Create loading indicator
        $this.Indicator = [LoadingIndicator]::new()
        $this.Indicator.Message = $message
        $this.Indicator.Style = [LoadingStyle]::Bar
    }
    
    [void] OnInitialize() {
        ([Screen]$this).OnInitialize()
        
        # Dark overlay
        if ($this.Theme) {
            $overlayColor = [VT]::RGBBG(0, 0, 0)
            $this.SetBackgroundColor($overlayColor)
        }
        
        # Center indicator
        $indicatorWidth = [Math]::Min(60, $this.Width - 10)
        $indicatorHeight = 5
        $indicatorX = ($this.Width - $indicatorWidth) / 2
        $indicatorY = ($this.Height - $indicatorHeight) / 2
        
        $this.Indicator.SetBounds($indicatorX, $indicatorY, $indicatorWidth, $indicatorHeight)
        $this.AddChild($this.Indicator)
        $this.Indicator.Initialize($this.ServiceContainer)
        $this.Indicator.Show()
        
        # Add title if provided
        if ($this.Title) {
            $titleElement = [UIElement]::new()
            $titleElement.OnRender = {
                $sb = Get-PooledStringBuilder 256
                $theme = $this.ServiceContainer.GetService('ThemeManager')
                $titleX = ($this.Parent.Width - $this.Parent.Title.Length) / 2
                $titleY = $this.Y - 2
                
                $sb.Append([VT]::MoveTo($titleX, $titleY))
                $sb.Append($theme.GetColor('accent'))
                $sb.Append($this.Parent.Title)
                $sb.Append([VT]::Reset())
                
                $result = $sb.ToString()
                Return-PooledStringBuilder $sb
                return $result
            }.GetNewClosure()
            
            $titleElement.SetBounds(0, $indicatorY - 2, $this.Width, 1)
            $this.AddChild($titleElement)
        }
        
        # Add cancel hint if cancellable
        if ($this.Cancellable) {
            $hintElement = [UIElement]::new()
            $hintElement.OnRender = {
                $sb = Get-PooledStringBuilder 256
                $theme = $this.ServiceContainer.GetService('ThemeManager')
                $hint = "Press ESC to cancel"
                $hintX = ($this.Parent.Width - $hint.Length) / 2
                $hintY = $this.Y + 3
                
                $sb.Append([VT]::MoveTo($hintX, $hintY))
                $sb.Append($theme.GetColor('disabled'))
                $sb.Append($hint)
                $sb.Append([VT]::Reset())
                
                $result = $sb.ToString()
                Return-PooledStringBuilder $sb
                return $result
            }.GetNewClosure()
            
            $hintElement.SetBounds(0, $indicatorY + $indicatorHeight, $this.Width, 1)
            $this.AddChild($hintElement)
        }
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 4096
        
        # Render dimmed background
        for ($y = 0; $y -lt $this.Height; $y++) {
            $sb.Append([VT]::MoveTo($this.X, $this.Y + $y))
            $sb.Append([VT]::Dim())
            $sb.Append('░' * $this.Width)
        }
        
        # Render children (indicator, title, hint)
        $sb.Append(([Screen]$this).OnRender())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($this.Cancellable -and $key.Key -eq [System.ConsoleKey]::Escape) {
            if ($this.OnCancel) {
                & $this.OnCancel
            }
            
            if ($global:ScreenManager) {
                [void]$global:ScreenManager.Pop()
            }
            return $true
        }
        
        return $false
    }
    
    [void] SetProgress([double]$progress) {
        $this.Indicator.SetProgress($progress)
    }
    
    [void] UpdateMessage([string]$message) {
        $this.Indicator.Message = $message
        $this.Indicator.Invalidate()
    }
}

# Helper class for managing loading states
class LoadingManager {
    hidden [LoadingOverlay]$_currentOverlay
    hidden [ScreenManager]$_screenManager
    
    [void] Initialize([ServiceContainer]$container) {
        $this._screenManager = $container.GetService('ScreenManager')
    }
    
    [LoadingOverlay] ShowLoading([string]$message, [bool]$cancellable = $true) {
        if ($this._currentOverlay) {
            $this.HideLoading()
        }
        
        $this._currentOverlay = [LoadingOverlay]::new($message)
        $this._currentOverlay.Cancellable = $cancellable
        
        if ($this._screenManager) {
            $this._screenManager.Push($this._currentOverlay)
        }
        
        return $this._currentOverlay
    }
    
    [void] HideLoading() {
        if ($this._currentOverlay -and $this._screenManager) {
            $this._screenManager.Pop()
            $this._currentOverlay = $null
        }
    }
    
    [void] UpdateProgress([double]$progress) {
        if ($this._currentOverlay) {
            $this._currentOverlay.SetProgress($progress)
        }
    }
    
    [void] UpdateMessage([string]$message) {
        if ($this._currentOverlay) {
            $this._currentOverlay.UpdateMessage($message)
        }
    }
}