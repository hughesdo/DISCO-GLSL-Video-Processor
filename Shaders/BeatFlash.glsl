#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// Audio-reactive uniforms for beat detection
uniform float beatAmplitude;    // 0.0 to 1.0, current detected beat level (main trigger)
uniform float kickLevel;        // 0.0 to 1.0, kick drum energy
uniform float bassLevel;        // 0.0 to 1.0, bass frequency energy

// Beat flash control uniforms
uniform float beatSensitivity;  // Threshold for triggering visual flash (0.0-1.0)
uniform float flashStrength;    // Intensity of color inversion and effects (0.0-3.0+)
uniform float flashDecay;       // How quickly effect fades (1.0=slow, 10.0=fast)
uniform float chromaticOffset;  // RGB channel separation amount
uniform float exposureBoost;    // Brightness boost during flash
uniform float bloomIntensity;   // White bloom effect strength
uniform float posterizeLevel;   // Posterization effect strength
uniform float timeSpeed;        // Overall animation speed multiplier

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

// Beat detection function - creates sharp flash impulses
float detectBeatFlash(float beatAmp, float kickEnergy, float bassEnergy, float time) {
    // Combine beat sources with emphasis on kick drums
    float combinedBeat = beatAmp * 0.6 + kickEnergy * 0.3 + bassEnergy * 0.1;
    
    // Only trigger if above sensitivity threshold
    if (combinedBeat < beatSensitivity) {
        return 0.0;
    }
    
    // Create sharp flash impulse - instant peak, exponential decay
    float flashTime = mod(time * 15.0, 1.0); // 15Hz flash detection rate
    float flashImpulse = (combinedBeat - beatSensitivity) * exp(-flashDecay * flashTime);
    
    return clamp(flashImpulse, 0.0, 1.0);
}

// Color inversion function
vec3 invertColors(vec3 color, float strength) {
    vec3 inverted = vec3(1.0) - color;
    return mix(color, inverted, strength);
}

// Posterization effect
vec3 posterize(vec3 color, float levels) {
    if (levels <= 1.0) return color;
    
    vec3 posterized = floor(color * levels) / levels;
    return posterized;
}

// Exposure adjustment
vec3 adjustExposure(vec3 color, float exposure) {
    return color * pow(2.0, exposure);
}

// White bloom effect
vec3 addBloom(vec3 color, float intensity) {
    float luminance = dot(color, vec3(0.299, 0.587, 0.114));
    vec3 bloom = vec3(luminance) * intensity;
    return color + bloom;
}

void main()
{
    // Fix coordinate system - flip Y coordinate
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;
    
    // Normalize to [0..1]
    vec2 uv = fragCoord / iResolution.xy;
    
    // Apply time speed multiplier
    float animTime = iTime * timeSpeed;
    
    // BEAT FLASH DETECTION
    // Detect beat hits that should trigger flash
    float flashIntensity = detectBeatFlash(beatAmplitude, kickLevel, bassLevel, animTime);
    
    // CHROMATIC ABERRATION SAMPLING
    // Sample RGB channels with slight offsets during flash
    vec2 chromaticOffsetAmount = vec2(chromaticOffset) * flashIntensity * flashStrength;
    
    // Red channel - offset right
    vec4 rChannel = texture(iChannel0, uv + chromaticOffsetAmount);
    
    // Green channel - no offset (center)
    vec4 gChannel = texture(iChannel0, uv);
    
    // Blue channel - offset left
    vec4 bChannel = texture(iChannel0, uv - chromaticOffsetAmount);
    
    // Combine channels for chromatic aberration effect
    vec3 chromaticColor = vec3(rChannel.r, gChannel.g, bChannel.b);
    
    // Sample normal video for blending
    vec3 normalColor = texture(iChannel0, uv).rgb;
    
    // FLASH EFFECT PROCESSING
    vec3 flashColor = chromaticColor;
    
    if (flashIntensity > 0.0) {
        // Apply color inversion
        flashColor = invertColors(flashColor, flashIntensity * flashStrength * 0.8);
        
        // Apply exposure boost
        float exposureAmount = exposureBoost * flashIntensity * flashStrength;
        flashColor = adjustExposure(flashColor, exposureAmount);
        
        // Apply white bloom
        float bloomAmount = bloomIntensity * flashIntensity * flashStrength;
        flashColor = addBloom(flashColor, bloomAmount);
        
        // Apply posterization for digital burn effect
        float posterizeLevels = mix(256.0, posterizeLevel, flashIntensity * flashStrength);
        flashColor = posterize(flashColor, posterizeLevels);
        
        // Add slight desaturation for burn effect
        float desaturation = flashIntensity * 0.3;
        vec3 gray = vec3(dot(flashColor, vec3(0.299, 0.587, 0.114)));
        flashColor = mix(flashColor, gray, desaturation);
        
        // Add subtle color temperature shift (cooler during flash)
        flashColor.b += flashIntensity * 0.1;
        flashColor.r -= flashIntensity * 0.05;
    }
    
    // FLASH BLENDING
    // Blend between normal video and flash effect
    float flashBlend = flashIntensity * flashStrength;
    vec3 finalColor = mix(normalColor, flashColor, flashBlend);
    
    // ADDITIONAL BEAT FLASH ENHANCEMENTS
    
    // Add brief white flash overlay for extra punch
    if (flashIntensity > 0.7) {
        float whiteFlash = (flashIntensity - 0.7) * 3.33; // Scale 0.7-1.0 to 0.0-1.0
        finalColor = mix(finalColor, vec3(1.0), whiteFlash * flashStrength * 0.3);
    }
    
    // Add subtle vignette during flash for focus effect
    if (flashIntensity > 0.0) {
        vec2 center = uv - 0.5;
        float vignette = 1.0 - dot(center, center) * flashIntensity * 0.5;
        finalColor *= vignette;
    }
    
    // Add film grain effect during flash
    if (flashIntensity > 0.0) {
        float grain = fract(sin(dot(uv * animTime, vec2(12.9898, 78.233))) * 43758.5453);
        grain = (grain - 0.5) * flashIntensity * 0.1;
        finalColor += grain;
    }
    
    // Ensure colors don't blow out but allow some overbright for flash effect
    finalColor = clamp(finalColor, 0.0, 2.0);
    
    fragColor = vec4(finalColor, 1.0);
}
