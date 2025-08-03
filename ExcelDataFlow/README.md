# ExcelDataFlow - Standalone Excel Data Management Application

A PowerShell-based TUI application for managing Excel field mappings and data operations.

## Features

✅ **3-Column Editable Grid** - Field Name, Source Cell, Destination Cell
✅ **40+ Pre-populated Excel Field Mappings** - Based on your existing system
✅ **File Management** - Source/destination Excel file and sheet configuration
✅ **Settings Persistence** - Automatic save/load to JSON configuration
✅ **Excel COM Integration** - Read/write Excel files (Windows) or test mode (Linux/Mac)
✅ **Cross-Platform** - Graceful handling of Excel availability

## Usage

### Windows (with Excel):
```powershell
.\Start.ps1
```

### Linux/Mac (test mode):
```bash
pwsh -File Start.ps1
```

### Controls:
- **F10** - Exit application
- **Tab** - Navigate between controls
- **Arrow Keys** - Move in grid/between fields
- **Enter** - Edit grid cells or activate buttons
- **Escape** - Cancel editing

## Configuration

Settings are automatically saved to `_Config/settings.json`:

```json
{
  "ExcelMappings": {
    "SourceFile": "C:\\path\\to\\source.xlsx",
    "SourceSheet": "SVI-CAS", 
    "DestFile": "C:\\path\\to\\destination.xlsx",
    "DestSheet": "Output",
    "FieldMappings": {
      "RequestDate": {
        "Sheet": "SVI-CAS",
        "Cell": "W23",
        "DestSheet": "Output", 
        "DestCell": ""
      }
      // ... 40+ more fields
    }
  }
}
```

## Architecture

- **Standalone** - No dependencies on Praxis or other systems
- **Modular** - Clean separation of UI, services, and data
- **Excel Service** - COM automation with graceful fallbacks
- **Configuration Service** - JSON-based settings persistence
- **UI Components** - Minimal, responsive text-based interface

## Field Mappings

Pre-populated with complete field set:
- Project Info: RequestDate, AuditType, AuditorName
- Contact Details: TPName, TPEmailAddress, TPPhoneNumber
- Site Information: SiteName, SiteAddress, SiteCity, SiteState
- Asset Details: CASNumber, AssetName, SerialNumber, ModelNumber
- Technical Data: Capacity, TankType, Product, LeakDetection
- And 25+ more fields...

## Next Steps

1. **Edit Configuration** - Set proper file paths and destination cells
2. **Data Extraction** - Implement extraction screen to read Excel data
3. **Export Operations** - Add Excel and text export functionality
4. **Field Validation** - Add cell reference validation and data preview

## Files

- `Start.ps1` - Main application entry point
- `Start-Working.ps1` - Command-line version for configuration setup
- `Base/` - Core UI framework classes
- `Components/` - UI controls (buttons, text boxes, data grid)
- `Services/` - Excel and configuration services
- `Screens/` - Application screens and dialogs