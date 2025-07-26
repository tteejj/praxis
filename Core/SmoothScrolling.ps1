# SmoothScrolling.ps1 - Smooth scrolling support for list components

class ScrollState {
    [double]$Position = 0.0      # Current scroll position (can be fractional during animation)
    [int]$TargetPosition = 0     # Target position to scroll to
    [double]$Velocity = 0.0      # Current scrolling velocity
    [bool]$IsScrolling = $false  # Whether currently animating
    [DateTime]$LastUpdate        # Last update time for delta calculation
    
    # Scrolling physics
    [double]$Acceleration = 3000.0  # Pixels per second squared
    [double]$MaxVelocity = 1000.0   # Max pixels per second
    [double]$Friction = 10.0        # Deceleration factor
    [double]$SnapThreshold = 0.5    # Distance to snap to target
}

class SmoothScroller {
    hidden [ScrollState]$State
    hidden [int]$MinPosition = 0
    hidden [int]$MaxPosition = 0
    hidden [int]$ViewportSize = 0
    hidden [int]$ContentSize = 0
    hidden [System.Timers.Timer]$UpdateTimer
    hidden [UIElement]$Parent
    
    # Scrolling settings
    [double]$ScrollSpeed = 3.0      # Lines per scroll event
    [bool]$EnableSmoothing = $true  # Toggle smooth scrolling
    [bool]$EnableInertia = $true    # Enable inertial scrolling
    
    SmoothScroller([UIElement]$parent) {
        $this.State = [ScrollState]::new()
        $this.State.LastUpdate = [DateTime]::Now
        $this.Parent = $parent
        
        # Create update timer for smooth animation
        $this.UpdateTimer = [System.Timers.Timer]::new(16)  # ~60 FPS
        $this.UpdateTimer.AutoReset = $true
        
        # Register timer event
        Register-ObjectEvent -InputObject $this.UpdateTimer -EventName Elapsed -Action {
            $Event.MessageData.Update()
        } -MessageData $this | Out-Null
    }
    
    [void] SetBounds([int]$viewportSize, [int]$contentSize) {
        $this.ViewportSize = $viewportSize
        $this.ContentSize = $contentSize
        $this.MaxPosition = [Math]::Max(0, $contentSize - $viewportSize)
        
        # Clamp current position
        if ($this.State.Position -gt $this.MaxPosition) {
            $this.State.Position = $this.MaxPosition
            $this.State.TargetPosition = $this.MaxPosition
        }
    }
    
    [void] ScrollTo([int]$position) {
        $this.State.TargetPosition = [Math]::Max($this.MinPosition, [Math]::Min($position, $this.MaxPosition))
        
        if ($this.EnableSmoothing) {
            $this.State.IsScrolling = $true
            if (-not $this.UpdateTimer.Enabled) {
                $this.UpdateTimer.Start()
            }
        } else {
            # Instant scroll
            $this.State.Position = $this.State.TargetPosition
            $this.Parent.Invalidate()
        }
    }
    
    [void] ScrollBy([int]$delta) {
        $newTarget = $this.State.TargetPosition + ($delta * $this.ScrollSpeed)
        $this.ScrollTo([int]$newTarget)
    }
    
    [void] ScrollUp() {
        $this.ScrollBy(-1)
    }
    
    [void] ScrollDown() {
        $this.ScrollBy(1)
    }
    
    [void] PageUp() {
        $this.ScrollBy(-$this.ViewportSize + 1)
    }
    
    [void] PageDown() {
        $this.ScrollBy($this.ViewportSize - 1)
    }
    
    [void] ScrollToTop() {
        $this.ScrollTo($this.MinPosition)
    }
    
    [void] ScrollToBottom() {
        $this.ScrollTo($this.MaxPosition)
    }
    
    [int] GetCurrentPosition() {
        return [int][Math]::Round($this.State.Position)
    }
    
    [bool] CanScrollUp() {
        return $this.GetCurrentPosition() -gt $this.MinPosition
    }
    
    [bool] CanScrollDown() {
        return $this.GetCurrentPosition() -lt $this.MaxPosition
    }
    
