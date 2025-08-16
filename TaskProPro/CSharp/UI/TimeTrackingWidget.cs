using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI {
    public class TimeTrackingWidget {
        // Configuration
        public TimeTrackingService TimeService { get; set; }
        public StatusBar StatusBar { get; set; }
        
        // CYBERPUNK COLOR PALETTE - Matching TaskProPro aesthetic
        public ConsoleColor HeaderColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor HighHoursColor { get; set; } = ConsoleColor.Red;
        public ConsoleColor MediumHoursColor { get; set; } = ConsoleColor.Yellow;
        public ConsoleColor LowHoursColor { get; set; } = ConsoleColor.Green;
        public ConsoleColor ProjectColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor TimeCodeColor { get; set; } = ConsoleColor.Magenta;
        public ConsoleColor TodayColor { get; set; } = ConsoleColor.Yellow;
        public ConsoleColor BorderColor { get; set; } = ConsoleColor.Cyan;
        public ConsoleColor BackgroundColor { get; set; } = ConsoleColor.Black;
        public ConsoleColor SelectionColor { get; set; } = ConsoleColor.DarkBlue;
        public ConsoleColor AmberText { get; set; } = ConsoleColor.Yellow;
        public ConsoleColor StatusGreen { get; set; } = ConsoleColor.Green;
        public ConsoleColor SubtaskColor { get; set; } = ConsoleColor.DarkGray;
        
        // State
        private List<SimpleTimeEntry> timeEntries = new List<SimpleTimeEntry>();
        private int selectedIndex = 0;
        private int scrollTop = 0;
        
        // Inline editing state - EXACT feature parity with standalone
        private int editingIndex = -1;
        private string editingField = "";  // "project", "description", "monday", "tuesday", "wednesday", "thursday", "friday"
        private string editingValue = "";
        private SimpleTimeEntry editingEntry = null;
        private bool isNewEntry = false;
        
        // Column widths for time entry layout
        private const int ProjectCol = 15;
        private const int DescCol = 30;
        private const int MonCol = 8;
        private const int TueCol = 8;
        private const int WedCol = 8;
        private const int ThuCol = 8;
        private const int FriCol = 8;
        private const int TotalCol = 8;
        
        public int SelectedIndex => selectedIndex;
        public int TotalItems => timeEntries.Count;
        public bool HasSelection => timeEntries.Count > 0 && selectedIndex >= 0 && selectedIndex < timeEntries.Count;
        public SimpleTimeEntry SelectedEntry => HasSelection ? timeEntries[selectedIndex] : null;
        
        public TimeTrackingWidget() {
            // Initialize with default configuration
        }
        
        public void Initialize(TimeTrackingService timeService) {
            TimeService = timeService ?? throw new ArgumentNullException(nameof(timeService));
            RefreshList();
        }
        
        public void RefreshList() {
            if (TimeService == null) return;
            
            timeEntries = TimeService.GetCurrentWeekEntries();
            
            // Adjust selection if it's out of bounds
            if (selectedIndex >= timeEntries.Count) {
                selectedIndex = Math.Max(0, timeEntries.Count - 1);
            }
        }
        
        public bool HandleInput(InputEvent input) {
            // Handle inline editing mode first
            if (editingIndex >= 0) {
                return HandleEditingInput(input);
            }
            
            // Navigation
            if (input.IsArrowUp) {
                if (selectedIndex > 0) {
                    selectedIndex--;
                    EnsureVisible();
                }
                return true;
            }
            
            if (input.IsArrowDown) {
                if (selectedIndex < timeEntries.Count - 1) {
                    selectedIndex++;
                    EnsureVisible();
                }
                return true;
            }
            
            // Week navigation
            if (input.IsArrowLeft) {
                TimeService?.NavigateToPreviousWeek();
                RefreshList();
                StatusBar?.ShowMessage($"Previous week: {TimeService?.GetWeekDisplayString()}");
                return true;
            }
            
            if (input.IsArrowRight) {
                TimeService?.NavigateToNextWeek();
                RefreshList();
                StatusBar?.ShowMessage($"Next week: {TimeService?.GetWeekDisplayString()}");
                return true;
            }
            
            // Time entry operations
            if (input.Key == ConsoleKey.E) {
                StartInlineEdit();
                return true;
            }
            
            if (input.Key == ConsoleKey.A) {
                StartInlineAdd();
                return true;
            }
            
            if (input.Key == ConsoleKey.D) {
                DeleteEntry();
                return true;
            }
            
            if (input.Key == ConsoleKey.C) {
                TimeService?.NavigateToCurrentWeek();
                RefreshList();
                StatusBar?.ShowSuccess("Navigated to current week");
                return true;
            }
            
            return false;
        }
        
        public void Render(ScreenBuffer screen, Rectangle bounds) {
            // Clear the area
            screen.FillRect(bounds.X, bounds.Y, bounds.Width, bounds.Height, ' ', 
                          AmberText, BackgroundColor);
            
            // Render cyberpunk header
            RenderCyberpunkHeader(screen, bounds);
            
            // Render time entry list
            var listBounds = new Rectangle(bounds.X, bounds.Y + 4, bounds.Width, bounds.Height - 6);
            RenderTimeEntryList(screen, listBounds);
            
            // Render status line
            RenderStatusLine(screen, bounds);
            
            // Render inline editor overlay if active
            if (editingIndex >= 0) {
                RenderInlineEditor(screen, bounds);
            }
        }
        
        private void RenderCyberpunkHeader(ScreenBuffer screen, Rectangle bounds) {
            var headerY = bounds.Y;
            
            // Draw cyberpunk border frame
            DrawCyberpunkBorder(screen, bounds.X, headerY, bounds.Width, 3);
            
            // Terminal-style header
            var headerText = "TIMETRACKER v2.1 - TIME ENTRY MANAGEMENT SYSTEM";
            var centerX = bounds.X + (bounds.Width - headerText.Length) / 2;
            screen.WriteAt(centerX, headerY + 1, headerText, AmberText, BackgroundColor);
            
            // Week display
            var weekText = TimeService?.GetWeekDisplayString() ?? "No week selected";
            if (TimeService?.IsCurrentWeek() == true) {
                weekText += " (CURRENT WEEK)";
            }
            screen.WriteAt(bounds.X + 2, headerY + 2, weekText, HeaderColor, BackgroundColor);
            
            // System status
            var entryCount = timeEntries.Count;
            var totalHours = timeEntries.Sum(e => e.Total);
            var systemInfo = $"ENTRIES:{entryCount:D3} | TOTAL:{totalHours:F1}H";
            var infoX = bounds.X + bounds.Width - systemInfo.Length - 2;
            screen.WriteAt(infoX, headerY + 2, systemInfo, StatusGreen, BackgroundColor);
        }
        
        private void RenderTimeEntryList(ScreenBuffer screen, Rectangle bounds) {
            // Column headers
            if (bounds.Height >= 3) {
                var headerY = bounds.Y;
                
                // Get current day for highlighting
                var currentDay = GetCurrentDayOfWeek();
                
                var monHeader = currentDay == "monday" ? "▸MON" : "MON";
                var tueHeader = currentDay == "tuesday" ? "▸TUE" : "TUE";
                var wedHeader = currentDay == "wednesday" ? "▸WED" : "WED";
                var thuHeader = currentDay == "thursday" ? "▸THU" : "THU";
                var friHeader = currentDay == "friday" ? "▸FRI" : "FRI";
                
                // Render column headers with cyberpunk styling
                var headerText = $"{"PROJECT".PadRight(ProjectCol)}{"DESCRIPTION".PadRight(DescCol)}{monHeader.PadRight(MonCol)}{tueHeader.PadRight(TueCol)}{wedHeader.PadRight(WedCol)}{thuHeader.PadRight(ThuCol)}{friHeader.PadRight(FriCol)}{"TOTAL"}";
                screen.WriteAt(bounds.X, headerY, headerText, HeaderColor, BackgroundColor);
                
                // Header separator
                var separator = new string('═', Math.Min(headerText.Length, bounds.Width));
                screen.WriteAt(bounds.X, headerY + 1, separator, HeaderColor, BackgroundColor);
            }
            
            // Time entry content area
            var contentY = bounds.Y + 2;
            var contentHeight = Math.Max(1, bounds.Height - 2);
            
            if (timeEntries.Count == 0) {
                // No entries message
                var noEntriesMsg = "[NO TIME ENTRIES FOR THIS WEEK]";
                var msgX = bounds.X + (bounds.Width - noEntriesMsg.Length) / 2;
                var msgY = contentY + contentHeight / 2;
                screen.WriteAt(msgX, msgY, noEntriesMsg, SubtaskColor, BackgroundColor);
                return;
            }
            
            // Calculate visible range
            EnsureVisible();
            var endIndex = Math.Min(timeEntries.Count, scrollTop + contentHeight);
            
            for (int i = scrollTop; i < endIndex; i++) {
                var entry = timeEntries[i];
                var displayIndex = i - scrollTop;
                var y = contentY + displayIndex;
                
                if (y >= contentY + contentHeight) break;
                
                // Selection highlighting
                var isSelected = (selectedIndex == i);
                if (isSelected) {
                    screen.FillRect(bounds.X, y, bounds.Width, 1, ' ', 
                                  BackgroundColor, SelectionColor);
                }
                
                // Render time entry with cyberpunk styling
                RenderTimeEntryContent(screen, bounds.X, y, entry, isSelected);
            }
        }
        
        private void RenderTimeEntryContent(ScreenBuffer screen, int x, int y, SimpleTimeEntry entry, bool isSelected) {
            var bgColor = isSelected ? SelectionColor : BackgroundColor;
            var currentDay = GetCurrentDayOfWeek();
            
            var xPos = x;
            
            // Project code column
            var projectColor = entry.IsTimeCode() ? TimeCodeColor : ProjectColor;
            var projectText = (entry.ProjectCode ?? "").PadRight(ProjectCol);
            screen.WriteAt(xPos, y, projectText, projectColor, bgColor);
            xPos += ProjectCol;
            
            // Description column
            var descText = (entry.Description ?? "").PadRight(DescCol);
            if (descText.Length > DescCol) {
                descText = descText.Substring(0, DescCol - 3) + "...";
            }
            screen.WriteAt(xPos, y, descText, SubtaskColor, bgColor);
            xPos += DescCol;
            
            // Daily hours columns
            RenderDayColumn(screen, xPos, y, entry.Monday, MonCol, currentDay == "monday", bgColor);
            xPos += MonCol;
            RenderDayColumn(screen, xPos, y, entry.Tuesday, TueCol, currentDay == "tuesday", bgColor);
            xPos += TueCol;
            RenderDayColumn(screen, xPos, y, entry.Wednesday, WedCol, currentDay == "wednesday", bgColor);
            xPos += WedCol;
            RenderDayColumn(screen, xPos, y, entry.Thursday, ThuCol, currentDay == "thursday", bgColor);
            xPos += ThuCol;
            RenderDayColumn(screen, xPos, y, entry.Friday, FriCol, currentDay == "friday", bgColor);
            xPos += FriCol;
            
            // Total column
            var totalText = entry.Total > 0 ? entry.Total.ToString("F1") : "";
            var totalColor = entry.GetTotalColor();
            screen.WriteAt(xPos, y, totalText.PadRight(TotalCol), totalColor, bgColor);
        }
        
        private void RenderDayColumn(ScreenBuffer screen, int x, int y, decimal hours, int colWidth, bool isCurrentDay, ConsoleColor bgColor) {
            var hoursText = hours > 0 ? hours.ToString("F1") : "";
            var color = isCurrentDay ? TodayColor : (hours > 0 ? LowHoursColor : SubtaskColor);
            
            if (hours > 8) color = HighHoursColor;
            else if (hours >= 4) color = MediumHoursColor;
            
            screen.WriteAt(x, y, hoursText.PadRight(colWidth), color, bgColor);
        }
        
        private void RenderStatusLine(ScreenBuffer screen, Rectangle bounds) {
            var statusY = bounds.Y + bounds.Height - 1;
            screen.FillRect(bounds.X, statusY, bounds.Width, 1, ' ', StatusGreen, BackgroundColor);
            
            if (editingIndex >= 0) {
                var statusText = $"EDITING [{editingField?.ToUpper() ?? "UNKNOWN"}]: Tab=Next Field  Enter=Save  Escape=Cancel";
                screen.WriteAt(bounds.X + 1, statusY, statusText, StatusGreen, BackgroundColor);
            } else {
                var statusText = "↑↓=Navigate  E=Edit  A=Add  D=Delete  C=Current Week  ←→=Week Nav";
                screen.WriteAt(bounds.X + 1, statusY, statusText, StatusGreen, BackgroundColor);
            }
        }
        
        private void RenderInlineEditor(ScreenBuffer screen, Rectangle bounds) {
            if (editingIndex < 0 || editingEntry == null) return;
            
            // Simple highlight for the editing field - could be enhanced with overlay
            var contentY = bounds.Y + 6; // Account for header
            var y = contentY + (editingIndex - scrollTop);
            
            if (y >= contentY && y < bounds.Y + bounds.Height - 2) {
                // Highlight the current editing position
                var xPos = bounds.X;
                
                // Calculate position based on editing field
                switch (editingField) {
                    case "project":
                        // Project column is at the start
                        break;
                    case "description":
                        xPos += ProjectCol;
                        break;
                    case "monday":
                        xPos += ProjectCol + DescCol;
                        break;
                    case "tuesday":
                        xPos += ProjectCol + DescCol + MonCol;
                        break;
                    case "wednesday":
                        xPos += ProjectCol + DescCol + MonCol + TueCol;
                        break;
                    case "thursday":
                        xPos += ProjectCol + DescCol + MonCol + TueCol + WedCol;
                        break;
                    case "friday":
                        xPos += ProjectCol + DescCol + MonCol + TueCol + WedCol + ThuCol;
                        break;
                }
                
                // Render editing value with highlight
                var fieldWidth = editingField switch {
                    "project" => ProjectCol,
                    "description" => DescCol,
                    _ => 8 // Day columns
                };
                
                var editText = (editingValue ?? "").PadRight(fieldWidth);
                if (editText.Length > fieldWidth) {
                    editText = editText.Substring(0, fieldWidth);
                }
                
                screen.WriteAt(xPos, y, editText, BackgroundColor, AmberText);
            }
        }
        
        private void DrawCyberpunkBorder(ScreenBuffer screen, int x, int y, int width, int height) {
            var borderColor = BorderColor;
            
            // Top border
            screen.WriteAt(x, y, "╔", borderColor, BackgroundColor);
            for (int i = 1; i < width - 1; i++) {
                screen.WriteAt(x + i, y, "═", borderColor, BackgroundColor);
            }
            screen.WriteAt(x + width - 1, y, "╗", borderColor, BackgroundColor);
            
            // Side borders
            for (int i = 1; i < height - 1; i++) {
                screen.WriteAt(x, y + i, "║", borderColor, BackgroundColor);
                screen.WriteAt(x + width - 1, y + i, "║", borderColor, BackgroundColor);
            }
            
            // Bottom border
            screen.WriteAt(x, y + height - 1, "╚", borderColor, BackgroundColor);
            for (int i = 1; i < width - 1; i++) {
                screen.WriteAt(x + i, y + height - 1, "═", borderColor, BackgroundColor);
            }
            screen.WriteAt(x + width - 1, y + height - 1, "╝", borderColor, BackgroundColor);
        }
        
        private string GetCurrentDayOfWeek() {
            var today = DateTime.Today.DayOfWeek;
            var isCurrentWeek = TimeService?.IsCurrentWeek() ?? false;
            
            if (!isCurrentWeek) return "";
            
            return today switch {
                DayOfWeek.Monday => "monday",
                DayOfWeek.Tuesday => "tuesday",
                DayOfWeek.Wednesday => "wednesday",
                DayOfWeek.Thursday => "thursday",
                DayOfWeek.Friday => "friday",
                _ => ""
            };
        }
        
        private void EnsureVisible() {
            if (timeEntries.Count == 0) return;
            
            var maxVisible = 10; // Approximate visible items
            
            if (selectedIndex < scrollTop) {
                scrollTop = selectedIndex;
            } else if (selectedIndex >= scrollTop + maxVisible) {
                scrollTop = selectedIndex - maxVisible + 1;
            }
            
            scrollTop = Math.Max(0, Math.Min(scrollTop, timeEntries.Count - maxVisible));
        }
        
        // INLINE EDITING METHODS - EXACT feature parity with standalone
        
        private void StartInlineEdit() {
            if (!HasSelection) return;
            
            editingIndex = selectedIndex;
            editingEntry = timeEntries[selectedIndex];
            editingField = "project";
            editingValue = editingEntry.ProjectCode ?? "";
            isNewEntry = false;
        }
        
        private void StartInlineAdd() {
            var newEntry = new SimpleTimeEntry();
            if (TimeService != null) {
                newEntry.WeekEndingFriday = TimeService.CurrentWeekFriday.ToString("yyyyMMdd");
            }
            
            timeEntries.Add(newEntry);
            editingIndex = timeEntries.Count - 1;
            editingEntry = newEntry;
            editingField = "project";
            editingValue = "";
            selectedIndex = editingIndex;
            isNewEntry = true;
            
            EnsureVisible();
        }
        
        private bool HandleEditingInput(InputEvent input) {
            if (input.IsEnter) {
                if (isNewEntry) {
                    if (editingField == "friday") {
                        SaveInlineEdit();
                    } else {
                        NextEditField();
                    }
                } else {
                    SaveInlineEdit();
                }
                return true;
            }
            
            if (input.IsEscape) {
                CancelInlineEdit();
                return true;
            }
            
            if (input.IsTab) {
                if (input.Shift) {
                    PreviousEditField();
                } else {
                    NextEditField();
                }
                return true;
            }
            
            if (input.IsBackspace) {
                if (!string.IsNullOrEmpty(editingValue)) {
                    editingValue = editingValue.Substring(0, editingValue.Length - 1);
                }
                return true;
            }
            
            // Character input
            if (input.IsPrintableChar && !input.Ctrl && !input.Alt) {
                editingValue += input.Char;
                return true;
            }
            
            return false;
        }
        
        private void NextEditField() {
            ApplyCurrentFieldValue();
            
            editingField = editingField switch {
                "project" => "description",
                "description" => "monday",
                "monday" => "tuesday",
                "tuesday" => "wednesday",
                "wednesday" => "thursday",
                "thursday" => "friday",
                "friday" => "project",
                _ => "project"
            };
            
            LoadFieldValue();
        }
        
        private void PreviousEditField() {
            ApplyCurrentFieldValue();
            
            editingField = editingField switch {
                "project" => "friday",
                "description" => "project",
                "monday" => "description",
                "tuesday" => "monday",
                "wednesday" => "tuesday",
                "thursday" => "wednesday",
                "friday" => "thursday",
                _ => "project"
            };
            
            LoadFieldValue();
        }
        
        private void ApplyCurrentFieldValue() {
            if (editingEntry == null) return;
            
            switch (editingField) {
                case "project":
                    editingEntry.ProjectCode = editingValue ?? "";
                    break;
                case "description":
                    editingEntry.Description = editingValue ?? "";
                    break;
                case "monday":
                    SetDayValue("Monday", editingValue);
                    break;
                case "tuesday":
                    SetDayValue("Tuesday", editingValue);
                    break;
                case "wednesday":
                    SetDayValue("Wednesday", editingValue);
                    break;
                case "thursday":
                    SetDayValue("Thursday", editingValue);
                    break;
                case "friday":
                    SetDayValue("Friday", editingValue);
                    break;
            }
        }
        
        private void LoadFieldValue() {
            editingValue = editingField switch {
                "project" => editingEntry?.ProjectCode ?? "",
                "description" => editingEntry?.Description ?? "",
                "monday" => editingEntry?.Monday > 0 ? editingEntry.Monday.ToString() : "",
                "tuesday" => editingEntry?.Tuesday > 0 ? editingEntry.Tuesday.ToString() : "",
                "wednesday" => editingEntry?.Wednesday > 0 ? editingEntry.Wednesday.ToString() : "",
                "thursday" => editingEntry?.Thursday > 0 ? editingEntry.Thursday.ToString() : "",
                "friday" => editingEntry?.Friday > 0 ? editingEntry.Friday.ToString() : "",
                _ => ""
            };
        }
        
        private void SetDayValue(string dayName, string value) {
            if (decimal.TryParse(value, out decimal hours)) {
                editingEntry?.SetDayHours(dayName, hours);
            } else {
                editingEntry?.SetDayHours(dayName, 0);
            }
        }
        
        private void SaveInlineEdit() {
            ApplyCurrentFieldValue();
            
            if (editingEntry != null) {
                // Determine if it's a time code or project
                if (!string.IsNullOrEmpty(editingEntry.ProjectCode) && 
                    editingEntry.ProjectCode.Length <= 5 && 
                    editingEntry.ProjectCode.Length >= 3) {
                    editingEntry.IsProjectEntry = false;
                } else {
                    editingEntry.IsProjectEntry = true;
                }
                
                editingEntry.CalculateTotal();
                
                if (!string.IsNullOrEmpty(editingEntry.ProjectCode)) {
                    if (isNewEntry) {
                        TimeService?.AddTimeEntry(editingEntry);
                    } else {
                        TimeService?.UpdateTimeEntry(editingEntry);
                    }
                } else if (isNewEntry) {
                    // Remove empty new entry
                    timeEntries.RemoveAt(editingIndex);
                }
            }
            
            EndInlineEdit();
            RefreshList();
        }
        
        private void CancelInlineEdit() {
            if (isNewEntry && editingIndex >= 0 && editingIndex < timeEntries.Count) {
                timeEntries.RemoveAt(editingIndex);
                if (selectedIndex >= timeEntries.Count) {
                    selectedIndex = Math.Max(0, timeEntries.Count - 1);
                }
            }
            
            EndInlineEdit();
        }
        
        private void EndInlineEdit() {
            editingIndex = -1;
            editingField = "";
            editingValue = "";
            editingEntry = null;
            isNewEntry = false;
        }
        
        private void DeleteEntry() {
            if (!HasSelection) return;
            
            var entry = timeEntries[selectedIndex];
            TimeService?.DeleteTimeEntry(entry.Id);
            RefreshList();
            StatusBar?.ShowWarning($"Deleted time entry for {entry.ProjectCode}");
        }
    }
}