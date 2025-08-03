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
        # Should never reach here, but PowerShell requires it
        return @{
            Left = 0
            Right = 0
            Top = 0
            Bottom = 0
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