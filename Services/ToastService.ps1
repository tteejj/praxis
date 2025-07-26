# ToastService.ps1 - Minimal toast notification system

enum ToastType {
    Info = 0
    Success = 1
    Warning = 2
    Error = 3
}

class Toast {
    [string]$Message
    [ToastType]$Type
    [DateTime]$CreatedAt
    [int]$Duration  # Milliseconds
    [double]$Progress  # 0.0 to 1.0 for fade animation
    [bool]$IsExpired
    
    Toast([string]$message, [ToastType]$type, [int]$duration) {
        $this.Message = $message
        $this.Type = $type
        $this.Duration = $duration
        $this.CreatedAt = [DateTime]::Now
        $this.Progress = 0.0
        $this.IsExpired = $false
    }
    
    [void] Update() {
        $elapsed = ([DateTime]::Now - $this.CreatedAt).TotalMilliseconds
        $this.Progress = [Math]::Min(1.0, $elapsed / $this.Duration)
        
        if ($elapsed -ge $this.Duration) {
            $this.IsExpired = $true
        }
    }
    
    [double] GetOpacity() {
        # Fade in for first 10%, solid for 80%, fade out for last 10%
        if ($this.Progress -lt 0.1) {
            return $this.Progress * 10
        } elseif ($this.Progress -gt 0.9) {
            return (1.0 - $this.Progress) * 10
        }
        return 1.0
    }
}

class ToastService {
    hidden [System.Collections.Generic.Queue[Toast]]$_toasts
    hidden [int]$MaxToasts = 5
    hidden [int]$DefaultDuration = 3000  # 3 seconds
    hidden [ThemeManager]$Theme
    hidden [EventBus]$EventBus
    hidden [System.Timers.Timer]$UpdateTimer
    
    # Toast position
    [string]$Position = "TopRight"  # TopLeft, TopRight, BottomLeft, BottomRight
    [int]$MarginX = 2
    [int]$MarginY = 1
    [int]$Spacing = 1
    [int]$MaxWidth = 40
    
    ToastService() {
        $this._toasts = [System.Collections.Generic.Queue[Toast]]::new()
        
        # Update timer for animations
        $this.UpdateTimer = [System.Timers.Timer]::new(50)  # 20 FPS
        $this.UpdateTimer.AutoReset = $true
        
        # Add event handler
        Register-ObjectEvent -InputObject $this.UpdateTimer -EventName Elapsed -Action {
            $Event.MessageData.UpdateToasts()
        } -MessageData $this | Out-Null
        
        $this.UpdateTimer.Start()
    }
    
    [void] Initialize([ServiceContainer]$container) {
        $this.Theme = $container.GetService('ThemeManager')
        $this.EventBus = $container.GetService('EventBus')
        
        # Subscribe to events that might trigger toasts
        if ($this.EventBus) {
            $this.EventBus.Subscribe('project.created', {
                param($sender, $data)
                $this.ShowSuccess("Project created successfully")
            }.GetNewClosure())
            
            $this.EventBus.Subscribe('task.completed', {
                param($sender, $data)
                $this.ShowSuccess("Task completed")
            }.GetNewClosure())
            
            $this.EventBus.Subscribe('error', {
                param($sender, $data)
                if ($data.Message) {
                    $this.ShowError($data.Message)
                }
            }.GetNewClosure())
        }
    }
    
    [void] UpdateToasts() {
        $changed = $false
        
        # Update all toasts
        foreach ($toast in $this._toasts) {
            $toast.Update()
            if ($toast.IsExpired) {
                $changed = $true
            }
        }
        
        # Remove expired toasts
        while ($this._toasts.Count -gt 0 -and $this._toasts.Peek().IsExpired) {
            [void]$this._toasts.Dequeue()
            $changed = $true
        }
        
        # Trigger re-render if changed
        if ($changed -and $this.EventBus) {
            $this.EventBus.Publish('toast.changed', $this, @{})
        }
    }
    
    [void] Show([string]$message, [ToastType]$type = [ToastType]::Info, [int]$duration = 0) {
        if ($duration -eq 0) {
            $duration = $this.DefaultDuration
        }
        
        $toast = [Toast]::new($message, $type, $duration)
        $this._toasts.Enqueue($toast)
        
        # Limit number of toasts
        while ($this._toasts.Count -gt $this.MaxToasts) {
            [void]$this._toasts.Dequeue()
        }
        
        # Trigger render
        if ($this.EventBus) {
            $this.EventBus.Publish('toast.changed', $this, @{})
        }
    }
    
