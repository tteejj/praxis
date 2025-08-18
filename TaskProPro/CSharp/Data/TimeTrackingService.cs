using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using TaskPro.Core;

namespace TaskPro.Data {
    public class TimeTrackingService {
        private string dataPath;
        private List<SimpleTimeEntry> timeEntries;
        private DateTime currentWeekFriday;
        
        public List<SimpleTimeEntry> TimeEntries => timeEntries;
        public DateTime CurrentWeekFriday => currentWeekFriday;
        
        public TimeTrackingService(string dataDirectory = null) {
            dataPath = dataDirectory ?? Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Data");
            timeEntries = new List<SimpleTimeEntry>();
            currentWeekFriday = GetCurrentWeekFriday();
            InitializeDataDirectory();
            LoadTimeEntries();
        }
        
        private void InitializeDataDirectory() {
            if (!Directory.Exists(dataPath)) {
                Directory.CreateDirectory(dataPath);
            }
            
            // Create backups directory
            var backupPath = Path.Combine(dataPath, "backups");
            if (!Directory.Exists(backupPath)) {
                Directory.CreateDirectory(backupPath);
            }
        }
        
        public void LoadTimeEntries() {
            var filePath = Path.Combine(dataPath, "timeentries.json");
            
            if (File.Exists(filePath)) {
                try {
                    var jsonContent = File.ReadAllText(filePath);
                    var data = JsonSerializer.Deserialize<List<SimpleTimeEntry>>(jsonContent);
                    
                    timeEntries = data ?? new List<SimpleTimeEntry>();
                    
                    // Recalculate totals and fix fiscal years
                    foreach (var entry in timeEntries) {
                        entry.CalculateTotal();
                        if (string.IsNullOrEmpty(entry.FiscalYear)) {
                            entry.FiscalYear = entry.CalculateFiscalYear();
                        }
                    }
                }
                catch (Exception ex) {
                    throw new TaskProException($"Error loading time entries: {ex.Message}", ex);
                }
            } else {
                // Create sample data for testing
                CreateSampleData();
            }
        }
        
        public void SaveTimeEntries() {
            try {
                // Create backup first
                CreateBackup();
                
                // Save to JSON
                var filePath = Path.Combine(dataPath, "timeentries.json");
                var options = new JsonSerializerOptions {
                    WriteIndented = true,
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                };
                
                var jsonContent = JsonSerializer.Serialize(timeEntries, options);
                File.WriteAllText(filePath, jsonContent);
            }
            catch (Exception ex) {
                throw new DataPersistenceException($"Error saving time entries: {ex.Message}", ex);
            }
        }
        
        private void CreateBackup() {
            var filePath = Path.Combine(dataPath, "timeentries.json");
            if (File.Exists(filePath)) {
                var timestamp = DateTime.Now.ToString("yyyyMMdd_HHmmss");
                var backupPath = Path.Combine(dataPath, "backups", $"timeentries_backup_{timestamp}.json");
                File.Copy(filePath, backupPath);
            }
        }
        
        private void CreateSampleData() {
            // Create some sample time entries for the current week
            var currentWeek = GetCurrentWeekFriday().ToString("yyyyMMdd");
            
            // Sample project entries with ID1/ID2 structure
            var project1 = new SimpleTimeEntry(currentWeek, "PROJ", "TASKPRO") {
                Description = "TaskProPro Development",
                Monday = 8.0m,
                Tuesday = 7.5m,
                Wednesday = 8.0m,
                IsLinkedToTask = true
            };
            project1.CalculateTotal();
            
            var project2 = new SimpleTimeEntry(currentWeek, "PROJ", "REVIEW") {
                Description = "Code Review and Testing",
                Thursday = 4.0m,
                Friday = 6.0m,
                IsLinkedToTask = true
            };
            project2.CalculateTotal();
            
            // Sample generic time code entry
            var meeting = new SimpleTimeEntry(currentWeek, "MEET") {
                Description = "Team meetings and planning",
                Friday = 2.0m,
                IsLinkedToTask = false
            };
            meeting.CalculateTotal();
            
            timeEntries = new List<SimpleTimeEntry> { project1, project2, meeting };
            SaveTimeEntries();
        }
        
