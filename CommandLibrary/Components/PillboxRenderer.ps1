# PillboxRenderer.ps1 - Enhanced pillbox selection renderer
# Based on TaskPro's sophisticated pillbox implementation

class PillboxRenderer {
    # Pillbox characters (rounded corners like TaskPro)
    [string]$TopLeft = "╭"
    [string]$TopRight = "╮"
    [string]$BottomLeft = "╰"
    [string]$BottomRight = "╯"
    [string]$Horizontal = "─"
    [string]$Vertical = "│"
    
    # Rendering parameters
    [int]$MinWidth = 50
    [int]$MaxWidth = 120
    [string]$BorderColor = ""
    [string]$ContentColor = ""
    [string]$TagColor = ""
    
    PillboxRenderer() {
        $this.UpdateColors()
    }
    
    [void] UpdateColors() {
        $this.BorderColor = [ColorThemeService]::GetColor("Border")
        $this.ContentColor = [ColorThemeService]::GetColor("CommandSelected")
        $this.TagColor = [ColorThemeService]::GetColor("TagHighlight")
    }
    
    [int] CalculateWidth([object]$item, [int]$maxWidth) {
        $mainContent = $this.GetMainContentLength($item)
        $metaContent = $this.GetMetaContentLength($item)
        
        # Use the longer of the two lines
        $contentWidth = [Math]::Max($mainContent, $metaContent)
        $pillboxWidth = $contentWidth + 4  # borders + padding
        
        # Ensure minimum width and don't exceed max
        return [Math]::Min($maxWidth, [Math]::Max($this.MinWidth, $pillboxWidth))
    }
    
    [int] GetMainContentLength([object]$item) {
        if (-not $item) { return 20 }
        
        $displayText = ""
        if ($item.GetType().Name -eq "Command") {
            $displayText = $item.GetDisplayText()
            if ($item.UseCount -gt 0) {
                $displayText += " ★$($item.UseCount)"
            }
        } else {
            $displayText = $item.ToString()
        }
        
        return [Measure]::TextWidth($displayText)
    }
    
    [int] GetMetaContentLength([object]$item) {
        if (-not $item -or $item.GetType().Name -ne "Command") { return 0 }
        
        if ($item.Tags.Count -eq 0) { return 0 }
        
        $tagDisplay = "  #" + ($item.Tags -join " #")
        return [Measure]::TextWidth($tagDisplay)
    }
    
    [void] RenderPillbox([System.Text.StringBuilder]$sb, [object]$item, [int]$x, [int]$y, [int]$width, [int]$maxY) {
        # Ensure we don't render beyond screen bounds
        if ($y + 3 -gt $maxY) { return }
        
        # Render top border
        $this.RenderBorder($sb, $x, $y, $width, "top")
        
        # Render main content line
        $this.RenderContentLine($sb, $item, $x, $y + 1, $width)
        
        # Render metadata line (tags, usage, etc.) if item has metadata
        if ($this.HasMetadata($item)) {
            $this.RenderMetaLine($sb, $item, $x, $y + 2, $width)
            $this.RenderBorder($sb, $x, $y + 3, $width, "bottom")
        } else {
            $this.RenderBorder($sb, $x, $y + 2, $width, "bottom")
        }
    }
    
    [bool] HasMetadata([object]$item) {
        if (-not $item -or $item.GetType().Name -ne "Command") { return $false }
        return $item.Tags.Count -gt 0
    }
    
    [int] GetPillboxHeight([object]$item) {
        return $this.CalculateDynamicHeight($item)
    }
    
    [int] CalculateDynamicHeight([object]$item) {
        $requiredLines = 2  # Base: top border + bottom border
        
        # Content analysis
        if ($this.HasMainContent($item)) { $requiredLines++ }
        if ($this.HasTags($item)) { $requiredLines++ }
        if ($this.HasMetadata($item)) { $requiredLines++ }
        
        # Spacer line only if we have content (efficiency)
        if ($requiredLines -gt 2) { $requiredLines++ }  # Add spacer
        
        return $requiredLines
    }
    
    [bool] HasMainContent([object]$item) {
        if (-not $item) { return $false }
        return -not [string]::IsNullOrWhiteSpace($item.GetDisplayText())
    }
    
    [bool] HasTags([object]$item) {
        if (-not $item -or $item.GetType().Name -ne "Command") { return $false }
        return $item.Tags.Count -gt 0
    }
    
