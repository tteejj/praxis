# CommandLibrary

A standalone PowerShell command management tool for storing, organizing, and quickly accessing reusable commands.

## Features

- **Store Commands**: Save frequently used commands with titles, descriptions, and tags
- **Quick Search**: Find commands by title, description, command text, or tags
- **Tag System**: Comprehensive tagging with smart suggestions and analytics
- **Advanced Search**: Special syntax for tag (#docker) and group (group:Git) searches
- **Clipboard Integration**: Copy commands to clipboard with one keystroke
- **Execute Commands**: Run commands directly from the library
- **Usage Tracking**: See which commands you use most
- **Group Organization**: Organize commands by category
- **Tag Statistics**: View tag usage and popularity metrics
- **Command Line Interface**: Both interactive and command-line modes

## Usage

### Interactive Mode
```bash
./CommandLibrary.ps1
```

### Quick Command Search
```bash
./CommandLibrary.ps1 -Command "git status"
```

### List All Commands
```bash
./CommandLibrary.ps1 -List
```

### Help
```bash
./CommandLibrary.ps1 -Help
```

## Interactive Mode Keys

| Key | Action |
|-----|--------|
| **Enter** | Copy selected command to clipboard |
| **E** | Edit selected command |
| **N** | Create new command |
| **D** | Delete selected command |
| **R** | Run selected command |
| **F3** | Enter search mode |
| **Q** | Quit |

## Default Commands

The library comes with useful default commands including:

- **PowerShell**: System information, file operations
- **Git**: Status, log, branch management
- **Docker**: Container and image management
- **Network**: Connectivity testing, configuration

## Data Storage

Commands are stored in `Data/commands.json` as JSON for easy backup and portability.

## Requirements

- PowerShell 5.1 or PowerShell Core 6+
- Terminal with ANSI color support

## Architecture

Based on the CommandLibraryScreen from the main Praxis system, simplified for standalone use:

- **Models**: Command data structure
- **Services**: Data persistence and CRUD operations
- **Components**: Reusable UI components (ListBox, Dialog)
- **Screens**: Main application screens
- **Core**: Terminal control utilities

## Development

The codebase is modular and extensible:

- Add new command fields by modifying `Models/Command.ps1`
- Extend search functionality in `Services/CommandService.ps1`
- Customize UI in `Components/` and `Screens/`
- Integrate with external systems via the service layer