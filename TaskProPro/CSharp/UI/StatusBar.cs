using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;

namespace TaskPro.UI
{
    /// <summary>
    /// Professional status bar with user feedback and adaptive layout
    /// </summary>
    public class StatusBar
    {
        // Configuration
        public ConsoleColor BackgroundColor { get; set; } = ConsoleColor.DarkBlue;
        public ConsoleColor ForegroundColor { get; set; } = ConsoleColor.White;
        public ConsoleColor HighlightColor { get; set; } = ConsoleColor.Yellow;
        public ConsoleColor ErrorColor { get; set; } = ConsoleColor.Red;
        public ConsoleColor SuccessColor { get; set; } = ConsoleColor.Green;
        
        // Status message system
        private string currentMessage = "";
        private ConsoleColor currentMessageColor = ConsoleColor.White;
        private DateTime messageExpiry = DateTime.MinValue;
        private const int MESSAGE_DURATION_MS = 3000; // 3 seconds
        
        // Shortcut definitions
        private readonly Dictionary<string, string> shortcuts = new Dictionary<string, string>
        {
            { "↑↓", "Navigate" },
            { "N", "New" },
            { "Enter", "Notes" },
            { "Space", "Complete" },
            { "D", "Delete" },
            { "/", "Filter" },
            { "E", "Edit Title" },
            { "P", "Priority" },
            { "U", "Due Date" },
            { "R", "Tag Editor" },
            { "T", "Theme" },
            { "Ctrl+Q", "Quit" },
            { "Ctrl+R", "Refresh" },
            { "Ctrl+↑↓", "Move" }
        };
        
        // Adaptive layout thresholds
        private const int MIN_WIDTH_FULL = 120;
        private const int MIN_WIDTH_MEDIUM = 80;
        private const int MIN_WIDTH_COMPACT = 40;
        
        /// <summary>
        /// Show a temporary status message
        /// </summary>
        public void ShowMessage(string message, MessageType type = MessageType.Info)
        {
            currentMessage = message;
            currentMessageColor = type switch
            {
                MessageType.Success => SuccessColor,
                MessageType.Error => ErrorColor,
                MessageType.Warning => HighlightColor,
                _ => ForegroundColor
            };
            messageExpiry = DateTime.Now.AddMilliseconds(MESSAGE_DURATION_MS);
        }
        
        /// <summary>
        /// Show success message
        /// </summary>
        public void ShowSuccess(string message)
        {
            ShowMessage(message, MessageType.Success);
        }
        
        /// <summary>
        /// Show error message
        /// </summary>
        public void ShowError(string message)
        {
            ShowMessage(message, MessageType.Error);
        }
        
        /// <summary>
        /// Show warning message
        /// </summary>
        public void ShowWarning(string message)
        {
            ShowMessage(message, MessageType.Warning);
        }
        
        /// <summary>
        /// Render the status bar with adaptive layout
        /// </summary>
        public void Render(ScreenBuffer screen, Rectangle bounds, StatusInfo status)
        {
            if (bounds.Height < 1) return;
            
            // Clear the status bar area
            screen.FillRect(bounds.X, bounds.Y, bounds.Width, bounds.Height, ' ', 
                          ForegroundColor, BackgroundColor);
            
            // Check for expired messages
            if (DateTime.Now > messageExpiry)
            {
                currentMessage = "";
            }
            
            // Determine layout based on width
            if (bounds.Width >= MIN_WIDTH_FULL)
            {
                RenderFullLayout(screen, bounds, status);
            }
            else if (bounds.Width >= MIN_WIDTH_MEDIUM)
            {
                RenderMediumLayout(screen, bounds, status);
            }
            else if (bounds.Width >= MIN_WIDTH_COMPACT)
            {
                RenderCompactLayout(screen, bounds, status);
            }
            else
            {
                RenderMinimalLayout(screen, bounds, status);
            }
        }
        
        /// <summary>
        /// Full layout for wide screens (120+ chars)
        /// </summary>
        private void RenderFullLayout(ScreenBuffer screen, Rectangle bounds, StatusInfo status)
        {
            var y = bounds.Y;
            
            // Top line: shortcuts
            var shortcutText = BuildShortcutText(bounds.Width - 2, false);
            screen.WriteAt(bounds.X + 1, y, shortcutText, ForegroundColor, BackgroundColor);
            
            if (bounds.Height > 1)
            {
                y++;
                // Bottom line: status info and messages
                var leftInfo = BuildStatusInfo(status, false);
                var maxInfoWidth = bounds.Width - 40; // Leave room for messages
                if (leftInfo.Length > maxInfoWidth)
                {
                    leftInfo = leftInfo.Substring(0, maxInfoWidth - 3) + "...";
                }
                
                screen.WriteAt(bounds.X + 1, y, leftInfo, ForegroundColor, BackgroundColor);
                
                // Right-align message if present
                if (!string.IsNullOrEmpty(currentMessage))
                {
                    var messageX = bounds.Right - currentMessage.Length - 1;
                    if (messageX > bounds.X + leftInfo.Length + 3)
                    {
                        screen.WriteAt(messageX, y, currentMessage, currentMessageColor, BackgroundColor);
                    }
                }
            }
        }
        
