using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using PraxisWpf.Models;
using PraxisWpf.Services;

namespace PraxisWpf.Behaviors
{
    public static class KeyboardNavigationBehavior
    {
        #region EnableEnhancedNavigation

        public static readonly DependencyProperty EnableEnhancedNavigationProperty =
            DependencyProperty.RegisterAttached(
                "EnableEnhancedNavigation",
                typeof(bool),
                typeof(KeyboardNavigationBehavior),
                new PropertyMetadata(false, OnEnableEnhancedNavigationChanged));

        public static bool GetEnhancedNavigation(DependencyObject obj)
        {
            return (bool)obj.GetValue(EnableEnhancedNavigationProperty);
        }

        public static void SetEnhancedNavigation(DependencyObject obj, bool value)
        {
            obj.SetValue(EnableEnhancedNavigationProperty, value);
        }

        private static void OnEnhancedNavigationChanged(DependencyObject sender, DependencyPropertyChangedEventArgs e)
        {
            if (sender is TreeView treeView)
            {
                if ((bool)e.NewValue)
                {
                    treeView.PreviewKeyDown += OnTreeViewPreviewKeyDown;
                    treeView.KeyDown += OnTreeViewKeyDown;
                }
                else
                {
                    treeView.PreviewKeyDown -= OnTreeViewPreviewKeyDown;
                    treeView.KeyDown -= OnTreeViewKeyDown;
                }
            }
        }

        #endregion

        #region Navigation State

        private static readonly Dictionary<TreeView, NavigationState> _navigationStates = new();

        private class NavigationState
        {
            public DateTime LastNavigationTime { get; set; }
            public Key LastNavigationKey { get; set; }
            public int RepeatCount { get; set; }
            public List<object> VisitedItems { get; set; } = new();
        }

        #endregion

        #region Event Handlers

        private static void OnTreeViewPreviewKeyDown(object sender, KeyEventArgs e)
        {
            if (sender is not TreeView treeView) return;

            try
            {
                // Handle navigation keys that need preview handling
                switch (e.Key)
                {
                    case Key.Home:
                        NavigateToFirst(treeView);
                        e.Handled = true;
                        break;

                    case Key.End:
                        NavigateToLast(treeView);
                        e.Handled = true;
                        break;

                    case Key.PageUp:
                        NavigatePageUp(treeView);
                        e.Handled = true;
                        break;

                    case Key.PageDown:
                        NavigatePageDown(treeView);
                        e.Handled = true;
                        break;

                    case Key.Tab:
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            NavigateToNextSibling(treeView, (Keyboard.Modifiers & ModifierKeys.Shift) == ModifierKeys.Shift);
                            e.Handled = true;
                        }
                        break;
                }
            }
            catch (Exception ex)
            {
                Logger.Error("KeyboardNavigationBehavior", "Error in preview key down", ex);
            }
        }

        private static void OnTreeViewKeyDown(object sender, KeyEventArgs e)
        {
            if (sender is not TreeView treeView) return;

            try
            {
                UpdateNavigationState(treeView, e.Key);

                // Handle enhanced navigation keys
                switch (e.Key)
                {
                    case Key.J:
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            NavigateDown(treeView);
                            e.Handled = true;
                        }
                        break;

                    case Key.K:
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            NavigateUp(treeView);
                            e.Handled = true;
                        }
                        break;

                    case Key.H:
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            NavigateToParent(treeView);
                            e.Handled = true;
                        }
                        break;