    [void] ShowInfo([string]$message) {
        $this.Show($message, [ToastType]::Info)
    }
    
    [void] ShowSuccess([string]$message) {
        $this.Show($message, [ToastType]::Success)
    }
    
    [void] ShowWarning([string]$message) {
        $this.Show($message, [ToastType]::Warning)
    }
    
    [void] ShowError([string]$message) {
        $this.Show($message, [ToastType]::Error)
    }
    
    [string] Render([int]$screenWidth, [int]$screenHeight) {
        if ($this._toasts.Count -eq 0) { return "" }
        
        $sb = Get-PooledStringBuilder 2048
        
        # Calculate base position
        $baseX = switch -Wildcard ($this.Position) {
            "*Left" { $this.MarginX }
            "*Right" { $screenWidth - $this.MaxWidth - $this.MarginX }
        }
        
        $baseY = switch -Wildcard ($this.Position) {
            "Top*" { $this.MarginY }
            "Bottom*" { $screenHeight - ($this._toasts.Count * 3) - $this.MarginY }
        }
        
        # Render each toast
        $y = $baseY
        foreach ($toast in $this._toasts) {
            $this.RenderToast($sb, $toast, $baseX, $y)
            $y += 3 + $this.Spacing
        }
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
    
    [void] RenderToast([System.Text.StringBuilder]$sb, [Toast]$toast, [int]$x, [int]$y) {
        if (-not $this.Theme) { return }
        
        # Get colors based on type
        $colors = switch ($toast.Type) {
            ([ToastType]::Success) { @{
                bg = $this.Theme.GetBgColor('success')
                fg = [VT]::RGB(255, 255, 255)
                icon = "✓"
            }}
            ([ToastType]::Warning) { @{
                bg = $this.Theme.GetBgColor('warning')
                fg = [VT]::RGB(0, 0, 0)
                icon = "!"
            }}
            ([ToastType]::Error) { @{
                bg = $this.Theme.GetBgColor('error')
                fg = [VT]::RGB(255, 255, 255)
                icon = "✗"
            }}
            default { @{
                bg = $this.Theme.GetBgColor('accent')
                fg = [VT]::RGB(255, 255, 255)
                icon = "i"
            }}
        }
        
        # Apply opacity for fade effect
        $opacity = $toast.GetOpacity()
        if ($opacity -lt 1.0) {
            # Simple fade by dimming
            if ($opacity -lt 0.5) {
                $sb.Append([VT]::Dim())
            }
        }
        
        # Truncate message if needed
        $message = $toast.Message
        $maxMessageLength = $this.MaxWidth - 6  # Account for icon and padding
        if ($message.Length -gt $maxMessageLength) {
            $message = $message.Substring(0, $maxMessageLength - 1) + "…"
        }
        
        # Render toast box
        $width = [Math]::Min($this.MaxWidth, $message.Length + 6)
        
        # Top border
        $sb.Append([VT]::MoveTo($x, $y))
        $sb.Append($colors.bg)
        $sb.Append($colors.fg)
        $sb.Append("╭─" + ("─" * ($width - 4)) + "─╮")
        
        # Content line
        $sb.Append([VT]::MoveTo($x, $y + 1))
        $sb.Append("│ ")
        $sb.Append($colors.icon)
        $sb.Append("  ")
        $sb.Append($message.PadRight($width - 6))
        $sb.Append(" │")
        
        # Bottom border
        $sb.Append([VT]::MoveTo($x, $y + 2))
        $sb.Append("╰─" + ("─" * ($width - 4)) + "─╯")
        
        $sb.Append([VT]::Reset())
    }
    
    [void] Clear() {
        $this._toasts.Clear()
        if ($this.EventBus) {
            $this.EventBus.Publish('toast.changed', $this, @{})
        }
    }
}

# Toast overlay component for screens
class ToastOverlay : UIElement {
    hidden [ToastService]$ToastService
    
    [void] OnInitialize() {
        $this.ToastService = $this.ServiceContainer.GetService('ToastService')
        
        # Subscribe to toast changes
        $eventBus = $this.ServiceContainer.GetService('EventBus')
        if ($eventBus -and $this.ToastService) {
            $eventBus.Subscribe('toast.changed', {
                $this.Invalidate()
            }.GetNewClosure())
        }
    }
    
    [string] OnRender() {
        if (-not $this.ToastService) { return "" }
        
        # Get screen dimensions from parent
        $width = $this.Width
        $height = $this.Height
        if ($this.Parent) {
            $width = $this.Parent.Width
            $height = $this.Parent.Height
        }
        
        return $this.ToastService.Render($width, $height)
    }
}