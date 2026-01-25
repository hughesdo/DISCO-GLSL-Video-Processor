# Amiga Font Texture System

This document explains the Amiga-style bitmap font texture generation and usage system for DISCO GLSL shaders.

## Overview

The Amiga font system consists of two main components:
1. **Font Texture Generator** (`shit.txt`) - Creates the bitmap font atlas
2. **GLSL Character Macros** - Provides easy text rendering in shaders

## Font Texture Generator (`shit.txt`)

### What It Does
- Generates a **1024x1024 pixel texture atlas** containing 256 characters
- Uses **16x16 character grid** (64x64 pixels per character cell)
- Creates **signed distance fields** for smooth scaling and anti-aliasing
- Supports multiple font families: Helvetica, Noto Mono, Symbola, Apple Symbols
- Includes special Amiga-style symbols and characters

### Key Features
- **Distance Field Rendering**: Smooth text at any scale
- **3D Lighting Support**: Gradient information stored in RGB channels
- **Special Characters**: Amiga demo scene symbols (notes, stars, smileys)
- **Multi-Font Support**: Different fonts for different character ranges

### Usage
1. Open `shit.txt` in a web browser
2. The texture atlas will be generated automatically
3. Right-click the canvas and "Save Image As..." to get the texture file
4. Use this texture as `iChannel0` in your GLSL shaders

### Technical Details
```javascript
// Character grid layout
tileCount = 16;           // 16x16 grid
cellSize = 64;            // 64x64 pixels per character
targetSize = 1024;        // Final texture size

// ASCII mapping
var text = String.fromCharCode(x + y * tileCount);
// Position (0,0) = ASCII 0, Position (1,0) = ASCII 1, etc.
```

## GLSL Character Macros

### Basic System
```glsl
#define S(a) c+=char(float(a)); tp.x-=FONT_SPACE;
#define FONT_SPACE 0.45
```

### Complete Character Set
```glsl
// Special characters
#define _note  S(10);   // ♪
#define _star  S(28);   // ★
#define _smily S(29);   // ☺
#define _      S(32);   // Space
#define _exc   S(33);   // !
#define _add   S(43);   // +
#define _dot   S(46);   // .

// Numbers
#define _0 S(48); #define _1 S(49); #define _2 S(50);
#define _3 S(51); #define _4 S(52); #define _5 S(53);
#define _6 S(54); #define _7 S(55); #define _8 S(56); #define _9 S(57);

// Uppercase letters
#define _A S(65); #define _B S(66); #define _C S(67); #define _D S(68);
#define _E S(69); #define _F S(70); #define _G S(71); #define _H S(72);
// ... (complete A-Z set)

// Lowercase letters  
#define _a S(97); #define _b S(98); #define _c S(99); #define _d S(100);
#define _e S(101); #define _f S(102); #define _g S(103); #define _h S(104);
// ... (complete a-z set)
```

### Character Rendering Function
```glsl
float char(int ch)
{
  // Calculate texture coordinates for character
  vec2 texCoord = 0.0625*(tp + vec2(ch - ch/16*16, 15 - ch/16));
  
  // Sample the font texture
  vec4 f = texture(iChannel0, texCoord);
  
  // Return 2D or 3D lighting
  if (use3DLighting < 0.5)
    return f.x;   // 2D: distance field only
  else
    return f.x * (f.y+0.3)*(f.z+0.3)*2.0;   // 3D: with gradients
}
```

## Usage in Shaders

### Simple Text Rendering
```glsl
// Set text position and size
tp = uv / FONT_SIZE1;
float c = 0.0;

// Render "DISCO" using macros
_D _I _S _C _O

// Apply color and blend
vec3 textColor = c * vec3(1.0, 0.5, 0.0);
```

### Audio-Reactive Text
```glsl
// Sinus wave text with audio reactivity
float audioSinusAmp = sinusAmplitude + bassLevel * 0.5;
tp.y += SIN_AMP * sin(tp.x * SIN_FREQ + time * SIN_SPEED + trebleLevel * 2.0);

// Beat-reactive color pulsing
vec3 textColor = c * vec3(pos, 0.5 + 0.5 * sin(2.0 * time + beatLevel * 3.0));
```

## Advantages Over Simple Character System

### Font Generator (`shit.txt`) vs Simple System:
- ✅ **Signed Distance Fields**: Smooth scaling, no pixelation
- ✅ **Anti-aliasing**: Clean edges at any size
- ✅ **3D Lighting**: Gradient information for depth effects
- ✅ **Special Symbols**: Amiga demo scene characters
- ✅ **Multi-Font Support**: Different fonts for different character types
- ✅ **Robust Rendering**: Handles edge cases and font metrics

### Character Macros vs Hardcoded:
- ✅ **Readable Code**: `_H _E _L _L _O` vs `char(72) char(101) char(108) char(108) char(111)`
- ✅ **Easy Editing**: Change text without looking up ASCII codes
- ✅ **Complete Character Set**: All letters, numbers, symbols
- ✅ **Consistent Spacing**: Automatic character spacing

## Integration Steps

1. **Generate Font Texture**:
   - Open `shit.txt` in browser
   - Save generated texture as PNG/JPG
   - Load as `iChannel0` in shader

2. **Update Shader**:
   - Replace hardcoded `char()` calls with macros
   - Add complete character macro definitions
   - Implement text positioning and effects

3. **Configure Text Content**:
   - Use macros for static text: `_D _I _S _C _O`
   - Or implement dynamic text system with JSON configuration

## File Structure
```
/Textures/
  amiga_font.png          # Generated font texture atlas
/Shaders/
  AmigaSinus3.glsl        # Shader using the font system
shit.txt                  # Font texture generator
Amiga Texture README.md   # This documentation
```

## Notes
- The font generator creates exactly what the GLSL shader expects
- Character positions match ASCII codes for easy mapping
- Distance field data enables smooth text rendering at any scale
- System supports both 2D flat text and 3D lit text effects
