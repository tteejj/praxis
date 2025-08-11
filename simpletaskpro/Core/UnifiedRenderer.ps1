# UnifiedRenderer.ps1 - Single rendering pipeline for all SimpleTaskPro screens
# Replaces SmoothRenderer's problematic dual-output system with pure StringBuilder approach
# Provides consistent animation support and performance optimizations for entire application

using namespace System.Collections.Generic

class UnifiedRenderer {
    # Core components - integrated with existing architecture
    [FastLineBuilder]$ContentBuilder
    [AppThemeManager]$ThemeManager
    [StringCache]$Cache
    
    # Animation settings - always enabled, no toggles
    [int]$AnimationSteps = 4           # Fast and smooth
    [int]$AnimationDelay = 30          # ms - much faster, responsive feel
    
    # Screen dimensions - auto-updated
    [int]$Width = 0
    [int]$Height = 0
    
    UnifiedRenderer() {
        $this.ContentBuilder = [FastLineBuilder]::new()
        $this.UpdateDimensions()
    }
    
    # Update dimensions if console was resized
    [void] UpdateDimensions() {
        $this.Width = [Console]::WindowWidth
        $this.Height = [Console]::WindowHeight
    }
    
    # Main rendering method - works with view models from FastLineBuilder
    # Each view model is [content_line, tag_line] string array  
    [string] RenderWithPillbox([string[][]]$viewModels, [int]$selectedIndex, [int]$startY = 3) {
        if (-not $viewModels -or $viewModels.Count -eq 0) { 
            return ""
        }
        
        # Convert view models to flat line list for existing pillbox logic
        $lines = [System.Collections.Generic.List[string]]::new()
        foreach ($viewModel in $viewModels) {
            $lines.Add($viewModel[0])  # content line
            $lines.Add($viewModel[1])  # tag line
        }
        
        # The lines already contain positioned content - we just add pillbox around selected item
        $output = [System.Text.StringBuilder]::new()
        [void]$output.Append([VT]::MoveTo(0, $startY))
        
        # Calculate which lines need pillbox (each task = 2 lines: content + tags)
        $pillboxStartLine = $selectedIndex * 2
        $pillboxEndLine = $pillboxStartLine + 1
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $actualY = $startY + $i
            
            if ($i -eq $pillboxStartLine -and $selectedIndex -ge 0) {
                # First line of selected item - add top border and side borders
                [void]$output.Append([VT]::MoveTo(0, $actualY))
                
                # Top border
                [void]$output.Append([AppThemeManager]::GetPillboxColor())
                [void]$output.Append("╭" + [StringCache]::GetHorizontalLine($this.Width - 2) + "╮")
                [void]$output.Append([VT]::Reset())
                [void]$output.Append("`n")
                
                # Content line with side borders
                [void]$output.Append([AppThemeManager]::GetPillboxColor() + "│" + [VT]::Reset())
                [void]$output.Append($line)
                
                # Pad to right border
                $paddingNeeded = $this.Width - $line.Length - 2
                if ($paddingNeeded -gt 0) {
                    [void]$output.Append([StringCache]::GetSpaces($paddingNeeded))
                }
                [void]$output.Append([AppThemeManager]::GetPillboxColor() + "│" + [VT]::Reset())
                
            } elseif ($i -eq $pillboxEndLine -and $selectedIndex -ge 0) {
                # Second line of selected item - tags line with borders
                [void]$output.Append("`n")
                [void]$output.Append([AppThemeManager]::GetPillboxColor() + "│" + [VT]::Reset())
                [void]$output.Append($line)
                
                # Pad to right border
                $paddingNeeded = $this.Width - $line.Length - 2
                if ($paddingNeeded -gt 0) {
                    [void]$output.Append([StringCache]::GetSpaces($paddingNeeded))
                }
                [void]$output.Append([AppThemeManager]::GetPillboxColor() + "│" + [VT]::Reset())
                [void]$output.Append("`n")
                
                # Bottom border
                [void]$output.Append([AppThemeManager]::GetPillboxColor())
                [void]$output.Append("╰" + [StringCache]::GetHorizontalLine($this.Width - 2) + "╯")
                [void]$output.Append([VT]::Reset())
                
            } else {
                # Normal line
                if ($i -gt 0) { [void]$output.Append("`n") }
                [void]$output.Append($line)
            }
        }
        
        return $output.ToString()
    }
    
    # Animated pillbox slide - pure StringBuilder approach
    # Replaces SmoothRenderer.AnimatePillboxSlide() problematic direct output
    [string] RenderWithAnimation([string[][]]$viewModels, [int]$fromIndex, [int]$toIndex, [int]$startY = 3) {
        if ($fromIndex -eq $toIndex -or -not $viewModels -or $viewModels.Count -eq 0) {
            return $this.RenderWithPillbox($viewModels, $toIndex, $startY)
        }
        
        # Smooth animation using StringBuilder regeneration - no direct VT commands
        for ($step = 0; $step -le $this.AnimationSteps; $step++) {
            # Calculate eased position using simple cubic ease-out
            $linearProgress = $step / [double]$this.AnimationSteps
            $easedProgress = 1 - [Math]::Pow(1 - $linearProgress, 3)
            
            # Interpolate position
            $currentIndex = [Math]::Round($fromIndex + ($toIndex - $fromIndex) * $easedProgress)
            
            # Generate frame content using StringBuilder
            $frameContent = [VT]::Clear() + [VT]::MoveTo(0, 0) + $this.RenderWithPillbox($viewModels, $currentIndex, $startY)
            
            # Output complete frame - single write operation
            [Console]::Write($frameContent)
            
            # Frame timing - simple and reliable
            if ($step -lt $this.AnimationSteps) {
                Start-Sleep -Milliseconds $this.AnimationDelay
            }
        }
        
        # Return final frame state
        return $this.RenderWithPillbox($viewModels, $toIndex, $startY)
    }
    
    # Generic screen rendering - extensible for all screen types
    [string] RenderScreen([System.Text.StringBuilder]$content, [bool]$clearScreen = $true) {
        $output = [System.Text.StringBuilder]::new()
        
        if ($clearScreen) {
            [void]$output.Append([VT]::Clear())
            [void]$output.Append([VT]::MoveTo(0, 0))
        }
        
        # Add the screen content
        [void]$output.Append($content.ToString())
        
        return $output.ToString()
    }
    
    # Status bar rendering with theme integration
    [string] RenderStatusBar([string]$statusText, [int]$y = -1) {
        if ($y -eq -1) { $y = $this.Height - 1 }
        
        $output = [System.Text.StringBuilder]::new()
        [void]$output.Append([VT]::MoveTo(0, $y))
        [void]$output.Append([AppThemeManager]::GetColor("StatusBar"))
        [void]$output.Append($statusText.PadRight($this.Width))
        [void]$output.Append([VT]::Reset())
        
        return $output.ToString()
    }
    
    # Header rendering with theme integration  
    [string] RenderHeader([string]$headerText, [int]$y = 0) {
        $output = [System.Text.StringBuilder]::new()
        [void]$output.Append([VT]::MoveTo(0, $y))
        [void]$output.Append([AppThemeManager]::GetColor("Header"))
        [void]$output.Append($headerText.PadRight($this.Width))
        [void]$output.Append([VT]::Reset())
        
        return $output.ToString()
    }
}