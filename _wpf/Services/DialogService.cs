using System.Windows;
using PraxisWpf.Interfaces;

namespace PraxisWpf.Services
{
    public class DialogService : IDialogService
    {
        public bool ShowConfirmationDialog(string title, string message, string details = "")
        {
            var fullMessage = string.IsNullOrEmpty(details) ? message : $"{message}\n\n{details}";
            var result = MessageBox.Show(
                fullMessage,
                title,
                MessageBoxButton.YesNo,
                MessageBoxImage.Question,
                MessageBoxResult.No);

            Logger.Debug("DialogService", $"Confirmation dialog result: {result} for '{title}'");
            return result == MessageBoxResult.Yes;
        }

        public void ShowWarningDialog(string title, string message, string details = "")
        {
            var fullMessage = string.IsNullOrEmpty(details) ? message : $"{message}\n\n{details}";
            MessageBox.Show(
                fullMessage,
                title,
                MessageBoxButton.OK,
                MessageBoxImage.Warning);

            Logger.Debug("DialogService", $"Warning dialog shown: '{title}'");
        }

        public void ShowErrorDialog(string title, string message, string details = "")
        {
            var fullMessage = string.IsNullOrEmpty(details) ? message : $"{message}\n\n{details}";
            MessageBox.Show(
                fullMessage,
                title,
                MessageBoxButton.OK,
                MessageBoxImage.Error);

            Logger.Debug("DialogService", $"Error dialog shown: '{title}'");
        }

        public void ShowInfoDialog(string title, string message, string details = "")
        {
            var fullMessage = string.IsNullOrEmpty(details) ? message : $"{message}\n\n{details}";
            MessageBox.Show(
                fullMessage,
                title,
                MessageBoxButton.OK,
                MessageBoxImage.Information);

            Logger.Debug("DialogService", $"Info dialog shown: '{title}'");
        }
    }
}