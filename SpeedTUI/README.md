# SpeedTUI - Fast, Simple Terminal UI Framework for PowerShell

SpeedTUI is a high-performance, easy-to-use Terminal User Interface (TUI) framework for PowerShell. It focuses on simplicity, speed, and developer experience with a modern builder pattern API inspired by Spectre Console.

## Features

- **🚀 Blazing Fast**: Direct terminal rendering with differential updates - no flicker, no cell buffers
- **🎨 Simple Theming**: Pre-built themes (default, dark, light, solarized, synthwave) with easy customization
- **📦 Rich Components**: Table, List, Label, Button, Grid Layout, Stack Layout - all pre-built and ready
- **🔧 Builder Pattern**: Fluent API for easy UI construction
- **📊 Reactive Data**: Automatic UI updates when data changes
- **🎯 Smart Focus**: Automatic tab navigation and focus management
- **📝 Extensive Logging**: Granular module-level logging for easy debugging
- **🛡️ Defensive Programming**: Comprehensive null checks and error handling

## Quick Start

```powershell
# Run the example application
./Start.ps1 -Example

# Or create your own
./Start.ps1
```

## Creating Your First App

```powershell
# Load SpeedTUI
. ./Start.ps1

# Create a simple app
$app = New-SpeedTUIApp "My First App" {
    param($builder)
    
    # Create a simple layout
    $stack = [VStack]::new().WithSpacing(1)
    
    # Add a title
    $title = [Label]::new("Welcome to SpeedTUI!").
        WithColor([Colors]::Bold + [Colors]::Cyan).
        WithAlignment("center", "middle")
    $stack.AddItem($title)
    
    # Add a list
    $list = [List]::new().
        AddItems(@("Option 1", "Option 2", "Option 3")).
        WithBorder("Rounded").
        WithOnSelectionChanged({
            param($list)
            Write-Host "Selected: $($list.GetSelectedValue())"
        })
    $stack.AddItem($list)
    
    # Add a button
    $button = [Button]::new("Click Me!").
        WithOnClick({
            Write-Host "Button clicked!"
        })
    $stack.AddItem($button)
    
    # Set the root component
    $builder.Root($stack)
}

# Run the app
$app.Run()
```

## Component Examples

### Grid Layout
```powershell
$grid = [GridBuilder]::new().
    Rows(@("auto", "1fr", "auto")).     # Header, content, footer
    Columns(@("200px", "1fr")).         # Sidebar, main
    Gap(1).                             # 1 char gap between cells
    Add($header, 0, 0, 1, 2).          # Row 0, span 2 columns
    Add($sidebar, 1, 0).               # Row 1, column 0
    Add($content, 1, 1).               # Row 1, column 1
    Add($footer, 2, 0, 1, 2).          # Row 2, span 2 columns
    Build()
```

### Table with Data
```powershell
$table = [Table]::new().
    AddColumn("Name", "Name").
    AddColumn("Status", "Status").
    AddColumn("Progress", "Progress").
    SetData($projectData).
    WithBorder("Single").
    WithAlternateRows().
    WithOnItemActivated({
        param($table, $item)
        # Handle item activation (Enter key)
    })
```

### Reactive Data Store
```powershell
# Create a data store
$store = [DataStoreManager]::GetStore("myapp")
$users = $store.Collection("users")

# Set data
$users.Set("currentUser", @{ Name = "John"; Role = "Admin" })

# Watch for changes
$users.Watch("currentUser", {
    param($prop, $old, $new)
    Write-Host "User changed from $($old.Name) to $($new.Name)"
})

# Update data - watchers are notified automatically
$users.Set("currentUser", @{ Name = "Jane"; Role = "User" })
```

## Architecture

SpeedTUI is built with performance and simplicity in mind:

- **No Z-Index**: Flat rendering model for maximum speed
- **No Cell Buffers**: Direct terminal writes with differential updates
- **String-Based Rendering**: Components render to strings, not objects
- **Automatic Focus Management**: Tab navigation works out of the box
- **Event-Driven**: Components communicate through events, not direct references

## Performance

SpeedTUI achieves high performance through:

1. **Differential Rendering**: Only changed regions are updated
2. **Direct Terminal Access**: No intermediate buffer layers
3. **String Caching**: Reuse of ANSI sequences and common strings
4. **Smart Clipping**: Only visible content is rendered
5. **Batched Updates**: Multiple changes rendered in single write

## Logging and Debugging

SpeedTUI includes comprehensive logging:

```powershell
# Enable debug logging
./Start.ps1 -Example -Debug -LogLevel Debug

# Configure module-specific logging
$logger = Get-Logger
$logger.SetModuleLevel("Table", [LogLevel]::Trace)
$logger.SetComponentLevel("RenderEngine", "Frame", [LogLevel]::Debug)

# View logs
Get-Content ./Logs/speedtui_*.log -Tail 50
```

## Themes

Switch themes at runtime:

```powershell
$app.ThemeManager.SetTheme("synthwave")  # or "dark", "light", "solarized"
```

Create custom themes:

```powershell
$custom = [Theme]::new("custom").
    DefineColor("primary", [Colors]::RGB(255, 128, 0)).
    DefineColor("secondary", [Colors]::RGB(0, 128, 255)).
    DefineColor("text", [Colors]::White).
    DefineColor("background", "", [Colors]::BgRGB(16, 16, 32))

$app.ThemeManager.RegisterTheme($custom)
$app.ThemeManager.SetTheme("custom")
```

## Requirements

- PowerShell 7.0 or later
- Terminal with ANSI/VT100 support
- Unicode support for box drawing characters

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please follow the existing code style and include tests for new features.

## Comparison with Other Frameworks

| Feature | SpeedTUI | Praxis | AxiomPhoenix |
|---------|----------|---------|--------------|
| Rendering | Direct strings | Cached strings | Cell buffer |
| Performance | Very Fast | Fast | Slow |
| API Style | Builder pattern | Traditional | Complex |
| Learning Curve | Easy | Moderate | Steep |
| Components | Pre-built | Custom | Complex |
| Theming | Simple | Complex | Very Complex |
| Data Binding | Reactive | Manual | None |