# SpacingSystem.ps1 - Consistent spacing and padding system

class Spacing {
    # Standard spacing units (based on 4px grid)
    static [int]$None = 0
    static [int]$Tiny = 1     # 1 character
    static [int]$Small = 2    # 2 characters
    static [int]$Medium = 4   # 4 characters (default)
    static [int]$Large = 8    # 8 characters
    static [int]$XLarge = 12  # 12 characters
    
    # Component-specific spacing
    static [hashtable]$Component = @{
        # Padding inside components
        ButtonPaddingX = 3
        ButtonPaddingY = 0
        
        TextBoxPaddingX = 1
        TextBoxPaddingY = 0
        
        ListBoxPaddingX = 1
        ListBoxPaddingY = 0
        
        ModalPaddingX = 2
        ModalPaddingY = 2
        
        # Margins between components
        ElementGap = 1
        SectionGap = 2
        ScreenMargin = 1
        
        # Focus indicators
        FocusOffset = 1
        FocusPadding = 1
    }
    
    # Get consistent padding for a component type
    static [hashtable] GetPadding([string]$componentType) {
        switch ($componentType) {
            "Button" {
                return @{
                    Left = [Spacing]::Component.ButtonPaddingX
                    Right = [Spacing]::Component.ButtonPaddingX
                    Top = [Spacing]::Component.ButtonPaddingY
                    Bottom = [Spacing]::Component.ButtonPaddingY
                }
            }
            "TextBox" {
                return @{
                    Left = [Spacing]::Component.TextBoxPaddingX
                    Right = [Spacing]::Component.TextBoxPaddingX
                    Top = [Spacing]::Component.TextBoxPaddingY
                    Bottom = [Spacing]::Component.TextBoxPaddingY
                }
            }
            "ListBox" {
                return @{
                    Left = [Spacing]::Component.ListBoxPaddingX
                    Right = [Spacing]::Component.ListBoxPaddingX
                    Top = [Spacing]::Component.ListBoxPaddingY
                    Bottom = [Spacing]::Component.ListBoxPaddingY
                }
            }
            "Modal" {
                return @{
                    Left = [Spacing]::Component.ModalPaddingX
                    Right = [Spacing]::Component.ModalPaddingX
                    Top = [Spacing]::Component.ModalPaddingY
                    Bottom = [Spacing]::Component.ModalPaddingY
                }
            }
            default {
                return @{
                    Left = [Spacing]::Small
                    Right = [Spacing]::Small
                    Top = [Spacing]::Tiny
                    Bottom = [Spacing]::Tiny
                }
            }
        }
    }
    
    # Calculate content area with padding
    static [hashtable] GetContentArea([int]$x, [int]$y, [int]$width, [int]$height, [hashtable]$padding) {
        return @{
            X = $x + $padding.Left
            Y = $y + $padding.Top
            Width = $width - $padding.Left - $padding.Right
            Height = $height - $padding.Top - $padding.Bottom
        }
    }
    
    # Create padding string
    static [string] Pad([string]$text, [int]$left, [int]$right = 0) {
        $leftPad = ' ' * $left
        $rightPad = ' ' * $right
        return "${leftPad}${text}${rightPad}"
    }
    
    # Create vertical spacing
    static [string] VerticalSpace([int]$lines) {
        return "`n" * $lines
    }
}

# Extension for UIElement to use consistent spacing
class SpacedElement : UIElement {
    [hashtable]$Padding = @{ Left = 0; Right = 0; Top = 0; Bottom = 0 }
    [hashtable]$Margin = @{ Left = 0; Right = 0; Top = 0; Bottom = 0 }
    
    [void] SetPadding([int]$all) {
        $this.Padding = @{
            Left = $all
            Right = $all
            Top = $all
            Bottom = $all
        }
        $this.Invalidate()
    }
    
    [void] SetPadding([int]$horizontal, [int]$vertical) {
        $this.Padding = @{
            Left = $horizontal
            Right = $horizontal
            Top = $vertical
            Bottom = $vertical
        }
        $this.Invalidate()
    }
    
    [void] SetPadding([int]$left, [int]$top, [int]$right, [int]$bottom) {
        $this.Padding = @{
            Left = $left
            Right = $right
            Top = $top
            Bottom = $bottom
        }
        $this.Invalidate()
    }
    
    [void] SetMargin([int]$all) {
        $this.Margin = @{
            Left = $all
            Right = $all
            Top = $all
            Bottom = $all
        }
        $this.Invalidate()
    }
    
    [void] SetMargin([int]$horizontal, [int]$vertical) {
        $this.Margin = @{
            Left = $horizontal
            Right = $horizontal
            Top = $vertical
            Bottom = $vertical
        }
        $this.Invalidate()
    }
    
    [hashtable] GetContentBounds() {
        return [Spacing]::GetContentArea(
            $this.X + $this.Margin.Left,
            $this.Y + $this.Margin.Top,
            $this.Width - $this.Margin.Left - $this.Margin.Right,
            $this.Height - $this.Margin.Top - $this.Margin.Bottom,
            $this.Padding
        )
    }
}

# Layout helpers
class LayoutHelper {
    # Stack elements vertically with consistent spacing
    static [void] StackVertical([UIElement[]]$elements, [int]$startX, [int]$startY, [int]$spacing = 0) {
        if (-not $spacing) {
            $spacing = [Spacing]::Component.ElementGap
        }
        
        $currentY = $startY
        foreach ($element in $elements) {
            $element.X = $startX
            $element.Y = $currentY
            $currentY += $element.Height + $spacing
        }
    }
    
    # Stack elements horizontally with consistent spacing
    static [void] StackHorizontal([UIElement[]]$elements, [int]$startX, [int]$startY, [int]$spacing = 0) {
        if (-not $spacing) {
            $spacing = [Spacing]::Component.ElementGap
        }
        
        $currentX = $startX
        foreach ($element in $elements) {
            $element.X = $currentX
            $element.Y = $startY
            $currentX += $element.Width + $spacing
        }
    }
    
    # Center elements in container
    static [void] CenterInContainer([UIElement]$element, [UIElement]$container) {
        $element.X = $container.X + ($container.Width - $element.Width) / 2
        $element.Y = $container.Y + ($container.Height - $element.Height) / 2
    }
    
    # Align elements
    static [void] AlignLeft([UIElement[]]$elements, [int]$x) {
        foreach ($element in $elements) {
            $element.X = $x
        }
    }
    
    static [void] AlignRight([UIElement[]]$elements, [int]$containerWidth, [int]$rightMargin = 0) {
        foreach ($element in $elements) {
            $element.X = $containerWidth - $element.Width - $rightMargin
        }
    }
    
    static [void] AlignCenter([UIElement[]]$elements, [int]$containerWidth) {
        foreach ($element in $elements) {
            $element.X = ($containerWidth - $element.Width) / 2
        }
    }
}