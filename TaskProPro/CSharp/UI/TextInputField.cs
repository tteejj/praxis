using System;
using System.Text;
using TaskPro.Core;

namespace TaskPro.UI
{
    /// <summary>
    /// Professional text input field with cursor positioning, selection, and Ctrl shortcuts
    /// </summary>
    public class TextInputField
    {
        private StringBuilder text = new StringBuilder();
        private int cursorPos = 0;
        private int selectionStart = -1;
        private int selectionEnd = -1;
        private int scrollOffset = 0;
        
        public string Text 
        { 
            get => text.ToString(); 
            set 
            { 
                text.Clear();
                text.Append(value ?? "");
                cursorPos = Math.Min(cursorPos, text.Length);
                ClearSelection();
            }
        }
        
        public int CursorPosition 
        { 
            get => cursorPos; 
            set => cursorPos = Math.Max(0, Math.Min(text.Length, value)); 
        }
        
        public bool HasSelection => selectionStart >= 0 && selectionEnd >= 0 && selectionStart != selectionEnd;
        public string SelectedText => HasSelection ? text.ToString(Math.Min(selectionStart, selectionEnd), 
                                                    Math.Abs(selectionEnd - selectionStart)) : "";
        
        public bool IsFocused { get; set; } = false;
        public int MaxLength { get; set; } = int.MaxValue;
        public bool ReadOnly { get; set; } = false;
        public string Placeholder { get; set; } = "";
        
        // Events
        public event Action<string> TextChanged;
        public event Action<string> EnterPressed;
        public event Action EscapePressed;
        public event Action TabPressed;
        
        /// <summary>
        /// Handle input and return true if input was consumed
        /// </summary>
        public bool HandleInput(InputEvent input)
        {
            if (ReadOnly && !input.IsArrowLeft && !input.IsArrowRight && !input.IsHome && !input.IsEnd) 
                return false;
            
            bool textModified = false;
            
            // Handle special keys first
            if (input.IsEnter)
            {
                EnterPressed?.Invoke(Text);
                return true;
            }
            
            if (input.IsEscape)
            {
                EscapePressed?.Invoke();
                return true;
            }
            
            if (input.IsTab)
            {
                TabPressed?.Invoke();
                return true;
            }
            
            // Selection shortcuts
            if (input.IsCtrlA)
            {
                SelectAll();
                return true;
            }
            
            // Copy/Paste shortcuts
            if (input.IsCtrlC && HasSelection)
            {
                // In a real implementation, you'd copy to clipboard
                // For now, just handle the input
                return true;
            }
            
            if (input.IsCtrlV && !ReadOnly)
            {
                // In a real implementation, you'd paste from clipboard
                // For now, just handle the input
                return true;
            }
            
            if (input.IsCtrlX && HasSelection && !ReadOnly)
            {
                // Cut to clipboard
                DeleteSelection();
                textModified = true;
            }
            
            // Navigation with selection
            if (input.IsShiftArrowLeft)
            {
                ExtendSelectionLeft();
                return true;
            }
            
            if (input.IsShiftArrowRight)
            {
                ExtendSelectionRight();
                return true;
            }
            
            if (input.IsShiftHome)
            {
                ExtendSelectionToStart();
                return true;
            }
            
            if (input.IsShiftEnd)
            {
                ExtendSelectionToEnd();
                return true;
            }
            
            // Navigation without selection (clears selection)
            if (input.IsArrowLeft)
            {
                if (HasSelection)
                {
                    cursorPos = Math.Min(selectionStart, selectionEnd);
                    ClearSelection();
                }
                else
                {
                    cursorPos = Math.Max(0, cursorPos - 1);
                }
                return true;
            }
            
            if (input.IsArrowRight)
            {
                if (HasSelection)
                {
                    cursorPos = Math.Max(selectionStart, selectionEnd);
                    ClearSelection();
                }
                else
                {
                    cursorPos = Math.Min(text.Length, cursorPos + 1);
                }
                return true;
            }
            
            if (input.IsHome)
            {
                cursorPos = 0;
                ClearSelection();
                return true;
            }
            
            if (input.IsEnd)
            {
                cursorPos = text.Length;
                ClearSelection();
                return true;
            }
            
            // Word navigation with Ctrl
            if (input.IsCtrlArrowLeft)
            {
                MoveToPreviousWord();
                ClearSelection();
                return true;
            }
            
            if (input.IsCtrlArrowRight)
            {
                MoveToNextWord();
                ClearSelection();
                return true;
            }
            
            if (ReadOnly) return false; // Stop here for read-only fields
            
            // Text modification
            if (input.IsBackspace)
            {
                if (HasSelection)
                {
                    DeleteSelection();
                }
                else if (cursorPos > 0)
                {
                    text.Remove(cursorPos - 1, 1);
                    cursorPos--;
                }
                textModified = true;
            }
            else if (input.IsDelete)
            {
                if (HasSelection)
                {
                    DeleteSelection();
                }
                else if (cursorPos < text.Length)
                {
                    text.Remove(cursorPos, 1);
                }
                textModified = true;
            }
            else if (input.IsPrintableChar && text.Length < MaxLength)
            {
                if (HasSelection)
                {
                    DeleteSelection();
                }
                
                text.Insert(cursorPos, input.Char);
                cursorPos++;
                textModified = true;
            }
            
            if (textModified)
            {
                TextChanged?.Invoke(Text);
            }
            
            return true;
        }
        
