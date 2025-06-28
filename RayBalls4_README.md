# RayBalls4.glsl README

## Overview
RayBalls4.glsl is the latest iteration in the RayBalls series, featuring enhanced video morphing and dynamic camera tracking. This shader combines ray-traced 3D spheres with sophisticated video integration and intelligent camera movement.

## Key Features

### 🎥 **Enhanced Video Morphing System**
- **Phase 1 (0.0-0.5s)**: Normal fullscreen video playback
- **Phase 2 (0.5-1.0s)**: Smooth morphing from flat video to 3D video ball
- **Phase 3 (1.0-4.0s)**: Dynamic camera pullback transition
- **Phase 4 (4.0s+)**: Continuous orbital motion with video-textured sphere

### 🎬 **Dynamic Camera Tracking**
- **Intelligent Height Adjustment**: Camera moves up/down based on video ball position
- **Adaptive Tilt System**: Camera tilts to maintain optimal viewing angle
- **Smooth Transitions**: Seamless camera movement between all phases
- **Collision Avoidance**: Camera adjusts to prevent video ball from going off-screen

### 🌟 **Advanced 3D Scene**
- **Ray-traced Spheres**: Multiple animated spheres with realistic lighting
- **Reflective Checkerboard Floor**: High-quality reflections and lighting
- **Video Ball Integration**: Camera-locked video texture on 3D sphere
- **Professional Lighting**: Realistic sun positioning and shadow calculations

### ⚙️ **User Controls**
- `ballSpeed`: Controls animation speed (0.1-3.0)
- `ballSize`: Adjusts video ball size with automatic orbit scaling (0.5-2.0)
- `videoReflectivity`: Controls video ball surface reflectivity (0.0-1.0)

## Technical Implementation

### **Camera System**
```glsl
// Dynamic camera adjustments based on video ball orbital position
CameraAdjustment getDynamicCameraAdjustment(float time)
```
- Calculates optimal camera height and tilt based on video ball position
- Prevents video ball from leaving the frame
- Smooth transitions using smoothstep functions

### **Video Morphing**
```glsl
// Seamless transition from flat video to 3D sphere
vec2 finalUV = mix(flatUV, sphereUV, morphFactor);
```
- Blends between 2D screen coordinates and 3D sphere UV mapping
- Maintains video aspect ratio throughout transformation
- Camera-locked texture system for consistent video orientation

### **Orbital Motion**
```glsl
// Continuous orbit with size-based collision prevention
float orbitRadius = 9.0 + (videoBallRadius - 3.0);
```
- Dynamic orbit radius scales with ball size
- Prevents collisions with other scene objects
- Smooth continuous motion without entry/exit phases

## Scene Composition

### **Objects**
1. **Red Sphere**: Animated position, small reflectivity
2. **Blue Sphere**: Animated position, small reflectivity  
3. **White Sphere**: Static position, higher reflectivity
4. **Video Ball**: Orbital motion, user-controllable reflectivity
5. **Checkerboard Floor**: Reflective surface with pattern

### **Lighting**
- **Sun Position**: High angle (1:30 PM) from southwest
- **Shadow Calculation**: Realistic shadows for all objects except video ball
- **Enhanced Video Lighting**: Special lighting for video ball visibility
- **Ambient Lighting**: Subtle fill light for overall scene balance

## Usage Notes

### **Performance**
- Ray-traced rendering with 6 reflection iterations
- Optimized shadow calculations
- Efficient video texture sampling

### **Visual Quality**
- Gamma correction (2.2)
- Exposure control (0.001)
- High-quality reflections and lighting
- Smooth animation timing

### **Compatibility**
- Requires video input in iChannel0
- Non-audio-reactive (pure visual effect)
- Standard DISCO shader format

## Evolution from Previous Versions

### **From RayBalls3**
- ✅ **Enhanced Camera System**: Added dynamic height and tilt adjustments
- ✅ **Improved Tracking**: Better video ball tracking during orbital motion
- ✅ **Smoother Transitions**: More refined camera movement between phases
- ✅ **Collision Prevention**: Automatic orbit radius scaling

### **Key Improvements**
- **Dynamic Camera Adjustments**: Responds to video ball position
- **Enhanced Viewing Angles**: Optimal camera positioning throughout animation
- **Professional Polish**: Refined timing and smooth transitions
- **Robust System**: Handles edge cases and maintains visual quality

## Technical Specifications

### **Shader Type**: Fragment Shader (Ray Tracing)
### **Input Channels**: 
- `iChannel0`: Video texture
### **Uniforms**: 
- `ballSpeed`, `ballSize`, `videoReflectivity`
### **Category**: 3D Effects
### **Audio Reactive**: No

## Future Enhancements
RayBalls4 serves as the foundation for RayBalls5, which adds audio-reactive waveform backgrounds while preserving all the advanced camera and morphing features developed in this version.
