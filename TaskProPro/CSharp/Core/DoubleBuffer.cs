using System;
using System.Text;

namespace TaskPro.Core
{
    /// <summary>
    /// True double-buffer implementation for zero-flicker rendering
    /// </summary>
    public class DoubleBuffer
    {
        private readonly int width;
        private readonly int height;
        private readonly char[,] charBuffer;
        private readonly ConsoleColor[,] fgBuffer;
        private readonly ConsoleColor[,] bgBuffer;
        private readonly char[,] prevCharBuffer;
        private readonly ConsoleColor[,] prevFgBuffer;
        private readonly ConsoleColor[,] prevBgBuffer;
        
        private bool frameStarted = false;
        private readonly StringBuilder outputBuffer;
        
        public int Width => width;
        public int Height => height;
        
        public DoubleBuffer(int width, int height)
        {
            this.width = width;
            this.height = height;
            
            // Current frame buffers
            charBuffer = new char[height, width];
            fgBuffer = new ConsoleColor[height, width];
            bgBuffer = new ConsoleColor[height, width];
            
            // Previous frame buffers (for change detection)
            prevCharBuffer = new char[height, width];
            prevFgBuffer = new ConsoleColor[height, width];
            prevBgBuffer = new ConsoleColor[height, width];
            
            // Output buffer for final rendering
            outputBuffer = new StringBuilder(width * height * 8); // Room for ANSI codes
            
            // Initialize with spaces
            Clear();
        }
        
        /// <summary>
        /// Begin a new frame
        /// </summary>
        public void BeginFrame()
        {
            frameStarted = true;
            // Clear current frame to spaces with default colors
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    charBuffer[y, x] = ' ';
                    fgBuffer[y, x] = ConsoleColor.White;
                    bgBuffer[y, x] = ConsoleColor.Black;
                }
            }
        }
        
        /// <summary>
        /// Write a single character at position
        /// </summary>
        public void WriteAt(int x, int y, char character, ConsoleColor fg = ConsoleColor.White, ConsoleColor bg = ConsoleColor.Black)
        {
            if (!frameStarted) throw new InvalidOperationException("Must call BeginFrame() first");
            if (x < 0 || x >= width || y < 0 || y >= height) return;
            
            charBuffer[y, x] = character;
            fgBuffer[y, x] = fg;
            bgBuffer[y, x] = bg;
        }
        
        /// <summary>
        /// Write text at position with color
        /// </summary>
        public void WriteAt(int x, int y, string text, ConsoleColor fg = ConsoleColor.White, ConsoleColor bg = ConsoleColor.Black)
        {
            if (string.IsNullOrEmpty(text)) return;
            
            for (int i = 0; i < text.Length && x + i < width; i++)
            {
                WriteAt(x + i, y, text[i], fg, bg);
            }
        }
        
        /// <summary>
        /// Fill a rectangle with character and colors
        /// </summary>
        public void FillRect(int x, int y, int width, int height, char fillChar, ConsoleColor fg = ConsoleColor.White, ConsoleColor bg = ConsoleColor.Black)
        {
            for (int dy = 0; dy < height && y + dy < this.height; dy++)
            {
                for (int dx = 0; dx < width && x + dx < this.width; dx++)
                {
                    WriteAt(x + dx, y + dy, fillChar, fg, bg);
                }
            }
        }
        
        /// <summary>
        /// Clear area to spaces with default colors
        /// </summary>
        public void ClearArea(int x, int y, int width, int height)
        {
            FillRect(x, y, width, height, ' ', ConsoleColor.White, ConsoleColor.Black);
        }
        
        /// <summary>
        /// Draw a pillbox border around text
        /// </summary>
        public void DrawPillbox(int x, int y, int width, string text, ConsoleColor borderColor)
        {
            if (y > 0) // Top border
            {
                WriteAt(x, y - 1, "╭", borderColor);
                for (int i = 1; i < width - 1; i++)
                {
                    WriteAt(x + i, y - 1, '─', borderColor);
                }
                WriteAt(x + width - 1, y - 1, "╮", borderColor);
            }
            
            // Text line with borders
            WriteAt(x, y, "│", borderColor);
            WriteAt(x + 1, y, text.PadRight(width - 2), ConsoleColor.Black, ConsoleColor.White);
            WriteAt(x + width - 1, y, "│", borderColor);
            
            if (y < height - 1) // Bottom border
            {
                WriteAt(x, y + 1, "╰", borderColor);
                for (int i = 1; i < width - 1; i++)
                {
                    WriteAt(x + i, y + 1, '─', borderColor);
                }
                WriteAt(x + width - 1, y + 1, "╯", borderColor);
            }
        }
        
        /// <summary>
        /// End frame and render to console with minimal updates
        /// </summary>
        public void EndFrame()
        {
            if (!frameStarted) return;
            
            outputBuffer.Clear();
            
            // Hide cursor during update
            outputBuffer.Append("\x1b[?25l");
            
            var currentFg = ConsoleColor.White;
            var currentBg = ConsoleColor.Black;
            var needsColorUpdate = true;
            
            // Render only changed cells for maximum efficiency
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    // Check if this cell changed
                    if (charBuffer[y, x] == prevCharBuffer[y, x] &&
                        fgBuffer[y, x] == prevFgBuffer[y, x] &&
                        bgBuffer[y, x] == prevBgBuffer[y, x])
                    {
                        continue; // Skip unchanged cells
                    }
                    
                    // Position cursor
                    outputBuffer.Append($"\x1b[{y + 1};{x + 1}H");
                    
                    // Update colors if needed
                    var newFg = fgBuffer[y, x];
                    var newBg = bgBuffer[y, x];
                    
                    if (needsColorUpdate || currentFg != newFg || currentBg != newBg)
                    {
                        outputBuffer.Append($"\x1b[38;5;{(int)newFg}m");
                        outputBuffer.Append($"\x1b[48;5;{(int)newBg}m");
                        currentFg = newFg;
                        currentBg = newBg;
                        needsColorUpdate = false;
                    }
                    
                    // Write character
                    outputBuffer.Append(charBuffer[y, x]);
                    
                    // Update previous frame buffer
                    prevCharBuffer[y, x] = charBuffer[y, x];
                    prevFgBuffer[y, x] = fgBuffer[y, x];
                    prevBgBuffer[y, x] = bgBuffer[y, x];
                }
            }
            
            // Reset colors and show cursor
            outputBuffer.Append("\x1b[0m");
            outputBuffer.Append("\x1b[?25h");
            
            // SINGLE WRITE TO CONSOLE - ZERO FLICKER!
            Console.Write(outputBuffer.ToString());
            
            frameStarted = false;
        }
        
        /// <summary>
        /// Force full screen refresh (for resize, etc.)
        /// </summary>
        public void ForceFullRefresh()
        {
            // Mark all cells as changed
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    prevCharBuffer[y, x] = '\0'; // Force change detection
                }
            }
        }
        
        /// <summary>
        /// Clear entire buffer
        /// </summary>
        public void Clear()
        {
            for (int y = 0; y < height; y++)
            {
                for (int x = 0; x < width; x++)
                {
                    charBuffer[y, x] = ' ';
                    fgBuffer[y, x] = ConsoleColor.White;
                    bgBuffer[y, x] = ConsoleColor.Black;
                    prevCharBuffer[y, x] = '\0'; // Force update
                }
            }
        }
    }
}