        /// <summary>
        /// Render the text field to screen buffer with CYBERPUNK aesthetic
        /// </summary>
        public void Render(ScreenBuffer screen, Rectangle bounds, ConsoleColor normalColor = ConsoleColor.White, 
                          ConsoleColor focusedColor = ConsoleColor.Yellow)
        {
            var displayText = GetDisplayText(bounds.Width - 2); // Account for brackets
            
            // CYBERPUNK STYLING
            var borderColor = IsFocused ? ConsoleColor.Cyan : ConsoleColor.DarkGray;
            var textColor = IsFocused ? ConsoleColor.Yellow : ConsoleColor.White;
            var bgColor = ConsoleColor.Black;
            
            // Draw cyberpunk field borders
            screen.WriteAt(bounds.X, bounds.Y, "[", borderColor, bgColor);
            screen.WriteAt(bounds.X + bounds.Width - 1, bounds.Y, "]", borderColor, bgColor);
            
            // Clear the field content area
            screen.FillRect(bounds.X + 1, bounds.Y, bounds.Width - 2, 1, ' ', textColor, bgColor);
            
            // Render text with cyberpunk styling
            if (!string.IsNullOrEmpty(displayText))
            {
                screen.WriteAt(bounds.X + 1, bounds.Y, displayText, textColor, bgColor);
            }
            else if (!string.IsNullOrEmpty(Placeholder) && !IsFocused)
            {
                var placeholderText = Placeholder.Length > bounds.Width - 2 ? 
                                    Placeholder.Substring(0, bounds.Width - 2) : Placeholder;
                screen.WriteAt(bounds.X + 1, bounds.Y, placeholderText, ConsoleColor.DarkGray, bgColor);
            }
            
            // Render selection highlight with cyberpunk colors
            if (HasSelection && IsFocused)
            {
                RenderCyberpunkSelection(screen, bounds, displayText);
            }
            
            // Show cyberpunk cursor with blinking effect
            if (IsFocused)
            {
                var cursorX = bounds.X + 1 + GetVisibleCursorPosition(bounds.Width - 2);
                if (cursorX >= bounds.X + 1 && cursorX < bounds.X + bounds.Width - 1)
                {
                    // Cyberpunk cursor - use block character for classic terminal feel
                    var isBlinking = (DateTime.Now.Millisecond / 500) % 2 == 0;
                    if (isBlinking)
                    {
                        var cursorChar = cursorPos < text.Length ? text[cursorPos] : ' ';
                        screen.WriteAt(cursorX, bounds.Y, cursorChar.ToString(), ConsoleColor.Black, ConsoleColor.Cyan);
                    }
                }
            }
        }
        
        private string GetDisplayText(int width)
        {
            if (text.Length == 0) return "";
            
            // Calculate scroll offset to keep cursor visible
            if (cursorPos < scrollOffset)
            {
                scrollOffset = cursorPos;
            }
            else if (cursorPos >= scrollOffset + width)
            {
                scrollOffset = cursorPos - width + 1;
            }
            
            // Get visible portion of text
            if (scrollOffset >= text.Length) return "";
            
            var visibleLength = Math.Min(width, text.Length - scrollOffset);
            return text.ToString(scrollOffset, visibleLength);
        }
        
