using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using PraxisWpf.Features.TaskViewer;
using PraxisWpf.Models;
using PraxisWpf.Services;

namespace PraxisWpf.Behaviors
{
    public static class TreeViewBehaviors
    {
        #region BindableSelectedItem

        public static readonly DependencyProperty BindableSelectedItemProperty =
            DependencyProperty.RegisterAttached(
                "BindableSelectedItem",
                typeof(object),
                typeof(TreeViewBehaviors),
                new FrameworkPropertyMetadata(null, FrameworkPropertyMetadataOptions.BindsTwoWayByDefault, OnBindableSelectedItemChanged));

        public static object GetBindableSelectedItem(DependencyObject obj)
        {
            return obj.GetValue(BindableSelectedItemProperty);
        }

        public static void SetBindableSelectedItem(DependencyObject obj, object value)
        {
            obj.SetValue(BindableSelectedItemProperty, value);
        }

        private static void OnBindableSelectedItemChanged(DependencyObject sender, DependencyPropertyChangedEventArgs e)
        {
            if (sender is TreeView treeView)
            {
                treeView.SelectedItemChanged -= OnTreeViewSelectedItemChanged;
                treeView.SelectedItemChanged += OnTreeViewSelectedItemChanged;

                if (!ReferenceEquals(treeView.SelectedItem, e.NewValue))
                {
                    // Find and select the item
                    SelectItemInTreeView(treeView, e.NewValue);
                }
            }
        }

        private static void OnTreeViewSelectedItemChanged(object sender, RoutedPropertyChangedEventArgs<object> e)
        {
            if (sender is TreeView treeView)
            {
                SetBindableSelectedItem(treeView, e.NewValue);

                // Ensure focus and visibility
                if (e.NewValue != null)
                {
                    if (!treeView.IsFocused)
                    {
                        treeView.Focus();
                    }

                    var treeViewItem = treeView.ItemContainerGenerator.ContainerFromItem(e.NewValue) as TreeViewItem;
                    treeViewItem?.BringIntoView();
                }
            }
        }

        private static void SelectItemInTreeView(TreeView treeView, object item)
        {
            if (item == null) return;

            var treeViewItem = treeView.ItemContainerGenerator.ContainerFromItem(item) as TreeViewItem;
            if (treeViewItem != null)
            {
                treeViewItem.IsSelected = true;
                treeViewItem.Focus();
            }
        }

        #endregion

        #region KeyboardShortcuts

        public static readonly DependencyProperty EnableKeyboardShortcutsProperty =
            DependencyProperty.RegisterAttached(
                "EnableKeyboardShortcuts",
                typeof(bool),
                typeof(TreeViewBehaviors),
                new PropertyMetadata(false, OnEnableKeyboardShortcutsChanged));

        public static bool GetEnableKeyboardShortcuts(DependencyObject obj)
        {
            return (bool)obj.GetValue(EnableKeyboardShortcutsProperty);
        }

        public static void SetEnableKeyboardShortcuts(DependencyObject obj, bool value)
        {
            obj.SetValue(EnableKeyboardShortcutsProperty, value);
        }

        private static void OnEnableKeyboardShortcutsChanged(DependencyObject sender, DependencyPropertyChangedEventArgs e)
        {
            if (sender is TreeView treeView)
            {
                if ((bool)e.NewValue)
                {
                    treeView.KeyDown += OnTreeViewKeyDown;
                    treeView.Loaded += OnTreeViewLoaded;
                }
                else
                {
                    treeView.KeyDown -= OnTreeViewKeyDown;
                    treeView.Loaded -= OnTreeViewLoaded;
                }
            }
        }

        private static void OnTreeViewLoaded(object sender, RoutedEventArgs e)
        {
            if (sender is TreeView treeView)
            {
                treeView.Focus();

                // Hook window activation
                var window = Window.GetWindow(treeView);
                if (window != null)
                {
                    window.Activated += (s, args) => treeView.Focus();
                }
            }
        }

        private static void OnTreeViewKeyDown(object sender, KeyEventArgs e)
        {
            if (sender is not TreeView treeView || treeView.DataContext is not TaskViewModel viewModel)
                return;

            try
            {
                switch (e.Key)
                {
                    case Key.N:
                        ExecuteCommandIfPossible(viewModel.NewCommand);
                        e.Handled = true;
                        break;

                    case Key.E:
                        ExecuteCommandIfPossible(viewModel.EditCommand);
                        e.Handled = true;
                        break;

                    case Key.Delete:
                        ExecuteCommandIfPossible(viewModel.DeleteCommand);
                        e.Handled = true;
                        break;

                    case Key.S when (Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control:
                        ExecuteCommandIfPossible(viewModel.SaveCommand);
                        e.Handled = true;
                        break;

                    case Key.Enter:
                    case Key.Space:
                    case Key.F2:
                        ExecuteCommandIfPossible(viewModel.EditCommand);
                        e.Handled = true;
                        break;

                    case Key.Right:
                        if (viewModel.SelectedItem?.Children.Count > 0 && !viewModel.SelectedItem.IsExpanded)
                        {
                            viewModel.SelectedItem.IsExpanded = true;
                            e.Handled = true;
                        }
                        break;

                    case Key.Left:
                        if (viewModel.SelectedItem?.Children.Count > 0 && viewModel.SelectedItem.IsExpanded)
                        {
                            viewModel.SelectedItem.IsExpanded = false;
                            e.Handled = true;
                        }
                        break;

                    case Key.OemPlus:
                    case Key.Add:
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            ExecuteCommandIfPossible(viewModel.ExpandAllCommand);
                        }
                        else
                        {
                            ExecuteCommandIfPossible(viewModel.ExpandCommand);
                        }
                        e.Handled = true;
                        break;

                    case Key.OemMinus:
                    case Key.Subtract:
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            ExecuteCommandIfPossible(viewModel.CollapseAllCommand);
                        }
                        else
                        {
                            ExecuteCommandIfPossible(viewModel.CollapseCommand);
                        }
                        e.Handled = true;
                        break;
                }
            }
            catch (System.Exception ex)
            {
                Logger.Error("TreeViewBehaviors", "Error handling key down", ex);
            }
        }

        private static void ExecuteCommandIfPossible(ICommand command)
        {
            if (command?.CanExecute(null) == true)
            {
                command.Execute(null);
            }
        }

        #endregion
    }
}