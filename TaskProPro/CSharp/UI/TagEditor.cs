using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI
{
    /// <summary>
    /// Professional tag management system with auto-completion
    /// </summary>
    public class TagEditor
    {
        // Configuration
        public ConsoleColor BackgroundColor { get; set; } = ConsoleColor.DarkBlue;
        public ConsoleColor ForegroundColor { get; set; } = ConsoleColor.White;
        public ConsoleColor BorderColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor TagColor { get; set; } = ConsoleColor.Yellow;
        public ConsoleColor CompletionColor { get; set; } = ConsoleColor.Green;
        public ConsoleColor SelectedCompletionColor { get; set; } = ConsoleColor.White;
        public ConsoleColor SelectedCompletionBackground { get; set; } = ConsoleColor.DarkGreen;
        public ConsoleColor HintColor { get; set; } = ConsoleColor.DarkGray;
        public ConsoleColor ErrorColor { get; set; } = ConsoleColor.Red;
        
        // State
        private bool isActive = false;
        private SimpleTask currentTask = null;
        private List<string> currentTags = new List<string>();
        private List<string> availableTags = new List<string>();
        private List<string> completionSuggestions = new List<string>();
        private int selectedCompletionIndex = -1;
        
        // Input state
        private string inputBuffer = "";
        private int cursorPosition = 0;
        private string errorMessage = "";
        private DateTime errorExpiry = DateTime.MinValue;
        
        // Events
        public event Action<SimpleTask> TagsUpdated;
        public event Action EditCancelled;
        public event Action<string> StatusMessage;
        
        // Common tags for suggestions
        private readonly string[] commonTags = {
            "work", "personal", "urgent", "important", "project", "meeting", 
            "email", "call", "research", "development", "bug", "feature",
            "documentation", "testing", "review", "planning", "shopping",
            "health", "exercise", "learning", "reading", "writing"
        };
        
        public bool IsActive => isActive;
        public IReadOnlyList<string> CurrentTags => currentTags.AsReadOnly();
        
        /// <summary>
        /// Start editing tags for a task
        /// </summary>
        public bool StartTagEditing(SimpleTask task, TaskManager taskManager)
        {
            if (task == null) return false;
            
            currentTask = task;
            currentTags = new List<string>(task.Tags);
            
            // Build available tags from all tasks
            availableTags = BuildAvailableTagsList(taskManager);
            
            isActive = true;
            inputBuffer = "";
            cursorPosition = 0;
            errorMessage = "";
            completionSuggestions.Clear();
            selectedCompletionIndex = -1;
            
            StatusMessage?.Invoke("Tag Editor - Type to add tags, Tab for completion, Enter to save");
            return true;
        }
        
        /// <summary>
        /// Cancel tag editing
        /// </summary>
        public void CancelEdit()
        {
            if (!isActive) return;
            
            isActive = false;
            currentTask = null;
            currentTags.Clear();
            inputBuffer = "";
            errorMessage = "";
            completionSuggestions.Clear();
            
            EditCancelled?.Invoke();
            StatusMessage?.Invoke("Tag editing cancelled");
        }
        
        /// <summary>
        /// Save tag changes
        /// </summary>
        public bool SaveTags()
        {
            if (!isActive || currentTask == null) return false;
            
            try {
                // Add current input as tag if it's not empty
                if (!string.IsNullOrWhiteSpace(inputBuffer))
                {
                    AddTagFromInput();
                }
                
                // Update task tags
                currentTask.Tags.Clear();
                foreach (var tag in currentTags)
                {
                    currentTask.Tags.Add(tag);
                }
                
                currentTask.Touch();
                
                // Complete editing
                isActive = false;
                var editedTask = currentTask;
                currentTask = null;
                currentTags.Clear();
                
                TagsUpdated?.Invoke(editedTask);
                StatusMessage?.Invoke($"Tags updated for '{editedTask.Title}'");
                return true;
            }
            catch (Exception ex)
            {
                ShowError($"Save failed: {ex.Message}");
                return false;
            }
        }
        
        /// <summary>
        /// Handle input for tag editing
        /// </summary>
        public bool HandleInput(InputEvent input)
        {
            if (!isActive) return false;
            
            // Clear expired error messages
            if (DateTime.Now > errorExpiry)
            {
                errorMessage = "";
            }
            
            // Global keys
            if (input.IsEscape)
            {
                CancelEdit();
                return true;
            }
            
            if (input.IsEnter)
            {
                SaveTags();
                return true;
            }
            
            // Completion navigation
            if (completionSuggestions.Any())
            {
                if (input.IsArrowUp && selectedCompletionIndex > 0)
                {
                    selectedCompletionIndex--;
                    return true;
                }
                
                if (input.IsArrowDown && selectedCompletionIndex < completionSuggestions.Count - 1)
                {
                    selectedCompletionIndex++;
                    return true;
                }
                
                if (input.IsTab || (input.IsEnter && selectedCompletionIndex >= 0))
                {
                    if (selectedCompletionIndex >= 0 && selectedCompletionIndex < completionSuggestions.Count)
                    {
                        inputBuffer = completionSuggestions[selectedCompletionIndex];
                        cursorPosition = inputBuffer.Length;
                        completionSuggestions.Clear();
                        selectedCompletionIndex = -1;
                        return true;
                    }
                }
            }
            
            // Text editing
            if (input.IsBackspace && cursorPosition > 0)
            {
                inputBuffer = inputBuffer.Remove(cursorPosition - 1, 1);
                cursorPosition--;
                UpdateCompletions();
                return true;
            }
            
            if (input.IsDelete && cursorPosition < inputBuffer.Length)
            {
                inputBuffer = inputBuffer.Remove(cursorPosition, 1);
                UpdateCompletions();
                return true;
            }
            
            // Cursor movement
            if (input.IsArrowLeft && cursorPosition > 0)
            {
                cursorPosition--;
                return true;
            }
            
            if (input.IsArrowRight && cursorPosition < inputBuffer.Length)
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
                cursorPosition = inputBuffer.Length;
                return true;
            }
            
            // Add current input as tag
            if (input.Key == ConsoleKey.Spacebar || input.Char == ',')
            {
                AddTagFromInput();
                return true;
            }
            
            // Remove last tag
            if (input.IsBackspace && cursorPosition == 0 && currentTags.Any())
            {
                currentTags.RemoveAt(currentTags.Count - 1);
                StatusMessage?.Invoke($"Removed tag '{currentTags.LastOrDefault()}'");
                return true;
            }
            
            // Text input
            if (input.IsPrintableChar && inputBuffer.Length < 30)
            {
                inputBuffer = inputBuffer.Insert(cursorPosition, input.Char.ToString());
                cursorPosition++;
                UpdateCompletions();
                return true;
            }
            
            return false;
        }
        
        /// <summary>
        /// Render the tag editor
        /// </summary>
        public void Render(ScreenBuffer screen, Rectangle bounds)
        {
            if (!isActive) return;
            
            // Calculate editor area
            var editorWidth = Math.Min(bounds.Width - 4, 100);
            var editorHeight = Math.Min(bounds.Height - 4, 15);
            var x = bounds.X + (bounds.Width - editorWidth) / 2;
            var y = bounds.Y + (bounds.Height - editorHeight) / 2;
            
            // Clear and draw background
            screen.FillRect(x, y, editorWidth, editorHeight, ' ', ForegroundColor, BackgroundColor);
            
            // Draw border
            DrawBorder(screen, x, y, editorWidth, editorHeight);
            
            // Draw title
            var title = " Tag Editor ";
            var titleX = x + (editorWidth - title.Length) / 2;
            screen.WriteAt(titleX, y, title, BorderColor, BackgroundColor);
            
            var contentY = y + 2;
            var contentWidth = editorWidth - 4;
            var contentX = x + 2;
            
            // Draw current tags
            contentY = DrawCurrentTags(screen, contentX, contentY, contentWidth);
            contentY++;
            
            // Draw input field
            contentY = DrawInputField(screen, contentX, contentY, contentWidth);
            contentY++;
            
            // Draw completions
            if (completionSuggestions.Any())
            {
                contentY = DrawCompletions(screen, contentX, contentY, contentWidth, editorHeight - (contentY - y) - 2);
            }
            
            // Draw hints/errors at bottom
            var hintY = y + editorHeight - 2;
            if (!string.IsNullOrEmpty(errorMessage))
            {
                var errorText = TruncateToFit(errorMessage, contentWidth);
                screen.WriteAt(contentX, hintY, errorText, ErrorColor, BackgroundColor);
            }
            else
            {
                var hint = "Space/Comma: Add tag | Backspace: Remove | Tab: Complete | Enter: Save | ESC: Cancel";
                var hintText = TruncateToFit(hint, contentWidth);
                screen.WriteAt(contentX, hintY, hintText, HintColor, BackgroundColor);
            }
        }
        
        // Private helper methods
        private List<string> BuildAvailableTagsList(TaskManager taskManager)
        {
            var allTags = new HashSet<string>(commonTags);
            
            if (taskManager != null)
            {
                var allTasks = taskManager.GetAllTasks();
                foreach (var task in allTasks)
                {
                    foreach (var tag in task.Tags)
                    {
                        allTags.Add(tag.ToLower());
                    }
                }
            }
            
            return allTags.OrderBy(t => t).ToList();
        }
        
        private void UpdateCompletions()
        {
            completionSuggestions.Clear();
            selectedCompletionIndex = -1;
            
            if (string.IsNullOrWhiteSpace(inputBuffer)) return;
            
            var input = inputBuffer.ToLower();
            var matches = availableTags
                .Where(tag => tag.StartsWith(input) && !currentTags.Contains(tag))
                .Take(8)
                .ToList();
            
            completionSuggestions.AddRange(matches);
            
            if (completionSuggestions.Any())
            {
                selectedCompletionIndex = 0;
            }
        }
        
        private void AddTagFromInput()
        {
            if (string.IsNullOrWhiteSpace(inputBuffer)) return;
            
            var newTag = inputBuffer.Trim().ToLower();
            if (newTag.Length == 0 || newTag.Length > 20) return;
            
            if (!currentTags.Contains(newTag))
            {
                currentTags.Add(newTag);
                StatusMessage?.Invoke($"Added tag '{newTag}'");
            }
            
            inputBuffer = "";
            cursorPosition = 0;
            completionSuggestions.Clear();
            selectedCompletionIndex = -1;
        }
        
        private void DrawBorder(ScreenBuffer screen, int x, int y, int width, int height)
        {
            // Top border
            screen.WriteAt(x, y, "╭" + new string('─', width - 2) + "╮", BorderColor);
            
            // Side borders
            for (int i = 1; i < height - 1; i++)
            {
                screen.WriteAt(x, y + i, "│", BorderColor);
                screen.WriteAt(x + width - 1, y + i, "│", BorderColor);
            }
            
            // Bottom border  
            screen.WriteAt(x, y + height - 1, "╰" + new string('─', width - 2) + "╯", BorderColor);
        }
        
        private int DrawCurrentTags(ScreenBuffer screen, int x, int y, int width)
        {
            screen.WriteAt(x, y, "Current Tags:", ForegroundColor, BackgroundColor);
            y++;
            
            if (!currentTags.Any())
            {
                screen.WriteAt(x, y, "(no tags)", HintColor, BackgroundColor);
                return y;
            }
            
            var line = "";
            foreach (var tag in currentTags)
            {
                var tagDisplay = $"[{tag}] ";
                if (line.Length + tagDisplay.Length > width)
                {
                    // Write current line and start new one
                    screen.WriteAt(x, y, line.TrimEnd(), TagColor, BackgroundColor);
                    y++;
                    line = tagDisplay;
                }
                else
                {
                    line += tagDisplay;
                }
            }
            
            if (line.Length > 0)
            {
                screen.WriteAt(x, y, line.TrimEnd(), TagColor, BackgroundColor);
            }
            
            return y;
        }
        
        private int DrawInputField(ScreenBuffer screen, int x, int y, int width)
        {
            screen.WriteAt(x, y, "Add Tag:", ForegroundColor, BackgroundColor);
            y++;
            
            // Input field background
            var fieldWidth = width - 2;
            screen.FillRect(x, y, fieldWidth, 1, ' ', BackgroundColor, ForegroundColor);
            
            // Input text
            var displayText = inputBuffer;
            var displayStart = 0;
            var displayCursor = cursorPosition;
            
            if (displayText.Length > fieldWidth - 2)
            {
                if (cursorPosition >= fieldWidth - 2)
                {
                    displayStart = cursorPosition - fieldWidth + 3;
                }
                displayText = displayText.Substring(displayStart, Math.Min(fieldWidth - 2, displayText.Length - displayStart));
                displayCursor = cursorPosition - displayStart;
            }
            
            screen.WriteAt(x + 1, y, displayText.PadRight(fieldWidth - 2), BackgroundColor, ForegroundColor);
            
            // Cursor
            if (displayCursor >= 0 && displayCursor <= displayText.Length)
            {
                var cursorChar = displayCursor < displayText.Length ? displayText[displayCursor] : ' ';
                screen.WriteAt(x + 1 + displayCursor, y, cursorChar.ToString(), ForegroundColor, TagColor);
            }
            
            return y;
        }
        
        private int DrawCompletions(ScreenBuffer screen, int x, int y, int width, int maxHeight)
        {
            if (!completionSuggestions.Any()) return y;
            
            y++;
            screen.WriteAt(x, y, "Suggestions:", CompletionColor, BackgroundColor);
            y++;
            
            var maxCompletions = Math.Min(completionSuggestions.Count, maxHeight - 2);
            for (int i = 0; i < maxCompletions; i++)
            {
                var completion = completionSuggestions[i];
                var isSelected = i == selectedCompletionIndex;
                
                var fg = isSelected ? SelectedCompletionColor : CompletionColor;
                var bg = isSelected ? SelectedCompletionBackground : BackgroundColor;
                
                var prefix = isSelected ? "► " : "  ";
                var displayText = TruncateToFit(prefix + completion, width - 2);
                
                screen.WriteAt(x, y + i, displayText.PadRight(width - 2), fg, bg);
            }
            
            return y + maxCompletions;
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