        private int GetVisibleCursorPosition(int width)
        {
            return Math.Min(width - 1, Math.Max(0, cursorPos - scrollOffset));
        }
        
        private void RenderSelection(ScreenBuffer screen, Rectangle bounds, string displayText)
        {
            if (!HasSelection) return;
            
            var visSelStart = Math.Max(0, Math.Min(selectionStart, selectionEnd) - scrollOffset);
            var visSelEnd = Math.Min(displayText.Length, Math.Max(selectionStart, selectionEnd) - scrollOffset);
            
            if (visSelStart < displayText.Length && visSelEnd > 0)
            {
                var selLength = visSelEnd - visSelStart;
                var selText = displayText.Substring(visSelStart, selLength);
                screen.WriteAt(bounds.X + visSelStart, bounds.Y, selText, 
                             ConsoleColor.White, ConsoleColor.Blue);
            }
        }
        
        private void RenderCyberpunkSelection(ScreenBuffer screen, Rectangle bounds, string displayText)
        {
            if (!HasSelection) return;
            
            var visSelStart = Math.Max(0, Math.Min(selectionStart, selectionEnd) - scrollOffset);
            var visSelEnd = Math.Min(displayText.Length, Math.Max(selectionStart, selectionEnd) - scrollOffset);
            
            if (visSelStart < displayText.Length && visSelEnd > 0)
            {
                var selLength = visSelEnd - visSelStart;
                var selText = displayText.Substring(visSelStart, selLength);
                // Cyberpunk selection: bright text on dark cyan background
                screen.WriteAt(bounds.X + 1 + visSelStart, bounds.Y, selText, 
                             ConsoleColor.Yellow, ConsoleColor.DarkCyan);
            }
        }
        
        private void SelectAll()
        {
            if (text.Length > 0)
            {
                selectionStart = 0;
                selectionEnd = text.Length;
                cursorPos = text.Length;
            }
        }
        
        private void ClearSelection()
        {
            selectionStart = -1;
            selectionEnd = -1;
        }
        
        private void ExtendSelectionLeft()
        {
            if (!HasSelection)
            {
                selectionStart = cursorPos;
                selectionEnd = cursorPos;
            }
            
            cursorPos = Math.Max(0, cursorPos - 1);
            selectionEnd = cursorPos;
        }
        
        private void ExtendSelectionRight()
        {
            if (!HasSelection)
            {
                selectionStart = cursorPos;
                selectionEnd = cursorPos;
            }
            
            cursorPos = Math.Min(text.Length, cursorPos + 1);
            selectionEnd = cursorPos;
        }
        
        private void ExtendSelectionToStart()
        {
            if (!HasSelection)
            {
                selectionStart = cursorPos;
            }
            cursorPos = 0;
            selectionEnd = cursorPos;
        }
        
        private void ExtendSelectionToEnd()
        {
            if (!HasSelection)
            {
                selectionStart = cursorPos;
            }
            cursorPos = text.Length;
            selectionEnd = cursorPos;
        }
        
        private void DeleteSelection()
        {
            if (!HasSelection) return;
            
            var start = Math.Min(selectionStart, selectionEnd);
            var length = Math.Abs(selectionEnd - selectionStart);
            
            text.Remove(start, length);
            cursorPos = start;
            ClearSelection();
        }
        
        private void MoveToPreviousWord()
        {
            if (cursorPos == 0) return;
            
            var pos = cursorPos - 1;
            
            // Skip whitespace
            while (pos > 0 && char.IsWhiteSpace(text[pos]))
            {
                pos--;
            }
            
            // Skip word characters
            while (pos > 0 && !char.IsWhiteSpace(text[pos - 1]))
            {
                pos--;
            }
            
            cursorPos = pos;
        }
        
        private void MoveToNextWord()
        {
            if (cursorPos >= text.Length) return;
            
            var pos = cursorPos;
            
            // Skip current word
            while (pos < text.Length && !char.IsWhiteSpace(text[pos]))
            {
                pos++;
            }
            
            // Skip whitespace
            while (pos < text.Length && char.IsWhiteSpace(text[pos]))
            {
                pos++;
            }
            
            cursorPos = pos;
        }
    }
}