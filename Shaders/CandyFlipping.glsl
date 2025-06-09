#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// Audio-reactive uniforms for candy flipping effects
uniform float bassLevel;        // 0.0 to 1.0, bass frequency energy
uniform float midLevel;         // 0.0 to 1.0, mid frequency energy  
uniform float trebleLevel;      // 0.0 to 1.0, treble frequency energy

// User-configurable uniforms for candy flipping control
uniform float flowIntensity;    // Overall flow distortion strength
uniform float waveFrequency;    // Frequency of wave distortions
uniform float pulseSpeed;       // Speed of pulsing effects
uniform float viscosity;        // Viscosity blending effect
uniform float chromaticShift;   // Chromatic aberration intensity
uniform float audioReactivity;  // How much audio affects the effect
uniform float timeSpeed;        // Overall animation speed
uniform float beatSensitivity;  // How sensitive to beat changes

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

// Beat detection function - creates sharp pulses from audio levels
float beatPulse(float audioLevel, float time, float decay) {
    // Create beat impulse - sharp attack, exponential decay
    float beatTime = mod(time, 1.0);
    return audioLevel * exp(-decay * beatTime);
}

// Smooth audio averaging (simulates bass averaging from original)
float getAudioAverage(float bass, float mid, float treble, float time) {
    // Simulate the bass averaging from the original shader
    float avgBass = bass;
    
    // Add some time-based variation to simulate changing audio data
    avgBass += 0.1 * sin(time * 3.0) * mid;
    avgBass += 0.05 * sin(time * 5.0) * treble;
    
    return clamp(avgBass, 0.0, 1.0);
}

void main()
{
    // Fix coordinate system - flip Y coordinate
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;
    
    vec2 uv = fragCoord / iResolution.xy;
    
    // Apply time speed multiplier
    float animTime = iTime * timeSpeed;
    
    // AUDIO-REACTIVE BASS SIMULATION
    // Simulate the bass averaging from the original shader
    float bass = getAudioAverage(bassLevel, midLevel, trebleLevel, animTime);
    
    // Add beat-reactive pulses for more dynamic response
    float bassPulse = beatPulse(bassLevel, animTime * 2.0, 3.0);
    float midPulse = beatPulse(midLevel, animTime * 1.5, 4.0);
    float treblePulse = beatPulse(trebleLevel, animTime * 4.0, 5.0);
    
    // Combine audio effects
    float audioBoost = (bass + bassPulse * 0.5 + midPulse * 0.3 + treblePulse * 0.2) * audioReactivity;
    
    // TIME-BASED DISTORTION WITH AUDIO REACTIVITY
    float t = animTime * pulseSpeed;
    
    // Flow distortion that responds to audio
    float flowX = sin(uv.y * waveFrequency + t) * flowIntensity * 0.05 * (1.0 + audioBoost);
    float flowY = cos(uv.x * waveFrequency + t) * flowIntensity * 0.05 * (1.0 + audioBoost);
    
    // Add beat-reactive distortion variations
    flowX += sin(uv.y * waveFrequency * 2.0 + t * 1.3) * flowIntensity * 0.02 * bassPulse;
    flowY += cos(uv.x * waveFrequency * 1.7 + t * 0.8) * flowIntensity * 0.02 * midPulse;
    
    // Apply distortion to UV coordinates
    vec2 distortedUV = uv + vec2(flowX, flowY);
    
    // CHROMATIC ABERRATION WITH AUDIO REACTIVITY
    // Create audio-reactive chromatic offset
    vec2 chromaticOffset = chromaticShift * vec2(cos(t), sin(t)) * audioBoost;
    
    // Add beat-reactive chromatic variations
    chromaticOffset += chromaticShift * 0.5 * vec2(
        sin(t * 2.0) * bassPulse,
        cos(t * 1.5) * treblePulse
    );
    
    // Sample RGB channels with chromatic aberration
    vec4 rChannel = texture(iChannel0, distortedUV + chromaticOffset);
    vec4 gChannel = texture(iChannel0, distortedUV);
    vec4 bChannel = texture(iChannel0, distortedUV - chromaticOffset);
    
    // VISCOSITY EFFECT WITH AUDIO REACTIVITY
    // Create viscosity blending that responds to audio
    float viscosityBlend = smoothstep(0.0, 1.0, sin(t) * 0.5 + 0.5) * viscosity;
    
    // Add audio-reactive viscosity variations
    viscosityBlend += midLevel * audioReactivity * 0.3 * sin(t * 3.0);
    viscosityBlend = clamp(viscosityBlend, 0.0, 1.0);
    
    // Create the chromatic aberration color
    vec4 chromaticColor = vec4(rChannel.r, gChannel.g, bChannel.b, 1.0);
    
    // Sample normal texture for blending
    vec4 normalColor = texture(iChannel0, distortedUV);
    
    // Apply viscosity blending
    vec4 color = mix(chromaticColor, normalColor, viscosityBlend);
    
    // ADDITIONAL CANDY FLIPPING EFFECTS
    
    // Add beat-reactive color intensity
    float colorIntensity = 1.0 + (bassPulse + midPulse + treblePulse) * audioReactivity * 0.2;
    color.rgb *= colorIntensity;
    
    // Add beat-reactive saturation boost
    float saturationBoost = 1.0 + audioBoost * 0.3;
    vec3 gray = vec3(dot(color.rgb, vec3(0.299, 0.587, 0.114)));
    color.rgb = mix(gray, color.rgb, saturationBoost);
    
    // Add subtle beat-reactive hue shifting
    float hueShift = audioBoost * 0.1 * sin(t * 0.5);
    float s = sin(hueShift), c = cos(hueShift);
    mat3 hueMatrix = mat3(
        vec3(0.299 + 0.701*c + 0.168*s, 0.587 - 0.587*c + 0.330*s, 0.114 - 0.114*c - 0.497*s),
        vec3(0.299 - 0.299*c - 0.328*s, 0.587 + 0.413*c + 0.035*s, 0.114 - 0.114*c + 0.292*s),
        vec3(0.299 - 0.3*c + 1.25*s,   0.587 - 0.588*c - 1.05*s, 0.114 + 0.886*c - 0.203*s)
    );
    color.rgb = color.rgb * hueMatrix;
    
    // Ensure colors don't blow out but allow some overbright for candy effect
    color.rgb = clamp(color.rgb, 0.0, 1.5);
    
    fragColor = color;
}
