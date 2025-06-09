#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// Audio-reactive uniforms for trippy effects
uniform float bassLevel;        // 0.0 to 1.0, bass frequency energy
uniform float midLevel;         // 0.0 to 1.0, mid frequency energy  
uniform float trebleLevel;      // 0.0 to 1.0, treble frequency energy

// User-configurable uniforms for trippy control
uniform float distortionAmount; // Overall distortion strength
uniform float swirlSpeed;       // How fast the swirl rotates
uniform float waveFrequency;    // Frequency of wave distortions
uniform float colorIntensity;   // Color saturation multiplier
uniform float timeSpeed;        // Overall animation speed
uniform float trippyMix;        // Mix between original and trippy (0.0 = original, 1.0 = full trippy)

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

void main()
{
    // Fix coordinate system - flip Y coordinate
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;
    
    // Convert to centered coordinates (-1 to 1) with aspect ratio correction
    vec2 uv = (fragCoord.xy / iResolution.xy) * 2.0 - 1.0;
    uv.x *= iResolution.x / iResolution.y;
    
    // Store original UV for mixing
    vec2 originalUV = fragCoord / iResolution.xy;
    
    // Apply time speed multiplier
    float animTime = iTime * timeSpeed;
    
    // BASS-REACTIVE DISTORTION - Wavy distortions (with built-in animation + audio boost)
    float bassPulse = 0.5 + 0.5 * sin(animTime * 2.0) + bassLevel; // Base animation + audio boost
    float midPulse = 0.5 + 0.5 * cos(animTime * 1.5) + midLevel;   // Base animation + audio boost

    float bassDistortion = sin(uv.x * 20.0 + animTime * 3.0) * 0.1 * bassPulse * distortionAmount;
    bassDistortion += cos(uv.y * 30.0 - animTime * 2.0) * 0.1 * midPulse * distortionAmount;
    uv += vec2(bassDistortion, bassDistortion);

    // SWIRL EFFECT - Rotating spiral distortion (always animated)
    float swirlAmount = swirlSpeed + bassLevel * 0.5; // Base swirl + audio boost
    float swirl = atan(uv.y, uv.x) + animTime * swirlAmount;
    float radius = length(uv);
    uv = vec2(cos(swirl), sin(swirl)) * radius;

    // TREBLE-REACTIVE MICRO-WAVES - High frequency detail distortions
    float treblePulse = 0.3 + 0.3 * sin(animTime * 4.0) + trebleLevel; // Base animation + audio boost
    vec2 microWaves = sin(uv * waveFrequency + animTime * 2.0) * 0.03 * treblePulse * distortionAmount;
    uv += microWaves;
    
    // Convert back to texture coordinates (0 to 1)
    vec2 trippyUV = uv * 0.5 + 0.5;
    
    // Sample the texture with trippy coordinates
    vec3 trippyColor = texture(iChannel0, trippyUV).rgb;
    
    // Sample original texture for mixing
    vec3 originalColor = texture(iChannel0, originalUV).rgb;
    
    // AUDIO-REACTIVE COLOR ENHANCEMENT (with built-in animation)
    // Create pulsing color channels that animate even without audio
    float redPulse = 1.0 + (0.3 + 0.3 * sin(animTime * 2.5) + bassLevel) * colorIntensity;
    float greenPulse = 1.0 + (0.3 + 0.3 * sin(animTime * 3.0 + 2.0) + midLevel) * colorIntensity;
    float bluePulse = 1.0 + (0.3 + 0.3 * sin(animTime * 3.5 + 4.0) + trebleLevel) * colorIntensity;

    vec3 audioColorMult = vec3(redPulse, greenPulse, bluePulse);

    // Apply color enhancement and contrast boost
    trippyColor = pow(trippyColor, vec3(1.5)) * audioColorMult;

    // Mix between original and trippy based on trippyMix parameter
    vec3 finalColor = mix(originalColor, trippyColor, trippyMix);

    // Add pulsing brightness (always animated + audio boost)
    float baseEnergy = 0.5 + 0.5 * sin(animTime * 3.0);
    float audioEnergy = (bassLevel + midLevel + trebleLevel) / 3.0;
    float pulse = 1.0 + sin(animTime * 4.0) * (baseEnergy + audioEnergy) * 0.2;
    finalColor *= pulse;
    
    // Ensure colors don't blow out
    finalColor = clamp(finalColor, 0.0, 2.0);
    
    fragColor = vec4(finalColor, 1.0);
}
