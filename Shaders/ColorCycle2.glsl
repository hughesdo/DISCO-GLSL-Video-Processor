#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// Audio-reactive uniforms for vibrating rainbow effects
uniform float bassLevel;        // 0.0 to 1.0, bass frequency energy
uniform float midLevel;         // 0.0 to 1.0, mid frequency energy  
uniform float trebleLevel;      // 0.0 to 1.0, treble frequency energy

// User-configurable uniforms for rainbow vibration
uniform float vibrateIntensity; // How much the rainbows vibrate to music
uniform float rainbowSpeed;     // Speed of rainbow cycling
uniform float rainbowFrequency; // Frequency/density of rainbow bands
uniform float bassVibration;    // How much bass makes rainbows vibrate
uniform float midPulse;         // How much mids make rainbows pulse
uniform float trebleFlash;      // How much treble makes rainbows flash
uniform float audioReactivity;  // Master audio sensitivity
uniform float timeSpeed;        // Overall animation speed
uniform float colorMix;         // Mix between original and rainbow (0=original, 1=full rainbow)

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

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

// Generate rainbow colors based on position and time
vec3 rainbow(float t) {
    t = fract(t); // Keep in [0,1] range
    vec3 color;
    
    if (t < 1.0/6.0) {
        color = vec3(1.0, 6.0*t, 0.0);           // Red to Yellow
    } else if (t < 2.0/6.0) {
        color = vec3(2.0-6.0*t, 1.0, 0.0);       // Yellow to Green
    } else if (t < 3.0/6.0) {
        color = vec3(0.0, 1.0, 6.0*t-2.0);       // Green to Cyan
    } else if (t < 4.0/6.0) {
        color = vec3(0.0, 4.0-6.0*t, 1.0);       // Cyan to Blue
    } else if (t < 5.0/6.0) {
        color = vec3(6.0*t-4.0, 0.0, 1.0);       // Blue to Magenta
    } else {
        color = vec3(1.0, 0.0, 6.0-6.0*t);       // Magenta to Red
    }
    
    return color;
}

// Beat detection function - creates sharp pulses from audio levels
float beatPulse(float audioLevel, float time, float decay) {
    // Create beat impulse - sharp attack, exponential decay
    float beatTime = mod(time, 1.0);
    return audioLevel * exp(-decay * beatTime);
}

// Vibration function - creates rapid oscillations
float vibrate(float audioLevel, float time, float frequency) {
    return audioLevel * sin(time * frequency);
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
    vec3 originalColor = texture(iChannel0, uv).rgb;
    
    // VIBRATING COLOR SHIFT GENERATION (like ColorCycle but with vibrations)

    // Base color shift amount (always animating)
    float baseShift = sin(animTime * rainbowSpeed + uv.x * rainbowFrequency + uv.y * rainbowFrequency * 0.5) * 0.5;

    // BASS VIBRATION - Makes color shifts vibrate
    float bassVibrateShift = vibrate(bassLevel, animTime * 15.0, 25.0) * bassVibration * vibrateIntensity * 0.3;

    // MID PULSE - Makes color shifts pulse
    float midPulseEffect = beatPulse(midLevel, animTime * 3.0, 4.0) * midPulse * 0.4;

    // TREBLE FLASH - Makes color shifts flash
    float trebleFlashEffect = beatPulse(trebleLevel, animTime * 8.0, 6.0) * trebleFlash * 0.2;

    // Combine all color shift effects
    float totalColorShift = baseShift + bassVibrateShift + midPulseEffect + trebleFlashEffect;

    // Add audio-reactive speed variations
    float audioSpeedBoost = (bassLevel + midLevel + trebleLevel) / 3.0 * audioReactivity * 0.3;
    totalColorShift += audioSpeedBoost;

    // Apply hue shift to the original video colors (like ColorCycle)
    vec3 shiftedColor = originalColor;

    // Convert to HSV for better color manipulation
    vec3 hsv = rgb2hsv(originalColor);

    // Apply the vibrating hue shift
    hsv.x += totalColorShift;
    hsv.x = fract(hsv.x); // Keep hue in [0,1] range
    
    // AUDIO-REACTIVE COLOR ENHANCEMENTS (applied to video colors)

    // Bass creates color intensity pulses
    float bassIntensity = 1.0 + beatPulse(bassLevel, animTime * 2.5, 3.0) * audioReactivity * 0.3;

    // Mids create saturation changes
    float midSaturation = 1.0 + midLevel * audioReactivity * 0.5;
    hsv.y *= midSaturation;
    hsv.y = clamp(hsv.y, 0.0, 1.0);

    // Treble creates brightness flashes
    float trebleBrightness = 1.0 + trebleFlashEffect * audioReactivity;
    hsv.z *= trebleBrightness;
    hsv.z = clamp(hsv.z, 0.0, 1.5);

    // Convert back to RGB
    vec3 colorShiftedVideo = hsv2rgb(hsv);

    // Apply bass intensity to the color-shifted video
    colorShiftedVideo *= bassIntensity;

    // ADDITIONAL VIBRATION EFFECTS (applied to the actual video colors)

    // Create color channel vibrations - different frequencies for each channel
    float redVibrate = vibrate(bassLevel, animTime * 18.0, 30.0) * 0.1;
    float greenVibrate = vibrate(midLevel, animTime * 22.0, 35.0) * 0.1;
    float blueVibrate = vibrate(trebleLevel, animTime * 26.0, 40.0) * 0.1;

    colorShiftedVideo.r += redVibrate * vibrateIntensity * audioReactivity;
    colorShiftedVideo.g += greenVibrate * vibrateIntensity * audioReactivity;
    colorShiftedVideo.b += blueVibrate * vibrateIntensity * audioReactivity;

    // Create color "earthquake" effect on strong bass
    float earthquakeEffect = bassLevel * audioReactivity;
    if (earthquakeEffect > 0.7) {
        float shake = sin(animTime * 100.0) * earthquakeEffect * 0.1;
        hsv.x += shake;
        hsv.x = fract(hsv.x);
        colorShiftedVideo = hsv2rgb(hsv);
    }

    // Mix original video with vibrating color-shifted video
    vec3 finalColor = mix(originalColor, colorShiftedVideo, colorMix);
    
    // Add overall audio energy pulse
    float energyPulse = 1.0 + (bassLevel + midLevel + trebleLevel) / 3.0 * audioReactivity * 0.2;
    finalColor *= energyPulse;
    
    // Ensure colors don't blow out but allow some overbright for effect
    finalColor = clamp(finalColor, 0.0, 2.0);
    
    fragColor = vec4(finalColor, 1.0);
}
