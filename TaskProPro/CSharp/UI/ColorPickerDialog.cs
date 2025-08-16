using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI
{
    /// <summary>
    /// Professional color picker with RGB/hex support and theme selection
    /// EXACT feature parity with standalone + enhanced capabilities
    /// </summary>
    public class ColorPickerDialog
    {
        // Configuration
        public ConsoleColor DialogColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor BackgroundColor { get; set; } = ConsoleColor.DarkBlue;
        public ConsoleColor TextColor { get; set; } = ConsoleColor.White;
        public ConsoleColor HighlightColor { get; set; } = ConsoleColor.Yellow;
        public ConsoleColor InputColor { get; set; } = ConsoleColor.White;
        public ConsoleColor InputBackground { get; set; } = ConsoleColor.DarkGray;
        public ConsoleColor PreviewBackground { get; set; } = ConsoleColor.Black;
        public ConsoleColor ErrorColor { get; set; } = ConsoleColor.Red;
        public ConsoleColor HintColor { get; set; } = ConsoleColor.DarkGray;
        
        // State
        private bool isActive = false;
        private SimpleTask currentTask = null;
        private string selectedMode = "theme"; // "theme", "custom", "rgb", "hex"
        private int selectedThemeIndex = 0;
        private string customInput = "";
        private int customInputCursor = 0;
        private RGBColor previewColor = new RGBColor(255, 255, 255);
        private string errorMessage = "";
        private DateTime errorExpiry = DateTime.MinValue;
        
        // RGB sliders
        private int rgbComponent = 0; // 0=R, 1=G, 2=B
        private byte[] rgbValues = new byte[] { 255, 255, 255 };
        
        // Events
        public event Action<SimpleTask> TaskColorUpdated;
        public event Action DialogClosed;
        public event Action<string> StatusMessage;
        
        public bool IsActive => isActive;
        public SimpleTask CurrentTask => currentTask;
        
        /// <summary>
        /// Start color picker for a task
        /// </summary>
        public bool StartColorPicker(SimpleTask task)
        {
            if (task == null) return false;
            
            currentTask = task;
            isActive = true;
            selectedMode = "theme";
            selectedThemeIndex = 0;
            customInput = "";
            customInputCursor = 0;
            errorMessage = "";
            rgbComponent = 0;
            
            // Initialize with current task color if it has a custom color
            if (!string.IsNullOrEmpty(task.CustomColor))
            {
                try
                {
                    previewColor = ColorThemeManager.ParseColor(task.CustomColor);
                    rgbValues[0] = previewColor.R;
                    rgbValues[1] = previewColor.G;
                    rgbValues[2] = previewColor.B;
                    customInput = previewColor.ToHex();
                }
                catch
                {
                    previewColor = new RGBColor(255, 255, 255);
                }
            }
            else
            {
                // Initialize with theme color
                var theme = ColorThemeManager.GetTheme(task.ColorTheme);
                previewColor = theme.TaskColor;
                rgbValues[0] = previewColor.R;
                rgbValues[1] = previewColor.G;
                rgbValues[2] = previewColor.B;
            }
            
            StatusMessage?.Invoke("Color Picker - Choose theme or custom color");
            return true;
        }
        
        /// <summary>
        /// Cancel color picker
        /// </summary>
        public void CancelPicker()
        {
            if (!isActive) return;
            
            isActive = false;
            currentTask = null;
            selectedMode = "theme";
            customInput = "";
            errorMessage = "";
            
            DialogClosed?.Invoke();
            StatusMessage?.Invoke("Color picker cancelled");
        }
        
        /// <summary>
        /// Apply selected color to task
        /// </summary>
        public bool ApplyColor()
        {
            if (!isActive || currentTask == null) return false;
            
            try
            {
                if (selectedMode == "theme")
                {
                    // Apply predefined theme
                    var themes = ColorThemeManager.GetPredefinedThemes().ToList();
                    if (selectedThemeIndex >= 0 && selectedThemeIndex < themes.Count)
                    {
                        var theme = themes[selectedThemeIndex];
                        currentTask.ColorTheme = theme.Key;
                        currentTask.CustomColor = ""; // Clear custom color
                        previewColor = theme.TaskColor;
                    }
                }
                else
                {
                    // Apply custom color
                    if (selectedMode == "rgb")
                    {
                        previewColor = new RGBColor(rgbValues[0], rgbValues[1], rgbValues[2]);
                    }
                    else if (selectedMode == "hex" || selectedMode == "custom")
                    {
                        if (!string.IsNullOrWhiteSpace(customInput))
                        {
                            previewColor = ColorThemeManager.ParseColor(customInput);
                        }
                    }
                    
                    currentTask.CustomColor = previewColor.ToHex();
                    currentTask.ColorTheme = "custom"; // Mark as custom colored
                }
                
                currentTask.Touch();
                
                // Complete picker
                isActive = false;
                var editedTask = currentTask;
                currentTask = null;
                
                TaskColorUpdated?.Invoke(editedTask);
                StatusMessage?.Invoke($"Color applied to '{editedTask.Title}'");
                return true;
            }
            catch (Exception ex)
            {
                ShowError($"Apply failed: {ex.Message}");
                return false;
            }
        }
        
        /// <summary>
        /// Handle input for color picker
        /// </summary>
        public bool HandleInput(InputEvent input)
        {
            if (!isActive) return false;
            
            // Clear expired errors
            if (DateTime.Now > errorExpiry)
            {
                errorMessage = "";
            }
            
            // Global keys
            if (input.IsEscape)
            {
                CancelPicker();
                return true;
            }
            
            if (input.IsEnter)
            {
                ApplyColor();
                return true;
            }
            
            // Mode switching
            if (input.Key == ConsoleKey.Tab)
            {
                CycleModes();
                return true;
            }
            
            // Mode-specific input handling
            switch (selectedMode)
            {
                case "theme":
                    return HandleThemeInput(input);
                case "custom":
                case "hex":
                    return HandleCustomInput(input);
                case "rgb":
                    return HandleRGBInput(input);
                default:
                    return false;
            }
        }
        
        /// <summary>
        /// Render the color picker dialog
        /// </summary>
        public void Render(ScreenBuffer screen, Rectangle bounds)
        {
            if (!isActive) return;
            
            // Calculate dialog area
            var dialogWidth = Math.Min(bounds.Width - 4, 80);
            var dialogHeight = Math.Min(bounds.Height - 4, 25);
            var x = bounds.X + (bounds.Width - dialogWidth) / 2;
            var y = bounds.Y + (bounds.Height - dialogHeight) / 2;
            
            // Clear and draw background
            screen.FillRect(x, y, dialogWidth, dialogHeight, ' ', TextColor, BackgroundColor);
            
            // Draw border
            DrawBorder(screen, x, y, dialogWidth, dialogHeight);
            
            // Draw title
            var title = $" Color Picker - {currentTask?.Title ?? "Unknown"} ";
            var titleX = x + (dialogWidth - title.Length) / 2;
            screen.WriteAt(titleX, y, title, DialogColor, BackgroundColor);
            
            var contentY = y + 2;
            var contentWidth = dialogWidth - 4;
            var contentX = x + 2;
            
            // Draw mode tabs
            contentY = DrawModeTabs(screen, contentX, contentY, contentWidth);
            contentY++;
            
            // Draw mode-specific content
            switch (selectedMode)
            {
                case "theme":
                    contentY = DrawThemeSelector(screen, contentX, contentY, contentWidth);
                    break;
                case "custom":
                case "hex":
                    contentY = DrawCustomInput(screen, contentX, contentY, contentWidth);
                    break;
                case "rgb":
                    contentY = DrawRGBSliders(screen, contentX, contentY, contentWidth);
                    break;
            }
            
            contentY++;
            
            // Draw color preview
            contentY = DrawColorPreview(screen, contentX, contentY, contentWidth);
            contentY++;
            
            // Draw help/error at bottom
            var helpY = y + dialogHeight - 2;
            if (!string.IsNullOrEmpty(errorMessage))
            {
                var errorText = TruncateToFit(errorMessage, contentWidth);
                screen.WriteAt(contentX, helpY, errorText, ErrorColor, BackgroundColor);
            }
            else
            {
                var help = "Tab: Switch mode | Enter: Apply | ESC: Cancel | ↑↓: Navigate";
                var helpText = TruncateToFit(help, contentWidth);
                screen.WriteAt(contentX, helpY, helpText, HintColor, BackgroundColor);
            }
        }
        
        // Private helper methods
        private void CycleModes()
        {
            var modes = new[] { "theme", "custom", "rgb" };
            var currentIndex = Array.IndexOf(modes, selectedMode);
            var nextIndex = (currentIndex + 1) % modes.Length;
            selectedMode = modes[nextIndex];
            
            StatusMessage?.Invoke($"Mode: {selectedMode.ToUpper()}");
        }
        
        private bool HandleThemeInput(InputEvent input)
        {
            var themes = ColorThemeManager.GetPredefinedThemes().ToList();
            
            if (input.IsArrowUp && selectedThemeIndex > 0)
            {
                selectedThemeIndex--;
                UpdatePreviewFromTheme();
                return true;
            }
            
            if (input.IsArrowDown && selectedThemeIndex < themes.Count - 1)
            {
                selectedThemeIndex++;
                UpdatePreviewFromTheme();
                return true;
            }
            
            return false;
        }
        
        private bool HandleCustomInput(InputEvent input)
        {
            if (input.IsBackspace && customInputCursor > 0)
            {
                customInput = customInput.Remove(customInputCursor - 1, 1);
                customInputCursor--;
                UpdatePreviewFromCustom();
                return true;
            }
            
            if (input.IsDelete && customInputCursor < customInput.Length)
            {
                customInput = customInput.Remove(customInputCursor, 1);
                UpdatePreviewFromCustom();
                return true;
            }
            
            if (input.IsArrowLeft && customInputCursor > 0)
            {
                customInputCursor--;
                return true;
            }
            
            if (input.IsArrowRight && customInputCursor < customInput.Length)
            {
                customInputCursor++;
                return true;
            }
            
            if (input.IsHome)
            {
                customInputCursor = 0;
                return true;
            }
            
            if (input.IsEnd)
            {
                customInputCursor = customInput.Length;
                return true;
            }
            
            if (input.IsPrintableChar && customInput.Length < 20)
            {
                customInput = customInput.Insert(customInputCursor, input.Char.ToString());
                customInputCursor++;
                UpdatePreviewFromCustom();
                return true;
            }
            
            return false;
        }
        
        private bool HandleRGBInput(InputEvent input)
        {
            if (input.IsArrowLeft && rgbComponent > 0)
            {
                rgbComponent--;
                return true;
            }
            
            if (input.IsArrowRight && rgbComponent < 2)
            {
                rgbComponent++;
                return true;
            }
            
            if (input.IsArrowUp)
            {
                if (rgbValues[rgbComponent] < 255)
                {
                    rgbValues[rgbComponent] = (byte)Math.Min(255, rgbValues[rgbComponent] + 5);
                    UpdatePreviewFromRGB();
                }
                return true;
            }
            
            if (input.IsArrowDown)
            {
                if (rgbValues[rgbComponent] > 0)
                {
                    rgbValues[rgbComponent] = (byte)Math.Max(0, rgbValues[rgbComponent] - 5);
                    UpdatePreviewFromRGB();
                }
                return true;
            }
            
            if (input.IsPageUp)
            {
                rgbValues[rgbComponent] = (byte)Math.Min(255, rgbValues[rgbComponent] + 25);
                UpdatePreviewFromRGB();
                return true;
            }
            
            if (input.IsPageDown)
            {
                rgbValues[rgbComponent] = (byte)Math.Max(0, rgbValues[rgbComponent] - 25);
                UpdatePreviewFromRGB();
                return true;
            }
            
            return false;
        }
        
        private void UpdatePreviewFromTheme()
        {
            var themes = ColorThemeManager.GetPredefinedThemes().ToList();
            if (selectedThemeIndex >= 0 && selectedThemeIndex < themes.Count)
            {
                previewColor = themes[selectedThemeIndex].TaskColor;
            }
        }
        
        private void UpdatePreviewFromCustom()
        {
            try
            {
                if (!string.IsNullOrWhiteSpace(customInput))
                {
                    previewColor = ColorThemeManager.ParseColor(customInput);
                    errorMessage = "";
                }
            }
            catch (Exception ex)
            {
                ShowError($"Invalid color: {ex.Message}");
            }
        }
        
        private void UpdatePreviewFromRGB()
        {
            previewColor = new RGBColor(rgbValues[0], rgbValues[1], rgbValues[2]);
        }
        
        private int DrawModeTabs(ScreenBuffer screen, int x, int y, int width)
        {
            var modes = new[] { "Theme", "Custom", "RGB" };
            var modeKeys = new[] { "theme", "custom", "rgb" };
            var tabWidth = width / modes.Length;
            
            for (int i = 0; i < modes.Length; i++)
            {
                var tabX = x + i * tabWidth;
                var isSelected = modeKeys[i] == selectedMode;
                var tabColor = isSelected ? HighlightColor : TextColor;
                var tabBg = isSelected ? ConsoleColor.DarkGray : BackgroundColor;
                
                var tabText = $" {modes[i]} ".PadRight(tabWidth);
                screen.WriteAt(tabX, y, tabText, tabColor, tabBg);
            }
            
            return y;
        }
        
        private int DrawThemeSelector(ScreenBuffer screen, int x, int y, int width)
        {
            screen.WriteAt(x, y, "Select Theme:", TextColor, BackgroundColor);
            y++;
            
            var themes = ColorThemeManager.GetPredefinedThemes().ToList();
            var maxVisible = 8;
            var startIndex = Math.Max(0, selectedThemeIndex - maxVisible / 2);
            var endIndex = Math.Min(themes.Count, startIndex + maxVisible);
            
            for (int i = startIndex; i < endIndex; i++)
            {
                var theme = themes[i];
                var isSelected = i == selectedThemeIndex;
                var prefix = isSelected ? "► " : "  ";
                var color = isSelected ? HighlightColor : TextColor;
                var bg = isSelected ? ConsoleColor.DarkGray : BackgroundColor;
                
                var text = $"{prefix}{theme.Name} - {theme.Description}";
                var displayText = TruncateToFit(text, width);
                
                screen.WriteAt(x, y, displayText.PadRight(width), color, bg);
                y++;
            }
            
            return y;
        }
        
        private int DrawCustomInput(ScreenBuffer screen, int x, int y, int width)
        {
            screen.WriteAt(x, y, "Enter color (hex #FF0080 or rgb 255,0,128):", TextColor, BackgroundColor);
            y++;
            
            // Input field
            var fieldWidth = Math.Min(width - 2, 30);
            screen.FillRect(x, y, fieldWidth, 1, ' ', InputColor, InputBackground);
            
            var displayText = customInput;
            if (displayText.Length > fieldWidth - 2)
            {
                displayText = displayText.Substring(0, fieldWidth - 5) + "...";
            }
            
            screen.WriteAt(x + 1, y, displayText, InputColor, InputBackground);
            
            // Cursor
            if (customInputCursor <= displayText.Length)
            {
                var cursorChar = customInputCursor < displayText.Length ? displayText[customInputCursor] : ' ';
                screen.WriteAt(x + 1 + customInputCursor, y, cursorChar.ToString(), InputBackground, InputColor);
            }
            
            return y;
        }
        
        private int DrawRGBSliders(ScreenBuffer screen, int x, int y, int width)
        {
            screen.WriteAt(x, y, "RGB Values (←→ to switch, ↑↓ to adjust):", TextColor, BackgroundColor);
            y++;
            
            var components = new[] { "Red", "Green", "Blue" };
            var sliderWidth = Math.Min(width - 20, 30);
            
            for (int i = 0; i < 3; i++)
            {
                var isSelected = i == rgbComponent;
                var color = isSelected ? HighlightColor : TextColor;
                var bg = isSelected ? ConsoleColor.DarkGray : BackgroundColor;
                
                var label = $"{components[i]}:".PadRight(8);
                var value = rgbValues[i].ToString().PadLeft(3);
                
                screen.WriteAt(x, y, label, color, bg);
                screen.WriteAt(x + 8, y, value, color, bg);
                
                // Slider bar
                var barX = x + 12;
                var barLength = sliderWidth;
                var fillLength = (int)((rgbValues[i] / 255.0) * barLength);
                
                // Background bar
                screen.FillRect(barX, y, barLength, 1, '░', TextColor, BackgroundColor);
                
                // Fill bar
                if (fillLength > 0)
                {
                    screen.FillRect(barX, y, fillLength, 1, '█', color, BackgroundColor);
                }
                
                y++;
            }
            
            return y;
        }
        
        private int DrawColorPreview(ScreenBuffer screen, int x, int y, int width)
        {
            screen.WriteAt(x, y, "Preview:", TextColor, BackgroundColor);
            y++;
            
            // Color preview box
            var previewWidth = Math.Min(width, 40);
            var previewHeight = 3;
            
            screen.FillRect(x, y, previewWidth, previewHeight, ' ', TextColor, PreviewBackground);
            
            // Preview text with color
            var colorText = $"Sample Text #{previewColor.ToHex()}";
            var previewFg = previewColor.ToConsoleColor();
            
            screen.WriteAt(x + 2, y + 1, colorText, previewFg, PreviewBackground);
            
            // RGB values
            var rgbText = $"RGB({previewColor.R}, {previewColor.G}, {previewColor.B})";
            screen.WriteAt(x + 2, y + 2, rgbText, TextColor, PreviewBackground);
            
            return y + previewHeight;
        }
        
        private void DrawBorder(ScreenBuffer screen, int x, int y, int width, int height)
        {
            // Top border
            screen.WriteAt(x, y, "╭" + new string('─', width - 2) + "╮", DialogColor);
            
            // Side borders
            for (int i = 1; i < height - 1; i++)
            {
                screen.WriteAt(x, y + i, "│", DialogColor);
                screen.WriteAt(x + width - 1, y + i, "│", DialogColor);
            }
            
            // Bottom border  
            screen.WriteAt(x, y + height - 1, "╰" + new string('─', width - 2) + "╯", DialogColor);
        }
        
        private void ShowError(string message)
        {
            errorMessage = message;
            errorExpiry = DateTime.Now.AddMilliseconds(3000);
        }
        
        private string TruncateToFit(string text, int maxWidth)
        {
            if (text.Length <= maxWidth) return text;
            return text.Substring(0, maxWidth - 3) + "...";
        }
    }
}