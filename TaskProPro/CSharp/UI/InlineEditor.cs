using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI
{
    /// <summary>
    /// Professional inline editing system for task properties
    /// </summary>
    public class InlineEditor
    {
        // Configuration
        public ConsoleColor EditBackgroundColor { get; set; } = ConsoleColor.DarkBlue;
        public ConsoleColor EditForegroundColor { get; set; } = ConsoleColor.White;
        public ConsoleColor CursorColor { get; set; } = ConsoleColor.Yellow;
        public ConsoleColor PromptColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor ErrorColor { get; set; } = ConsoleColor.Red;
        public ConsoleColor HintColor { get; set; } = ConsoleColor.DarkGray;
        
        // State
        private bool isActive = false;
        private EditMode currentMode = EditMode.None;
        private string editBuffer = "";
        private int cursorPosition = 0;
        private SimpleTask currentTask = null;
        private string errorMessage = "";
        private DateTime errorExpiry = DateTime.MinValue;
        
        // Events
        public event Action<SimpleTask> TaskUpdated;
        public event Action EditCancelled;
        public event Action<string> StatusMessage;
        
        public bool IsActive => isActive;
        public EditMode CurrentMode => currentMode;
        
        /// <summary>
        /// Start editing a task property
        /// </summary>
        public bool StartEdit(SimpleTask task, EditMode mode)
        {
            if (task == null) return false;
            
            currentTask = task;
            currentMode = mode;
            isActive = true;
            cursorPosition = 0;
            errorMessage = "";
            
            // Initialize edit buffer based on mode
            editBuffer = mode switch
            {
                EditMode.Title => task.Title,
                EditMode.Priority => GetPriorityText(task.Priority),
                EditMode.DueDate => FormatDueDateForEdit(task.DueDate),
                EditMode.Tags => string.Join(", ", task.Tags),
                EditMode.Notes => task.Notes,
                _ => ""
            };
            
            cursorPosition = editBuffer.Length; // Start at end
            
            StatusMessage?.Invoke($"Editing {mode.ToString().ToLower()} - ESC to cancel, Enter to save");
            return true;
        }
        
        /// <summary>
        /// Cancel current edit
        /// </summary>
        public void CancelEdit()
        {
            if (!isActive) return;
            
            isActive = false;
            currentMode = EditMode.None;
            currentTask = null;
            editBuffer = "";
            errorMessage = "";
            
            EditCancelled?.Invoke();
            StatusMessage?.Invoke("Edit cancelled");
        }
        
        /// <summary>
        /// Save current edit
        /// </summary>
        public bool SaveEdit()
        {
            if (!isActive || currentTask == null) return false;
            
            try
            {
                // Validate and apply changes based on mode
                switch (currentMode)
                {
                    case EditMode.Title:
                        if (string.IsNullOrWhiteSpace(editBuffer))
                        {
                            ShowError("Title cannot be empty");
                            return false;
                        }
                        currentTask.Title = editBuffer.Trim();
                        break;
                        
                    case EditMode.Priority:
                        if (!TryParsePriority(editBuffer, out var priority))
                        {
                            ShowError("Invalid priority. Use: T(oday), H(igh), M(edium), L(ow)");
                            return false;
                        }
                        currentTask.Priority = priority;
                        break;
                        
                    case EditMode.DueDate:
                        if (!TryParseDueDate(editBuffer, out var dueDate))
                        {
                            ShowError("Invalid date. Use: yyyy-mm-dd, 'today', 'tomorrow', or 'none'");
                            return false;
                        }
                        currentTask.DueDate = dueDate;
                        break;
                        
                    case EditMode.Tags:
                        var tags = ParseTags(editBuffer);
                        currentTask.Tags.Clear();
                        foreach (var tag in tags)
                        {
                            currentTask.Tags.Add(tag);
                        }
                        break;
                        
                    case EditMode.Notes:
                        currentTask.Notes = editBuffer;
                        break;
                }
                
                // Mark as modified
                currentTask.Touch();
                
                // Complete the edit
                isActive = false;
                currentMode = EditMode.None;
                var editedTask = currentTask;
                currentTask = null;
                editBuffer = "";
                
                TaskUpdated?.Invoke(editedTask);
                StatusMessage?.Invoke($"Saved changes to {editedTask.Title}");
                return true;
            }
            catch (Exception ex)
            {
                ShowError($"Save failed: {ex.Message}");
                return false;
            }
        }
        
        /// <summary>
        /// Handle input for inline editing
        /// </summary>
        public bool HandleInput(InputEvent input)
        {
            if (!isActive) return false;
            
            // Clear expired error messages
            if (DateTime.Now > errorExpiry)
            {
                errorMessage = "";
            }
            
            // Global edit keys
            if (input.IsEscape)
            {
                CancelEdit();
                return true;
            }
            
            if (input.IsEnter)
            {
                SaveEdit();
                return true;
            }
            
            // Text editing keys
            if (input.IsBackspace && cursorPosition > 0)
            {
                editBuffer = editBuffer.Remove(cursorPosition - 1, 1);
                cursorPosition--;
                return true;
            }
            
            if (input.IsDelete && cursorPosition < editBuffer.Length)
            {
                editBuffer = editBuffer.Remove(cursorPosition, 1);
                return true;
            }
            
            // Cursor movement
            if (input.IsArrowLeft && cursorPosition > 0)
            {
                cursorPosition--;
                return true;
            }
            
            if (input.IsArrowRight && cursorPosition < editBuffer.Length)
            {
                cursorPosition++;
                return true;
            }
            
            if (input.IsHome)
            {
                cursorPosition = 0;
                return true;
            }
            
            if (input.IsEnd)
            {
                cursorPosition = editBuffer.Length;
                return true;
            }
            
            // Word movement
            if (input.IsCtrlArrowLeft)
            {
                cursorPosition = FindPreviousWordBoundary(editBuffer, cursorPosition);
                return true;
            }
            
            if (input.IsCtrlArrowRight)
            {
                cursorPosition = FindNextWordBoundary(editBuffer, cursorPosition);
                return true;
            }
            
            // Text input
            if (input.IsPrintableChar && editBuffer.Length < 200) // Reasonable limit
            {
                editBuffer = editBuffer.Insert(cursorPosition, input.Char.ToString());
                cursorPosition++;
                return true;
            }
            
            // Ctrl+A - Select all (move to beginning, would need selection system)
            if (input.IsCtrlA)
            {
                cursorPosition = 0;
                return true;
            }
            
            return false;
        }
        
        /// <summary>
        /// Render the inline editor
        /// </summary>
        public void Render(ScreenBuffer screen, Rectangle bounds)
        {
            if (!isActive) return;
            
            // Calculate editor area - center it
            var editorWidth = Math.Min(bounds.Width - 4, 80);
            var editorHeight = 4;
            var x = bounds.X + (bounds.Width - editorWidth) / 2;
            var y = bounds.Y + (bounds.Height - editorHeight) / 2;
            
            // Draw editor background
            screen.FillRect(x, y, editorWidth, editorHeight, ' ', EditForegroundColor, EditBackgroundColor);
            
            // Draw border
            screen.WriteAt(x, y, "╭" + new string('─', editorWidth - 2) + "╮", PromptColor);
            screen.WriteAt(x, y + 1, "│", PromptColor);
            screen.WriteAt(x + editorWidth - 1, y + 1, "│", PromptColor);
            screen.WriteAt(x, y + 2, "│", PromptColor);
            screen.WriteAt(x + editorWidth - 1, y + 2, "│", PromptColor);
            screen.WriteAt(x, y + 3, "╰" + new string('─', editorWidth - 2) + "╯", PromptColor);
            
            // Draw title
            var title = $" Editing {currentMode} ";
            var titleX = x + (editorWidth - title.Length) / 2;
            screen.WriteAt(titleX, y, title, PromptColor, EditBackgroundColor);
            
            // Draw input field
            var fieldWidth = editorWidth - 4;
            var fieldY = y + 1;
            var fieldX = x + 2;
            
            // Calculate visible portion of text
            var displayText = editBuffer;
            var displayStart = 0;
            var displayCursor = cursorPosition;
            
            if (displayText.Length > fieldWidth - 2)
            {
                // Scroll the text to keep cursor visible
                if (cursorPosition >= fieldWidth - 2)
                {
                    displayStart = cursorPosition - fieldWidth + 3;
                }
                displayText = displayText.Substring(displayStart, Math.Min(fieldWidth - 2, displayText.Length - displayStart));
                displayCursor = cursorPosition - displayStart;
            }
            
            // Draw the text
            screen.WriteAt(fieldX, fieldY, displayText.PadRight(fieldWidth - 2), EditForegroundColor, EditBackgroundColor);
            
            // Draw cursor
            if (displayCursor >= 0 && displayCursor <= displayText.Length)
            {
                var cursorChar = displayCursor < displayText.Length ? displayText[displayCursor] : ' ';
                screen.WriteAt(fieldX + displayCursor, fieldY, cursorChar.ToString(), EditBackgroundColor, CursorColor);
            }
            
            // Draw hints and errors
            var hintY = y + 2;
            if (!string.IsNullOrEmpty(errorMessage))
            {
                var errorText = TruncateToFit(errorMessage, fieldWidth);
                screen.WriteAt(fieldX, hintY, errorText, ErrorColor, EditBackgroundColor);
            }
            else
            {
                var hint = GetHintText(currentMode);
                if (!string.IsNullOrEmpty(hint))
                {
                    var hintText = TruncateToFit(hint, fieldWidth);
                    screen.WriteAt(fieldX, hintY, hintText, HintColor, EditBackgroundColor);
                }
            }
        }
        
        // Helper methods
        private void ShowError(string message)
        {
            errorMessage = message;
            errorExpiry = DateTime.Now.AddMilliseconds(5000); // 5 seconds
        }
        
        private string GetPriorityText(Priority priority)
        {
            return priority switch
            {
                Priority.Today => "Today",
                Priority.High => "High", 
                Priority.Medium => "Medium",
                Priority.Low => "Low",
                _ => "Medium"
            };
        }
        
        private bool TryParsePriority(string text, out Priority priority)
        {
            priority = Priority.Medium;
            if (string.IsNullOrWhiteSpace(text)) return false;
            
            var normalized = text.Trim().ToLower();
            return normalized switch
            {
                "t" or "today" => (priority = Priority.Today) == Priority.Today,
                "h" or "high" => (priority = Priority.High) == Priority.High,
                "m" or "medium" => (priority = Priority.Medium) == Priority.Medium,
                "l" or "low" => (priority = Priority.Low) == Priority.Low,
                _ => false
            };
        }
        
        private string FormatDueDateForEdit(DateTime dueDate)
        {
            if (dueDate == DateTime.MinValue) return "none";
            
            var today = DateTime.Today;
            if (dueDate.Date == today) return "today";
            if (dueDate.Date == today.AddDays(1)) return "tomorrow";
            
            return dueDate.ToString("yyyy-MM-dd");
        }
        
        private bool TryParseDueDate(string text, out DateTime dueDate)
        {
            dueDate = DateTime.MinValue;
            if (string.IsNullOrWhiteSpace(text)) return true;
            
            var normalized = text.Trim().ToLower();
            var today = DateTime.Today;
            
            return normalized switch
            {
                "none" or "null" or "" => (dueDate = DateTime.MinValue) == DateTime.MinValue,
                "today" => (dueDate = today) == today,
                "tomorrow" => (dueDate = today.AddDays(1)) == today.AddDays(1),
                "yesterday" => (dueDate = today.AddDays(-1)) == today.AddDays(-1),
                _ => DateTime.TryParse(text, out dueDate)
            };
        }
        
        private List<string> ParseTags(string tagText)
        {
            if (string.IsNullOrWhiteSpace(tagText)) return new List<string>();
            
            return tagText.Split(',', StringSplitOptions.RemoveEmptyEntries)
                         .Select(tag => tag.Trim().ToLower())
                         .Where(tag => !string.IsNullOrEmpty(tag) && tag.Length <= 20)
                         .Distinct()
                         .ToList();
        }
        
        private string GetHintText(EditMode mode)
        {
            return mode switch
            {
                EditMode.Title => "Enter task title",
                EditMode.Priority => "T(oday), H(igh), M(edium), L(ow)",
                EditMode.DueDate => "yyyy-mm-dd, 'today', 'tomorrow', 'none'", 
                EditMode.Tags => "Comma-separated tags",
                EditMode.Notes => "Task notes and details",
                _ => ""
            };
        }
        
        private int FindPreviousWordBoundary(string text, int position)
        {
            if (position <= 0) return 0;
            
            // Skip current whitespace
            while (position > 0 && char.IsWhiteSpace(text[position - 1]))
                position--;
            
            // Find start of current word
            while (position > 0 && !char.IsWhiteSpace(text[position - 1]))
                position--;
            
            return position;
        }
        
        private int FindNextWordBoundary(string text, int position)
        {
            if (position >= text.Length) return text.Length;
            
            // Skip current word
            while (position < text.Length && !char.IsWhiteSpace(text[position]))
                position++;
            
            // Skip whitespace
            while (position < text.Length && char.IsWhiteSpace(text[position]))
                position++;
            
            return position;
        }
        
        private string TruncateToFit(string text, int maxWidth)
        {
            if (text.Length <= maxWidth) return text;
            return text.Substring(0, maxWidth - 3) + "...";
        }
    }
    
    /// <summary>
    /// Types of inline editing modes
    /// </summary>
    public enum EditMode
    {
        None,
        Title,
        Priority,
        DueDate,
        Tags,
        Notes
    }
}