    [void] Update() {
        if (-not $this.State.IsScrolling) {
            $this.UpdateTimer.Stop()
            return
        }
        
        $now = [DateTime]::Now
        $deltaTime = ($now - $this.State.LastUpdate).TotalSeconds
        $this.State.LastUpdate = $now
        
        # Calculate distance to target
        $distance = $this.State.TargetPosition - $this.State.Position
        
        if ([Math]::Abs($distance) -lt $this.State.SnapThreshold) {
            # Snap to target
            $this.State.Position = $this.State.TargetPosition
            $this.State.Velocity = 0
            $this.State.IsScrolling = $false
            $this.UpdateTimer.Stop()
        } else {
            # Apply smooth scrolling physics
            if ($this.EnableInertia) {
                # Calculate desired velocity based on distance
                $desiredVelocity = $distance * 10  # Proportional control
                
                # Limit velocity
                $desiredVelocity = [Math]::Max(-$this.State.MaxVelocity, 
                                  [Math]::Min($desiredVelocity, $this.State.MaxVelocity))
                
                # Apply acceleration towards desired velocity
                $velocityDiff = $desiredVelocity - $this.State.Velocity
                $acceleration = $velocityDiff * $this.State.Friction
                
                # Update velocity
                $this.State.Velocity += $acceleration * $deltaTime
                
                # Apply friction
                $this.State.Velocity *= [Math]::Pow(0.95, $deltaTime * 60)  # Frame-rate independent
            } else {
                # Simple easing without inertia
                $this.State.Velocity = $distance * 8  # Direct proportional
            }
            
            # Update position
            $this.State.Position += $this.State.Velocity * $deltaTime
            
            # Clamp position
            $this.State.Position = [Math]::Max($this.MinPosition, 
                                  [Math]::Min($this.State.Position, $this.MaxPosition))
        }
        
        # Notify parent to redraw
        $this.Parent.Invalidate()
    }
    
    [void] StopScrolling() {
        $this.State.IsScrolling = $false
        $this.State.Velocity = 0
        $this.UpdateTimer.Stop()
    }
    
    # Get scroll indicator info
    [hashtable] GetScrollBarInfo([int]$scrollBarHeight) {
        if ($this.ContentSize -le $this.ViewportSize) {
            return @{ Show = $false }
        }
        
        $thumbHeight = [Math]::Max(1, [int]($scrollBarHeight * $this.ViewportSize / $this.ContentSize))
        $scrollRange = $scrollBarHeight - $thumbHeight
        $scrollRatio = $this.GetCurrentPosition() / [double]$this.MaxPosition
        $thumbPosition = [int]($scrollRange * $scrollRatio)
        
        return @{
            Show = $true
            ThumbHeight = $thumbHeight
            ThumbPosition = $thumbPosition
            IsAtTop = $this.GetCurrentPosition() -eq $this.MinPosition
            IsAtBottom = $this.GetCurrentPosition() -eq $this.MaxPosition
        }
    }
}

# Scrollable list box with smooth scrolling
class SmoothScrollListBox : MinimalListBox {
    hidden [SmoothScroller]$Scroller
    [bool]$ShowScrollBar = $true
    
    SmoothScrollListBox() : base() {
        $this.Scroller = [SmoothScroller]::new($this)
    }
    
    [void] OnBoundsChanged() {
        ([MinimalListBox]$this).OnBoundsChanged()
        
        # Update scroller bounds
        $viewportHeight = $this.Height
        if ($this.ShowBorder) { $viewportHeight -= 2 }
        if ($this.Title) { $viewportHeight -= 1 }
        
        $contentHeight = $this.Items.Count
        $this.Scroller.SetBounds($viewportHeight, $contentHeight)
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([System.ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectIndex($this.SelectedIndex - 1)
                    $this.EnsureVisible($this.SelectedIndex)
                }
                return $true
            }
            ([System.ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                    $this.SelectIndex($this.SelectedIndex + 1)
                    $this.EnsureVisible($this.SelectedIndex)
                }
                return $true
            }
            ([System.ConsoleKey]::PageUp) {
                $this.Scroller.PageUp()
                $newIndex = [Math]::Max(0, $this.Scroller.GetCurrentPosition())
                $this.SelectIndex($newIndex)
                return $true
            }
            ([System.ConsoleKey]::PageDown) {
                $this.Scroller.PageDown()
                $newIndex = [Math]::Min($this.Items.Count - 1, 
                           $this.Scroller.GetCurrentPosition() + $this.Height - 3)
                $this.SelectIndex($newIndex)
                return $true
            }
            ([System.ConsoleKey]::Home) {
                $this.Scroller.ScrollToTop()
                $this.SelectIndex(0)
                return $true
            }
            ([System.ConsoleKey]::End) {
                $this.Scroller.ScrollToBottom()
                $this.SelectIndex($this.Items.Count - 1)
                return $true
            }
        }
        
