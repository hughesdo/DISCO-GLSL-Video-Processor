#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// User-configurable uniforms for warping control
uniform float warpMode;         // 0=procedural, 1=texture-based warping
uniform float warpIntensity;    // Overall warp strength multiplier
uniform float warpFrequency;    // Frequency of warp patterns
uniform float warpSpeed;        // Speed of warp animation
uniform float timeSpeed;        // Overall animation speed multiplier
uniform float layer1Amp;        // Amplitude of first warp layer
uniform float layer2Amp;        // Amplitude of second warp layer
uniform float layer3Amp;        // Amplitude of third warp layer
uniform float layer4Amp;        // Amplitude of fourth warp layer

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

void main()
{
    // Fix coordinate system - flip Y coordinate
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;
    
    vec2 uv = fragCoord / iResolution.xy;
    
    // Apply time speed multiplier
    float animTime = iTime * timeSpeed;
    
    vec2 warp;
    
    if (warpMode < 0.5) {
        // Procedural warping (enhanced version of original)
        float freq = warpFrequency * sin(0.5 * animTime * warpSpeed);
        
        // Multi-layer procedural warp with configurable amplitudes
        warp = layer1Amp * cos(uv.xy * 1.0 * freq + vec2(0.0, 1.0) + animTime * warpSpeed) +
               layer2Amp * cos(uv.yx * 2.3 * freq + vec2(1.0, 2.0) + animTime * warpSpeed) +
               layer3Amp * cos(uv.xy * 4.1 * freq + vec2(5.0, 3.0) + animTime * warpSpeed) +
               layer4Amp * cos(uv.yx * 7.9 * freq + vec2(3.0, 4.0) + animTime * warpSpeed);
    }
    else {
        // Texture-based warping (using the video itself as warp source)
        vec2 warpSampleUV = uv * 0.1 + animTime * warpSpeed * vec2(0.04, 0.03);
        vec4 warpSample = texture(iChannel0, warpSampleUV);
        warp = warpSample.xz; // Use red and blue channels for X and Z displacement
        
        // Normalize and scale the warp
        warp = (warp - 0.5) * 2.0; // Convert from [0,1] to [-1,1]
    }
    
    // Apply warp intensity
    vec2 st = uv + warp * warpIntensity;
    
    // Sample the warped texture
    fragColor = vec4(texture(iChannel0, st).xyz, 1.0);
}
