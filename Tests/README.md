# PRAXIS Test Suite

Comprehensive test suite for the PRAXIS terminal UI framework using Pester 5.

## 📁 Structure

```
Tests/
├── Unit/                    # Unit tests for individual components
│   ├── Base/               # Tests for base classes (UIElement, Screen, etc)
│   ├── Components/         # Tests for UI components (DataGrid, ListBox, etc)
│   ├── Core/              # Tests for core functionality (VT100, BorderStyle, etc)
│   ├── Models/            # Tests for data models
│   ├── Screens/           # Tests for screen implementations
│   └── Services/          # Tests for services (EventBus, ThemeManager, etc)
├── Integration/            # Integration tests for full workflows
├── Performance/            # Performance and load tests
├── Mocks/                 # Mock objects and test doubles
├── TestHelpers.psm1       # Common test utilities and helpers
└── Run-Tests.ps1          # Test runner script
```

## 🚀 Running Tests

### Run all tests
```powershell
./Tests/Run-Tests.ps1
```

### Run specific test category
```powershell
# Unit tests only
./Tests/Run-Tests.ps1 -TestPath "Unit"

# Performance tests only
./Tests/Run-Tests.ps1 -PerformanceOnly

# Specific component tests
./Tests/Run-Tests.ps1 -TestPath "Unit/Screens"
```

### Run with code coverage
```powershell
./Tests/Run-Tests.ps1 -CodeCoverage
```

### Run with detailed output
```powershell
./Tests/Run-Tests.ps1 -ShowDetailed
```

### CI mode (generates XML reports)
```powershell
./Tests/Run-Tests.ps1 -CI
```

## 📊 Test Coverage

The test suite covers:

- **Core Components**: VT100 sequences, BorderStyle, StringCache
- **Base Classes**: UIElement, Container, Screen, BaseDialog
- **UI Components**: DataGrid, ListBox, TextBox, Buttons, etc.
- **Services**: EventBus, ThemeManager, FocusManager, etc.
- **Screens**: All application screens and dialogs
- **Integration**: Full application workflows
- **Performance**: Screen loading, data processing, memory usage

## 🧪 Test Categories

### Unit Tests
- Fast, isolated tests for individual components
- Mock all dependencies
- Test single responsibility
- ~100ms timeout per test

### Integration Tests
- Test component interactions
- Use real services where possible
- Test complete workflows
- ~1s timeout per test

### Performance Tests
- Measure execution time
- Check memory usage
- Validate performance requirements
- Specific timing thresholds

## 📝 Writing New Tests

### Test File Naming
- Unit tests: `[ComponentName].Tests.ps1`
- Integration tests: `[Workflow].Tests.ps1`
- Performance tests: `[Feature]Performance.Tests.ps1`

### Test Structure
```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../TestHelpers.psm1" -Force
    # Load dependencies
}

Describe "Component Name" {
    BeforeEach {
        # Setup for each test
    }
    
    Context "Feature/Scenario" {
        It "Should do something specific" {
            # Arrange
            $component = [Component]::new()
            
            # Act
            $result = $component.DoSomething()
            
            # Assert
            $result | Should -Be $expected
        }
    }
    
    AfterEach {
        # Cleanup
    }
}
```

### Using Test Helpers

```powershell
# Create mock services
$container = New-MockServiceContainer
$logger = New-MockLogger
$eventBus = New-MockEventBus

# Measure performance
$perf = Measure-Performance -Name "Operation" -ScriptBlock {
    # Code to measure
}

# Create console key inputs
$key = New-ConsoleKeyInfo -KeyChar 'a' -Control $true
```

## 🎯 Performance Targets

- **Screen Loading**: < 100ms
- **Screen Switching**: < 50ms
- **Input Processing**: < 10ms per keystroke
- **Data Grid Render** (1000 items): < 50ms
- **Memory Growth**: < 10MB per 100 operations

## 🐛 Debugging Tests

### Run single test file
```powershell
Invoke-Pester ./Tests/Unit/Core/VT100.Tests.ps1 -Output Detailed
```

### Debug in VS Code
1. Set breakpoints in test files
2. Use "PowerShell: Debug Pester Tests" command
3. Or run with `-Breakpoint` parameter

### View test logs
```powershell
# Tests create logs in Tests/test.log
Get-Content ./Tests/test.log -Tail 50
```

## 🔧 Continuous Integration

The test suite is designed for CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run Tests
  run: |
    pwsh -Command "./Tests/Run-Tests.ps1 -CI -CodeCoverage"
    
- name: Upload Coverage
  uses: codecov/codecov-action@v3
  with:
    file: ./Tests/coverage.xml
```

## 📈 Metrics

Current test suite statistics:
- Total Tests: 50+
- Code Coverage: Target 80%
- Execution Time: < 30 seconds
- Performance Tests: 10+
- Integration Scenarios: 8+

## 🤝 Contributing

When adding new features:
1. Write unit tests first (TDD)
2. Add integration tests for workflows
3. Include performance tests for critical paths
4. Update this README if adding new test categories

## 🚨 Known Issues

- Some performance tests may fail on slower systems
- Memory tests are skipped by default (unreliable in PowerShell)
- Some integration tests require specific terminal capabilities

## 📚 Resources

- [Pester Documentation](https://pester.dev/)
- [PowerShell Testing Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/testing-guidelines)
- [PRAXIS Architecture Guide](../docs/ARCHITECTURE.md)