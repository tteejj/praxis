# SimplTaskPro Packaging System

## Overview
This packaging system allows you to bundle the entire SimplTaskPro application for distribution via email while preserving the original source files.

## Scripts

### `package.ps1` - Create Distribution Package
**Non-destructive packaging** - original files remain untouched.

```powershell
# Package current directory
./package.ps1

# Package specific folder  
./package.ps1 -FolderName "MyApp"

# Custom chunk size for smaller email attachments
./package.ps1 -ChunkSize 25000
```

**What it does:**
1. Creates temporary copy of source files
2. Renames `.ps1` → `ps1.txt` in temp copy only
3. Creates zip file from temp copy
4. Encodes to base64 and splits into email-sized chunks
5. Cleans up temporary files
6. **Original source files unchanged!**

### `unpackage.ps1` - Extract Distribution Package
```powershell
# Extract default package
./unpackage.ps1

# Extract specific package
./unpackage.ps1 -BaseFileName "myapp.zip.b64"
```

**What it does:**
1. Joins base64 chunk files
2. Decodes base64 to zip file
3. Ready for manual unzip

### `restore-ps1.ps1` - Restore File Extensions
```powershell
# Restore current directory
./restore-ps1.ps1

# Restore specific folder
./restore-ps1.ps1 -FolderPath "ExtractedApp"
```

**What it does:**
1. Converts `ps1.txt` files back to `.ps1`
2. Makes application runnable again

## Typical Workflow

### Sender (Distribution):
```bash
./package.ps1                    # Creates *.zip.b64.part1, part2, etc.
# Email all .part files
```

### Receiver (Installation):
```bash
./unpackage.ps1                  # Creates app.zip from parts
unzip app.zip                    # Extract files
./restore-ps1.ps1 -FolderPath ExtractedFolder  # Fix extensions
cd ExtractedFolder && ./SimpleTaskPro.ps1      # Run application
```

## Why This System?

1. **Email Compatible**: Breaks large files into small chunks
2. **Non-Destructive**: Original development files never modified
3. **Cross-Platform**: Works on Windows, Linux, macOS with PowerShell
4. **Simple**: Three scripts handle the entire distribution pipeline

## File Size Limits
- Default chunk size: 50KB (good for most email systems)
- Configurable via `-ChunkSize` parameter
- Base64 encoding adds ~33% overhead