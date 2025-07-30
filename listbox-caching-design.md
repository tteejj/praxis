# ListBox Component Caching Design

## Overview
Design for implementing efficient render caching across ListBox components to improve performance by avoiding unnecessary re-renders.

## Current State Analysis

### Components Analyzed:
1. **SearchableListBox** (663 lines) - Most complex with search functionality
2. **MinimalListBox** (273 lines) - Clean minimalist implementation  
3. **ListBox** (365 lines) - Standard implementation in backup

### Existing Caching Patterns:
- `_cachedRender` - String cache for complete render output
- `_dataVersion` - Version tracking for data changes (in ListBox)
- `_colors` hashtable - Theme color caching
- `_itemsCacheInvalid` - Boolean flag for cache invalidation

### Inheritance Hierarchy:
```
UIElement (base)
  └── Container 
      └── FocusableComponent
          └── MinimalListBox
  └── UIElement (direct)
      └── SearchableListBox
      └── ListBox (backup)
```

## Proposed Caching Architecture

### 1. Version Tracking System

```powershell
class CacheVersion {
    [int]$Data = 0        # Increments on item changes
    [int]$Selection = 0   # Increments on selection changes
    [int]$Dimensions = 0  # Increments on size changes
    [int]$Theme = 0       # Increments on theme changes
    [int]$Focus = 0       # Increments on focus changes
    
    [bool] HasChanged([CacheVersion]$other) {
        return $this.Data -ne $other.Data -or
               $this.Selection -ne $other.Selection -or
               $this.Dimensions -ne $other.Dimensions -or
               $this.Theme -ne $other.Theme -or
               $this.Focus -ne $other.Focus
    }
    
    [CacheVersion] Clone() {
        $clone = [CacheVersion]::new()
        $clone.Data = $this.Data
        $clone.Selection = $this.Selection
        $clone.Dimensions = $this.Dimensions
        $clone.Theme = $this.Theme
        $clone.Focus = $this.Focus
        return $clone
    }
}
```

### 2. Cache Structure

```powershell
class RenderCache {
    [string]$Content = ""
    [CacheVersion]$Version
    [hashtable]$Segments = @{}  # Partial renders by region
    
    RenderCache() {
        $this.Version = [CacheVersion]::new()
    }
}
```

### 3. Invalidation Strategy

#### Granular Invalidation Levels:
1. **Full Invalidation** - Complete re-render needed
   - Data changes (add/remove items)
   - Dimension changes
   - Theme changes

2. **Selection Invalidation** - Only selection rendering
   - Selection index changes
   - Focus changes

3. **Scroll Invalidation** - Only viewport update
   - Scroll offset changes

### 4. Integration Approach

#### Base Class Enhancement (UIElement):
```powershell
# Add to UIElement
hidden [CacheVersion]$_cacheVersion
hidden [CacheVersion]$_lastRenderedVersion

[bool] NeedsRender() {
    if (-not $this._lastRenderedVersion) { return $true }
    return $this._cacheVersion.HasChanged($this._lastRenderedVersion)
}
```

#### ListBox Implementation Pattern:
```powershell
# In ListBox components
[void] SetItems($items) {
    # ... existing code ...
    $this._cacheVersion.Data++
    $this.Invalidate()
}

[void] SelectIndex([int]$index) {
    # ... existing code ...
    $this._cacheVersion.Selection++
    $this.InvalidateSelection()  # New targeted invalidation
}

[void] OnBoundsChanged() {
    # ... existing code ...
    $this._cacheVersion.Dimensions++
    $this.Invalidate()
}

[void] OnThemeChanged() {
    # ... existing code ...
    $this._cacheVersion.Theme++
    $this.Invalidate()
}
```

### 5. Rendering Optimization

```powershell
[string] OnRender() {
    # Check if we need full re-render
    if (-not $this.NeedsRender() -and $this._renderCache.Content) {
        return $this._renderCache.Content
    }
    
    # Check for partial update possibilities
    if ($this._lastRenderedVersion -and 
        $this._cacheVersion.Selection -ne $this._lastRenderedVersion.Selection -and
        $this._cacheVersion.Data -eq $this._lastRenderedVersion.Data) {
        # Only selection changed - do partial update
        return $this.RenderSelectionUpdate()
    }
    
    # Full render needed
    $this._renderCache.Content = $this.RenderFull()
    $this._lastRenderedVersion = $this._cacheVersion.Clone()
    return $this._renderCache.Content
}
```

### 6. Memory Management

- Use object pooling for StringBuilder instances
- Clear segment caches on full invalidation
- Limit cache size for very large lists

## Implementation Priority

1. **Phase 1**: Implement CacheVersion class and integrate with UIElement
2. **Phase 2**: Update MinimalListBox with full caching
3. **Phase 3**: Update SearchableListBox with search-aware caching
4. **Phase 4**: Performance testing and optimization

## Expected Performance Gains

- **Navigation**: 80-90% reduction in render time for arrow key navigation
- **Focus Changes**: 70-80% reduction for focus-only updates
- **Scrolling**: 60-70% reduction for scroll operations
- **Search**: 50-60% reduction for filtered results (SearchableListBox)

## Compatibility Notes

- Maintains backward compatibility with existing API
- No changes to public methods
- Transparent to consumers of the components