                    case Key.L:
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            NavigateToChild(treeView);
                            e.Handled = true;
                        }
                        break;

                    case Key.G:
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            if ((Keyboard.Modifiers & ModifierKeys.Shift) == ModifierKeys.Shift)
                            {
                                NavigateToLast(treeView); // Ctrl+Shift+G
                            }
                            else
                            {
                                NavigateToFirst(treeView); // Ctrl+G
                            }
                            e.Handled = true;
                        }
                        break;

                    case Key.F:
                        if ((Keyboard.Modifiers & ModifierKeys.Control) == ModifierKeys.Control)
                        {
                            // Quick search functionality could be added here
                            Logger.Debug("KeyboardNavigationBehavior", "Quick search triggered (not implemented)");
                            e.Handled = true;
                        }
                        break;

                    case Key.B:
                        if ((Keyboard.Modifiers & ModifierKeys.Alt) == ModifierKeys.Alt)
                        {
                            NavigateBack(treeView);
                            e.Handled = true;
                        }
                        break;

                    // Number keys for quick navigation
                    case Key.D1:
                    case Key.D2:
                    case Key.D3:
                    case Key.D4:
                    case Key.D5:
                    case Key.D6:
                    case Key.D7:
                    case Key.D8:
                    case Key.D9:
                        if ((Keyboard.Modifiers & ModifierKeys.Alt) == ModifierKeys.Alt)
                        {
                            var index = e.Key - Key.D1; // 0-8
                            NavigateToIndex(treeView, index);
                            e.Handled = true;
                        }
                        break;
                }
            }
            catch (Exception ex)
            {
                Logger.Error("KeyboardNavigationBehavior", "Error in key down", ex);
            }
        }

        #endregion

        #region Navigation Methods

        private static void NavigateToFirst(TreeView treeView)
        {
            var firstItem = GetFirstVisibleItem(treeView);
            if (firstItem != null)
            {
                SelectTreeViewItem(treeView, firstItem);
                Logger.Debug("KeyboardNavigationBehavior", "Navigated to first item");
            }
        }

        private static void NavigateToLast(TreeView treeView)
        {
            var lastItem = GetLastVisibleItem(treeView);
            if (lastItem != null)
            {
                SelectTreeViewItem(treeView, lastItem);
                Logger.Debug("KeyboardNavigationBehavior", "Navigated to last item");
            }
        }

        private static void NavigatePageUp(TreeView treeView)
        {
            // Simulate page up by moving 10 items up
            for (int i = 0; i < 10; i++)
            {
                NavigateUp(treeView);
            }
            Logger.Debug("KeyboardNavigationBehavior", "Page up navigation");
        }

        private static void NavigatePageDown(TreeView treeView)
        {
            // Simulate page down by moving 10 items down
            for (int i = 0; i < 10; i++)
            {
                NavigateDown(treeView);
            }
            Logger.Debug("KeyboardNavigationBehavior", "Page down navigation");
        }

        private static void NavigateUp(TreeView treeView)
        {
            var currentItem = treeView.SelectedItem;
            if (currentItem == null) return;

            var allItems = GetAllVisibleItems(treeView).ToList();
            var currentIndex = allItems.IndexOf(currentItem);
            
            if (currentIndex > 0)
            {
                SelectTreeViewItem(treeView, allItems[currentIndex - 1]);
            }
        }

        private static void NavigateDown(TreeView treeView)
        {
            var currentItem = treeView.SelectedItem;
            if (currentItem == null) return;

            var allItems = GetAllVisibleItems(treeView).ToList();
            var currentIndex = allItems.IndexOf(currentItem);
            
            if (currentIndex >= 0 && currentIndex < allItems.Count - 1)
            {
                SelectTreeViewItem(treeView, allItems[currentIndex + 1]);
            }
        }

        private static void NavigateToParent(TreeView treeView)
        {
            if (treeView.SelectedItem is TaskItem currentTask)
            {
                var parent = FindParentTask(treeView, currentTask);
                if (parent != null)
                {
                    SelectTreeViewItem(treeView, parent);
                    Logger.Debug("KeyboardNavigationBehavior", "Navigated to parent");
                }
            }
        }

        private static void NavigateToChild(TreeView treeView)
        {
            if (treeView.SelectedItem is TaskItem currentTask && currentTask.Children.Count > 0)
            {
                if (!currentTask.IsExpanded)
                {
                    currentTask.IsExpanded = true;
                }
                SelectTreeViewItem(treeView, currentTask.Children[0]);
                Logger.Debug("KeyboardNavigationBehavior", "Navigated to first child");
            }
        }

        private static void NavigateToNextSibling(TreeView treeView, bool reverse = false)
        {
            if (treeView.SelectedItem is not TaskItem currentTask) return;

            var parent = FindParentTask(treeView, currentTask);
            var siblings = parent?.Children ?? treeView.ItemsSource as System.Collections.ObjectModel.ObservableCollection<TaskItem>;
            
            if (siblings == null) return;

            var currentIndex = siblings.IndexOf(currentTask);
            int nextIndex;

            if (reverse)
            {
                nextIndex = currentIndex > 0 ? currentIndex - 1 : siblings.Count - 1;
            }
            else
            {
                nextIndex = currentIndex < siblings.Count - 1 ? currentIndex + 1 : 0;
            }

            if (nextIndex >= 0 && nextIndex < siblings.Count)
            {
                SelectTreeViewItem(treeView, siblings[nextIndex]);
                Logger.Debug("KeyboardNavigationBehavior", $"Navigated to {(reverse ? "previous" : "next")} sibling");
            }
        }

        private static void NavigateToIndex(TreeView treeView, int index)
        {
            var allItems = GetAllVisibleItems(treeView).ToList();
            if (index >= 0 && index < allItems.Count)
            {
                SelectTreeViewItem(treeView, allItems[index]);
                Logger.Debug("KeyboardNavigationBehavior", $"Navigated to index {index}");
            }
        }

        private static void NavigateBack(TreeView treeView)
        {
            if (!_navigationStates.TryGetValue(treeView, out var state)) return;
            
            if (state.VisitedItems.Count > 1)
            {
                // Remove current item and go to previous
                state.VisitedItems.RemoveAt(state.VisitedItems.Count - 1);
                var previousItem = state.VisitedItems[^1];
                SelectTreeViewItem(treeView, previousItem);
                Logger.Debug("KeyboardNavigationBehavior", "Navigated back");
            }
        }

        #endregion

        #region Helper Methods

        private static void UpdateNavigationState(TreeView treeView, Key key)
        {
            if (!_navigationStates.TryGetValue(treeView, out var state))
            {
                state = new NavigationState();
                _navigationStates[treeView] = state;
            }

            var now = DateTime.UtcNow;
            
            if (state.LastNavigationKey == key && (now - state.LastNavigationTime).TotalMilliseconds < 500)
            {
                state.RepeatCount++;
            }
            else
            {
                state.RepeatCount = 1;
            }

            state.LastNavigationKey = key;
            state.LastNavigationTime = now;

            // Track visited items for back navigation
            if (treeView.SelectedItem != null)
            {
                state.VisitedItems.Add(treeView.SelectedItem);
                
                // Limit history size
                if (state.VisitedItems.Count > 20)
                {
                    state.VisitedItems.RemoveAt(0);
                }
            }
        }

        private static object? GetFirstVisibleItem(TreeView treeView)
        {
            return GetAllVisibleItems(treeView).FirstOrDefault();
        }

        private static object? GetLastVisibleItem(TreeView treeView)
        {
            return GetAllVisibleItems(treeView).LastOrDefault();
        }

        private static IEnumerable<object> GetAllVisibleItems(TreeView treeView)
        {
            if (treeView.ItemsSource is System.Collections.ObjectModel.ObservableCollection<TaskItem> items)
            {
                return GetVisibleItemsRecursive(items);
            }
            return Enumerable.Empty<object>();
        }

        private static IEnumerable<TaskItem> GetVisibleItemsRecursive(System.Collections.ObjectModel.ObservableCollection<TaskItem> items)
        {
            foreach (var item in items)
            {
                yield return item;
                
                if (item.IsExpanded && item.Children.Count > 0)
                {
                    foreach (var child in GetVisibleItemsRecursive(item.Children))
                    {
                        yield return child;
                    }
                }
            }
        }

        private static TaskItem? FindParentTask(TreeView treeView, TaskItem childTask)
        {
            if (treeView.ItemsSource is System.Collections.ObjectModel.ObservableCollection<TaskItem> rootItems)
            {
                return FindParentTaskRecursive(rootItems, childTask);
            }
            return null;
        }

        private static TaskItem? FindParentTaskRecursive(System.Collections.ObjectModel.ObservableCollection<TaskItem> items, TaskItem targetTask)
        {
            foreach (var item in items)
            {
                if (item.Children.Contains(targetTask))
                {
                    return item;
                }

                var parent = FindParentTaskRecursive(item.Children, targetTask);
                if (parent != null)
                {
                    return parent;
                }
            }
            return null;
        }

        private static void SelectTreeViewItem(TreeView treeView, object item)
        {
            var treeViewItem = treeView.ItemContainerGenerator.ContainerFromItem(item) as TreeViewItem;
            if (treeViewItem != null)
            {
                treeViewItem.IsSelected = true;
                treeViewItem.Focus();
                treeViewItem.BringIntoView();
            }
        }

        #endregion
    }
}