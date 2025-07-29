# DataGrid Update Plan

## Vision:
- DataGrid is a complete, self-contained table with all lines connecting
- Title in rounded rectangle box with lines extending to grid edges
- Header separator connects to borders (├─┤)
- Row lines connect to borders (├─┤)
- All missing features restored

## Implementation Steps:

### 1. Title Design:
```
  ╭─ Title ─╮────────────────────╮
  │  Header Column 1 │ Column 2  │
  ├──────────────────┼───────────┤
  │  Row 1 Data      │ Data      │
  ├──────────────────┼───────────┤
  │  Row 2 Data      │ Data      │
  ╰──────────────────┴───────────╯
```

### 2. Features to Add Back:
- AlternateRowColors implementation
- AddColumn() convenience method
- MaxContentWidth tracking for better auto-sizing
- All other missing functionality

### 3. Border Connections:
- Header separator uses LT (├) and RT (┤) to connect
- Row separators use LT (├) and RT (┤) to connect
- Column separators use TT (┬) for header, Cross (┼) for intersections

Ready to implement?