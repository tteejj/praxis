using System;
using System.Collections.Generic;
using System.Linq;
using TaskPro.Core;
using TaskPro.Data;

namespace TaskPro.UI {
    public class TimeTrackingWidget {
        // Configuration
        public TimeTrackingService TimeService { get; set; }
        public TaskManager TaskManager { get; set; }
        public StatusBar StatusBar { get; set; }
        public TaskSelectionDialog TaskSelectionDialog { get; set; }
        
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
        
        // Column widths for time entry layout - Updated for ID1/ID2 system
        private const int ID1Col = 8;
        private const int ID2Col = 12;
        private const int DescCol = 25;
        private const int MonCol = 6;
        private const int TueCol = 6;
        private const int WedCol = 6;
        private const int ThuCol = 6;
        private const int FriCol = 6;
        private const int TotalCol = 8;
        
        public int SelectedIndex => selectedIndex;
        public int TotalItems => timeEntries.Count;
        public bool HasSelection => timeEntries.Count > 0 && selectedIndex >= 0 && selectedIndex < timeEntries.Count;
        public SimpleTimeEntry SelectedEntry => HasSelection ? timeEntries[selectedIndex] : null;
        
        public TimeTrackingWidget() {
            // Initialize with default configuration
        }
        
        public void Initialize(TimeTrackingService timeService, TaskManager taskManager = null) {
            TimeService = timeService ?? throw new ArgumentNullException(nameof(timeService));
            TaskManager = taskManager;
            
            // Initialize task selection dialog
            if (TaskManager != null) {
                TaskSelectionDialog = new TaskSelectionDialog();
                TaskSelectionDialog.TaskManager = TaskManager;
                TaskSelectionDialog.StatusBar = StatusBar;
            }
            
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
            // Handle task selection dialog first (highest priority)
            if (TaskSelectionDialog?.IsActive == true) {
                return TaskSelectionDialog.HandleInput(input);
            }
            
            // Handle inline editing mode next
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
            
            if (input.Key == ConsoleKey.T) {
                OpenTaskSelection();
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
            
            // Render time entry list (account for 5-line header + status)
            var listBounds = new Rectangle(bounds.X, bounds.Y + 5, bounds.Width, bounds.Height - 7);
            RenderTimeEntryList(screen, listBounds);
            
            // Render status line
            RenderStatusLine(screen, bounds);
            
            // Render inline editor overlay if active
            if (editingIndex >= 0) {
                RenderInlineEditor(screen, bounds);
            }
            
            // Render task selection dialog if active
            if (TaskSelectionDialog?.IsActive == true) {
                TaskSelectionDialog.Render(screen, bounds);
            }
        }
        
        private void RenderCyberpunkHeader(ScreenBuffer screen, Rectangle bounds) {
            var headerY = bounds.Y;
            
            // Draw cyberpunk border frame
            DrawCyberpunkBorder(screen, bounds.X, headerY, bounds.Width, 4);
            
            // Terminal-style header with TaskProPro branding
            var headerText = "TASKPRO v2.1 - TIME TRACKING SYSTEM";
            var centerX = bounds.X + (bounds.Width - headerText.Length) / 2;
            screen.WriteAt(centerX, headerY + 1, headerText, AmberText, BackgroundColor);
            
            // System status line with mode indicator
            var systemStatus = "[SYS:ONLINE] [MODE:TIME_TRACK] [F1:TASK_MGMT]";
            screen.WriteAt(bounds.X + 2, headerY + 2, systemStatus, StatusGreen, BackgroundColor);
            
            // Week display with current week indicator
            var weekText = TimeService?.GetWeekDisplayString() ?? "No week selected";
            if (TimeService?.IsCurrentWeek() == true) {
                weekText += " (CURRENT)";
            }
            screen.WriteAt(bounds.X + 2, headerY + 3, $"WEEK: {weekText}", HeaderColor, BackgroundColor);
            
            // Weekly summary with cumulative hours
            var summary = TimeService?.GetCurrentWeeklySummary();
            if (summary != null) {
                var summaryInfo = $"WEEK TOTAL: {summary.WeekTotal:F1}H | ENTRIES: {summary.TotalEntries}";
                var infoX = bounds.X + bounds.Width - summaryInfo.Length - 2;
                var summaryColor = summary.GetWeekTotalColor();
                screen.WriteAt(infoX, headerY + 3, summaryInfo, summaryColor, BackgroundColor);
            }
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
                
                // Professional column headers with separators - ID1/ID2 system
                var headerText = $"{"ID1".PadRight(ID1Col)}│{"ID2".PadRight(ID2Col)}│{"DESCRIPTION".PadRight(DescCol)}│{monHeader.PadRight(MonCol)}│{tueHeader.PadRight(TueCol)}│{wedHeader.PadRight(WedCol)}│{thuHeader.PadRight(ThuCol)}│{friHeader.PadRight(FriCol)}│{"TOTAL"}";
                screen.WriteAt(bounds.X, headerY, headerText, HeaderColor, BackgroundColor);
                
                // Professional header separator with column markers
                var separator = $"{new string('─', ID1Col)}┼{new string('─', ID2Col)}┼{new string('─', DescCol)}┼{new string('─', MonCol)}┼{new string('─', TueCol)}┼{new string('─', WedCol)}┼{new string('─', ThuCol)}┼{new string('─', FriCol)}┼{new string('─', TotalCol)}";
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
            var isEditingThis = (editingIndex >= 0 && editingEntry != null && editingEntry.Id == entry.Id);
            
            var xPos = x;
            
            // ID1 column - with inline editing support
            if (isEditingThis && editingField == "id1") {
                var editText = editingValue.PadRight(ID1Col);
                if (editText.Length > ID1Col) editText = editText.Substring(0, ID1Col);
                screen.WriteAt(xPos, y, editText, BackgroundColor, AmberText);
            } else {
                var id1Color = entry.IsLinkedToTask ? ProjectColor : TimeCodeColor;
                var id1Text = (entry.ID1 ?? "").PadRight(ID1Col);
                if (id1Text.Length > ID1Col) id1Text = id1Text.Substring(0, ID1Col);
                screen.WriteAt(xPos, y, id1Text, id1Color, bgColor);
            }
            xPos += ID1Col;
            
            // Column separator
            screen.WriteAt(xPos, y, "│", HeaderColor, bgColor);
            xPos += 1;
            
            // ID2 column - with inline editing support
            if (isEditingThis && editingField == "id2") {
                var editText = editingValue.PadRight(ID2Col);
                if (editText.Length > ID2Col) editText = editText.Substring(0, ID2Col);
                screen.WriteAt(xPos, y, editText, BackgroundColor, AmberText);
            } else {
                var id2Color = entry.IsLinkedToTask ? ProjectColor : SubtaskColor;
                var id2Text = (entry.ID2 ?? "").PadRight(ID2Col);
                if (id2Text.Length > ID2Col) id2Text = id2Text.Substring(0, ID2Col);
                screen.WriteAt(xPos, y, id2Text, id2Color, bgColor);
            }
            xPos += ID2Col;
            
            // Column separator
            screen.WriteAt(xPos, y, "│", HeaderColor, bgColor);
            xPos += 1;
            
            // Description column - with inline editing support
            if (isEditingThis && editingField == "description") {
                var editText = editingValue.PadRight(DescCol);
                if (editText.Length > DescCol) editText = editText.Substring(0, DescCol);
                screen.WriteAt(xPos, y, editText, BackgroundColor, AmberText);
            } else {
                var descText = (entry.Description ?? "").PadRight(DescCol);
                if (descText.Length > DescCol) descText = descText.Substring(0, DescCol - 3) + "...";
                screen.WriteAt(xPos, y, descText, SubtaskColor, bgColor);
            }
            xPos += DescCol;
            
            // Column separator
            screen.WriteAt(xPos, y, "│", HeaderColor, bgColor);
            xPos += 1;
            
            // Daily hours columns - with inline editing support and separators
            RenderDayColumn(screen, xPos, y, entry.Monday, MonCol, "monday", currentDay == "monday", bgColor, isEditingThis);
            xPos += MonCol;
            screen.WriteAt(xPos, y, "│", HeaderColor, bgColor);
            xPos += 1;
            
            RenderDayColumn(screen, xPos, y, entry.Tuesday, TueCol, "tuesday", currentDay == "tuesday", bgColor, isEditingThis);
            xPos += TueCol;
            screen.WriteAt(xPos, y, "│", HeaderColor, bgColor);
            xPos += 1;
            
            RenderDayColumn(screen, xPos, y, entry.Wednesday, WedCol, "wednesday", currentDay == "wednesday", bgColor, isEditingThis);
            xPos += WedCol;
            screen.WriteAt(xPos, y, "│", HeaderColor, bgColor);
            xPos += 1;
            
            RenderDayColumn(screen, xPos, y, entry.Thursday, ThuCol, "thursday", currentDay == "thursday", bgColor, isEditingThis);
            xPos += ThuCol;
            screen.WriteAt(xPos, y, "│", HeaderColor, bgColor);
            xPos += 1;
            
            RenderDayColumn(screen, xPos, y, entry.Friday, FriCol, "friday", currentDay == "friday", bgColor, isEditingThis);
            xPos += FriCol;
            screen.WriteAt(xPos, y, "│", HeaderColor, bgColor);
            xPos += 1;
            
            // Total column
            var totalText = entry.Total > 0 ? entry.Total.ToString("F1") : "";
            var totalColor = entry.GetTotalColor();
            screen.WriteAt(xPos, y, totalText.PadRight(TotalCol), totalColor, bgColor);
        }
        
        private void RenderDayColumn(ScreenBuffer screen, int x, int y, decimal hours, int colWidth, string dayName, bool isCurrentDay, ConsoleColor bgColor, bool isEditingThis) {
            // Handle inline editing for this day column
            if (isEditingThis && editingField == dayName) {
                var editText = editingValue.PadRight(colWidth);
                if (editText.Length > colWidth) editText = editText.Substring(0, colWidth);
                screen.WriteAt(x, y, editText, BackgroundColor, AmberText);
            } else {
                var hoursText = hours > 0 ? hours.ToString("F1") : "";
                var color = isCurrentDay ? TodayColor : (hours > 0 ? LowHoursColor : SubtaskColor);
                
                if (hours > 8) color = HighHoursColor;
                else if (hours >= 4) color = MediumHoursColor;
                
                screen.WriteAt(x, y, hoursText.PadRight(colWidth), color, bgColor);
            }
        }
        
        private void RenderStatusLine(ScreenBuffer screen, Rectangle bounds) {
            var statusY = bounds.Y + bounds.Height - 1;
            screen.FillRect(bounds.X, statusY, bounds.Width, 1, ' ', StatusGreen, BackgroundColor);
            
            if (editingIndex >= 0) {
                var statusText = $"EDITING [{editingField?.ToUpper() ?? "UNKNOWN"}]: Tab=Next Field  Enter=Save  Escape=Cancel";
                screen.WriteAt(bounds.X + 1, statusY, statusText, StatusGreen, BackgroundColor);
            } else {
                var statusText = "↑↓=Navigate  E=Edit  A=Add  T=Task Select  D=Delete  C=Current Week  ←→=Week Nav";
                screen.WriteAt(bounds.X + 1, statusY, statusText, StatusGreen, BackgroundColor);
            }
        }
        
        private void RenderInlineEditor(ScreenBuffer screen, Rectangle bounds) {
            // Inline editing is now handled directly in RenderTimeEntryContent
            // This method is kept for compatibility but does nothing
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
        
        private void OpenTaskSelection() {
            if (!HasSelection || TaskSelectionDialog == null) return;
            
            var entry = timeEntries[selectedIndex];
            TaskSelectionDialog.StartSelection(entry, (updatedEntry) => {
                if (updatedEntry != null) {
                    TimeService?.UpdateTimeEntry(updatedEntry);
                    RefreshList();
                }
            });
        }
        
        private void StartInlineEdit() {
            if (!HasSelection) return;
            
            editingIndex = selectedIndex;
            editingEntry = timeEntries[selectedIndex];
            editingField = "id1";
            editingValue = editingEntry.ID1 ?? "";
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
            editingField = "id1";
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
                "id1" => "id2",
                "id2" => "description",
                "description" => "monday",
                "monday" => "tuesday",
                "tuesday" => "wednesday",
                "wednesday" => "thursday",
                "thursday" => "friday",
                "friday" => "id1",
                _ => "id1"
            };
            
            LoadFieldValue();
        }
        
        private void PreviousEditField() {
            ApplyCurrentFieldValue();
            
            editingField = editingField switch {
                "id1" => "friday",
                "id2" => "id1",
                "description" => "id2",
                "monday" => "description",
                "tuesday" => "monday",
                "wednesday" => "tuesday",
                "thursday" => "wednesday",
                "friday" => "thursday",
                _ => "id1"
            };
            
            LoadFieldValue();
        }
        
        private void ApplyCurrentFieldValue() {
            if (editingEntry == null) return;
            
            switch (editingField) {
                case "id1":
                    editingEntry.ID1 = editingValue ?? "";
                    break;
                case "id2":
                    editingEntry.ID2 = editingValue ?? "";
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
                "id1" => editingEntry?.ID1 ?? "",
                "id2" => editingEntry?.ID2 ?? "",
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
                editingEntry.CalculateTotal();
                
                if (!string.IsNullOrEmpty(editingEntry.ID1)) {
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
            StatusBar?.ShowWarning($"Deleted time entry for {entry.GetProjectIdentifier()}");
        }
    }
}