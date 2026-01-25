/*
 * Amiga Sinus 3 - Complete Amiga Demo Collection with Audio Reactivity
 * Adapted for DISCO system by Augment Agent
 * 
 * Original: Amiga_Demos_1.glsl by gPlatl
 * Collection of Amiga based demos...
 *   v0.1  2016-01-31  initial version
 *   v1.0  2016-04-19  first release
 * 
 * Used codes...
 * ReadKey:    https://www.shadertoy.com/view/llVSRm
 * Scroller:   https://www.shadertoy.com/view/MtySzd
 * RGB_Bars:   https://www.shadertoy.com/view/4lVGzc
 * Copper:     https://www.shadertoy.com/view/Md3GRl
 * RubberCube: https://www.shadertoy.com/view/4lt3R7
 * Amigaball:  https://www.shadertoy.com/view/Xd3XWX
 * Greetings:  https://www.shadertoy.com/view/ld2yDz
 */

#version 330

uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0; // Font texture

// User-defined controls (replacing keyboard/mouse input)
uniform float sinusAmplitude;     // Sinus wave amplitude (0.0-2.0)
uniform float use3DLighting;      // 3D lighting toggle (0.0=2D, 1.0=3D)
uniform float demoMode;           // Demo selection (0.0=auto, 1.0-4.0=manual)
uniform float backgroundMode;     // Background selection (0.0=auto, 1.0-4.0=manual)
uniform float autoSwitchSpeed;    // Auto demo switch speed (0.1-2.0)

// Audio-reactive uniforms
uniform float bassLevel;          // Bass frequency energy (0.0-1.0)
uniform float midLevel;           // Mid frequency energy (0.0-1.0)
uniform float trebleLevel;        // Treble frequency energy (0.0-1.0)
uniform float beatLevel;          // Beat detection level (0.0-1.0)
uniform float kickLevel;          // Kick drum energy (0.0-1.0)
uniform float audioIntensity;     // Overall audio intensity (0.0-1.0)

// Text input uniforms (will be populated by text input system)
uniform float scrollText1Length; // Length of main scroll text
uniform float scrollText2Length; // Length of bottom text

in vec2 v_text;
out vec4 fragColor;

//--- common data ---
float time = 0.0;
bool mousePressed = false;
vec2 pos = vec2(0);      //  0 .. 1
vec2 uv  = vec2(0);      // -1 .. 1
vec2 aspect = vec2(1.0); // R.xy / R.y

vec2 tp  = vec2(0);      // text position
vec3 aColor = vec3(0);

//== font handling =========================================

//--- font data ---
#define FONT_SIZE1 0.40
#define FONT_SIZE2 0.25
#define FONT_SPACE 0.45

const vec2 vFontSize  = vec2(8.0, 15.0);  // multiples of 4x5 work best

//----- access to the image of ascii code characters ------
#define SPACE tp.x-=FONT_SPACE;
#define S(a) c+=char(a);   tp.x-=FONT_SPACE;

#define _note  S(10);   #define _star  S(28);   #define _smily S(29);
#define _ tp.x-=FONT_SPACE;
#define _exc   S(33);   #define _add   S(43);   #define _comma S(44);   
#define _sub   S(45);   #define _dot   S(46);   #define _slash S(47);

#define _0 S(48); #define _1 S(49); #define _2 S(50); #define _3 S(51); #define _4 S(52);
#define _5 S(53); #define _6 S(54); #define _7 S(55); #define _8 S(56); #define _9 S(57);
#define _ddot S(58); #define _sc S(59); #define _less S(60); #define _eq S(61); 
#define _gr S(62); #define _qm S(63); #define _at S(64);

#define _A S(65);
#define _B S(66);
#define _C S(67);
#define _D S(68);
#define _E S(69);
#define _F S(70);
#define _G S(71);
#define _H S(72);
#define _I S(73);
#define _J S(74);
#define _K S(75);
#define _L S(76);
#define _M S(77);
#define _N S(78);
#define _O S(79);
#define _P S(80);
#define _Q S(81);
#define _R S(82);
#define _S S(83);
#define _T S(84);
#define _U S(85);
#define _V S(86);
#define _W S(87);
#define _X S(88);
#define _Y S(89);
#define _Z S(90);

