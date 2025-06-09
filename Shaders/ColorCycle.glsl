#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// Audio-reactive uniforms for color cycling
uniform float bassLevel;        // 0.0 to 1.0, bass frequency energy
uniform float midLevel;         // 0.0 to 1.0, mid frequency energy  
uniform float trebleLevel;      // 0.0 to 1.0, treble frequency energy

// User-configurable uniforms for color control
uniform float cycleSpeed;       // Speed of color cycling animation
uniform float audioReactivity;  // How much audio affects color cycling (0.0 = none, 1.0 = full)
uniform float spatialFrequency; // Spatial frequency of color patterns
uniform float hueRange;         // Range of hue shifting (0.0 = none, 1.0 = full spectrum)
uniform float bassHueShift;     // How much bass affects hue shifting
uniform float midSaturation;    // How much mids affect saturation
uniform float trebleBrightness; // How much treble affects brightness
uniform float timeSpeed;        // Overall animation speed multiplier

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

// Hue shift function - rotates colors through the spectrum
vec3 hueShift(vec3 color, float shift) {
    float angle = shift * 6.28318; // 2*pi for full rotation
    float s = sin(angle), c = cos(angle);
    
    // RGB to HSV rotation matrix
    mat3 rot = mat3(
        vec3(0.299 + 0.701*c + 0.168*s, 0.587 - 0.587*c + 0.330*s, 0.114 - 0.114*c - 0.497*s),
        vec3(0.299 - 0.299*c - 0.328*s, 0.587 + 0.413*c + 0.035*s, 0.114 - 0.114*c + 0.292*s),
        vec3(0.299 - 0.3*c + 1.25*s,   0.587 - 0.588*c - 1.05*s, 0.114 + 0.886*c - 0.203*s)
    );
    
    return clamp(color * rot, 0.0, 1.0);
}

// Convert RGB to HSV for better color manipulation
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Convert HSV back to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main()
{
    // Fix coordinate system - flip Y coordinate
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;
    
    vec2 uv = fragCoord / iResolution.xy;
    
    // Apply time speed multiplier
    float animTime = iTime * timeSpeed;
    
    // Sample original color
    vec3 color = texture(iChannel0, uv).rgb;
    
    // AUDIO-REACTIVE COLOR CYCLING
    
    // Base color cycling animation (always active)
    float baseCycle = sin(animTime * cycleSpeed + uv.x * spatialFrequency + uv.y * spatialFrequency) * 0.5;
    
    // Audio-reactive enhancements
    float audioCycle = (bassLevel * bassHueShift + midLevel * 0.3 + trebleLevel * 0.2) * audioReactivity;
    
    // Combine base animation with audio reactivity
    float totalShift = (baseCycle + audioCycle) * hueRange;
    
    // Apply hue shifting
    color = hueShift(color, totalShift);
    
    // ADDITIONAL AUDIO-REACTIVE COLOR EFFECTS
    
    // Convert to HSV for more precise color control
    vec3 hsv = rgb2hsv(color);
    
    // Mid frequencies affect saturation (color intensity)
    float saturationBoost = 1.0 + midLevel * midSaturation * audioReactivity;
    hsv.y *= saturationBoost;
    hsv.y = clamp(hsv.y, 0.0, 1.0);
    
    // Treble frequencies affect brightness/value
    float brightnessBoost = 1.0 + trebleLevel * trebleBrightness * audioReactivity;
    hsv.z *= brightnessBoost;
    hsv.z = clamp(hsv.z, 0.0, 1.2); // Allow slight overbright
    
    // Bass creates additional hue shifts in different areas
    float bassHueOffset = bassLevel * audioReactivity * 0.1 * sin(uv.x * 20.0 + animTime * 2.0);
    hsv.x += bassHueOffset;
    hsv.x = fract(hsv.x); // Keep hue in [0,1] range
    
    // Convert back to RGB
    color = hsv2rgb(hsv);
    
    // Add subtle audio-reactive color pulsing
    float audioPulse = 1.0 + (bassLevel + midLevel + trebleLevel) / 3.0 * audioReactivity * 0.1;
    color *= audioPulse;
    
    // Ensure colors don't blow out
    color = clamp(color, 0.0, 1.5);
    
    fragColor = vec4(color, 1.0);
}
