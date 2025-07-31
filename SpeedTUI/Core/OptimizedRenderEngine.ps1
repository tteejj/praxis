# SpeedTUI Optimized Render Engine - Praxis-style performance with minimal flickering
# This replaces SimplifiedRenderEngine with better differential rendering

using namespace System.Text
using namespace System.Collections.Generic

<#
.SYNOPSIS
Optimized render engine that minimizes flickering like Praxis

.DESCRIPTION
This render engine:
- Uses absolute positioning for all content
- Only updates changed regions
- Caches rendered content aggressively
- Minimizes screen clears
- Provides flicker-free experience

.EXAMPLE
$engine = [OptimizedRenderEngine]::new()
$engine.Initialize()
$engine.BeginFrame()
$engine.WriteAt(10, 5, "Hello")
$engine.EndFrame()
#>
class OptimizedRenderEngine {
    # Core properties
    hidden [Dictionary[string, string]]$_lastContent  # Last content by position key
    hidden [StringBuilder]$_currentFrame              # Current frame being built
    hidden [bool]$_initialized = $false              # Initialization state
    hidden [bool]$_needsClear = $true                # Whether next frame needs clear
    
    # Screen dimensions
    [int]$Width
    [int]$Height
    
    # Performance tracking
    hidden [int]$_frameCount = 0
    hidden [int]$_updatedCells = 0
    
    <#
    .SYNOPSIS
    Initialize the optimized render engine
    #>
    OptimizedRenderEngine() {
        $this._lastContent = [Dictionary[string, string]]::new()
        
        # Get console dimensions
        $this.UpdateDimensions()
    }
    
    <#
    .SYNOPSIS
    Initialize the render engine for use
    #>
    [void] Initialize() {
        if ($this._initialized) { return }
        
        # Clear screen once and hide cursor
        [Console]::Clear()
        [Console]::CursorVisible = $false
        [Console]::SetCursorPosition(0, 0)
        
        # Initialize string cache
        [InternalStringCache]::Initialize()
        
        $this._initialized = $true
        $this._needsClear = $false
    }
    
    <#
    .SYNOPSIS
    Cleanup and restore console state
    #>
    [void] Cleanup() {
        # Restore cursor
        [Console]::CursorVisible = $true
        [Console]::Clear()
        
        # Clear caches
        $this._lastContent.Clear()
    }
    
    <#
    .SYNOPSIS
    Update screen dimensions
    #>
    [void] UpdateDimensions() {
        try {
            $this.Width = [Console]::WindowWidth
            $this.Height = [Console]::WindowHeight
        } catch {
            # Fallback dimensions
            $this.Width = 80
            $this.Height = 24
        }
    }
    
    <#
    .SYNOPSIS
    Begin a new frame
    #>
    [void] BeginFrame() {
        # Get a pooled StringBuilder
        $this._currentFrame = Get-PooledStringBuilder 4096
        $this._updatedCells = 0
    }
    
    <#
    .SYNOPSIS
    Write content at specific position (Praxis-style)
    
    .PARAMETER x
    X coordinate
    
    .PARAMETER y
    Y coordinate
    
    .PARAMETER content
    Content to write
    #>
    [void] WriteAt([int]$x, [int]$y, [string]$content) {
        if ($null -eq $this._currentFrame) {
            throw "BeginFrame must be called before WriteAt"
        }
        
        if ([string]::IsNullOrEmpty($content)) { return }
        
        # Create position key
        $key = "$x,$y"
        
        # Check if content at this position has changed
        $lastValue = $null
        if ($this._lastContent.TryGetValue($key, [ref]$lastValue)) {
            if ($lastValue -eq $content) {
                # Content unchanged - skip
                return
            }
        }
        
        # Content changed - add to frame
        $this._currentFrame.Append([InternalVT100]::MoveTo($x, $y))
        $this._currentFrame.Append($content)
        
        # Update cache
        $this._lastContent[$key] = $content
        $this._updatedCells++
    }
    
    <#
    .SYNOPSIS
    Clear a specific line
    
