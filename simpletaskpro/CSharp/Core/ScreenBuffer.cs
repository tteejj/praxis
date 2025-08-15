using System;
using System.Text;

namespace TaskPro.Core
{
    /// <summary>
    /// Professional flicker-free screen buffer for TUI applications
    /// </summary>
    public class ScreenBuffer
    {
        private readonly StringBuilder buffer;
        private readonly int width;
        private readonly int height;
        private bool frameStarted = false;
        
        public int Width => width;
        public int Height => height;
        
        public ScreenBuffer(int width, int height)
        {
            this.width = width;
            this.height = height;
            this.buffer = new StringBuilder(width * height * 2); // Extra space for ANSI codes
        }
        
        /// <summary>
        /// Begin a new frame - call before any Write operations
        /// </summary>
        public void BeginFrame()
        {
            buffer.Clear();
            buffer.Append("\x1b[?25l"); // Hide cursor
            buffer.Append("\x1b[H");    // Move to home position
            frameStarted = true;
        }
        
        /// <summary>
        /// Write text at specific position with color
        /// </summary>
        public void WriteAt(int x, int y, string text, ConsoleColor foreground = ConsoleColor.White, ConsoleColor background = ConsoleColor.Black)
        {
            if (!frameStarted) throw new InvalidOperationException("Must call BeginFrame() first");
            if (x < 0 || y < 0 || x >= width || y >= height) return;
            if (string.IsNullOrEmpty(text)) return;
            
            // Position cursor
            buffer.Append($"\x1b[{y + 1};{x + 1}H");
            
            // Set colors if not default
            if (foreground != ConsoleColor.White || background != ConsoleColor.Black)
            {
                buffer.Append($"\x1b[{GetForegroundColor(foreground)};{GetBackgroundColor(background)}m");
            }
            
            // Write text (truncate if too long)
            var maxLength = width - x;
            if (text.Length > maxLength)
            {
                text = text.Substring(0, maxLength);
            }
            
            buffer.Append(text);
            
            // Reset colors if they were changed
            if (foreground != ConsoleColor.White || background != ConsoleColor.Black)
            {
                buffer.Append("\x1b[0m");
            }
        }
        
        /// <summary>
        /// Write text at position with ANSI color codes directly
        /// </summary>
        public void WriteAtWithAnsi(int x, int y, string textWithAnsi)
        {
            if (!frameStarted) throw new InvalidOperationException("Must call BeginFrame() first");
            if (x < 0 || y < 0 || x >= width || y >= height) return;
            if (string.IsNullOrEmpty(textWithAnsi)) return;
            
            buffer.Append($"\x1b[{y + 1};{x + 1}H{textWithAnsi}");
        }
        
        /// <summary>
        /// Fill a rectangular area with a character and color
        /// </summary>
        public void FillRect(int x, int y, int w, int h, char fillChar = ' ', 
                           ConsoleColor foreground = ConsoleColor.White, ConsoleColor background = ConsoleColor.Black)
        {
            var fillLine = new string(fillChar, w);
            for (int row = 0; row < h; row++)
            {
                WriteAt(x, y + row, fillLine, foreground, background);
            }
        }
        
        /// <summary>
        /// Draw a box border around an area
        /// </summary>
        public void DrawBox(int x, int y, int w, int h, ConsoleColor color = ConsoleColor.White)
        {
            if (w < 2 || h < 2) return;
            
            // Corners and edges
            WriteAt(x, y, "┌", color);
            WriteAt(x + w - 1, y, "┐", color);
            WriteAt(x, y + h - 1, "└", color);
            WriteAt(x + w - 1, y + h - 1, "┘", color);
            
            // Horizontal lines
            var hLine = new string('─', w - 2);
            WriteAt(x + 1, y, hLine, color);
            WriteAt(x + 1, y + h - 1, hLine, color);
            
            // Vertical lines
            for (int row = 1; row < h - 1; row++)
            {
                WriteAt(x, y + row, "│", color);
                WriteAt(x + w - 1, y + row, "│", color);
            }
        }
        
