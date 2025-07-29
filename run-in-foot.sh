#!/bin/bash

# Wrapper script to run PRAXIS in foot terminal with proper settings

echo "Starting PRAXIS in foot terminal..."

# Set proper locale
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Set terminal type for better compatibility
export TERM=xterm-256color

# Run PRAXIS
exec pwsh -file Start.ps1 "$@"