using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using PraxisWpf.Features.TaskViewer;
using PraxisWpf.Services;

namespace PraxisWpf.Behaviors
{
    public static class TextBoxBehaviors
    {
        #region AutoFocusAndSelect

        public static readonly DependencyProperty AutoFocusAndSelectProperty =
            DependencyProperty.RegisterAttached(
                "AutoFocusAndSelect",
                typeof(bool),
                typeof(TextBoxBehaviors),
                new PropertyMetadata(false, OnAutoFocusAndSelectChanged));

        public static bool GetAutoFocusAndSelect(DependencyObject obj)
        {
            return (bool)obj.GetValue(AutoFocusAndSelectProperty);
        }

        public static void SetAutoFocusAndSelect(DependencyObject obj, bool value)
        {
            obj.SetValue(AutoFocusAndSelectProperty, value);
        }

        private static void OnAutoFocusAndSelectChanged(DependencyObject sender, DependencyPropertyChangedEventArgs e)
        {
            if (sender is TextBox textBox)
            {
                if ((bool)e.NewValue)
                {
                    textBox.Loaded += OnTextBoxLoaded;
                }
                else
                {
                    textBox.Loaded -= OnTextBoxLoaded;
                }
            }
        }

        private static void OnTextBoxLoaded(object sender, RoutedEventArgs e)
        {
            if (sender is TextBox textBox)
            {
                try
                {
                    textBox.Focus();
                    textBox.SelectAll();
                }
                catch (System.Exception ex)
                {
                    Logger.Error("TextBoxBehaviors", "Error in auto focus and select", ex);
                }
            }
        }

        #endregion

        #region EditModeKeyHandling

        public static readonly DependencyProperty EnableEditModeKeysProperty =
            DependencyProperty.RegisterAttached(
                "EnableEditModeKeys",
                typeof(bool),
                typeof(TextBoxBehaviors),
                new PropertyMetadata(false, OnEnableEditModeKeysChanged));

        public static bool GetEnableEditModeKeys(DependencyObject obj)
        {
            return (bool)obj.GetValue(EnableEditModeKeysProperty);
        }

        public static void SetEnableEditModeKeys(DependencyObject obj, bool value)
        {
            obj.SetValue(EnableEditModeKeysProperty, value);
        }

        private static void OnEnableEditModeKeysChanged(DependencyObject sender, DependencyPropertyChangedEventArgs e)
        {
            if (sender is TextBox textBox)
            {
                if ((bool)e.NewValue)
                {
                    textBox.KeyDown += OnEditModeKeyDown;
                }
                else
                {
                    textBox.KeyDown -= OnEditModeKeyDown;
                }
            }
        }

        private static void OnEditModeKeyDown(object sender, KeyEventArgs e)
        {
            if (sender is not TextBox textBox) return;

            try
            {
                // Find the TaskViewModel through the DataContext chain
                var viewModel = FindTaskViewModel(textBox);
                if (viewModel == null) return;

                switch (e.Key)
                {
                    case Key.Enter:
                        // Enter confirms the edit and exits edit mode
                        if (viewModel.SelectedItem != null)
                        {
                            viewModel.SelectedItem.IsInEditMode = false;
                            ReturnFocusToTreeView(textBox);
                        }
                        e.Handled = true;
                        break;

                    case Key.Escape:
                        // Escape cancels the edit and exits edit mode
                        if (viewModel.SelectedItem != null)
                        {
                            viewModel.SelectedItem.IsInEditMode = false;
                            ReturnFocusToTreeView(textBox);
                            // TODO: Implement undo functionality
                        }
                        e.Handled = true;
                        break;
                }
            }
            catch (System.Exception ex)
            {
                Logger.Error("TextBoxBehaviors", "Error handling edit mode key down", ex);
            }
        }

        private static TaskViewModel? FindTaskViewModel(DependencyObject element)
        {
            var current = element;
            while (current != null)
            {
                if (current is FrameworkElement fe && fe.DataContext is TaskViewModel viewModel)
                {
                    return viewModel;
                }
                current = LogicalTreeHelper.GetParent(current);
            }
            return null;
        }

        private static void ReturnFocusToTreeView(DependencyObject element)
        {
            var current = element;
            while (current != null)
            {
                if (current is TreeView treeView)
                {
                    treeView.Focus();
                    return;
                }
                current = LogicalTreeHelper.GetParent(current) ?? VisualTreeHelper.GetParent(current);
            }
        }

        #endregion
    }
}