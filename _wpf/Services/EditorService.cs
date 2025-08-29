using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using PraxisWpf.Interfaces;

namespace PraxisWpf.Services
{
    public class EditorService : IEditorService
    {
        private readonly IPreferencesService _preferencesService;
        private readonly IDialogService _dialogService;
        private readonly string _notesDirectory;

        public EditorService(IPreferencesService preferencesService, IDialogService dialogService)
        {
            _preferencesService = preferencesService;
            _dialogService = dialogService;
            _notesDirectory = Path.Combine(Environment.CurrentDirectory, "Notes");
            
            // Ensure notes directory exists
            if (!Directory.Exists(_notesDirectory))
            {
                Directory.CreateDirectory(_notesDirectory);
                Logger.Info("EditorService", $"Created notes directory: {_notesDirectory}");
            }
        }

        public async Task<bool> OpenNotesAsync(string projectName, string? existingContent = null)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(projectName))
                {
                    Logger.Warning("EditorService", "Project name is empty");
                    return false;
                }

                var notesFilePath = GetNotesFilePath(projectName);
                
                // Create notes file if it doesn't exist
                if (!File.Exists(notesFilePath))
                {
                    var createdPath = await CreateNotesFileAsync(projectName, existingContent ?? "");
                    if (string.IsNullOrEmpty(createdPath))
                    {
                        return false;
                    }
                }
                else if (!string.IsNullOrEmpty(existingContent))
                {
                    // Update existing file with content
                    await File.WriteAllTextAsync(notesFilePath, existingContent);
                    Logger.Debug("EditorService", $"Updated notes file: {notesFilePath}");
                }