#define _a S(97);
#define _b S(98);
#define _c S(99);
#define _d S(100);
#define _e S(101);
#define _f S(102);
#define _g S(103);
#define _h S(104);
#define _i S(105);
#define _j S(106);
#define _k S(107);
#define _l S(108);
#define _m S(109);
#define _n S(110);
#define _o S(111);
#define _p S(112);
#define _q S(113);
#define _r S(114);
#define _s S(115);
#define _t S(116);
#define _u S(117);
#define _v S(118);
#define _w S(119);
#define _x S(120);
#define _y S(121);
#define _z S(122);

//----------------------------------------------------------
// return font image intensity of character ch at text position tp
//----------------------------------------------------------
float char(int ch)
{
  // Fixed texture coordinate calculation (same as AmigaSinus1 & 2)
  float x = float(ch - ch/16*16);  // Column (0-15)
  float y = float(ch/16);          // Row (0-15) - correct mapping

  // Flip character rendering to fix upside-down text
  vec2 flipped_tp = vec2(tp.x, 1.0 - tp.y);
  vec2 texCoord = 0.0625*(flipped_tp + vec2(x, y));

  vec4 f = any(lessThan(vec4(tp,1,1), vec4(0,0,tp)))
               ? vec4(0)
               : texture(iChannel0, texCoord);
  if (use3DLighting < 0.5)
    return f.x;   // 2d
  else
    return f.x * (f.y+0.3)*(f.z+0.3)*2.0;   // 3d
}

//----------------------------------------------------------
// render scroll text with audio-reactive sinus amplitude
//----------------------------------------------------------

#define SCROLL_SPEED 2.0
#define SCROLL_LEN 40.
#define SIN_FREQ 0.75
#define SIN_SPEED 3.0

//----------------------------------------------------------
vec3 ScrollText1()
{
  tp = uv / FONT_SIZE1;  // set font size
  tp.x = 2.0*(tp.x -4.0 +mod(time*SCROLL_SPEED, SCROLL_LEN));

  // Audio-reactive sinus amplitude
  float audioSinusAmp = sinusAmplitude + bassLevel * 0.5 + beatLevel * 0.3;
  float SIN_AMP = 1.5 * audioSinusAmp / 2.0 - 0.5;
  tp.y += 1.0 + SIN_AMP*sin(tp.x*SIN_FREQ + time*SIN_SPEED + trebleLevel * 2.0);

  float c = 0.0;

  // PLACEHOLDER_TEXT_1
  _D _I _S _C _O _ _R _u _l _e _s

  // Audio-reactive color with beat pulsing
  vec3 fcol = c * vec3(pos, 0.5+0.5*sin(2.0*time + beatLevel * 3.0));
  if (c >= 0.5) return fcol;
  return mix (aColor, fcol, c);
}

//----------------------------------------------------------
vec3 ScrollText2()
{
  tp = uv / FONT_SIZE2;  // set font size
  tp.x = 1.8*(tp.x -4.0 +mod(time*SCROLL_SPEED, SCROLL_LEN));
  tp.y = (uv.y + 0.88) / 0.2;  // set position & font size

  float c = 0.0;

  // PLACEHOLDER_TEXT_2
  _A _u _d _i _o _ _V _i _b _e _s

  // Audio-reactive color with mid-frequency modulation
  vec3 fcol = c * vec3(pos, 0.5+0.5*sin(time + midLevel * 4.0));
  if (c >= 0.5) return fcol;
  return mix (aColor, fcol, c);
}

//----------------------------------------------------------
// render red green blue sinus bars with audio reactivity
//----------------------------------------------------------
vec3 calcSine(float frequency, float amplitude, float shift, float yOffset
             ,vec3 color, float height)
{
  float audioFreq = frequency + audioIntensity * 0.5;
  float audioAmp = amplitude + bassLevel * 0.2;
  float y = sin(time * audioFreq + shift + uv.x) * audioAmp + yOffset;
  return color * smoothstep(height, 0.0, distance(y, uv.y));
}

vec3 RGB_Bars()
{
  return calcSine(2.0, 0.25, 0.0, 0.5, vec3(0.0, 0.0, 1.0), 0.10)
       + calcSine(2.6, 0.15, 0.2, 0.5, vec3(0.0, 1.0, 0.0), 0.10)
       + calcSine(0.9, 0.35, 0.5, 0.5, vec3(1.0, 0.0, 0.0), 0.10);
}

