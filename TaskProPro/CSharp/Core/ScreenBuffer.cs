using System;
using System.Text;

namespace TaskPro.Core
{
    /// <summary>
    /// Professional flicker-free screen buffer using double buffering
    /// </summary>
    public class ScreenBuffer
    {
        private readonly DoubleBuffer doubleBuffer;
        
        public int Width => doubleBuffer.Width;
        public int Height => doubleBuffer.Height;
        
        public ScreenBuffer(int width, int height)
        {
            doubleBuffer = new DoubleBuffer(width, height);
        }
        
        /// <summary>
        /// Begin a new frame - call before any Write operations
        /// </summary>
        public void BeginFrame()
        {
            doubleBuffer.BeginFrame();
        }
        
        /// <summary>
        /// Write text at specific position with color
        /// </summary>
        public void WriteAt(int x, int y, string text, ConsoleColor foreground = ConsoleColor.White, ConsoleColor background = ConsoleColor.Black)
        {
            doubleBuffer.WriteAt(x, y, text, foreground, background);
        }
        
        /// <summary>
        /// Write text at position with ANSI color codes directly
        /// </summary>
        public void WriteAtWithAnsi(int x, int y, string textWithAnsi)
        {
            // For now, just write without ANSI processing
            doubleBuffer.WriteAt(x, y, textWithAnsi);
        }
        
        /// <summary>
        /// Fill a rectangular area with a character and color
        /// </summary>
        public void FillRect(int x, int y, int w, int h, char fillChar = ' ', 
                           ConsoleColor foreground = ConsoleColor.White, ConsoleColor background = ConsoleColor.Black)
        {
            doubleBuffer.FillRect(x, y, w, h, fillChar, foreground, background);
        }
        
        /// <summary>
        /// Clear area to spaces with default colors
        /// </summary>
        public void ClearArea(int x, int y, int width, int height)
        {
            doubleBuffer.ClearArea(x, y, width, height);
        }
        
        /// <summary>
        /// Draw a box border around an area
        /// </summary>
        public void DrawBox(int x, int y, int w, int h, ConsoleColor color = ConsoleColor.White)
        {
            if (w < 2 || h < 2) return;
            
            // Corners and edges
            doubleBuffer.WriteAt(x, y, '┌', color);
            doubleBuffer.WriteAt(x + w - 1, y, '┐', color);
            doubleBuffer.WriteAt(x, y + h - 1, '└', color);
            doubleBuffer.WriteAt(x + w - 1, y + h - 1, '┘', color);
            
            // Horizontal lines
            for (int i = 1; i < w - 1; i++)
            {
                doubleBuffer.WriteAt(x + i, y, '─', color);
                doubleBuffer.WriteAt(x + i, y + h - 1, '─', color);
            }
            
            // Vertical lines
            for (int row = 1; row < h - 1; row++)
            {
                doubleBuffer.WriteAt(x, y + row, '│', color);
                doubleBuffer.WriteAt(x + w - 1, y + row, '│', color);
            }
        }
        
        /// <summary>
        /// Draw a pillbox highlight around selected item
        /// </summary>
        public void DrawPillbox(int x, int y, int w, string text, ConsoleColor color = ConsoleColor.Blue)
        {
            doubleBuffer.DrawPillbox(x, y, w, text, color);
        }
        
        /// <summary>
        /// Clear the entire buffer
        /// </summary>
        public void Clear()
        {
            doubleBuffer.Clear();
        }
        
        /// <summary>
        /// End frame and render to console - ZERO FLICKER!
        /// </summary>
        public void EndFrame()
        {
            doubleBuffer.EndFrame();
        }
        
        /// <summary>
        /// Force full screen refresh
        /// </summary>
        public void ForceFullRefresh()
        {
            doubleBuffer.ForceFullRefresh();
        }
    }
}