    [void] RenderBorder([System.Text.StringBuilder]$sb, [int]$x, [int]$y, [int]$width, [string]$type) {
        [void]$sb.Append([VT]::MoveTo($x, $y))
        
        # Multi-color border highlighting
        $highlightColor = [ColorThemeService]::GetColor("CommandHighlight")
        $borderColorValue = $this.BorderColor
        
        if ($type -eq "top") {
            [void]$sb.Append($highlightColor + $this.TopLeft)
            [void]$sb.Append($borderColorValue + ($this.Horizontal * ($width - 2)))
            [void]$sb.Append($highlightColor + $this.TopRight)
        } else {
            [void]$sb.Append($highlightColor + $this.BottomLeft)
            [void]$sb.Append($borderColorValue + ($this.Horizontal * ($width - 2)))
            [void]$sb.Append($highlightColor + $this.BottomRight)
        }
        [void]$sb.Append([VT]::Reset())
    }
    
    [void] RenderContentLine([System.Text.StringBuilder]$sb, [object]$item, [int]$x, [int]$y, [int]$width) {
        [void]$sb.Append([VT]::MoveTo($x, $y))
        
        # Content-aware height calculation means we only render this if we have content
        if (-not $this.HasMainContent($item)) { return }
        
        # Highlighted border sides
        $highlightColor = [ColorThemeService]::GetColor("CommandHighlight")
        [void]$sb.Append($highlightColor + $this.Vertical + [VT]::Reset())
        
        # Build display text with colors
        $displayText = ""
        if ($item.GetType().Name -eq "Command") {
            $displayText = $item.GetDisplayText()
            
            # Add usage count with color if > 0
            if ($item.UseCount -gt 0) {
                $usageDisplay = [ColorThemeService]::GetUsageDisplay($item.UseCount)
                $displayText += " $usageDisplay"
            }
        } else {
            $displayText = $item.ToString()
        }
        
        # Apply content color with background highlighting
        $bgColor = [ColorThemeService]::GetColor("PillboxBG")
        [void]$sb.Append(" $bgColor$($this.ContentColor)$displayText$([VT]::Reset())")
        
        # Calculate and fill remaining space with background
        $contentLength = [Measure]::TextWidth($displayText)
        $remainingSpace = $width - $contentLength - 3  # 3 = left border + 2 spaces
        if ($remainingSpace -gt 0) {
            [void]$sb.Append($bgColor + (" " * $remainingSpace) + [VT]::Reset())
        }
        
        # Move to right border position and render highlighted border
        [void]$sb.Append([VT]::MoveTo($x + $width - 1, $y))
        [void]$sb.Append($highlightColor + $this.Vertical + [VT]::Reset())
    }
    
    [void] RenderMetaLine([System.Text.StringBuilder]$sb, [object]$item, [int]$x, [int]$y, [int]$width) {
        [void]$sb.Append([VT]::MoveTo($x, $y))
        
        # Only render if we have tags (content-aware)
        if (-not $this.HasTags($item)) { return }
        
        # Highlighted border sides for meta line too
        $highlightColor = [ColorThemeService]::GetColor("CommandHighlight")
        [void]$sb.Append($highlightColor + $this.Vertical + [VT]::Reset())
        
        if ($item.GetType().Name -eq "Command" -and $item.Tags.Count -gt 0) {
            # Render tags with enhanced display and background
            $bgColor = [ColorThemeService]::GetColor("PillboxBG")
            $tagDisplay = ""
            foreach ($tag in $item.Tags) {
                $tagDisplay += " " + [ColorThemeService]::GetTagDisplay($tag, $true)
            }
            [void]$sb.Append("  $bgColor$tagDisplay$([VT]::Reset())")
            
            # Calculate and fill remaining space with background
            $tagLength = [Measure]::TextWidth($tagDisplay)
            $remainingSpace = $width - $tagLength - 4  # 4 = left border + 2 spaces + right space
            if ($remainingSpace -gt 0) {
                [void]$sb.Append($bgColor + (" " * $remainingSpace) + [VT]::Reset())
            }
        }
        
        # Move to right border position and render highlighted border
        [void]$sb.Append([VT]::MoveTo($x + $width - 1, $y))
        [void]$sb.Append($highlightColor + $this.Vertical + [VT]::Reset())
    }
    
    [void] RenderSpacerLine([System.Text.StringBuilder]$sb, [int]$x, [int]$y, [int]$width) {
        # Render empty line above pillbox for visual separation
        [void]$sb.Append([VT]::MoveTo($x, $y))
        [void]$sb.Append(" " * $width)
    }
}

# Factory function for easy creation
function New-PillboxRenderer {
    return [PillboxRenderer]::new()
}