        /// <summary>
        /// Draw a pillbox highlight around selected item (like your TaskPro design)
        /// </summary>
        public void DrawPillbox(int x, int y, int w, string text, ConsoleColor color = ConsoleColor.Blue)
        {
            // Top border
            WriteAt(x, y, "╭", color);
            WriteAt(x + 1, y, new string('─', w - 2), color);
            WriteAt(x + w - 1, y, "╮", color);
            
            // Content with sides
            WriteAt(x, y + 1, "│", color);
            WriteAt(x + 1, y + 1, text.PadRight(w - 2), ConsoleColor.Black, color);
            WriteAt(x + w - 1, y + 1, "│", color);
            
            // Bottom border
            WriteAt(x, y + 2, "╰", color);
            WriteAt(x + 1, y + 2, new string('─', w - 2), color);
            WriteAt(x + w - 1, y + 2, "╯", color);
        }
        
        /// <summary>
        /// Clear specific area
        /// </summary>
        public void ClearArea(int x, int y, int w, int h)
        {
            FillRect(x, y, w, h, ' ', ConsoleColor.White, ConsoleColor.Black);
        }
        
        /// <summary>
        /// End frame and write to console - single write for zero flicker
        /// </summary>
        public void EndFrame()
        {
            if (!frameStarted) return;
            
            buffer.Append("\x1b[?25h"); // Show cursor
            Console.Write(buffer.ToString());
            frameStarted = false;
        }
        
        /// <summary>
        /// Force cursor to specific position (for text input)
        /// </summary>
        public void SetCursorPosition(int x, int y)
        {
            buffer.Append($"\x1b[{y + 1};{x + 1}H");
        }
        
        /// <summary>
        /// Hide/show cursor
        /// </summary>
        public void SetCursorVisible(bool visible)
        {
            buffer.Append(visible ? "\x1b[?25h" : "\x1b[?25l");
        }
        
        private static int GetForegroundColor(ConsoleColor color) => color switch
        {
            ConsoleColor.Black => 30,
            ConsoleColor.DarkRed => 31,
            ConsoleColor.DarkGreen => 32,
            ConsoleColor.DarkYellow => 33,
            ConsoleColor.DarkBlue => 34,
            ConsoleColor.DarkMagenta => 35,
            ConsoleColor.DarkCyan => 36,
            ConsoleColor.Gray => 37,
            ConsoleColor.DarkGray => 90,
            ConsoleColor.Red => 91,
            ConsoleColor.Green => 92,
            ConsoleColor.Yellow => 93,
            ConsoleColor.Blue => 94,
            ConsoleColor.Magenta => 95,
            ConsoleColor.Cyan => 96,
            ConsoleColor.White => 97,
            _ => 97
        };
        
        private static int GetBackgroundColor(ConsoleColor color) => color switch
        {
            ConsoleColor.Black => 40,
            ConsoleColor.DarkRed => 41,
            ConsoleColor.DarkGreen => 42,
            ConsoleColor.DarkYellow => 43,
            ConsoleColor.DarkBlue => 44,
            ConsoleColor.DarkMagenta => 45,
            ConsoleColor.DarkCyan => 46,
            ConsoleColor.Gray => 47,
            ConsoleColor.DarkGray => 100,
            ConsoleColor.Red => 101,
            ConsoleColor.Green => 102,
            ConsoleColor.Yellow => 103,
            ConsoleColor.Blue => 104,
            ConsoleColor.Magenta => 105,
            ConsoleColor.Cyan => 106,
            ConsoleColor.White => 107,
            _ => 40
        };
    }
    
    /// <summary>
    /// Simple rectangle for layout calculations
    /// </summary>
    public struct Rectangle
    {
        public int X { get; set; }
        public int Y { get; set; }
        public int Width { get; set; }
        public int Height { get; set; }
        
        public Rectangle(int x, int y, int width, int height)
        {
            X = x;
            Y = y;
            Width = width;
            Height = height;
        }
        
        public int Right => X + Width;
        public int Bottom => Y + Height;
        
        public bool Contains(int x, int y)
        {
            return x >= X && x < Right && y >= Y && y < Bottom;
        }
    }
}