# SmoothRenderer.ps1 - Better screen updates and optional animations for TaskListScreen

using namespace System.Text
using namespace System.Collections.Generic

class SmoothRenderer {
    [int]$Width
    [int]$Height
    [bool]$EnableAnimations = $true
    [int]$AnimationDuration = 80  # milliseconds - reduced for snappier feel
    
    SmoothRenderer() {
        $this.Width = [Console]::WindowWidth
        $this.Height = [Console]::WindowHeight
    }
    
    # Render complete screen content at once - no line-by-line VT operations
    [void] RenderFullScreen([List[string]]$lines, [int]$startY = 3) {
        if (-not $lines -or $lines.Count -eq 0) { return }
        
        $output = [StringBuilder]::new()
        
        # Move to start position
        [void]$output.Append([VT]::MoveTo(0, $startY))
        
        # Build complete output
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($i -gt 0) {
                [void]$output.Append("`n")
            }
            [void]$output.Append($line)
        }
        
        # Clear any remaining lines below content
        $contentEndY = $startY + $lines.Count
        $screenEndY = $this.Height - 2
        
        if ($contentEndY -lt $screenEndY) {
            for ($clearY = $contentEndY; $clearY -lt $screenEndY; $clearY++) {
                [void]$output.Append([VT]::MoveTo(0, $clearY))
                [void]$output.Append([VT]::ClearLine())
            }
        }
        
        # Output everything at once
        [Console]::Write($output.ToString())
    }
    
    # Render with pillbox highlight for selected item
    [void] RenderWithPillbox([List[string]]$lines, [int]$selectedIndex, [int]$startY = 3) {
        if (-not $lines -or $lines.Count -eq 0) { return }
        
        $output = [StringBuilder]::new()
        
        # Calculate pillbox position (each task takes 2 lines)
        $pillboxStartLine = $selectedIndex * 2
        $pillboxEndLine = $pillboxStartLine + 1
        
        [void]$output.Append([VT]::MoveTo(0, $startY))
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $actualY = $startY + $i
            
            if ($i -gt 0) {
                [void]$output.Append("`n")
            }
            
            # Check if this line should be in pillbox
            if ($i -eq $pillboxStartLine) {
                # Pillbox start - render spacer, top border, content
                [void]$output.Append([VT]::MoveTo(0, $actualY))
                [void]$output.Append("") # Empty spacer line
                [void]$output.Append("`n")
                
                # Top border
                [void]$output.Append($this.GetPillboxColor())
                [void]$output.Append("╭" + ("─" * ($this.Width - 2)) + "╮")
                [void]$output.Append([VT]::Reset())
                [void]$output.Append("`n")
                
                # Content line with border
                [void]$output.Append($this.GetPillboxColor())
                [void]$output.Append("│")
                [void]$output.Append([VT]::Reset())
                
                # Remove leading space and padding to shift content left by 1
                $adjustedLine = if ($line.StartsWith(" ")) { $line.Substring(1) } else { $line }
                [void]$output.Append($adjustedLine)
                
                # Pad to right border - account for removed space
                $paddingNeeded = $this.Width - $adjustedLine.Length - 2
                if ($paddingNeeded -gt 0) {
                    [void]$output.Append(" " * $paddingNeeded)
                }
                [void]$output.Append($this.GetPillboxColor())
                [void]$output.Append("│")
                [void]$output.Append([VT]::Reset())
                
            } elseif ($i -eq $pillboxEndLine) {
                # Second line of pillbox (tags)
                [void]$output.Append($this.GetPillboxColor())
                [void]$output.Append("│")
                [void]$output.Append([VT]::Reset())
                
                # Remove leading space and padding to shift content left by 1
                $adjustedLine = if ($line.StartsWith(" ")) { $line.Substring(1) } else { $line }
                [void]$output.Append($adjustedLine)
                
                # Pad to right border - account for removed space
                $paddingNeeded = $this.Width - $adjustedLine.Length - 2
                if ($paddingNeeded -gt 0) {
                    [void]$output.Append(" " * $paddingNeeded)
                }
                [void]$output.Append($this.GetPillboxColor())
                [void]$output.Append("│")
                [void]$output.Append([VT]::Reset())
                [void]$output.Append("`n")
                
                # Bottom border
                [void]$output.Append($this.GetPillboxColor())
                [void]$output.Append("╰" + ("─" * ($this.Width - 2)) + "╯")
                [void]$output.Append([VT]::Reset())
                
            } else {
                # Normal line
                [void]$output.Append($line)
            }
        }
        
        # Clear remaining lines
        $contentEndY = $startY + $lines.Count + 3  # Account for pillbox extra lines
        $screenEndY = $this.Height - 2
        
        if ($contentEndY -lt $screenEndY) {
            for ($clearY = $contentEndY; $clearY -lt $screenEndY; $clearY++) {
                [void]$output.Append([VT]::MoveTo(0, $clearY))
                [void]$output.Append([VT]::ClearLine())
            }
        }
        
        [Console]::Write($output.ToString())
    }
    
    # Optional: Animate pillbox movement with smooth slide effect
    [void] AnimatePillboxSlide([int]$fromIndex, [int]$toIndex, [List[string]]$lines, [int]$startY = 3) {
        if (-not $this.EnableAnimations -or $fromIndex -eq $toIndex) {
            $this.RenderWithPillbox($lines, $toIndex, $startY)
            return
        }
        
        # Smooth animation with ease-out curve - fewer steps, better feel
        $steps = 5  # Reduced from 8 for better performance
        $totalDuration = 80  # Reduced from 150ms for snappier feel
        
        for ($step = 0; $step -le $steps; $step++) {
            $linearProgress = $step / [double]$steps
            
            # Ease-out curve: fast start, slow finish (more natural)
            $easedProgress = 1 - [Math]::Pow(1 - $linearProgress, 3)
            
            $currentIndex = $fromIndex + ($toIndex - $fromIndex) * $easedProgress
            
            # For simplicity, just render at discrete positions
            $discreteIndex = [Math]::Round($currentIndex)
            
            # Render at discrete positions
            $this.RenderWithPillbox($lines, $discreteIndex, $startY)
            
            if ($step -lt $steps) {
                # Variable timing - shorter delays for later frames (ease-out)
                $frameProgress = ($step + 1) / [double]($steps + 1)
                $frameDuration = $totalDuration * (1 - $frameProgress * 0.4) / $steps  # 40% variation
                Start-Sleep -Milliseconds ([Math]::Max(10, [Math]::Round($frameDuration)))
            }
        }
    }
    
    # Get pillbox border color - use centralized theme
    [string] GetPillboxColor() {
        return [AppThemeManager]::GetPillboxColor()  # Use centralized theme system
    }
    
    # Update dimensions if console was resized
    [void] UpdateDimensions() {
        $this.Width = [Console]::WindowWidth
        $this.Height = [Console]::WindowHeight
    }
    
    # Enable/disable animations
    [void] SetAnimationsEnabled([bool]$enabled) {
        $this.EnableAnimations = $enabled
    }
    
    # Set animation duration
    [void] SetAnimationDuration([int]$milliseconds) {
        $this.AnimationDuration = $milliseconds
    }
}