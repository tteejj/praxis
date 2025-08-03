# MacroFactory - Visual IDEA Macro Builder

A standalone PowerShell TUI application for building IDEA automation macros visually. No more hand-coding IDEAScript - build powerful automation sequences with a drag-and-drop interface!

## Features

- **Visual Macro Building** - Three-pane interface for intuitive macro creation
- **Component Library** - Pre-built actions for common IDEA operations
- **Live Context Tracking** - See available variables and their types in real-time
- **Script Preview** - View generated IDEAScript before execution
- **Save/Load Macros** - Reuse your automation workflows
- **Parameter Validation** - Ensures your macro is valid before generation

## Usage

### Starting MacroFactory

```powershell
# Basic usage
./MacroFactory.ps1

# With debug logging
./MacroFactory.ps1 -Debug
```

### Interface Overview

The application has three main panes:

1. **Component Library (Left)** - Available actions you can add to your macro
2. **Macro Sequence (Center)** - Your current macro steps in order
3. **Context Panel (Right)** - Variables available at each step

### Keyboard Shortcuts

**Global:**
- `Tab` - Switch between panes
- `Q` - Quit application

**Component Library:**
- `↑↓` - Navigate actions
- `Enter` - Add selected action to macro

**Macro Sequence:**
- `↑↓` - Navigate steps
- `Enter` - Edit action parameters
- `D` - Delete selected action
- `Ctrl+↑↓` - Move action up/down
- `F5` - Preview generated script
- `Ctrl+S` - Save macro
- `Ctrl+O` - Open saved macro

## Building a Macro

1. **Add Actions**: Select actions from the Component Library and press Enter
2. **Configure Parameters**: Each action will open a configuration dialog
3. **Arrange Steps**: Use Ctrl+↑↓ to reorder actions as needed
4. **Preview Script**: Press F5 to see the generated IDEAScript
5. **Save Macro**: Press Ctrl+S to save for later use

## Available Actions

### Analysis
- **Summarize Data** - Create summaries grouped by fields with statistics

### Data
- **Append Field** - Add new fields to your database

### Export
- **Export to Excel** - Export databases to Excel files

### Advanced
- **Custom IDEA Command** - Add custom IDEAScript code

## Action Configuration

When adding an action, you'll see a configuration dialog:

- Text fields: Type values directly
- Boolean fields: Press Enter to toggle Yes/No
- Choice fields: Press Enter to cycle through options
- Use Tab/Shift+Tab to navigate between fields

## Example Workflow

1. Start with "Summarize Data" action
   - Set database: `ActiveDatabase`
   - Set field to summarize: `CUSTOMER_ID`
   - Set output variable: `customerSummary`

2. Add "Append Field" action
   - Set database: `customerSummary`
   - Set field name: `RISK_SCORE`
   - Set type: `Numeric`

3. Add "Export to Excel" action
   - Set database: `customerSummary`
   - Set filename: `customer_analysis.xlsx`
   - Include headers: `Yes`

4. Press F5 to preview the complete script
5. Press Ctrl+S to save as "Customer Risk Analysis"

## Generated Script Format

MacroFactory generates standard IDEAScript (VBScript) that can be:
- Run directly in IDEA
- Modified in IDEA's Script Editor
- Integrated into larger automation workflows

## Tips

- Use meaningful variable names for clarity
- Check the Context Panel to see available variables
- Save frequently-used patterns as named macros
- Use the Custom IDEA Command action for advanced operations

## Troubleshooting

**Actions show "⚠️ Missing" status:**
- Click Enter on the action to configure required parameters

**Script generation fails:**
- Ensure all actions have required parameters configured
- Check that variable references exist in the context

**Can't save/load macros:**
- Check write permissions in the MacroFactory/Data/macros directory

## File Structure

```
MacroFactory/
├── MacroFactory.ps1      # Main entry point
├── Core/                 # Core utilities
├── Models/               # Action definitions
├── Services/             # Business logic
├── Components/           # UI components
├── Screens/              # Application screens
└── Data/                 # Saved macros and logs
    ├── macros/          # Saved macro files
    └── macrofactory.log # Application log
```

## Extending MacroFactory

To add new actions:

1. Create a new class inheriting from `BaseAction` in Models/
2. Define the `Consumes` and `Produces` properties
3. Implement the `RenderScript()` method
4. Add the action to the available actions in `MacroFactoryScreen.ps1`

## Requirements

- PowerShell 5.1 or higher
- Windows Terminal or any terminal supporting ANSI escape sequences
- Minimum terminal size: 100x30 characters

## License

Part of the Praxis project - Use freely for IDEA automation!