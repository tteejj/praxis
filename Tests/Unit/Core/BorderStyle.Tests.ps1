# BorderStyle.Tests.ps1 - Tests for BorderStyle component

BeforeAll {
    Import-Module "$PSScriptRoot/../../TestHelpers.psm1" -Force
    . "$PSScriptRoot/../../../Core/BorderStyle.ps1"
}

Describe "BorderStyle Class" {
    Context "Border Type Definitions" {
        It "Should have None border type with empty characters" {
            $chars = [BorderStyle]::GetBorderChars([BorderType]::None)
            $chars.TopLeft | Should -Be ""
            $chars.TopRight | Should -Be ""
            $chars.BottomLeft | Should -Be ""
            $chars.BottomRight | Should -Be ""
            $chars.Horizontal | Should -Be ""
            $chars.Vertical | Should -Be ""
        }
        
        It "Should have Single border type with correct characters" {
            $chars = [BorderStyle]::GetBorderChars([BorderType]::Single)
            $chars.TopLeft | Should -Be "┌"
            $chars.TopRight | Should -Be "┐"
            $chars.BottomLeft | Should -Be "└"
            $chars.BottomRight | Should -Be "┘"
            $chars.Horizontal | Should -Be "─"
            $chars.Vertical | Should -Be "│"
        }
        
        It "Should have Double border type with correct characters" {
            $chars = [BorderStyle]::GetBorderChars([BorderType]::Double)
            $chars.TopLeft | Should -Be "╔"
            $chars.TopRight | Should -Be "╗"
            $chars.BottomLeft | Should -Be "╚"
            $chars.BottomRight | Should -Be "╝"
            $chars.Horizontal | Should -Be "═"
            $chars.Vertical | Should -Be "║"
        }
        
        It "Should have Rounded border type with correct characters" {
            $chars = [BorderStyle]::GetBorderChars([BorderType]::Rounded)
            $chars.TopLeft | Should -Be "╭"
            $chars.TopRight | Should -Be "╮"
            $chars.BottomLeft | Should -Be "╰"
            $chars.BottomRight | Should -Be "╯"
            $chars.Horizontal | Should -Be "─"
            $chars.Vertical | Should -Be "│"
        }
    }
    
    Context "Special Characters" {
        It "Should have correct junction characters" {
            $chars = [BorderStyle]::GetBorderChars([BorderType]::Single)
            $chars.Cross | Should -Be "┼"
            $chars.TopJunction | Should -Be "┬"
            $chars.BottomJunction | Should -Be "┴"
            $chars.LeftJunction | Should -Be "├"
            $chars.RightJunction | Should -Be "┤"
        }
        
        It "Should have correct arrow characters" {
            $chars = [BorderStyle]::GetBorderChars([BorderType]::Single)
            $chars.UpArrow | Should -Be "▲"
            $chars.DownArrow | Should -Be "▼"
            $chars.LeftArrow | Should -Be "◄"
            $chars.RightArrow | Should -Be "►"
            $chars.UpDownArrow | Should -Be "↕"
            $chars.LeftRightArrow | Should -Be "↔"
        }
    }
    
    Context "Cache Performance" {
        It "Should cache border characters for performance" {
            # First call might initialize
            $chars1 = [BorderStyle]::GetBorderChars([BorderType]::Single)
            
            # Measure subsequent calls
            $perf = Measure-Performance -Name "1000 GetBorderChars calls" -ScriptBlock {
                for ($i = 0; $i -lt 1000; $i++) {
                    [BorderStyle]::GetBorderChars([BorderType]::Single) | Out-Null
                }
            }
            
            # Should be very fast due to caching
            $perf.ElapsedMilliseconds | Should -BeLessThan 50
        }
    }
    
    Context "BorderChar Hashtable Structure" {
        It "Should return hashtable with all required properties" {
            $chars = [BorderStyle]::GetBorderChars([BorderType]::Single)
            
            # Check all properties exist
            $requiredProps = @(
                'TopLeft', 'TopRight', 'BottomLeft', 'BottomRight',
                'Horizontal', 'Vertical', 'Cross',
                'TopJunction', 'BottomJunction', 'LeftJunction', 'RightJunction',
                'UpArrow', 'DownArrow', 'LeftArrow', 'RightArrow',
                'UpDownArrow', 'LeftRightArrow',
                'Check', 'Radio', 'RadioSelected',
                'Block', 'Shade1', 'Shade2', 'Shade3'
            )
            
            foreach ($prop in $requiredProps) {
                $chars.ContainsKey($prop) | Should -Be $true
            }
        }
    }
}