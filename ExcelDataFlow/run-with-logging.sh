#!/bin/bash

echo "Starting ExcelDataFlow with debug logging..."
echo "The debug log will be saved to debug.log"
echo "Press Ctrl+C to exit"
echo ""

# Clear any existing log
rm -f debug.log

# Run the application
pwsh ./Start.ps1

echo ""
echo "=== DEBUG LOG CONTENTS ==="
cat debug.log 2>/dev/null || echo "No log file found"