        // Data Access Methods
        public List<SimpleTimeEntry> GetCurrentWeekEntries() {
            var currentWeek = currentWeekFriday.ToString("yyyyMMdd");
            return timeEntries.Where(e => e.WeekEndingFriday == currentWeek).ToList();
        }
        
        public List<SimpleTimeEntry> GetWeekEntries(string weekEndingFriday) {
            return timeEntries.Where(e => e.WeekEndingFriday == weekEndingFriday).ToList();
        }
        
        public List<SimpleTimeEntry> GetAllEntries() {
            return new List<SimpleTimeEntry>(timeEntries);
        }
        
        public void AddTimeEntry(SimpleTimeEntry entry) {
            if (entry == null) throw new ArgumentNullException(nameof(entry));
            
            // Ensure unique ID
            if (timeEntries.Any(e => e.Id == entry.Id)) {
                entry.Id = Guid.NewGuid().ToString();
            }
            
            entry.CalculateTotal();
            entry.Touch();
            timeEntries.Add(entry);
            SaveTimeEntries();
        }
        
        public void UpdateTimeEntry(SimpleTimeEntry entry) {
            if (entry == null) throw new ArgumentNullException(nameof(entry));
            
            var index = timeEntries.FindIndex(e => e.Id == entry.Id);
            if (index >= 0) {
                entry.CalculateTotal();
                entry.Touch();
                timeEntries[index] = entry;
                SaveTimeEntries();
            } else {
                throw new ArgumentException($"Time entry with ID {entry.Id} not found");
            }
        }
        
        public void DeleteTimeEntry(string id) {
            var index = timeEntries.FindIndex(e => e.Id == id);
            if (index >= 0) {
                timeEntries.RemoveAt(index);
                SaveTimeEntries();
            }
        }
        
        public SimpleTimeEntry GetTimeEntry(string id) {
            return timeEntries.FirstOrDefault(e => e.Id == id);
        }
        
        // Week Navigation Methods
        public DateTime GetCurrentWeekFriday() {
            var today = DateTime.Today;
            var daysUntilFriday = ((int)DayOfWeek.Friday - (int)today.DayOfWeek + 7) % 7;
            if (daysUntilFriday == 0 && today.DayOfWeek != DayOfWeek.Friday) {
                daysUntilFriday = 7;
            }
            
            return today.AddDays(daysUntilFriday);
        }
        
        public void NavigateToWeek(DateTime weekEndingFriday) {
            currentWeekFriday = weekEndingFriday;
        }
        
        public void NavigateToCurrentWeek() {
            currentWeekFriday = GetCurrentWeekFriday();
        }
        
        public void NavigateToPreviousWeek() {
            currentWeekFriday = currentWeekFriday.AddDays(-7);
        }
        
        public void NavigateToNextWeek() {
            currentWeekFriday = currentWeekFriday.AddDays(7);
        }
        
        public string GetWeekDisplayString() {
            var mondayDate = currentWeekFriday.AddDays(-4);
            return $"{mondayDate:MMM dd} - {currentWeekFriday:MMM dd, yyyy}";
        }
        
        public bool IsCurrentWeek() {
            var actualCurrentFriday = GetCurrentWeekFriday();
            return currentWeekFriday.Date == actualCurrentFriday.Date;
        }
        
        // Statistics and Summary Methods
        public decimal GetWeekTotal(string weekEndingFriday) {
            var weekEntries = GetWeekEntries(weekEndingFriday);
            return weekEntries.Sum(e => e.Total);
        }
        
        public decimal GetCurrentWeekTotal() {
            return GetWeekTotal(currentWeekFriday.ToString("yyyyMMdd"));
        }
        
        public List<(string ProjectCode, string Description, decimal Total, bool IsProjectEntry)> GetWeekSummary(string weekEndingFriday) {
            var weekEntries = GetWeekEntries(weekEndingFriday);
            return weekEntries.Select(e => (
                ProjectCode: e.ID2,  // Use ID2 as project code
                Description: e.Description,
                Total: e.Total,
                IsProjectEntry: !string.IsNullOrEmpty(e.ID2)  // Project entry if ID2 is set
            )).ToList();
        }
        