        return ([MinimalListBox]$this).HandleInput($key)
    }
    
    [void] EnsureVisible([int]$index) {
        $scrollPos = $this.Scroller.GetCurrentPosition()
        $viewportHeight = $this.Height
        if ($this.ShowBorder) { $viewportHeight -= 2 }
        if ($this.Title) { $viewportHeight -= 1 }
        
        if ($index -lt $scrollPos) {
            # Scroll up to show item
            $this.Scroller.ScrollTo($index)
        } elseif ($index -ge $scrollPos + $viewportHeight) {
            # Scroll down to show item
            $this.Scroller.ScrollTo($index - $viewportHeight + 1)
        }
    }
    
    [string] OnRender() {
        $sb = Get-PooledStringBuilder 4096
        
        # Render border and title
        if ($this.ShowBorder) {
            $sb.Append([BorderStyle]::RenderBorderWithTitle(
                $this.X, $this.Y, $this.Width, $this.Height,
                $this.BorderType, $this._colors.border,
                $this.Title, $this._colors.title
            ))
        }
        
        # Calculate content area
        $contentX = $this.X
        $contentY = $this.Y
        $contentWidth = $this.Width
        $contentHeight = $this.Height
        
        if ($this.ShowBorder) {
            $contentX++
            $contentY++
            $contentWidth -= 2
            $contentHeight -= 2
        }
        
        if ($this.Title -and $this.ShowBorder) {
            $contentY++
            $contentHeight--
        }
        
        # Render items with smooth scrolling
        $scrollPos = $this.Scroller.GetCurrentPosition()
        $visibleItems = [Math]::Min($contentHeight, $this.Items.Count - $scrollPos)
        
        for ($i = 0; $i -lt $visibleItems; $i++) {
            $itemIndex = $scrollPos + $i
            $item = $this.Items[$itemIndex]
            $y = $contentY + $i
            
            $sb.Append([VT]::MoveTo($contentX, $y))
            
            # Selection highlight
            if ($itemIndex -eq $this.SelectedIndex) {
                if ($this.IsFocused) {
                    $sb.Append($this._colors.selectedBg)
                    $sb.Append($this._colors.selectedFg)
                } else {
                    $sb.Append($this._colors.inactiveSelectedBg)
                    $sb.Append($this._colors.text)
                }
            } else {
                $sb.Append($this._colors.text)
            }
            
            # Render item text
            $displayText = $this.GetDisplayText($item)
            if ($displayText.Length -gt $contentWidth - 1) {
                $displayText = $displayText.Substring(0, $contentWidth - 4) + "..."
            }
            $sb.Append($displayText.PadRight($contentWidth - 1))
        }
        
        # Render scroll bar
        if ($this.ShowScrollBar -and $this.ShowBorder) {
            $scrollInfo = $this.Scroller.GetScrollBarInfo($contentHeight)
            if ($scrollInfo.Show) {
                $scrollX = $this.X + $this.Width - 1
                
                # Render scroll track
                for ($i = 0; $i -lt $contentHeight; $i++) {
                    $sb.Append([VT]::MoveTo($scrollX, $contentY + $i))
                    
                    if ($i -ge $scrollInfo.ThumbPosition -and 
                        $i -lt $scrollInfo.ThumbPosition + $scrollInfo.ThumbHeight) {
                        # Thumb
                        $sb.Append($this._colors.accent)
                        $sb.Append('█')
                    } else {
                        # Track
                        $sb.Append($this._colors.disabled)
                        $sb.Append('│')
                    }
                }
                
                # Scroll indicators
                if (-not $scrollInfo.IsAtTop) {
                    $sb.Append([VT]::MoveTo($scrollX, $contentY))
                    $sb.Append($this._colors.accent)
                    $sb.Append('▲')
                }
                
                if (-not $scrollInfo.IsAtBottom) {
                    $sb.Append([VT]::MoveTo($scrollX, $contentY + $contentHeight - 1))
                    $sb.Append($this._colors.accent)
                    $sb.Append('▼')
                }
            }
        }
        
        $sb.Append([VT]::Reset())
        
        $result = $sb.ToString()
        Return-PooledStringBuilder $sb
        return $result
    }
}