                return await OpenFileAsync(notesFilePath);
            }
            catch (Exception ex)
            {
                Logger.Error("EditorService", $"Failed to open notes for project '{projectName}'", ex);
                _dialogService.ShowErrorDialog("Editor Error", 
                    $"Failed to open notes for project '{projectName}'", 
                    ex.Message);
                return false;
            }
        }

        public async Task<bool> OpenFileAsync(string filePath)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(filePath) || !File.Exists(filePath))
                {
                    Logger.Warning("EditorService", $"File does not exist: {filePath}");
                    return false;
                }

                var preferences = _preferencesService.LoadPreferences();
                
                if (!preferences.Editor.UseExternalEditor || !IsExternalEditorConfigured())
                {
                    // Use system default
                    return await OpenWithSystemDefaultAsync(filePath);
                }

                return await OpenWithExternalEditorAsync(filePath, preferences.Editor.ExternalEditorPath, preferences.Editor.ExternalEditorArgs);
            }
            catch (Exception ex)
            {
                Logger.Error("EditorService", $"Failed to open file: {filePath}", ex);
                _dialogService.ShowErrorDialog("Editor Error", 
                    $"Failed to open file: {Path.GetFileName(filePath)}", 
                    ex.Message);
                return false;
            }
        }

        public async Task<string?> CreateNotesFileAsync(string projectName, string initialContent = "")
        {
            try
            {
                var fileName = SanitizeFileName(projectName) + ".md";
                var filePath = Path.Combine(_notesDirectory, fileName);
                
                var content = string.IsNullOrWhiteSpace(initialContent) 
                    ? CreateDefaultNotesContent(projectName)
                    : initialContent;

                await File.WriteAllTextAsync(filePath, content);
                Logger.Info("EditorService", $"Created notes file: {filePath}");
                
                return filePath;
            }
            catch (Exception ex)
            {
                Logger.Error("EditorService", $"Failed to create notes file for project '{projectName}'", ex);
                return null;
            }
        }

        public async Task<string?> GetNotesContentAsync(string projectName)
        {
            try
            {
                var filePath = GetNotesFilePath(projectName);
                
                if (!File.Exists(filePath))
                {
                    return null;
                }

                return await File.ReadAllTextAsync(filePath);
            }
            catch (Exception ex)
            {
                Logger.Error("EditorService", $"Failed to read notes content for project '{projectName}'", ex);
                return null;
            }
        }

        public bool IsExternalEditorConfigured()
        {
            try
            {
                var preferences = _preferencesService.LoadPreferences();
                return preferences.Editor.UseExternalEditor && 
                       !string.IsNullOrWhiteSpace(preferences.Editor.ExternalEditorPath);
            }
            catch (Exception ex)
            {
                Logger.Error("EditorService", "Failed to check external editor configuration", ex);
                return false;
            }
        }

        public bool ValidateEditorConfiguration()
        {
            try
            {
                var preferences = _preferencesService.LoadPreferences();
                
                if (!preferences.Editor.UseExternalEditor)
                {
                    return true; // System default is always valid
                }

                if (string.IsNullOrWhiteSpace(preferences.Editor.ExternalEditorPath))
                {
                    return false;
                }

                return File.Exists(preferences.Editor.ExternalEditorPath);
            }
            catch (Exception ex)
            {
                Logger.Error("EditorService", "Failed to validate editor configuration", ex);
                return false;
            }
        }

        public string GetNotesFilePath(string projectName)
        {
            var fileName = SanitizeFileName(projectName) + ".md";
            return Path.Combine(_notesDirectory, fileName);
        }

        #region Private Methods

        private async Task<bool> OpenWithExternalEditorAsync(string filePath, string editorPath, string editorArgs)
        {
            try
            {
                var arguments = string.Format(editorArgs ?? "\"{0}\"", filePath);
                
                var startInfo = new ProcessStartInfo
                {
                    FileName = editorPath,
                    Arguments = arguments,
                    UseShellExecute = true,
                    CreateNoWindow = false
                };

                using var process = Process.Start(startInfo);
                if (process == null)
                {
                    Logger.Error("EditorService", "Failed to start external editor process");
                    return false;
                }

                Logger.Info("EditorService", $"Opened file with external editor: {filePath}");
                
                // Don't wait for the editor to close - let it run independently
                return true;
            }
            catch (Exception ex)
            {
                Logger.Error("EditorService", $"Failed to open with external editor: {editorPath}", ex);
                
                // Fallback to system default
                Logger.Info("EditorService", "Falling back to system default editor");
                return await OpenWithSystemDefaultAsync(filePath);
            }
        }

        private async Task<bool> OpenWithSystemDefaultAsync(string filePath)
        {
            try
            {
                var startInfo = new ProcessStartInfo
                {
                    FileName = filePath,
                    UseShellExecute = true,
                    Verb = "open"
                };

                using var process = Process.Start(startInfo);
                if (process == null)
                {
                    Logger.Error("EditorService", "Failed to start system default editor");
                    return false;
                }

                Logger.Info("EditorService", $"Opened file with system default: {filePath}");
                return true;
            }
            catch (Exception ex)
            {
                Logger.Error("EditorService", "Failed to open with system default", ex);
                return false;
            }
        }

        private string CreateDefaultNotesContent(string projectName)
        {
            return $"""
# {projectName} - Project Notes

## Overview
<!-- Project description and goals -->

## Tasks
<!-- Key tasks and milestones -->

## Notes
<!-- General notes and observations -->

## Links
<!-- Useful links and references -->

## Created: {DateTime.Now:yyyy-MM-dd HH:mm}
""";
        }

        private static string SanitizeFileName(string fileName)
        {
            if (string.IsNullOrWhiteSpace(fileName))
            {
                return "Untitled";
            }

            // Remove invalid characters and replace with underscores
            var invalidChars = Path.GetInvalidFileNameChars();
            var sanitized = fileName;
            
            foreach (var invalidChar in invalidChars)
            {
                sanitized = sanitized.Replace(invalidChar, '_');
            }
            
            // Also replace some problematic characters
            sanitized = sanitized.Replace(' ', '_')
                                 .Replace('.', '_')
                                 .Replace(':', '_');
            
            // Limit length
            if (sanitized.Length > 50)
            {
                sanitized = sanitized.Substring(0, 50);
            }
            
            return sanitized;
        }

        #endregion
    }
}