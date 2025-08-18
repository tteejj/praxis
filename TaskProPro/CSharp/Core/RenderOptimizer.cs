using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;

namespace TaskPro.Core
{
    /// <summary>
    /// High-performance render optimization system
    /// Provides StringBuilder pooling, ANSI caching, and optimized formatting
    /// </summary>
    public static class RenderOptimizer
    {
        // THREAD-SAFE STRINGBUILDER POOL
        private static readonly ThreadLocal<StringBuilder> StringBuilderPool = 
            new(() => new StringBuilder(512));
        
        // PRE-COMPUTED ANSI COLOR SEQUENCES
        private static readonly Dictionary<ConsoleColor, string> AnsiColors = new()
        {
            [ConsoleColor.Black] = "\x1b[30m",
            [ConsoleColor.DarkBlue] = "\x1b[34m", 
            [ConsoleColor.DarkGreen] = "\x1b[32m",
            [ConsoleColor.DarkCyan] = "\x1b[36m",
            [ConsoleColor.DarkRed] = "\x1b[31m",
            [ConsoleColor.DarkMagenta] = "\x1b[35m",
            [ConsoleColor.DarkYellow] = "\x1b[33m",
            [ConsoleColor.Gray] = "\x1b[37m",
            [ConsoleColor.DarkGray] = "\x1b[90m",
            [ConsoleColor.Blue] = "\x1b[94m",
            [ConsoleColor.Green] = "\x1b[92m",
            [ConsoleColor.Cyan] = "\x1b[96m",
            [ConsoleColor.Red] = "\x1b[91m",
            [ConsoleColor.Magenta] = "\x1b[95m",
            [ConsoleColor.Yellow] = "\x1b[93m",
            [ConsoleColor.White] = "\x1b[97m"
        };
        
        private static readonly string AnsiReset = "\x1b[0m";
        
        // SHARED FORMATTING BUFFERS
        private static readonly char[] PaddingBuffer = new char[256];
        
        static RenderOptimizer()
        {
            // Initialize padding buffer with spaces
            Array.Fill(PaddingBuffer, ' ');
        }
        
        /// <summary>
        /// Get a pooled StringBuilder for zero-allocation string building
        /// </summary>
        public static StringBuilder GetStringBuilder()
        {
            var sb = StringBuilderPool.Value;
            sb.Clear();
            return sb;
        }
        
        /// <summary>
        /// Build a complete colored row with single allocation
        /// </summary>
        public static string BuildColoredRow(params (string text, ConsoleColor color)[] segments)
        {
            var sb = GetStringBuilder();
            
            foreach (var (text, color) in segments)
            {
                if (AnsiColors.TryGetValue(color, out var ansiCode))
                {
                    sb.Append(ansiCode);
                }
                sb.Append(text);
                sb.Append(AnsiReset);
            }
            
            return sb.ToString();
        }
        
        /// <summary>
        /// Fast string padding with zero allocation for small sizes
        /// </summary>
        public static string PadRightFast(string input, int totalWidth)
        {
            if (input.Length >= totalWidth) 
                return input.Substring(0, totalWidth);
                
            var padCount = totalWidth - input.Length;
            if (padCount <= PaddingBuffer.Length)
            {
                var sb = GetStringBuilder();
                sb.Append(input);
                sb.Append(PaddingBuffer, 0, padCount);
                return sb.ToString();
            }
            
            // Fallback for very large padding
            return input.PadRight(totalWidth);
        }
        
        /// <summary>
        /// Build professional box drawing border
        /// </summary>
        public static string BuildBorder(int width, BorderType type)
        {
            var sb = GetStringBuilder();
            
            switch (type)
            {
                case BorderType.Top:
                    sb.Append('╔');
                    sb.Append('═', width - 2);
                    sb.Append('╗');
                    break;
                    
                case BorderType.Middle:
                    sb.Append('╠');
                    sb.Append('═', width - 2);
                    sb.Append('╣');
                    break;
                    
                case BorderType.Bottom:
                    sb.Append('╚');
                    sb.Append('═', width - 2);
                    sb.Append('╝');
                    break;
                    
                case BorderType.Separator:
                    // Excel-style column separators: PRI(3)│DUE(10)│ID1(4)│ID2(12)│TITLE(30)│TAGS(15)
                    sb.Append("───┼──────────┼────┼────────────┼──────────────────────────────┼───────────────");
                    if (width > sb.Length)
                    {
                        sb.Append('─', width - sb.Length);
                    }
                    break;
            }
            
            return sb.ToString();
        }
        
        /// <summary>
        /// Get ANSI color code for a ConsoleColor
        /// </summary>
        public static string GetAnsiColor(ConsoleColor color)
        {
            return AnsiColors.TryGetValue(color, out var ansi) ? ansi : AnsiColors[ConsoleColor.White];
        }
    }
    
    /// <summary>
    /// Border types for professional UI
    /// </summary>
    public enum BorderType
    {
        Top,
        Middle, 
        Bottom,
        Separator
    }
    
    /// <summary>
    /// Cached task display data for performance
    /// </summary>
    public class TaskDisplayCache
    {
        public string FormattedRow { get; set; }
        public DateTime LastModified { get; set; }
        public bool IsValid { get; set; }
        
        public TaskDisplayCache()
        {
            FormattedRow = "";
            LastModified = DateTime.MinValue;
            IsValid = false;
        }
    }
}