// Created by sebastien durand - 11/2024
// License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported License.
// Adapted for DISCO system by Augment Agent

// Original idea from:
// https://whenistheweekend.com/theSphere.html

#version 330

uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;  // stabilizedSphere_2.mp4 (ping-pong looped)
uniform sampler2D iChannel2;  // User input video

in vec2 v_text;
out vec4 fragColor;

// #define WITH_GRID // display grid (disabled)
#define AA 4

float iSphere(in vec3 ro, in vec3 rd, in float r, out float e) {
    float b = dot(rd,-ro), d = b*b - dot(ro,ro) + r*r;
    if (d < 0.) return -1.;
    e = sqrt(d);
    return b - e;
}

// Grid function removed - no longer needed

void main() {
    vec2 fragCoord = v_text * iResolution;
    
    float r = 1.575,      // sphere radius
          hGround = .1,   // ground elevation (sphere is at 0,0,0)
          // PING-PONG TWIST: Create triangle wave instead of sawtooth
          cycle = mod(iTime, 40.7),  // Full cycle time (was 20.35 * 2)
          an = -0.0205 * (cycle < 20.35 ? cycle : 40.7 - cycle); // Twist then untwist
    
    vec3 ro = vec3( 3.5*cos(an), 1.7, 3.5*sin(an) ),
         ww = normalize( -ro ),
         uu = normalize( cross(ww,vec3(0.0,1.,0.0) ) ),
         vv = normalize( cross(uu,ww));

    vec4 tot = vec4(0);
    
    for (int j=0; j<AA; j++)
    for (int i=0; i<AA; i++)
    {
        vec2 off = vec2( float(i), float(j) ) / float(AA) - .5,
             uv = (-iResolution.xy + 2.*(fragCoord+off)) / iResolution.y;
        
        uv += vec2(-.077,.105); // to fit video
        
        vec3 rd = normalize( uv.x*uu + uv.y*vv + 1.5*ww ),
             pos = vec3(0);
        vec4 col = vec4(0);
        float a, y, h, tmin = 10000.0, edge = 0.;
       
        // The sphere
        h = iSphere( ro, rd, r, edge );
        if (h>=0. && h<tmin) {
            tmin = h;
            pos = ro + h*rd;
            vec3 p = normalize(pos);
            a = atan(-p.z,p.x);
            y = asin(p.y);

            // RESTORED: Original mapping with tiling/wrapping, but starting from top
            // Original: vec2(.5+.55*a, .85*y+.05)
            // Key insight: 'a' ranges -π to +π, so .55*a creates values outside 0-1
            // This causes texture wrapping/tiling - that's why it wasn't zoomed!
            // 'y' ranges -π/2 to +π/2, so we adjust to start from top

            col = texture(iChannel2,vec2(.5+.55*a,.85*y+.05));
            col *= 1.+ 1.*smoothstep(.2*r,0., edge); 
            col.a = smoothstep(-.1, .1*r, edge); 
        }
   
        // The ground
        h = (-ro.y-hGround)/rd.y;
        if (h>0. && h<tmin) {
            tmin = h;
            pos = ro + h*rd;

            // RESTORED: Original ground mapping exactly as it was
            vec3 p = normalize(pos);
            a = atan(-p.z,p.x);
            y = length(pos.zx)+.37;
            col = 10.*texture(iChannel2,vec2(.5+.55*a,.85*y+.05),5.);
            col.a = .25*smoothstep(2.7,1.5,y);
        }
   
    // Grid overlay removed for cleaner video display
    
        tot += pow( col, vec4(.45,.45,.45,1.) );
    }
    tot /= float(AA*AA);

    // Compose colors with ping-pong looped background video
    vec4 txt = texture(iChannel0, v_text);
    fragColor = mix(txt, tot, tot.a);
}