        // Validation Methods
        public bool ValidateTimeEntry(SimpleTimeEntry entry, out List<string> errors) {
            errors = new List<string>();
            
            if (string.IsNullOrWhiteSpace(entry.ID1)) {
                errors.Add("ID1 (time code) is required");
            }
            
            if (entry.ID1?.Length > 20) {
                errors.Add("ID1 must be 20 characters or less");
            }
            
            if (entry.ID2?.Length > 20) {
                errors.Add("ID2 must be 20 characters or less");
            }
            
            if (entry.Description?.Length > 200) {
                errors.Add("Description must be 200 characters or less");
            }
            
            if (entry.Monday < 0 || entry.Monday > 24) {
                errors.Add("Monday hours must be between 0 and 24");
            }
            
            if (entry.Tuesday < 0 || entry.Tuesday > 24) {
                errors.Add("Tuesday hours must be between 0 and 24");
            }
            
            if (entry.Wednesday < 0 || entry.Wednesday > 24) {
                errors.Add("Wednesday hours must be between 0 and 24");
            }
            
            if (entry.Thursday < 0 || entry.Thursday > 24) {
                errors.Add("Thursday hours must be between 0 and 24");
            }
            
            if (entry.Friday < 0 || entry.Friday > 24) {
                errors.Add("Friday hours must be between 0 and 24");
            }
            
            // Check for duplicate ID1/ID2 combinations in the same week
            var existingEntry = timeEntries.FirstOrDefault(e => 
                e.Id != entry.Id && 
                e.WeekEndingFriday == entry.WeekEndingFriday && 
                e.ID1?.ToUpper() == entry.ID1?.ToUpper() &&
                e.ID2?.ToUpper() == entry.ID2?.ToUpper());
                
            if (existingEntry != null) {
                var identifier = string.IsNullOrEmpty(entry.ID2) ? entry.ID1 : $"{entry.ID1}/{entry.ID2}";
                errors.Add($"Time entry '{identifier}' already exists for this week");
            }
            
            return errors.Count == 0;
        }
        
        // Bulk Operations
        public void ImportTimeEntries(List<SimpleTimeEntry> entries) {
            foreach (var entry in entries) {
                if (ValidateTimeEntry(entry, out var errors)) {
                    AddTimeEntry(entry);
                } else {
                    throw new ArgumentException($"Invalid time entry for {entry.ID2}: {string.Join(", ", errors)}");
                }
            }
        }
        
        public List<SimpleTimeEntry> ExportWeekEntries(string weekEndingFriday) {
            return GetWeekEntries(weekEndingFriday);
        }
        
        // Search and Filter Methods
        public List<SimpleTimeEntry> SearchEntries(string searchTerm) {
            if (string.IsNullOrWhiteSpace(searchTerm)) {
                return new List<SimpleTimeEntry>(timeEntries);
            }
            
            searchTerm = searchTerm.ToLower();
            return timeEntries.Where(e => 
                e.ID2.ToLower().Contains(searchTerm) ||
                e.Description.ToLower().Contains(searchTerm)
            ).ToList();
        }
        
        public List<SimpleTimeEntry> GetProjectEntries() {
            return timeEntries.Where(e => !string.IsNullOrEmpty(e.ID2)).ToList();
        }
        
        public List<SimpleTimeEntry> GetTimeCodeEntries() {
            return timeEntries.Where(e => string.IsNullOrEmpty(e.ID2)).ToList();
        }
        
        public List<string> GetUniqueID1Codes() {
            return timeEntries.Select(e => e.ID1)
                             .Where(code => !string.IsNullOrEmpty(code))
                             .Distinct()
                             .OrderBy(code => code)
                             .ToList();
        }
        
        public List<string> GetUniqueID2Codes() {
            return timeEntries.Select(e => e.ID2)
                             .Where(code => !string.IsNullOrEmpty(code))
                             .Distinct()
                             .OrderBy(code => code)
                             .ToList();
        }
        
