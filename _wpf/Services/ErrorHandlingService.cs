using System;
using System.Windows;

namespace PraxisWpf.Services
{
    /// <summary>
    /// Centralized error handling and user notification service.
    /// Provides consistent error reporting across the application.
    /// </summary>
    public static class ErrorHandlingService
    {
        /// <summary>
        /// Shows an error message to the user and logs the error.
        /// </summary>
        /// <param name="context">The context where the error occurred (e.g., class name)</param>
        /// <param name="userMessage">User-friendly error message</param>
        /// <param name="exception">The exception that occurred (optional)</param>
        /// <param name="technicalDetails">Additional technical details to show (optional)</param>
        public static void HandleError(string context, string userMessage, Exception? exception = null, string? technicalDetails = null)
        {
            // Log the error
            if (exception != null)
            {
                Logger.Error(context, userMessage, exception);
            }
            else
            {
                Logger.Error(context, userMessage);
            }

            // Prepare user message
            var displayMessage = userMessage;
            if (!string.IsNullOrEmpty(technicalDetails))
            {
                displayMessage += $"\n\nTechnical details: {technicalDetails}";
            }

            // Show to user
            ShowErrorToUser("Error", displayMessage);
        }

        /// <summary>
        /// Shows a warning message to the user and logs the warning.
        /// </summary>
        /// <param name="context">The context where the warning occurred</param>
        /// <param name="userMessage">User-friendly warning message</param>
        /// <param name="technicalDetails">Additional technical details (optional)</param>
        public static void HandleWarning(string context, string userMessage, string? technicalDetails = null)
        {
            Logger.Warning(context, userMessage);

            var displayMessage = userMessage;
            if (!string.IsNullOrEmpty(technicalDetails))
            {
                displayMessage += $"\n\nDetails: {technicalDetails}";
            }

            ShowWarningToUser("Warning", displayMessage);
        }

        /// <summary>
        /// Shows a critical error that may require application shutdown.
        /// </summary>
        /// <param name="context">The context where the critical error occurred</param>
        /// <param name="userMessage">User-friendly error message</param>
        /// <param name="exception">The exception that occurred</param>
        /// <param name="shouldExit">Whether the application should exit after showing the message</param>
        public static void HandleCriticalError(string context, string userMessage, Exception exception, bool shouldExit = false)
        {
            Logger.Critical(context, userMessage, exception);

            var displayMessage = $"{userMessage}\n\nThis is a critical error that may require restarting the application.";
            if (exception != null)
            {
                displayMessage += $"\n\nError details: {exception.Message}";
            }

            var result = MessageBox.Show(
                displayMessage,
                "Critical Error",
                shouldExit ? MessageBoxButton.OK : MessageBoxButton.OKCancel,
                MessageBoxImage.Error);

            if (shouldExit || result == MessageBoxResult.OK && shouldExit)
            {
                Application.Current?.Shutdown();
            }
        }

        /// <summary>
        /// Shows a validation error to the user.
        /// </summary>
        /// <param name="context">The context where validation failed</param>
        /// <param name="validationMessage">The validation error message</param>
        public static void HandleValidationError(string context, string validationMessage)
        {
            Logger.Warning(context, $"Validation failed: {validationMessage}");
            
            MessageBox.Show(
                $"Validation Error:\n\n{validationMessage}",
                "Input Validation",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
        }

        /// <summary>
        /// Asks the user to confirm a potentially destructive action.
        /// </summary>
        /// <param name="message">The confirmation message</param>
        /// <param name="title">The dialog title (optional)</param>
        /// <returns>True if user confirmed, false otherwise</returns>
        public static bool ConfirmAction(string message, string title = "Confirm Action")
        {
            var result = MessageBox.Show(
                message,
                title,
                MessageBoxButton.YesNo,
                MessageBoxImage.Question,
                MessageBoxResult.No); // Default to No for safety

            return result == MessageBoxResult.Yes;
        }

        private static void ShowErrorToUser(string title, string message)
        {
            try
            {
                MessageBox.Show(message, title, MessageBoxButton.OK, MessageBoxImage.Error);
            }
            catch (Exception ex)
            {
                // Last resort - if we can't even show a message box, log it
                Logger.Critical("ErrorHandlingService", "Failed to show error message to user", ex);
            }
        }

        private static void ShowWarningToUser(string title, string message)
        {
            try
            {
                MessageBox.Show(message, title, MessageBoxButton.OK, MessageBoxImage.Warning);
            }
            catch (Exception ex)
            {
                // Convert to error log if warning display fails
                Logger.Error("ErrorHandlingService", "Failed to show warning message to user", ex);
            }
        }
    }
}