#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// User-configurable uniforms for webby control
uniform float webIntensity;     // Overall web distortion intensity
uniform float webFrequency;     // Frequency of web patterns
uniform float webSpeed;         // Speed of web animation
uniform float timeSpeed;        // Overall animation speed multiplier
uniform float horizontalWarp;   // Horizontal warping strength
uniform float verticalWarp;     // Vertical warping strength
uniform float colorPower;       // Power function applied to colors
uniform float colorFrequency;   // Frequency of color modulation

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

void main()
{
    // Fix coordinate system - flip Y coordinate
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;
    
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord / iResolution.xy;
    
    // Apply time speed multiplier
    float animTime = iTime * timeSpeed;
    
    // Create webby distortion effects
    // Horizontal warping with configurable intensity and frequency
    uv.x *= 1.0 + sin(animTime * webSpeed) / 5.5 * sin(uv.y * webFrequency) * horizontalWarp;
    
    // Vertical warping with configurable intensity and frequency  
    uv.y += 0.2 * cos(uv.x * (webFrequency * 0.67)) / 5.0 * sin(animTime * webSpeed * 0.001) * verticalWarp;
    
    // Apply overall web intensity scaling
    vec2 center = vec2(0.5);
    vec2 offset = (uv - center) * webIntensity;
    uv = center + offset;
    
    // Sample the texture with webby distortion
    vec4 cam = texture(iChannel0, uv);
    
    // Apply color transformation with configurable parameters
    vec3 col = pow(cos(colorFrequency * cam.rgb), vec3(colorPower));
    
    // Output to screen
    fragColor = vec4(col, 1.0);
}
