# AnimationHelper.ps1 - Simple animation support for smooth transitions

enum EasingType {
    Linear = 0
    EaseIn = 1
    EaseOut = 2
    EaseInOut = 3
    Bounce = 4
}

class Animation {
    [string]$Name
    [double]$StartValue
    [double]$EndValue
    [double]$Duration  # Milliseconds
    [DateTime]$StartTime
    [EasingType]$Easing
    [scriptblock]$OnUpdate
    [scriptblock]$OnComplete
    [bool]$IsComplete
    [double]$CurrentValue
    
    Animation([string]$name, [double]$start, [double]$end, [double]$duration) {
        $this.Name = $name
        $this.StartValue = $start
        $this.EndValue = $end
        $this.Duration = $duration
        $this.Easing = [EasingType]::EaseInOut
        $this.StartTime = [DateTime]::Now
        $this.IsComplete = $false
        $this.CurrentValue = $start
    }
    
    [void] Update() {
        if ($this.IsComplete) { return }
        
        $elapsed = ([DateTime]::Now - $this.StartTime).TotalMilliseconds
        $progress = [Math]::Min(1.0, $elapsed / $this.Duration)
        
        # Apply easing
        $easedProgress = switch ($this.Easing) {
            ([EasingType]::Linear) { $progress }
            ([EasingType]::EaseIn) { $progress * $progress }
            ([EasingType]::EaseOut) { 1 - (1 - $progress) * (1 - $progress) }
            ([EasingType]::EaseInOut) {
                if ($progress -lt 0.5) {
                    2 * $progress * $progress
                } else {
                    1 - 2 * (1 - $progress) * (1 - $progress)
                }
            }
            ([EasingType]::Bounce) {
                if ($progress -lt 0.5) {
                    8 * $progress * $progress
                } else {
                    1 - 8 * (1 - $progress) * (1 - $progress)
                }
            }
        }
        
        # Calculate current value
        $this.CurrentValue = $this.StartValue + ($this.EndValue - $this.StartValue) * $easedProgress
        
        # Call update callback
        if ($this.OnUpdate) {
            & $this.OnUpdate $this.CurrentValue
        }
        
        # Check if complete
        if ($progress -ge 1.0) {
            $this.IsComplete = $true
            $this.CurrentValue = $this.EndValue
            if ($this.OnComplete) {
                & $this.OnComplete
            }
        }
    }
}

class AnimationManager {
    hidden [System.Collections.Generic.Dictionary[string, Animation]]$_animations
    hidden [System.Timers.Timer]$_updateTimer
    hidden [EventBus]$EventBus
    [int]$FrameRate = 30  # FPS
    
    AnimationManager() {
        $this._animations = [System.Collections.Generic.Dictionary[string, Animation]]::new()
        
        # Create update timer
        $interval = 1000 / $this.FrameRate
        $this._updateTimer = [System.Timers.Timer]::new($interval)
        $this._updateTimer.AutoReset = $true
        
        # Add event handler
        Register-ObjectEvent -InputObject $this._updateTimer -EventName Elapsed -Action {
            $Event.MessageData.UpdateAnimations()
        } -MessageData $this | Out-Null
    }
    
    [void] Initialize([ServiceContainer]$container) {
        $this.EventBus = $container.GetService('EventBus')
    }
    
    [void] StartAnimation([Animation]$animation) {
        $this._animations[$animation.Name] = $animation
        
        # Start timer if not running
        if (-not $this._updateTimer.Enabled) {
            $this._updateTimer.Start()
        }
    }
    
    [void] StopAnimation([string]$name) {
        if ($this._animations.ContainsKey($name)) {
            $this._animations.Remove($name)
        }
        
        # Stop timer if no animations
        if ($this._animations.Count -eq 0) {
            $this._updateTimer.Stop()
        }
    }
    
    [void] UpdateAnimations() {
        $completed = @()
        
        foreach ($animation in $this._animations.Values) {
            $animation.Update()
            if ($animation.IsComplete) {
                $completed += $animation.Name
            }
        }
        
        # Remove completed animations
        foreach ($name in $completed) {
            $this._animations.Remove($name)
        }
        
        # Stop timer if no animations
        if ($this._animations.Count -eq 0) {
            $this._updateTimer.Stop()
        }
        
        # Notify of animation frame
        if ($this.EventBus -and $this._animations.Count -gt 0) {
            $this.EventBus.Publish('animation.frame', $this, @{})
        }
    }
    
