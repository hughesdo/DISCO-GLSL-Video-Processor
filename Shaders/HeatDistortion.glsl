#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// Audio-reactive uniforms for heat distortion
uniform float bassLevel;        // 0.0 to 1.0, bass frequency energy
uniform float midLevel;         // 0.0 to 1.0, mid frequency energy  
uniform float trebleLevel;      // 0.0 to 1.0, treble frequency energy

// User-configurable uniforms for heat control
uniform float heatStrength;     // Overall heat distortion intensity
uniform float heatSpeed;        // How fast the heat waves move
uniform float heatFrequency;    // Frequency/scale of heat patterns
uniform float audioReactivity;  // How much audio affects heat (0.0 = none, 1.0 = full)
uniform float timeSpeed;        // Overall animation speed multiplier
uniform float noiseComplexity;  // Noise detail level (higher = more complex)

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

// Hash function for noise generation
float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

// Simple 3D noise function
float noise(vec3 x) {
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    
    float n = p.x + p.y * 157.0 + 113.0 * p.z;
    return mix(mix(mix(hash(n +   0.0), hash(n +   1.0), f.x),
                   mix(hash(n + 157.0), hash(n + 158.0), f.x), f.y),
               mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
                   mix(hash(n + 270.0), hash(n + 271.0), f.x), f.y), f.z);
}

// Fractal Brownian Motion to create complex noise patterns
float fbm(vec3 p, int octaves) {
    float sum = 0.0;
    float amp = 1.0;
    float freq = 1.0;
    
    // Variable octaves based on complexity setting
    for(int i = 0; i < octaves; i++) {
        sum += noise(p * freq) * amp;
        amp *= 0.5;
        freq *= 2.0;
    }
    
    return sum;
}

void main()
{
    // Fix coordinate system - flip Y coordinate
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;
    
    // Get normalized texture coordinates
    vec2 uv = fragCoord / iResolution.xy;
    
    // Apply time speed multiplier
    float animTime = iTime * timeSpeed;
    
    // AUDIO-REACTIVE HEAT PARAMETERS
    // Base heat animation + audio boost
    float baseHeatIntensity = 0.5 + 0.3 * sin(animTime * 1.5); // Always animating
    float audioHeatBoost = (bassLevel + midLevel + trebleLevel) / 3.0 * audioReactivity;
    float totalHeatStrength = heatStrength * (baseHeatIntensity + audioHeatBoost);
    
    // Audio-reactive speed variation
    float baseSpeed = heatSpeed;
    float audioSpeedBoost = bassLevel * audioReactivity * 2.0; // Bass makes heat faster
    float totalHeatSpeed = baseSpeed + audioSpeedBoost;
    
    // Audio-reactive frequency variation  
    float baseFreq = heatFrequency;
    float audioFreqBoost = trebleLevel * audioReactivity * 3.0; // Treble adds detail
    float totalHeatFreq = baseFreq + audioFreqBoost;
    
    // Determine noise complexity (more octaves = more detail)
    int octaves = int(3.0 + noiseComplexity * 3.0); // 3-6 octaves
    
    // Create complex noise patterns using FBM with audio-reactive parameters
    float noiseX = fbm(vec3(uv * totalHeatFreq, animTime * totalHeatSpeed), octaves);
    float noiseY = fbm(vec3(uv * totalHeatFreq + vec2(43.21, 56.78), 
                           animTime * totalHeatSpeed * 0.7 + 10.0), octaves);
    
    // Add second layer of noise for more complexity (mid-frequency driven)
    float midBoost = 1.0 + midLevel * audioReactivity;
    float noiseX2 = fbm(vec3(uv * totalHeatFreq * 2.0 + vec2(123.45, 78.90), 
                            animTime * totalHeatSpeed * 1.3), octaves) * midBoost;
    float noiseY2 = fbm(vec3(uv * totalHeatFreq * 2.0 + vec2(87.65, 43.21), 
                            animTime * totalHeatSpeed * 0.9 + 5.0), octaves) * midBoost;
    
    // Mix noise layers
    float finalNoiseX = mix(noiseX, noiseX2, 0.5);
    float finalNoiseY = mix(noiseY, noiseY2, 0.5);
    
    // Calculate distortion offset - applies to entire screen
    vec2 offset = vec2(
        (finalNoiseX * 2.0 - 1.0) * totalHeatStrength, 
        (finalNoiseY * 2.0 - 1.0) * totalHeatStrength
    );

    // Apply distortion with clamping to prevent sampling outside texture
    vec2 distortedUV = clamp(uv + offset, 0.0, 1.0);
    vec4 texColor = texture(iChannel0, distortedUV);
    
    // Add subtle heat shimmer effect (brightness variation)
    float shimmer = 1.0 + sin(animTime * 8.0 + length(offset) * 50.0) * 0.05 * totalHeatStrength;
    texColor.rgb *= shimmer;
    
    // Add subtle color temperature shift based on heat intensity
    float heatGlow = length(offset) * 10.0;
    vec3 heatTint = vec3(1.0 + heatGlow * 0.1, 1.0 - heatGlow * 0.05, 1.0 - heatGlow * 0.1);
    texColor.rgb *= heatTint;
    
    // Ensure colors don't blow out
    texColor.rgb = clamp(texColor.rgb, 0.0, 1.2);
    
    fragColor = texColor;
}