    .PARAMETER y
    Line number to clear
    #>
    [void] ClearLine([int]$y) {
        if ($null -eq $this._currentFrame) {
            throw "BeginFrame must be called before ClearLine"
        }
        
        $this._currentFrame.Append([InternalVT100]::MoveTo(0, $y))
        $this._currentFrame.Append([InternalStringCache]::GetAnsiSequence("clearline"))
        
        # Remove cached content for this line
        $keysToRemove = @()
        foreach ($key in $this._lastContent.Keys) {
            if ($key -match "^\d+,$y$") {
                $keysToRemove += $key
            }
        }
        foreach ($key in $keysToRemove) {
            $this._lastContent.Remove($key)
        }
    }
    
    <#
    .SYNOPSIS
    Force a full screen clear on next frame
    #>
    [void] RequestClear() {
        $this._needsClear = $true
        $this._lastContent.Clear()
    }
    
    <#
    .SYNOPSIS
    End the current frame and render to console
    #>
    [void] EndFrame() {
        if ($null -eq $this._currentFrame) {
            throw "BeginFrame must be called before EndFrame"
        }
        
        # Check if we need to clear screen
        if ($this._needsClear) {
            [Console]::Clear()
            [Console]::SetCursorPosition(0, 0)
            $this._needsClear = $false
        }
        
        # Only write if we have updates
        if ($this._updatedCells -gt 0) {
            $frameContent = $this._currentFrame.ToString()
            [Console]::Write($frameContent)
        }
        
        # Return StringBuilder to pool
        Return-PooledStringBuilder $this._currentFrame
        $this._currentFrame = $null
        
        $this._frameCount++
    }
    
    <#
    .SYNOPSIS
    Clear a rectangular area
    
    .PARAMETER x
    Starting X coordinate
    
    .PARAMETER y
    Starting Y coordinate
    
    .PARAMETER width
    Width to clear
    
    .PARAMETER height
    Height to clear
    #>
    [void] Clear([int]$x, [int]$y, [int]$width, [int]$height) {
        if ($null -eq $this._currentFrame) {
            throw "Clear can only be called between BeginFrame and EndFrame"
        }
        
        $spaces = [InternalStringCache]::GetSpaces($width)
        
        for ($row = 0; $row -lt $height; $row++) {
            $this.WriteAt($x, $y + $row, $spaces)
        }
    }
    
    <#
    .SYNOPSIS
    Draw a box at the specified location
    
    .PARAMETER x
    X coordinate
    
    .PARAMETER y
    Y coordinate
    
    .PARAMETER width
    Box width
    
    .PARAMETER height
    Box height
    
    .PARAMETER style
    Box style (Single, Double, Rounded)
    #>
    [void] DrawBox([int]$x, [int]$y, [int]$width, [int]$height, [string]$style = "Single") {
        if ($null -eq $this._currentFrame) {
            throw "DrawBox can only be called between BeginFrame and EndFrame"
        }
        
        if ($width -lt 2 -or $height -lt 2) { return }
        
        # Get box characters
        $chars = switch ($style) {
            "Double" { @{
                TL = "╔"; TR = "╗"; BL = "╚"; BR = "╝"
                H = "═"; V = "║"
            }}
            "Rounded" { @{
                TL = "╭"; TR = "╮"; BL = "╰"; BR = "╯"
                H = "─"; V = "│"
            }}
            default { @{
                TL = "┌"; TR = "┐"; BL = "└"; BR = "┘"
                H = "─"; V = "│"
            }}
        }
        
        # Pre-compute horizontal line
        $hLine = $chars.H * ($width - 2)
        
        # Top border
        $this.WriteAt($x, $y, $chars.TL + $hLine + $chars.TR)
        
        # Side borders with spaces in between
        $spaces = [InternalStringCache]::GetSpaces($width - 2)
        for ($row = 1; $row -lt $height - 1; $row++) {
            $this.WriteAt($x, $y + $row, $chars.V)
            $this.WriteAt($x + 1, $y + $row, $spaces)
            $this.WriteAt($x + $width - 1, $y + $row, $chars.V)
        }
        
        # Bottom border
        $this.WriteAt($x, $y + $height - 1, $chars.BL + $hLine + $chars.BR)
    }
    
    <#
    .SYNOPSIS
    Get performance statistics
    
    .OUTPUTS
    Hashtable with performance metrics
    #>
    [hashtable] GetPerformanceStats() {
        return @{
            FrameCount = $this._frameCount
            CachedPositions = $this._lastContent.Count
            LastUpdatedCells = $this._updatedCells
            Width = $this.Width
            Height = $this.Height
        }
    }
}