    # Helper methods for common animations
    [Animation] SlideIn([UIElement]$element, [string]$direction, [double]$duration = 300) {
        $startX = $element.X
        $startY = $element.Y
        $endX = $element.X
        $endY = $element.Y
        $anim = $null
        
        switch ($direction) {
            "Left" {
                $startX = -$element.Width
                $anim = [Animation]::new("SlideIn_$($element.GetHashCode())", $startX, $endX, $duration)
                $anim.OnUpdate = {
                    param($value)
                    $element.X = [int]$value
                    $element.Invalidate()
                }.GetNewClosure()
            }
            "Right" {
                $startX = [Console]::WindowWidth
                $anim = [Animation]::new("SlideIn_$($element.GetHashCode())", $startX, $endX, $duration)
                $anim.OnUpdate = {
                    param($value)
                    $element.X = [int]$value
                    $element.Invalidate()
                }.GetNewClosure()
            }
            "Top" {
                $startY = -$element.Height
                $anim = [Animation]::new("SlideIn_$($element.GetHashCode())", $startY, $endY, $duration)
                $anim.OnUpdate = {
                    param($value)
                    $element.Y = [int]$value
                    $element.Invalidate()
                }.GetNewClosure()
            }
            "Bottom" {
                $startY = [Console]::WindowHeight
                $anim = [Animation]::new("SlideIn_$($element.GetHashCode())", $startY, $endY, $duration)
                $anim.OnUpdate = {
                    param($value)
                    $element.Y = [int]$value
                    $element.Invalidate()
                }.GetNewClosure()
            }
        }
        
        if ($anim) {
            $anim.Easing = [EasingType]::EaseOut
        }
        return $anim
    }
    
    [Animation] FadeIn([UIElement]$element, [double]$duration = 200) {
        $anim = [Animation]::new("FadeIn_$($element.GetHashCode())", 0.0, 1.0, $duration)
        $anim.Easing = [EasingType]::EaseIn
        
        # Since we can't do real opacity in terminal, simulate with visibility
        $anim.OnUpdate = {
            param($value)
            # Show element after 10% progress
            if ($value -gt 0.1 -and -not $element.Visible) {
                $element.Visible = $true
                $element.Invalidate()
            }
        }.GetNewClosure()
        
        return $anim
    }
    
    [Animation] Pulse([UIElement]$element, [int]$times = 2, [double]$duration = 500) {
        # Pulse effect using size changes
        $originalWidth = $element.Width
        $originalHeight = $element.Height
        
        $anim = [Animation]::new("Pulse_$($element.GetHashCode())", 0, $times * 2 * [Math]::PI, $duration)
        $anim.Easing = [EasingType]::Linear
        
        $anim.OnUpdate = {
            param($value)
            $scale = 1 + 0.1 * [Math]::Sin($value)  # 10% size variation
            $newWidth = [int]($originalWidth * $scale)
            $newHeight = [int]($originalHeight * $scale)
            
            # Center the scaling
            $element.X -= ($newWidth - $element.Width) / 2
            $element.Y -= ($newHeight - $element.Height) / 2
            
            $element.Width = $newWidth
            $element.Height = $newHeight
            $element.Invalidate()
        }.GetNewClosure()
        
        $anim.OnComplete = {
            # Restore original size
            $element.Width = $originalWidth
            $element.Height = $originalHeight
            $element.Invalidate()
        }.GetNewClosure()
        
        return $anim
    }
}

# Extension methods for UIElement
class AnimatedElement : UIElement {
    hidden [AnimationManager]$AnimationManager
    
    [void] OnInitialize() {
        $this.AnimationManager = $this.ServiceContainer.GetService('AnimationManager')
    }
    
    [void] SlideIn([string]$direction, [double]$duration = 300) {
        if ($this.AnimationManager) {
            $anim = $this.AnimationManager.SlideIn($this, $direction, $duration)
            $this.AnimationManager.StartAnimation($anim)
        }
    }
    
    [void] FadeIn([double]$duration = 200) {
        if ($this.AnimationManager) {
            $anim = $this.AnimationManager.FadeIn($this, $duration)
            $this.AnimationManager.StartAnimation($anim)
        }
    }
    
    [void] Pulse([int]$times = 2) {
        if ($this.AnimationManager) {
            $anim = $this.AnimationManager.Pulse($this, $times)
            $this.AnimationManager.StartAnimation($anim)
        }
    }
}