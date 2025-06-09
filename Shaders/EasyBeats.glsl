#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// Audio-reactive uniforms (automatically provided by audio analysis)
uniform float bassLevel;        // 0.0 to 1.0, bass frequency energy
uniform float midLevel;         // 0.0 to 1.0, mid frequency energy  
uniform float trebleLevel;      // 0.0 to 1.0, treble frequency energy
uniform float beatLevel;        // 0.0 to 1.0, general beat detection
uniform float kickLevel;        // 0.0 to 1.0, kick drum detection

// Simple, foolproof controls - fewer options, more impact
uniform float intensity;        // Overall effect intensity (0.0 = off, 1.0 = normal, 2.0 = intense)
uniform float shakeAmount;      // Screen shake strength (0.0 = no shake, 1.0 = strong shake)
uniform float colorPop;         // Color enhancement on beats (0.0 = none, 1.0 = vibrant)

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

// Simple random function for shake
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void main()
{
    // Fix coordinate system - flip Y coordinate
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;
    
    // Get normalized texture coordinates
    vec2 uv = fragCoord / iResolution.xy;
    
    // SCREEN SHAKE EFFECT - Beat-reactive camera shake
    vec2 shakeOffset = vec2(0.0);
    
    // Strong kicks trigger screen shake
    float kickStrength = kickLevel * intensity;
    if (kickStrength > 0.3) {
        // Create omnidirectional shake
        float shakeTime = iTime * 50.0; // Fast shake frequency
        float shakeDecay = exp(-kickStrength * 8.0); // Rapid decay
        
        // Random shake direction
        vec2 shakeDir = vec2(
            sin(shakeTime + kickStrength * 10.0),
            cos(shakeTime * 1.3 + kickStrength * 15.0)
        );
        
        // Apply shake with user control
        shakeOffset = shakeDir * kickStrength * shakeAmount * 0.02;
        
        // Keep shake within reasonable bounds
        shakeOffset = clamp(shakeOffset, -0.05, 0.05);
    }
    
    // Apply shake to UV coordinates
    vec2 shakenUV = uv + shakeOffset;
    
    // Sample the video texture with shake applied
    vec3 color = texture(iChannel0, shakenUV).rgb;
    
    // BEAT-REACTIVE COLOR ENHANCEMENT
    // Simple but effective color popping on beats
    float beatPulse = beatLevel * intensity;
    
    if (beatPulse > 0.4) {
        // Enhance colors on strong beats
        color = pow(color, vec3(0.8)); // Increase contrast
        color *= (1.0 + beatPulse * colorPop * 0.5); // Brightness boost
        
        // Add subtle color shift on beats
        color.r *= (1.0 + bassLevel * colorPop * 0.2);
        color.g *= (1.0 + midLevel * colorPop * 0.2);
        color.b *= (1.0 + trebleLevel * colorPop * 0.2);
    }
    
    // BASS-REACTIVE PULSE
    // Simple pulsing effect that follows the bass
    float bassPulse = bassLevel * intensity;
    if (bassPulse > 0.3) {
        // Subtle zoom effect on bass hits
        vec2 center = vec2(0.5);
        vec2 centeredUV = uv - center;
        float zoomFactor = 1.0 + bassPulse * 0.02;
        vec2 zoomedUV = centeredUV / zoomFactor + center;
        
        // Blend between normal and zoomed
        vec3 zoomedColor = texture(iChannel0, zoomedUV + shakeOffset).rgb;
        color = mix(color, zoomedColor, bassPulse * 0.5);
    }
    
    // TREBLE-REACTIVE SPARKLE
    // Add subtle sparkle/noise on treble hits
    float treblePulse = trebleLevel * intensity;
    if (treblePulse > 0.5) {
        // Create sparkle effect
        float noise = random(uv + iTime * 0.1);
        if (noise > (1.0 - treblePulse * 0.1)) {
            color += vec3(treblePulse * colorPop * 0.3);
        }
    }
    
    // AUTOMATIC ENERGY COMPENSATION
    // Ensure the effect always looks good regardless of audio levels
    float totalEnergy = (bassLevel + midLevel + trebleLevel) / 3.0;
    
    // Boost effects when audio is quiet
    if (totalEnergy < 0.3) {
        color *= (1.0 + (0.3 - totalEnergy) * intensity * 0.2);
    }
    
    // Prevent overexposure when audio is loud
    if (totalEnergy > 0.8) {
        color *= (1.0 - (totalEnergy - 0.8) * 0.3);
    }
    
    // FINAL POLISH
    // Subtle vignette to keep focus on center
    vec2 vignetteUV = uv - 0.5;
    float vignette = 1.0 - dot(vignetteUV, vignetteUV) * 0.3;
    color *= vignette;
    
    // Ensure colors stay in reasonable range
    color = clamp(color, 0.0, 2.0);
    
    fragColor = vec4(color, 1.0);
}