//----------------------------------------------------------
// render Amiga Copper Bars with audio reactivity
//----------------------------------------------------------
vec3 Copper()
{
  float df = time * (0.8 + audioIntensity * 0.4);
  float r = 0.5 + 0.5 * sin(df + 3.1415 + bassLevel);
  float g = 0.5 + 0.5 * cos(df + midLevel);
  float b = 0.5 + 0.5 * sin(df + trebleLevel);

  vec3 barColor = vec3(0.0);
  float barsize = 0.04 + beatLevel * 0.02;

  for(float i=0.0; i<0.9; i+=0.08)
  {
    float p = 0.7 + 0.2 * cos(1.8*time+160.*i + kickLevel * 2.0);
    if ((pos.y <= p + barsize) && (pos.y >= p - barsize))
    {
      barColor = (1.0 - abs(p - pos.y) / barsize) * vec3(r+i,g+i,b+i);
    }
  }
  return barColor;
}

//----------------------------------------------------------
// render plasma background with audio reactivity
//----------------------------------------------------------
vec3 Plasma()
{
  float fScale = 2.1 + audioIntensity * 0.5;
  float t1 = time * (0.01 + bassLevel * 0.005);
  float t2 = time * (0.8 + midLevel * 0.3);
  vec2 p = pos*5.0;
  for(int i=1; i<33; i++)
  {
    vec2 newp = p;
    newp.x += 0.25/float(i)*cos(float(i)*p.y+t1*cos(t2)*0.3/40.0+0.03*float(i))*fScale-t1;
    newp.y += 0.50/float(i)*cos(float(i)*p.x+t1*t2*0.3/50.0+0.03*float(i+10))*fScale+12.34;
    p = newp;
  }
  vec3 col = 0.2 * vec3(0.5*sin(3.0*p.x)+0.5, 0.5*sin(3.0*p.y)+0.5, sin(p.x+p.y)) + 0.2;
  return col;
}

//----------------------------------------------------------
// Demo mode selection with user controls and auto-switching
//----------------------------------------------------------
#define BACK_DEMOS 4.
#define MAIN_DEMOS 4.

int getDemoMode() {
  if (demoMode >= 1.0 && demoMode <= 4.0) {
    return int(demoMode);  // Manual selection 1-4
  }
  else if (demoMode >= 5.0) {
    // Option 5: Random switching every 5 seconds
    float switchTime = 5.0;
    return int(mod(floor(time / switchTime), MAIN_DEMOS)) + 1;
  }
  // Auto mode (0.0) with user-controlled speed
  float switchTime = 5.0 / autoSwitchSpeed;
  return int(mod(floor(time / switchTime), MAIN_DEMOS)) + 1;
}

int getBackgroundMode() {
  if (backgroundMode >= 1.0 && backgroundMode <= 4.0) {
    return int(backgroundMode);  // Manual selection
  }
  // Auto mode with slightly different timing
  float switchTime = 6.0 / autoSwitchSpeed;
  return int(mod(floor(time / switchTime), BACK_DEMOS)) + 1;
}

vec3 frameDrawing()   // frame and background drawing
{
  float rep = 128.;
  float df = gl_FragCoord.x / rep + time * 5.0;
  if (pos.y < 0.5) df *= -1.0;
  vec3 color = vec3(0.5 + 0.5 * sin(df + 3.1415 + beatLevel)
                   ,0.5 + 0.5 * cos(df + midLevel)
                   ,0.5 + 0.5 * sin(df + trebleLevel));
  if (pos.y > 0.945 && pos.y<0.95)  return color;
  if (pos.y > 0.05  && pos.y<0.055) return color;
  if (pos.y < 0.05  || pos.y>0.95)  return vec3 (0.0, 0.15, 0.25);

  int backDemo = getBackgroundMode();
  if      (backDemo == 1) return vec3(0);
  else if (backDemo == 2) return vec3(0.1); // Simplified starfield
  else if (backDemo == 3) return Plasma();
  return vec3(0);
}

void main()
{
  vec2 fragCoord = v_text * iResolution;
  time = iTime;
  mousePressed = (use3DLighting > 0.5);
  pos = fragCoord.xy / iResolution.xy;
  uv = pos * 2.0 - 1.0;
  aspect = iResolution.xy / iResolution.y;

  int mainDemo = getDemoMode();
  aColor = frameDrawing();

  if      (mainDemo == 1) aColor += RGB_Bars();
  else if (mainDemo == 2) aColor += Copper();
  else if (mainDemo == 3) aColor += Plasma() * 0.5; // Dimmed for text visibility
  else if (mainDemo == 4) aColor += vec3(bassLevel, midLevel, trebleLevel) * 0.3;

  aColor = ScrollText1();
  aColor = ScrollText2();

  fragColor = vec4(aColor, 1.0);
}
