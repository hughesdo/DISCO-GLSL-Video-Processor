#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// User-configurable uniforms (keeping these so your app doesn't break)
uniform float progress;
uniform float raySamples;
uniform float saturation;
uniform float baseIntensity;
uniform float colorShift;
uniform float waveAmplitude;
uniform float pulseSpeed;

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

#define PI 3.1415926538

float DecreaseLightTransition(float adjustedLighting, float originalLighting, float speed)
{
    float decreasedLighting = pow(4.0, smoothstep(adjustedLighting, originalLighting, sin(iTime * speed)));
    return decreasedLighting;
}

void main()
{
    // Fix coordinate system - flip Y coordinate (keep this for your environment)
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;
    
    // Use original raySamples calculation (ignore the uniform for now)
    float actualRaySamples = 140.0 * fract(215.0 - tan(iTime) * 1.28);
    
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord / iResolution.xy;
    float RayScale = 1.0;
    
    // Restore original editUV calculation (remove waveAmplitude)
    vec2 editUV = 0.4 + (uv.y + tan(iTime * atan(iTime * 8.0))) * 
                  sin(uv.x/max(uv.x, 0.001) - 0.32 + tan(sin(iTime * 0.1 * tan(iTime)))) * 
                  vec2((uv * 2.0) - 1.0);
    
    vec2 shake = editUV;
    
    // Restore original progress calculation
    float progress = 500.0 * tan(iTime * 4.245) / iResolution.x - 1.0;
    
    shake.xy *= atan(progress * 1.0 / 22.0) / 1.0;
    
    vec2 displacement = editUV;
    displacement.xy *= atan(progress * PI / 50.0) / sin(iTime + 0.1); // Keep the +0.1 offset for stability
    
    // Sample the input texture
    vec4 col = texture(iChannel0, displacement + uv);
    
    // Restore original intensity calculation (remove baseIntensity and pulseSpeed)
    col *= 0.99 + 0.1 * sin(110.0 * iTime);
    
    // Original vignette effect
    col *= 0.5 + 0.5 * 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    
    // Original lighting transition
    col *= DecreaseLightTransition(12.0, 0.0, 2.0);
    
    // Original ray sampling loop (using actualRaySamples instead of uniform)
    for(float i = 0.0; i < actualRaySamples; i++)
    {
        RayScale -= 0.0002;
        uv -= abs(cos(iTime * 1.0));
        uv *= RayScale;
        uv += abs(cos(iTime * 1.0));
        col += smoothstep(0.0, 0.8, texture(iChannel0, displacement + uv) * 0.2);
    }
    
    // Use original fixed saturation value (ignore the uniform for baseline behavior)
    float actualSaturation = 0.3;
    vec3 luminance = vec3(0.04, 0.04, 0.04);
    float oneMinusSat = 0.1 - actualSaturation;
    
    vec3 red = vec3(luminance.x * oneMinusSat);
    red += vec3(actualSaturation, 0, 0);
    
    vec3 green = vec3(luminance.y * oneMinusSat);
    green += vec3(0, actualSaturation, 0);
    
    vec3 blue = vec3(luminance.z * oneMinusSat);
    blue += vec3(0, 0, actualSaturation);
    
    mat4 fullSat = mat4(
        red,     0,
        green,   0,
        blue,    0,
        0, 0, 0, 1
    );
    
    // Output to screen
    fragColor = vec4(col *= fullSat);
}