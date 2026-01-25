// ============================================
// IMAGE (Main Output) - Simple Composite (same as original)
// ============================================
// CHANNEL SETUP:
//   iChannel0 = Buffer A (original video)
//   iChannel1 = Buffer B (psychedelic tracer effect)
// ============================================

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    fragColor = max(texture(iChannel0, uv), texture(iChannel1, uv + 0.002));
}
