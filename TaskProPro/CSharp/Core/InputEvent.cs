using System;

namespace TaskPro.Core
{
    /// <summary>
    /// Clean input event wrapper with professional key detection
    /// </summary>
    public class InputEvent
    {
        public ConsoleKey Key { get; set; }
        public char Char { get; set; }
        public bool Ctrl { get; set; }
        public bool Alt { get; set; }
        public bool Shift { get; set; }
        
        // Clean arrow key detection
        public bool IsArrowUp => Key == ConsoleKey.UpArrow;
        public bool IsArrowDown => Key == ConsoleKey.DownArrow;
        public bool IsArrowLeft => Key == ConsoleKey.LeftArrow;
        public bool IsArrowRight => Key == ConsoleKey.RightArrow;
        
        // Navigation keys
        public bool IsHome => Key == ConsoleKey.Home;
        public bool IsEnd => Key == ConsoleKey.End;
        public bool IsPageUp => Key == ConsoleKey.PageUp;
        public bool IsPageDown => Key == ConsoleKey.PageDown;
        
        // Action keys
        public bool IsEnter => Key == ConsoleKey.Enter;
        public bool IsEscape => Key == ConsoleKey.Escape;
        public bool IsTab => Key == ConsoleKey.Tab;
        public bool IsBackspace => Key == ConsoleKey.Backspace;
        public bool IsDelete => Key == ConsoleKey.Delete;
        
        // Professional Ctrl shortcuts
        public bool IsCtrlA => Ctrl && Key == ConsoleKey.A;
        public bool IsCtrlC => Ctrl && Key == ConsoleKey.C;
        public bool IsCtrlV => Ctrl && Key == ConsoleKey.V;
        public bool IsCtrlX => Ctrl && Key == ConsoleKey.X;
        public bool IsCtrlZ => Ctrl && Key == ConsoleKey.Z;
        public bool IsCtrlY => Ctrl && Key == ConsoleKey.Y;
        public bool IsCtrlS => Ctrl && Key == ConsoleKey.S;
        public bool IsCtrlN => Ctrl && Key == ConsoleKey.N;
        public bool IsCtrlO => Ctrl && Key == ConsoleKey.O;
        public bool IsCtrlQ => Ctrl && Key == ConsoleKey.Q;
        public bool IsCtrlR => Ctrl && Key == ConsoleKey.R;
        
        // Movement with Ctrl
        public bool IsCtrlArrowLeft => Ctrl && Key == ConsoleKey.LeftArrow;
        public bool IsCtrlArrowRight => Ctrl && Key == ConsoleKey.RightArrow;
        public bool IsCtrlHome => Ctrl && Key == ConsoleKey.Home;
        public bool IsCtrlEnd => Ctrl && Key == ConsoleKey.End;
        
        // Selection with Shift
        public bool IsShiftArrowLeft => Shift && Key == ConsoleKey.LeftArrow;
        public bool IsShiftArrowRight => Shift && Key == ConsoleKey.RightArrow;
        public bool IsShiftArrowUp => Shift && Key == ConsoleKey.UpArrow;
        public bool IsShiftArrowDown => Shift && Key == ConsoleKey.DownArrow;
        public bool IsShiftHome => Shift && Key == ConsoleKey.Home;
        public bool IsShiftEnd => Shift && Key == ConsoleKey.End;
        public bool IsShiftTab => Shift && Key == ConsoleKey.Tab;
        
        // Combined shortcuts
        public bool IsCtrlEnter => Ctrl && Key == ConsoleKey.Enter;
        
        // Character input detection
        public bool IsPrintableChar => !char.IsControl(Char) && Char != '\0';
        public bool IsWhitespace => char.IsWhiteSpace(Char);
        public bool IsDigit => char.IsDigit(Char);
        public bool IsLetter => char.IsLetter(Char);
        
        // Function keys for TaskPro shortcuts
        public bool IsF1 => Key == ConsoleKey.F1;
        public bool IsF2 => Key == ConsoleKey.F2;
        public bool IsF3 => Key == ConsoleKey.F3;
        public bool IsF4 => Key == ConsoleKey.F4;
        public bool IsF5 => Key == ConsoleKey.F5;
        public bool IsF12 => Key == ConsoleKey.F12;
        
        // Function key detection
        public bool IsFunction => Key >= ConsoleKey.F1 && Key <= ConsoleKey.F24;
        public int FunctionKey => IsFunction ? (int)(Key - ConsoleKey.F1) + 1 : 0;
        
        // Space key detection
        public bool IsSpace => Key == ConsoleKey.Spacebar || Char == ' ';
        
        public static InputEvent FromConsoleKeyInfo(ConsoleKeyInfo keyInfo)
        {
            return new InputEvent
            {
                Key = keyInfo.Key,
                Char = keyInfo.KeyChar,
                Ctrl = (keyInfo.Modifiers & ConsoleModifiers.Control) != 0,
                Alt = (keyInfo.Modifiers & ConsoleModifiers.Alt) != 0,
                Shift = (keyInfo.Modifiers & ConsoleModifiers.Shift) != 0
            };
        }
        
        public override string ToString()
        {
            var modifiers = "";
            if (Ctrl) modifiers += "Ctrl+";
            if (Alt) modifiers += "Alt+";
            if (Shift) modifiers += "Shift+";
            
            return $"{modifiers}{Key}";
        }
    }
}