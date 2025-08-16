using System;
using System.Collections.Generic;
using System.Globalization;

namespace TaskPro.UI
{
    /// <summary>
    /// RGB color structure with hex support
    /// </summary>
    public struct RGBColor
    {
        public byte R { get; set; }
        public byte G { get; set; }
        public byte B { get; set; }
        
        public RGBColor(byte r, byte g, byte b)
        {
            R = r;
            G = g;
            B = b;
        }
        
        public RGBColor(string hex)
        {
            if (hex.StartsWith("#"))
                hex = hex.Substring(1);
                
            if (hex.Length == 6)
            {
                R = byte.Parse(hex.Substring(0, 2), NumberStyles.HexNumber);
                G = byte.Parse(hex.Substring(2, 2), NumberStyles.HexNumber);
                B = byte.Parse(hex.Substring(4, 2), NumberStyles.HexNumber);
            }
            else
            {
                R = G = B = 255; // Default to white
            }
        }
        
        public string ToHex() => $"#{R:X2}{G:X2}{B:X2}";
        
        public string ToVT100() => $"\x1b[38;2;{R};{G};{B}m";
        
        public ConsoleColor ToConsoleColor()
        {
            // Convert RGB to closest ConsoleColor for fallback
            var colors = new (ConsoleColor color, int r, int g, int b)[]
            {
                (ConsoleColor.Black, 0, 0, 0),
                (ConsoleColor.DarkRed, 128, 0, 0),
                (ConsoleColor.DarkGreen, 0, 128, 0),
                (ConsoleColor.DarkYellow, 128, 128, 0),
                (ConsoleColor.DarkBlue, 0, 0, 128),
                (ConsoleColor.DarkMagenta, 128, 0, 128),
                (ConsoleColor.DarkCyan, 0, 128, 128),
                (ConsoleColor.Gray, 192, 192, 192),
                (ConsoleColor.DarkGray, 128, 128, 128),
                (ConsoleColor.Red, 255, 0, 0),
                (ConsoleColor.Green, 0, 255, 0),
                (ConsoleColor.Yellow, 255, 255, 0),
                (ConsoleColor.Blue, 0, 0, 255),
                (ConsoleColor.Magenta, 255, 0, 255),
                (ConsoleColor.Cyan, 0, 255, 255),
                (ConsoleColor.White, 255, 255, 255)
            };
            
            var minDistance = double.MaxValue;
            var closest = ConsoleColor.White;
            
            foreach (var (color, r, g, b) in colors)
            {
                var distance = Math.Sqrt(Math.Pow(R - r, 2) + Math.Pow(G - g, 2) + Math.Pow(B - b, 2));
                if (distance < minDistance)
                {
                    minDistance = distance;
                    closest = color;
                }
            }
            
            return closest;
        }
    }
    
    /// <summary>
    /// Color theme definition with RGB support
    /// </summary>
    public class ColorTheme
    {
        public string Name { get; set; }
        public string Key { get; set; }
        public RGBColor TaskColor { get; set; }
        public RGBColor SubtaskColor { get; set; }
        public string Description { get; set; }
        
        public ColorTheme(string key, string name, RGBColor taskColor, RGBColor subtaskColor, string description = "")
        {
            Key = key;
            Name = name;
            TaskColor = taskColor;
            SubtaskColor = subtaskColor;
            Description = description;
        }
    }
    
