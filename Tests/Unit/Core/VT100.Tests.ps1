# VT100.Tests.ps1 - Tests for VT100 terminal control sequences

BeforeAll {
    Import-Module "$PSScriptRoot/../../TestHelpers.psm1" -Force
    . "$PSScriptRoot/../../../Core/StringCache.ps1"
    . "$PSScriptRoot/../../../Core/VT100.ps1"
}

Describe "VT100 Static Class" {
    Context "Cursor Movement" {
        It "Should generate correct MoveTo sequence" {
            $result = [VT]::MoveTo(10, 20)
            $result | Should -Be "`e[20;10H"
        }
        
        It "Should generate correct MoveUp sequence" {
            $result = [VT]::MoveUp(5)
            $result | Should -Be "`e[5A"
        }
        
        It "Should generate correct MoveDown sequence" {
            $result = [VT]::MoveDown(3)
            $result | Should -Be "`e[3B"
        }
        
        It "Should generate correct MoveRight sequence" {
            $result = [VT]::MoveRight(7)
            $result | Should -Be "`e[7C"
        }
        
        It "Should generate correct MoveLeft sequence" {
            $result = [VT]::MoveLeft(2)
            $result | Should -Be "`e[2D"
        }
    }
    
    Context "Cursor Visibility" {
        It "Should generate correct ShowCursor sequence" {
            $result = [VT]::ShowCursor()
            $result | Should -Be "`e[?25h"
        }
        
        It "Should generate correct HideCursor sequence" {
            $result = [VT]::HideCursor()
            $result | Should -Be "`e[?25l"
        }
    }
    
    Context "Screen Operations" {
        It "Should generate correct Clear sequence" {
            $result = [VT]::Clear()
            $result | Should -Be "`e[2J"
        }
        
        It "Should generate correct ClearLine sequence" {
            $result = [VT]::ClearLine()
            $result | Should -Be "`e[2K"
        }
        
        It "Should generate correct Reset sequence" {
            $result = [VT]::Reset()
            $result | Should -Be "`e[0m"
        }
    }
    
    Context "Text Formatting" {
        It "Should generate correct Bold sequence" {
            $result = [VT]::Bold()
            $result | Should -Be "`e[1m"
        }
        
        It "Should generate correct Dim sequence" {
            $result = [VT]::Dim()
            $result | Should -Be "`e[2m"
        }
        
        It "Should generate correct Italic sequence" {
            $result = [VT]::Italic()
            $result | Should -Be "`e[3m"
        }
        
        It "Should generate correct Underline sequence" {
            $result = [VT]::Underline()
            $result | Should -Be "`e[4m"
        }
    }
    
    Context "Colors" {
        It "Should generate correct RGB foreground color" {
            $result = [VT]::RgbFg(255, 128, 64)
            $result | Should -Be "`e[38;2;255;128;64m"
        }
        
        It "Should generate correct RGB background color" {
            $result = [VT]::RgbBg(64, 128, 255)
            $result | Should -Be "`e[48;2;64;128;255m"
        }
        
        It "Should generate correct 256-color foreground" {
            $result = [VT]::Color256Fg(42)
            $result | Should -Be "`e[38;5;42m"
        }
        
        It "Should generate correct 256-color background" {
            $result = [VT]::Color256Bg(142)
            $result | Should -Be "`e[48;5;142m"
        }
    }
    
    Context "Performance" {
        It "Should generate sequences quickly" {
            $perf = Measure-Performance -Name "1000 MoveTo calls" -ScriptBlock {
                for ($i = 0; $i -lt 1000; $i++) {
                    [VT]::MoveTo($i % 80, $i % 24) | Out-Null
                }
            }
            
            # Should complete 1000 calls in less than 100ms
            $perf.ElapsedMilliseconds | Should -BeLessThan 100
        }
    }
}