        /// <summary>
        /// Medium layout for medium screens (80-119 chars)
        /// </summary>
        private void RenderMediumLayout(ScreenBuffer screen, Rectangle bounds, StatusInfo status)
        {
            var y = bounds.Y;
            
            if (!string.IsNullOrEmpty(currentMessage))
            {
                // Show message first if present
                var messageText = TruncateToFit(currentMessage, bounds.Width - 2);
                screen.WriteAt(bounds.X + 1, y, messageText, currentMessageColor, BackgroundColor);
            }
            else
            {
                // Show essential shortcuts
                var shortcutText = BuildShortcutText(bounds.Width - 2, true);
                screen.WriteAt(bounds.X + 1, y, shortcutText, ForegroundColor, BackgroundColor);
            }
            
            if (bounds.Height > 1)
            {
                y++;
                // Status info
                var statusText = BuildStatusInfo(status, true);
                statusText = TruncateToFit(statusText, bounds.Width - 2);
                screen.WriteAt(bounds.X + 1, y, statusText, ForegroundColor, BackgroundColor);
            }
        }
        
        /// <summary>
        /// Compact layout for small screens (40-79 chars)
        /// </summary>
        private void RenderCompactLayout(ScreenBuffer screen, Rectangle bounds, StatusInfo status)
        {
            var y = bounds.Y;
            
            if (!string.IsNullOrEmpty(currentMessage))
            {
                // Message takes priority
                var messageText = TruncateToFit(currentMessage, bounds.Width - 2);
                screen.WriteAt(bounds.X + 1, y, messageText, currentMessageColor, BackgroundColor);
            }
            else
            {
                // Show only critical shortcuts
                var essentialShortcuts = "N:New | Space:Toggle | D:Del | Ctrl+Q:Quit";
                essentialShortcuts = TruncateToFit(essentialShortcuts, bounds.Width - 2);
                screen.WriteAt(bounds.X + 1, y, essentialShortcuts, ForegroundColor, BackgroundColor);
            }
        }
        
        /// <summary>
        /// Minimal layout for very small screens (< 40 chars)
        /// </summary>
        private void RenderMinimalLayout(ScreenBuffer screen, Rectangle bounds, StatusInfo status)
        {
            if (!string.IsNullOrEmpty(currentMessage))
            {
                var messageText = TruncateToFit(currentMessage, bounds.Width - 2);
                screen.WriteAt(bounds.X + 1, bounds.Y, messageText, currentMessageColor, BackgroundColor);
            }
            else if (status.TaskCount > 0)
            {
                var countText = $"{status.SelectedIndex + 1}/{status.TaskCount}";
                if (countText.Length <= bounds.Width - 2)
                {
                    screen.WriteAt(bounds.X + 1, bounds.Y, countText, ForegroundColor, BackgroundColor);
                }
            }
        }
        
        /// <summary>
        /// Build shortcut text for display
        /// </summary>
        private string BuildShortcutText(int maxWidth, bool essential)
        {
            var selectedShortcuts = essential ? 
                new[] { "↑↓:Navigate", "E:Edit", "Space:Complete", "D:Delete", "Ctrl+Q:Quit" } :
                shortcuts.Select(kvp => $"{kvp.Key}:{kvp.Value}").ToArray();
            
            var result = string.Join(" | ", selectedShortcuts);
            
            if (result.Length > maxWidth)
            {
                // Try to fit as many as possible
                var parts = selectedShortcuts.ToList();
                while (parts.Count > 1 && string.Join(" | ", parts).Length > maxWidth)
                {
                    parts.RemoveAt(parts.Count - 1);
                }
                result = string.Join(" | ", parts);
                
                if (result.Length > maxWidth)
                {
                    result = result.Substring(0, maxWidth - 3) + "...";
                }
            }
            
            return result;
        }
        
        /// <summary>
        /// Build status information text
        /// </summary>
        private string BuildStatusInfo(StatusInfo status, bool compact)
        {
            var parts = new List<string>();
            
            // Task count and selection
            if (status.TaskCount > 0)
            {
                parts.Add($"Tasks: {status.SelectedIndex + 1}/{status.TaskCount}");
                
                if (!compact)
                {
                    // Additional info for full layout
                    if (status.CompletedCount > 0)
                    {
                        parts.Add($"Done: {status.CompletedCount}");
                    }
                    
                    if (!string.IsNullOrEmpty(status.FilterText) && status.FilterText != "All")
                    {
                        parts.Add($"Filter: {status.FilterText}");
                    }
                    
                    if (status.HasDueTasks)
                    {
                        parts.Add("⚠ Due tasks");
                    }
                }
            }
            else
            {
                parts.Add("No tasks");
            }
            
            return string.Join(" | ", parts);
        }
        
        /// <summary>
        /// Truncate text to fit within specified width
        /// </summary>
        private string TruncateToFit(string text, int maxWidth)
        {
            if (text.Length <= maxWidth) return text;
            return text.Substring(0, maxWidth - 3) + "...";
        }
        
        /// <summary>
        /// Check if there are active messages
        /// </summary>
        public bool HasActiveMessage => !string.IsNullOrEmpty(currentMessage) && DateTime.Now <= messageExpiry;
    }
    
    /// <summary>
    /// Status information for the status bar
    /// </summary>
    public class StatusInfo
    {
        public int TaskCount { get; set; }
        public int SelectedIndex { get; set; }
        public int CompletedCount { get; set; }
        public string FilterText { get; set; } = "All";
        public bool HasDueTasks { get; set; }
        public string CurrentMode { get; set; } = "Normal";
    }
    
    /// <summary>
    /// Types of status messages
    /// </summary>
    public enum MessageType
    {
        Info,
        Success,
        Warning,
        Error
    }
}