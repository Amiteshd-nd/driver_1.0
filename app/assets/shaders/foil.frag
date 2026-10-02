#version 460 core
#include <flutter/runtime_effect.glsl>

// Pugmark holographic foil (DESIGN.md §6). A rainbow band whose angle follows device tilt,
// plus a slow time drift so it shimmers on web/desktop with no gyroscope.
// Draw this over the card art with BlendMode.plus or screen, masked by the art's alpha in Dart.

uniform vec2 uSize;      // widget size in px
uniform float uTime;     // seconds
uniform float uTiltX;    // -1..1 (device roll)
uniform float uTiltY;    // -1..1 (device pitch)
uniform float uStrength; // 0..1 overall opacity

out vec4 fragColor;

vec3 hsv2rgb(vec3 c) {
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  // band direction rotates with tilt; drifts slowly with time
  float angle = 0.9 + uTiltX * 0.8 + uTiltY * 0.4 + uTime * 0.08;
  vec2 dir = vec2(cos(angle), sin(angle));
  float t = dot(uv - 0.5, dir) + uTiltX * 0.35 + uTime * 0.03;
  // three soft bands with distinct hue offsets
  float band = smoothstep(0.02, 0.18, 0.2 - abs(fract(t * 1.6) - 0.5));
  float hue = fract(t * 1.6 + uv.y * 0.15 + uTime * 0.02);
  vec3 rgb = hsv2rgb(vec3(hue, 0.55, 1.0));
  // fine diagonal micro-texture like real foil
  float micro = 0.85 + 0.15 * sin((uv.x + uv.y) * 420.0 + uTime * 2.0);
  float a = band * micro * uStrength * 0.55;
  fragColor = vec4(rgb * a, a);
}
