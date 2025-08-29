namespace PraxisWpf.Interfaces
{
    public interface IDialogService
    {
        bool ShowConfirmationDialog(string title, string message, string details = "");
        void ShowWarningDialog(string title, string message, string details = "");
        void ShowErrorDialog(string title, string message, string details = "");
        void ShowInfoDialog(string title, string message, string details = "");
    }
}