        // Cumulative Hours Methods
        public WeeklySummary GetWeeklySummary(string weekEndingFriday) {
            var weekEntries = GetWeekEntries(weekEndingFriday);
            var summary = new WeeklySummary {
                WeekEndingFriday = weekEndingFriday,
                WeekDisplay = new SimpleTimeEntry { WeekEndingFriday = weekEndingFriday }.GetWeekDisplayString()
            };
            
            // Calculate totals by day
            summary.MondayTotal = weekEntries.Sum(e => e.Monday);
            summary.TuesdayTotal = weekEntries.Sum(e => e.Tuesday);
            summary.WednesdayTotal = weekEntries.Sum(e => e.Wednesday);
            summary.ThursdayTotal = weekEntries.Sum(e => e.Thursday);
            summary.FridayTotal = weekEntries.Sum(e => e.Friday);
            summary.WeekTotal = weekEntries.Sum(e => e.Total);
            
            // Group by ID1 for category breakdown
            var byID1 = weekEntries.GroupBy(e => e.ID1).ToList();
            foreach (var group in byID1) {
                summary.CategoryTotals.Add(group.Key, group.Sum(e => e.Total));
            }
            
            // Group by ID1/ID2 for project breakdown
            var byProject = weekEntries.Where(e => !string.IsNullOrEmpty(e.ID2))
                                     .GroupBy(e => $"{e.ID1}/{e.ID2}").ToList();
            foreach (var group in byProject) {
                summary.ProjectTotals.Add(group.Key, group.Sum(e => e.Total));
            }
            
            summary.TotalEntries = weekEntries.Count;
            
            return summary;
        }
        
        public WeeklySummary GetCurrentWeeklySummary() {
            return GetWeeklySummary(currentWeekFriday.ToString("yyyyMMdd"));
        }
        
        public List<WeeklySummary> GetWeeklySummariesForRange(DateTime startDate, DateTime endDate) {
            var summaries = new List<WeeklySummary>();
            var current = startDate;
            
            while (current <= endDate) {
                // Get Friday of the week containing current date
                var fridayOfWeek = current.AddDays((int)DayOfWeek.Friday - (int)current.DayOfWeek);
                if (fridayOfWeek < current) {
                    fridayOfWeek = fridayOfWeek.AddDays(7);
                }
                
                var weekString = fridayOfWeek.ToString("yyyyMMdd");
                var summary = GetWeeklySummary(weekString);
                
                if (!summaries.Any(s => s.WeekEndingFriday == weekString)) {
                    summaries.Add(summary);
                }
                
                current = current.AddDays(7);
            }
            
            return summaries.OrderBy(s => s.WeekEndingFriday).ToList();
        }
    }
    
    public class WeeklySummary {
        public string WeekEndingFriday { get; set; } = "";
        public string WeekDisplay { get; set; } = "";
        
        // Daily totals
        public decimal MondayTotal { get; set; } = 0m;
        public decimal TuesdayTotal { get; set; } = 0m;
        public decimal WednesdayTotal { get; set; } = 0m;
        public decimal ThursdayTotal { get; set; } = 0m;
        public decimal FridayTotal { get; set; } = 0m;
        public decimal WeekTotal { get; set; } = 0m;
        
        // Category breakdowns
        public Dictionary<string, decimal> CategoryTotals { get; set; } = new Dictionary<string, decimal>();
        public Dictionary<string, decimal> ProjectTotals { get; set; } = new Dictionary<string, decimal>();
        
        public int TotalEntries { get; set; } = 0;
        
        public string GetCyberpunkWeekTotal() {
            if (WeekTotal == 0) return "---.--";
            return WeekTotal.ToString("F1").PadLeft(6);
        }
        
        public ConsoleColor GetWeekTotalColor() {
            if (WeekTotal == 0) return ConsoleColor.DarkGray;
            if (WeekTotal >= 40) return ConsoleColor.Red;      // Overtime
            if (WeekTotal >= 35) return ConsoleColor.Yellow;   // Full week
            if (WeekTotal >= 20) return ConsoleColor.Green;    // Partial week
            return ConsoleColor.Cyan;                          // Low hours
        }
    }
}