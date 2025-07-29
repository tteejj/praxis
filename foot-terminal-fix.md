# Foot Terminal Fix Summary

## Issue
Tab display works in Ghostty but not in Foot terminal, with locale warnings and potential rendering issues.

## Root Causes
1. **Locale warnings**: Foot shows locale errors that may affect UTF-8 rendering
2. **Terminal width**: Foot may have different default width causing more aggressive tab overflow
3. **ANSI escape handling**: Potential differences in how foot processes escape sequences

## Solutions Applied

### 1. Tab Overflow Fix (Already Applied)
- Modified TabContainer.ps1 to properly check bounds using maxX
- Added color reset after each tab to prevent bleeding
- Removed gap line that was interfering with content

### 2. Locale Fix
Created wrapper script `run-in-foot.sh`:
```bash
#!/bin/bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8
export TERM=xterm-256color
exec pwsh -file Start.ps1 "$@"
```

### 3. Running PRAXIS in Foot

**Option 1 - Use wrapper script:**
```bash
foot -e ./run-in-foot.sh
```

**Option 2 - Direct with locale:**
```bash
LC_ALL=C.UTF-8 foot -e pwsh -file Start.ps1
```

**Option 3 - Configure foot permanently:**
Add to `~/.config/foot/foot.ini`:
```ini
[environment]
LC_ALL=C.UTF-8
TERM=xterm-256color
```

## Additional Notes
- The tab overflow protection ensures tabs don't render beyond terminal width
- With 80-column terminal, only tabs 1-5 will show (6-8 are hidden to prevent overflow)
- This is by design to prevent the text artifacts you were seeing

## Testing
1. Run PRAXIS using one of the methods above
2. Press keys 1-8 to switch tabs
3. Verify no text artifacts appear
4. Hidden tabs (6-8) are still accessible via number keys even if not visible