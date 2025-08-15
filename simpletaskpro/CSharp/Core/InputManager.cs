using System;
using System.Collections.Generic;

namespace TaskPro.Core
{
    /// <summary>
    /// Professional input manager with clean key handling
    /// </summary>
    public static class InputManager
    {
        private static Dictionary<string, ConsoleKey> customKeyMappings = new Dictionary<string, ConsoleKey>();
        
        /// <summary>
        /// Read input with professional key detection
        /// </summary>
        public static InputEvent ReadInput()
        {
            var keyInfo = Console.ReadKey(true);
            return InputEvent.FromConsoleKeyInfo(keyInfo);
        }
        
        /// <summary>
        /// Check if input is available without blocking
        /// </summary>
        public static bool IsInputAvailable()
        {
            return Console.KeyAvailable;
        }
        
        /// <summary>
        /// Wait for specific key press (for confirmations)
        /// </summary>
        public static bool WaitForConfirmation(string prompt = "Press Y to confirm, any other key to cancel: ")
        {
            Console.Write(prompt);
            var input = ReadInput();
            return input.Key == ConsoleKey.Y;
        }
        
        /// <summary>
        /// Wait for any key press
        /// </summary>
        public static InputEvent WaitForAnyKey(string prompt = "Press any key to continue...")
        {
            if (!string.IsNullOrEmpty(prompt))
            {
                Console.Write(prompt);
            }
            return ReadInput();
        }
        
        /// <summary>
        /// Register custom key mappings for application shortcuts
        /// </summary>
        public static void RegisterKeyMapping(string actionName, ConsoleKey key)
        {
            customKeyMappings[actionName] = key;
        }
        
        /// <summary>
        /// Check if input matches a registered action
        /// </summary>
        public static bool IsActionKey(InputEvent input, string actionName)
        {
            if (customKeyMappings.TryGetValue(actionName, out var mappedKey))
            {
                return input.Key == mappedKey;
            }
            return false;
        }
        
        /// <summary>
        /// Get help text for common shortcuts
        /// </summary>
        public static string GetShortcutsHelp()
        {
            return @"
Navigation:  ↑↓ = Move    Home/End = First/Last    PgUp/PgDn = Page
Editing:     Enter = Edit    Escape = Cancel    Tab = Next field
Text:        Ctrl+A = Select All    Ctrl+C/V = Copy/Paste    Ctrl+Z = Undo
Actions:     Ctrl+N = New    Ctrl+S = Save    Delete = Remove
Application: F1 = Help    F5 = Refresh    Q = Quit
";
        }
        
        /// <summary>
        /// Parse key combination from string (for configuration)
        /// </summary>
        public static InputEvent ParseKeyString(string keyString)
        {
            var parts = keyString.Split('+');
            var input = new InputEvent();
            
            foreach (var part in parts)
            {
                switch (part.Trim().ToUpper())
                {
                    case "CTRL":
                        input.Ctrl = true;
                        break;
                    case "ALT":
                        input.Alt = true;
                        break;
                    case "SHIFT":
                        input.Shift = true;
                        break;
                    default:
                        if (Enum.TryParse<ConsoleKey>(part.Trim(), true, out var key))
                        {
                            input.Key = key;
                        }
                        break;
                }
            }
            
            return input;
        }
    }
}