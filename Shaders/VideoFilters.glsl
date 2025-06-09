#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// User-configurable uniforms for filter control
uniform float filterMode;           // 0=desaturate, 1=invert, 2=chromatic, 3=color switch, 4=all quadrants
uniform float chromaticAmount;      // Chromatic aberration intensity
uniform float showDividers;         // Show divider lines between filters (0=off, 1=on)
uniform float dividerWidth;         // Width of divider lines
uniform float saturationAmount;     // Desaturation amount (0=full color, 1=full desaturate)
uniform float invertAmount;         // Invert amount (0=normal, 1=full invert)
uniform float colorShiftMode;       // Color channel shifting mode (0=brg, 1=gbr, 2=rbg)

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

void main()
{
    // Fix coordinate system - flip Y coordinate
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;
    
    vec2 p = fragCoord.xy / iResolution.xy;
    
    vec4 col = texture(iChannel0, p);
    vec4 originalCol = col;
    
    // Determine which filter to apply based on mode
    if (filterMode < 0.5) {
        // Mode 0: Show all quadrants (original behavior)
        
        // Desaturate (left quarter)
        if (p.x < 0.25) {
            float gray = (col.r + col.g + col.b) / 3.0;
            col = mix(originalCol, vec4(gray, gray, gray, col.a), saturationAmount);
        }
        // Invert (second quarter)
        else if (p.x < 0.5) {
            vec4 inverted = vec4(1.0) - texture(iChannel0, p);
            inverted.a = col.a; // Keep original alpha
            col = mix(originalCol, inverted, invertAmount);
        }
        // Chromatic aberration (third quarter)
        else if (p.x < 0.75) {
            vec2 offset = vec2(chromaticAmount, 0.0);
            col.r = texture(iChannel0, p + offset.xy).r;
            col.g = texture(iChannel0, p).g;
            col.b = texture(iChannel0, p + offset.yx).b;
        }
        // Color switching (right quarter)
        else {
            if (colorShiftMode < 0.5) {
                col.rgb = texture(iChannel0, p).brg; // Blue, Red, Green
            } else if (colorShiftMode < 1.5) {
                col.rgb = texture(iChannel0, p).gbr; // Green, Blue, Red
            } else {
                col.rgb = texture(iChannel0, p).rbg; // Red, Blue, Green
            }
        }
        
        // Draw divider lines
        if (showDividers > 0.5) {
            float lineWidth = dividerWidth / iResolution.x;
            if (mod(abs(p.x + 0.5 / iResolution.y), 0.25) < lineWidth) {
                col = vec4(1.0);
            }
        }
    }
    else if (filterMode < 1.5) {
        // Mode 1: Full screen desaturate
        float gray = (col.r + col.g + col.b) / 3.0;
        col = mix(originalCol, vec4(gray, gray, gray, col.a), saturationAmount);
    }
    else if (filterMode < 2.5) {
        // Mode 2: Full screen invert
        vec4 inverted = vec4(1.0) - texture(iChannel0, p);
        inverted.a = col.a; // Keep original alpha
        col = mix(originalCol, inverted, invertAmount);
    }
    else if (filterMode < 3.5) {
        // Mode 3: Full screen chromatic aberration
        vec2 offset = vec2(chromaticAmount, 0.0);
        col.r = texture(iChannel0, p + offset.xy).r;
        col.g = texture(iChannel0, p).g;
        col.b = texture(iChannel0, p + offset.yx).b;
    }
    else {
        // Mode 4: Full screen color switching
        if (colorShiftMode < 0.5) {
            col.rgb = texture(iChannel0, p).brg; // Blue, Red, Green
        } else if (colorShiftMode < 1.5) {
            col.rgb = texture(iChannel0, p).gbr; // Green, Blue, Red
        } else {
            col.rgb = texture(iChannel0, p).rbg; // Red, Blue, Green
        }
    }
    
    fragColor = col;
}
