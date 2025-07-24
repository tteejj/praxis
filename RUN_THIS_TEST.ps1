#!/usr/bin/env pwsh
Write-Host @"

SHORTCUT AND FOCUS TEST INSTRUCTIONS
====================================

The debug output has been added to help diagnose the issues.

When you run Start.ps1, you will see:
- [REG] messages when shortcuts are registered
- [UNREG] messages when shortcuts are unregistered  
- [DEBUG] messages for each key press
- [SM] messages from ShortcutManager processing
- [MATCH] messages when checking if shortcuts match
- Screen activation messages

To test:
1. Run: pwsh -File Start.ps1
2. Press 1 to go to Projects screen
3. Press 'e' - watch for debug output
4. Press 2 to go to Tasks screen  
5. Press 'e' again

The debug output will show exactly what's happening with shortcuts.

"@ -ForegroundColor Yellow