#!/usr/bin/env pwsh

# Test script to debug MinimalDataGrid freeze issue

# First backup the current MinimalDataGrid
Copy-Item -Path "./Components/MinimalDataGrid.ps1" -Destination "./Components/MinimalDataGrid.ps1.backup" -Force

# Create a test version with debug output
$debugContent = @'
# MinimalDataGrid.ps1 - Debug version

class MinimalDataGrid : FocusableComponent {
    # Public properties
    [System.Collections.Generic.List[object]]$Items
    [System.Collections.Generic.List[GridColumn]]$Columns
    [int]$SelectedIndex = -1
    [string]$Title = ""
    [bool]$ShowBorder = $true
    [BorderType]$BorderType = [BorderType]::Rounded
    [bool]$ShowTitle = $true
    [bool]$ShowHeader = $true
    [bool]$ShowGridLines = $false
    [bool]$ShowColumnSeparators = $true
    [bool]$ShowRowNumbers = $false
    [bool]$AlternateRowColors = $false
    [int]$RowSpacing = 0
    [scriptblock]$OnItemSelected = $null
    
    # Layout properties
    hidden [int]$_contentX
    hidden [int]$_contentY
    hidden [int]$_contentWidth
    hidden [int]$_contentHeight
    hidden [int]$_headerY
    hidden [int]$_dataY
    hidden [int]$_scrollOffset = 0
    hidden [int]$_viewportRows = 0
    hidden [int]$_titleHeight = 0
    
    # Cached colors
    hidden [hashtable]$_colors = @{}
    hidden [ThemeManager]$Theme
    hidden [hashtable]$_borderChars = @{}
    
    hidden [int]$_renderCount = 0
    
    MinimalDataGrid() : base() {
        Write-Host "MinimalDataGrid constructor called" -ForegroundColor Yellow
        $this.Items = [System.Collections.Generic.List[object]]::new()
        $this.Columns = [System.Collections.Generic.List[GridColumn]]::new()
        $this.IsFocusable = $true
        $this._colors = @{}
    }
    
    [void] OnInitialize() {
        Write-Host "MinimalDataGrid OnInitialize called" -ForegroundColor Yellow
        ([FocusableComponent]$this).OnInitialize()
        $this.Theme = $this.ServiceContainer.GetService("ThemeManager")
        if ($this.Theme) {
            $this.Theme.Subscribe({ $this.OnThemeChanged() })
            $this.OnThemeChanged()
        }
    }
    
    [void] OnThemeChanged() {
        Write-Host "MinimalDataGrid OnThemeChanged called" -ForegroundColor Yellow
        $this.CacheThemeColors()
        $this.Invalidate()
    }
    
    [void] CacheThemeColors() {
        if ($this.Theme) {
            $this._colors = @{
                border = $this.Theme.GetColor('border.normal')
                background = $this.Theme.GetBgColor('surface.background')
                header = $this.Theme.GetColor('list.header.text')
                headerBg = $this.Theme.GetBgColor('list.header.background')
                text = $this.Theme.GetColor('text.primary')
                selectedText = $this.Theme.GetColor('menu.text.selected')
                selectedBg = $this.Theme.GetBgColor('menu.background.selected')
                gridLine = $this.Theme.GetColor('border.faint')
                focusIndicator = $this.Theme.GetColor('color.primary')
                titleColor = $this.Theme.GetColor('color.primary')
                alternate = $this.Theme.GetColor('text.disabled')
            }
        }
        
        if ($this.BorderType -ne [BorderType]::None) {
            $style = [BorderStyle]::Styles[$this.BorderType.ToString()]
            if ($style) {
                $this._borderChars = $style
            }
        }
    }
    
    [void] SetColumns([array]$columns) {
        Write-Host "MinimalDataGrid SetColumns called with $($columns.Count) columns" -ForegroundColor Yellow
        $this.Columns.Clear()
        foreach ($colDef in $columns) {
            $col = [GridColumn]::new()
            $col.Name = $colDef.Name
            $col.Header = if ($colDef.Header) { $colDef.Header } else { $colDef.Name }
            $col.Width = if ($colDef.Width) { $colDef.Width } else { 0 }
            $col.Getter = if ($colDef.Getter) { $colDef.Getter } else { $null }
            $col.ValueGetter = if ($colDef.Getter) { $colDef.Getter } else { $null }
            $col.Formatter = if ($colDef.Formatter) { $colDef.Formatter } else { $null }
            $this.Columns.Add($col)
        }
        $this.AutoSizeColumns()
        $this.Invalidate()
    }
    
    [void] SetItems([array]$items) {
        Write-Host "MinimalDataGrid SetItems called with $($items.Count) items" -ForegroundColor Yellow
        $this.Items.Clear()
        if ($items) {
            foreach ($item in $items) {
                $this.Items.Add($item)
            }
        }
        if ($this.SelectedIndex -ge $this.Items.Count) {
            $this.SelectedIndex = $this.Items.Count - 1
        }
        $this.AutoSizeColumns()
        $this.Invalidate()
    }
    
    [void] AutoSizeColumns() {
        # Simple version for testing
        if ($this.Columns.Count -eq 0) { return }
    }
    
    [void] OnBoundsChanged() {
        Write-Host "MinimalDataGrid OnBoundsChanged called: X=$($this.X), Y=$($this.Y), W=$($this.Width), H=$($this.Height)" -ForegroundColor Yellow
        $this.CalculateLayout()
        ([FocusableComponent]$this).OnBoundsChanged()
    }
    
    [void] CalculateLayout() {
        # Calculate content area
        if ($this.ShowBorder -and $this.BorderType -ne [BorderType]::None) {
            $this._contentX = $this.X + 1
            $this._contentY = $this.Y + 1
            $this._contentWidth = $this.Width - 2
            $this._contentHeight = $this.Height - 2
        } else {
            $this._contentX = $this.X
            $this._contentY = $this.Y
            $this._contentWidth = $this.Width
            $this._contentHeight = $this.Height
        }
    }
    
    [string] OnRender() {
        $this._renderCount++
        Write-Host "MinimalDataGrid OnRender called (count: $($this._renderCount))" -ForegroundColor Cyan
        
        # Simple test render
        return "MinimalDataGrid Test Render"
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        return $false
    }
    
    [bool] OnHandleInput([System.ConsoleKeyInfo]$key) {
        return $this.HandleInput($key)
    }
}

class GridColumn {
    [string]$Name
    [string]$Header
    [scriptblock]$Getter
    [scriptblock]$ValueGetter
    [scriptblock]$Formatter
    [int]$Width
    [int]$MaxContentWidth
}
'@

# Write the debug version
$debugContent | Out-File -FilePath "./Components/MinimalDataGrid.ps1" -Encoding UTF8

Write-Host "Debug version of MinimalDataGrid created. Run Start.ps1 to test." -ForegroundColor Green
Write-Host "Press Enter to restore the original after testing..."
Read-Host

# Restore the original
Copy-Item -Path "./Components/MinimalDataGrid.ps1.backup" -Destination "./Components/MinimalDataGrid.ps1" -Force
Remove-Item -Path "./Components/MinimalDataGrid.ps1.backup" -Force

Write-Host "Original MinimalDataGrid restored." -ForegroundColor Green