    /// <summary>
    /// Color theme manager with predefined themes and custom color support
    /// </summary>
    public static class ColorThemeManager
    {
        private static readonly Dictionary<string, ColorTheme> predefinedThemes = new Dictionary<string, ColorTheme>
        {
            ["default"] = new ColorTheme("default", "Default", 
                new RGBColor(250, 248, 240), new RGBColor(160, 160, 160), "Standard white theme"),
                
            ["urgent"] = new ColorTheme("urgent", "Urgent", 
                new RGBColor(255, 100, 100), new RGBColor(200, 80, 80), "High priority red theme"),
                
            ["work"] = new ColorTheme("work", "Work", 
                new RGBColor(100, 150, 255), new RGBColor(80, 120, 200), "Professional blue theme"),
                
            ["personal"] = new ColorTheme("personal", "Personal", 
                new RGBColor(80, 200, 120), new RGBColor(60, 160, 100), "Personal green theme"),
                
            ["project"] = new ColorTheme("project", "Project", 
                new RGBColor(200, 120, 255), new RGBColor(160, 100, 200), "Project purple theme"),
                
            ["client"] = new ColorTheme("client", "Client", 
                new RGBColor(255, 165, 0), new RGBColor(200, 130, 0), "Client orange theme"),
                
            ["research"] = new ColorTheme("research", "Research", 
                new RGBColor(100, 200, 200), new RGBColor(80, 160, 160), "Research cyan theme"),
                
            ["meeting"] = new ColorTheme("meeting", "Meeting", 
                new RGBColor(255, 200, 100), new RGBColor(200, 160, 80), "Meeting gold theme"),
                
            ["deadline"] = new ColorTheme("deadline", "Deadline", 
                new RGBColor(255, 80, 120), new RGBColor(200, 60, 100), "Deadline hot pink theme"),
                
            ["completed"] = new ColorTheme("completed", "Completed", 
                new RGBColor(120, 120, 120), new RGBColor(90, 90, 90), "Completed gray theme")
        };
        
        public static IEnumerable<ColorTheme> GetPredefinedThemes() => predefinedThemes.Values;
        
        public static ColorTheme GetTheme(string key)
        {
            return predefinedThemes.TryGetValue(key, out var theme) ? theme : predefinedThemes["default"];
        }
        
        public static string GetNextTheme(string currentKey)
        {
            var themeOrder = new[] { "default", "urgent", "work", "personal", "project", 
                                   "client", "research", "meeting", "deadline", "completed" };
            
            var currentIndex = Array.IndexOf(themeOrder, currentKey);
            if (currentIndex == -1) currentIndex = 0;
            
            var nextIndex = (currentIndex + 1) % themeOrder.Length;
            return themeOrder[nextIndex];
        }
        
        public static string GetPreviousTheme(string currentKey)
        {
            var themeOrder = new[] { "default", "urgent", "work", "personal", "project", 
                                   "client", "research", "meeting", "deadline", "completed" };
            
            var currentIndex = Array.IndexOf(themeOrder, currentKey);
            if (currentIndex == -1) currentIndex = 0;
            
            var prevIndex = (currentIndex - 1 + themeOrder.Length) % themeOrder.Length;
            return themeOrder[prevIndex];
        }
        
        public static bool IsValidHexColor(string hex)
        {
            if (string.IsNullOrWhiteSpace(hex)) return false;
            
            if (hex.StartsWith("#"))
                hex = hex.Substring(1);
                
            return hex.Length == 6 && int.TryParse(hex, NumberStyles.HexNumber, null, out _);
        }
        
        public static RGBColor ParseColor(string input)
        {
            if (string.IsNullOrWhiteSpace(input))
                return new RGBColor(255, 255, 255);
                
            // Try hex format first
            if (input.StartsWith("#") || input.Length == 6)
            {
                try
                {
                    return new RGBColor(input);
                }
                catch
                {
                    // Fall through to RGB parsing
                }
            }
            
            // Try RGB format: "255,128,64" or "rgb(255,128,64)"
            input = input.Replace("rgb(", "").Replace(")", "").Trim();
            var parts = input.Split(',');
            
            if (parts.Length == 3 && 
                byte.TryParse(parts[0].Trim(), out byte r) &&
                byte.TryParse(parts[1].Trim(), out byte g) &&
                byte.TryParse(parts[2].Trim(), out byte b))
            {
                return new RGBColor(r, g, b);
            }
            
            // Default to white if parsing fails
            return new RGBColor(255, 255, 255);
        }
    }
}