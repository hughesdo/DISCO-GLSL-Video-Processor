// Source: https://www.shadertoy.com/view/Wcc3z2
// Author: @XorDev on X (formerly Twitter)

#version 330
precision highp float;

uniform vec2 iResolution;
uniform float iTime;
uniform sampler2D iChannel0;  // video input

// Audio reactive uniforms
uniform float bassLevel;
uniform float midLevel;
uniform float trebleLevel;
uniform float beatLevel;
uniform float kickLevel;
uniform float rmsLevel;

out vec4 fragColor;

// your original ShaderToy mainImage, tweaked:
void mainImage(out vec4 O, vec2 I) {
  float i, d, z, rr;
  for (O *= i; i++ < 90.0;
       O += (cos(z * 0.5 + iTime + vec4(0,2,4,3)) + 1.3) / d / z )
  {
    vec3 R = vec3(iResolution.x, iResolution.y, iResolution.y);
    vec3 p = z * normalize(vec3(I + I, 0.0) - R);
    rr = max(-++p, 0.0).y;
    
    // Enhanced audio reactivity: combine multiple audio features
    float audioIntensity = bassLevel * 0.4 + midLevel * 0.3 + trebleLevel * 0.3;
    float beatPulse = beatLevel * kickLevel;
    
    // sample audio texture: x coordinate from geometry, y from depth
    float a = texture(iChannel0, vec2((p.x + 6.5) / 15.0,
                  (-p.z - 3.0) * 50.0 / R.y)).r;
    
    // Apply audio reactivity to the waveform displacement
    p.y += rr + rr - 4.0 * a - 2.0 * audioIntensity - beatPulse;
    
    z += d = 0.1 * (0.1 * rr + abs(p.y) / (1.0 + rr + rr + rr*rr)
                   + max(d = p.z + 3.0, -d * 0.1));
  }
  O = tanh(O / 900.0);
}

void main() {
    mainImage(fragColor, gl_FragCoord.xy);
}
