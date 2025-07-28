# Synthwave Theme Documentation

## Overview

The Synthwave theme brings the nostalgic aesthetics of 1980s retro-futurism to PRAXIS with vibrant neon colors, gradient effects, and a distinctive cyberpunk atmosphere.

## Available Variants

### 1. **synthwave-84**
The main synthwave theme featuring:
- **Primary**: Hot pink/magenta (#FF0090) - Classic synthwave accent
- **Secondary**: Electric cyan (#00FFFF) - Neon glow effect
- **Background**: Deep purple-black (#0F0019) - Night sky base
- **Surface**: Dark purple (#230F37) - Elevated surfaces

### 2. **synthwave-outrun**
An alternative variant with sunset vibes:
- **Primary**: Sunset orange (#FF6A00)
- **Secondary**: Blue violet (#8A2BE2)
- **Background**: Almost black with purple tint (#0A0014)
- **Surface**: Dark purple (#280A3C)

## Key Features

### Gradient Effects
Both themes include gradient endpoints for smooth color transitions:
- **Border gradients**: Create neon glow effects
- **Background gradients**: Add depth and atmosphere
- **Accent gradients**: Special effects and animations

### Neon Color Palette
- Vibrant, high-contrast colors optimized for terminal display
- Carefully chosen color combinations for readability
- State-based color intensities (hover, pressed, focused)

### Component Styling
- **Buttons**: Glowing borders with gradient backgrounds
- **Inputs**: Cyan focus borders with pink highlights  
- **Lists**: Purple selection backgrounds with cyan text
- **Dialogs**: Neon pink borders with gradient effects
- **Progress bars**: Animated neon colors

## Usage

### Applying the Theme

1. **Via Settings Screen**:
   - Press `6` to open Settings
   - Navigate to Theme category
   - Select "synthwave-84" or "synthwave-outrun"
   - Press Enter to apply

2. **Via Command Line**:
   ```powershell
   ./Start.ps1 -Theme "synthwave-84"
   ```

3. **Programmatically**:
   ```powershell
   $themeManager = $global:ServiceContainer.GetService('ThemeManager')
   $themeManager.SetTheme('synthwave-84')
   ```

### Using Gradients in Components

```powershell
# Get gradient colors
$gradient = $themeManager.GetGradient('gradient.border.start', 'gradient.border.end', 10)

# Use in rendering
foreach ($color in $gradient) {
    Write-Host "$color█" -NoNewline
}
```

### Accessing Theme Colors

```powershell
# Get specific colors
$pink = $themeManager.GetColor('primary')
$cyan = $themeManager.GetColor('secondary')
$background = $themeManager.GetColor('background')

# Get RGB values
$rgbValues = $themeManager.GetRGB('primary')  # Returns @(255, 0, 144)
```

## Customization

The theme can be further customized by modifying the color values in `ThemeSynthwave.ps1`:

```powershell
# Create your own synthwave variant
[ThemeBuilder]::new("my-synthwave").
    BasedOn("dark").
    WithPrimary(255, 20, 147).      # Deep pink
    WithSecondary(0, 240, 240).     # Bright cyan
    WithBackground(20, 0, 40).      # Purple-black
    Build()
```

## Demo Scripts

- **test-synthwave-theme.ps1**: Launch PRAXIS with synthwave theme
- **demo-synthwave-gradients.ps1**: See gradient effects in action

## Design Philosophy

The synthwave theme embodies:
- **Nostalgia**: 1980s retro-futuristic aesthetics
- **High Contrast**: Neon colors on dark backgrounds
- **Visual Interest**: Gradients and glow effects
- **Usability**: Maintaining readability despite bold colors

## Tips for Best Experience

1. Use a terminal that supports true color (24-bit RGB)
2. Consider using a retro-styled font like "Courier New" or a bitmap font
3. Adjust terminal opacity slightly for a glowing monitor effect
4. Play some synthwave music while coding for full immersion!

## Color Reference

| Element | synthwave-84 | synthwave-outrun |
|---------|--------------|------------------|
| Primary | #FF0090 | #FF6A00 |
| Secondary | #00FFFF | #8A2BE2 |
| Background | #0F0019 | #0A0014 |
| Surface | #230F37 | #280A3C |
| Error | #FF1E46 | #FF003C |
| Warning | #FFFF00 | #FFC800 |
| Success | #00FF7F | #00FF64 |

Enjoy the neon-soaked, retro-futuristic experience of the Synthwave theme!