#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// Audio-reactive uniforms for ripple effects
uniform float trebleLevel;      // 0.0 to 1.0, treble frequency energy (main driver)
uniform float bassLevel;        // 0.0 to 1.0, bass frequency energy (for low ripples)
uniform float midLevel;         // 0.0 to 1.0, mid frequency energy (for mid ripples)

// User-configurable uniforms for ripple control
uniform float rippleIntensity;  // Overall ripple strength multiplier
uniform float rippleFrequency;  // How many ripples (higher = more rings)
uniform float rippleSpeed;      // How fast ripples move outward
uniform float centerX;          // Ripple center X position (0.0 to 1.0)
uniform float centerY;          // Ripple center Y position (0.0 to 1.0)
uniform float multiRipple;      // Enable multiple ripple sources (0.0 = single, 1.0 = multi)
uniform float timeSpeed;        // Overall animation speed multiplier

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

void main()
{
    // Fix coordinate system - flip Y coordinate
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;
    
    // Normalize to [0..1]
    vec2 uv = fragCoord / iResolution.xy;
    
    // Apply time speed multiplier
    float animTime = iTime * timeSpeed;
    
    // Main ripple center (user configurable)
    vec2 center = vec2(centerX, centerY);
    float dist = distance(uv, center);
    
    // TREBLE-DRIVEN MAIN RIPPLES - High frequency creates fine ripples
    float baseRippleAmount = 0.3 + 0.3 * sin(animTime * 2.0); // Base animation
    float trebleRipple = (baseRippleAmount + trebleLevel) * rippleIntensity;
    float mainRipple = sin(dist * rippleFrequency - animTime * rippleSpeed) * 0.02 * trebleRipple;
    
    // BASS-DRIVEN SLOW RIPPLES - Low frequency creates large, slow ripples
    float bassRippleAmount = 0.2 + 0.2 * sin(animTime * 1.0); // Base animation
    float bassRipple = (bassRippleAmount + bassLevel) * rippleIntensity;
    float slowRipple = sin(dist * (rippleFrequency * 0.3) - animTime * (rippleSpeed * 0.5)) * 0.03 * bassRipple;
    
    // MID-DRIVEN MEDIUM RIPPLES - Mid frequency creates medium ripples
    float midRippleAmount = 0.25 + 0.25 * sin(animTime * 1.5); // Base animation
    float midRipple = (midRippleAmount + midLevel) * rippleIntensity;
    float mediumRipple = sin(dist * (rippleFrequency * 0.6) - animTime * (rippleSpeed * 0.75)) * 0.025 * midRipple;
    
    // MULTIPLE RIPPLE SOURCES (when multiRipple > 0.5)
    vec2 rippleOffset = vec2(0.0);
    
    if (multiRipple > 0.5) {
        // Additional ripple centers for more complex patterns
        vec2 center2 = vec2(0.3, 0.7);
        vec2 center3 = vec2(0.7, 0.3);
        
        float dist2 = distance(uv, center2);
        float dist3 = distance(uv, center3);
        
        // Secondary ripples with different phases
        float ripple2 = sin(dist2 * rippleFrequency - animTime * rippleSpeed + 2.0) * 0.015 * trebleRipple;
        float ripple3 = sin(dist3 * rippleFrequency - animTime * rippleSpeed + 4.0) * 0.015 * trebleRipple;
        
        rippleOffset += vec2(ripple2 + ripple3);
    }
    
    // Combine all ripple effects
    vec2 totalRipple = vec2(mainRipple + slowRipple + mediumRipple) + rippleOffset;
    
    // Sample the texture with ripple displacement
    vec3 color = texture(iChannel0, uv + totalRipple).rgb;
    
    // Add subtle brightness pulse based on audio energy
    float audioEnergy = (trebleLevel + bassLevel + midLevel) / 3.0;
    float energyPulse = 1.0 + (0.1 + 0.1 * sin(animTime * 3.0) + audioEnergy * 0.1);
    color *= energyPulse;
    
    // Add subtle color tinting based on ripple intensity
    float rippleGlow = length(totalRipple) * 20.0;
    vec3 rippleTint = vec3(1.0 + rippleGlow * 0.1, 1.0, 1.0 + rippleGlow * 0.05);
    color *= rippleTint;
    
    // Ensure colors don't blow out
    color = clamp(color, 0.0, 1.5);
    
    fragColor = vec4(color, 1.0);
}
