#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_height;
uniform float u_fade_height;
uniform sampler2D u_backdrop;

out vec4 frag_color;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  float progress = clamp((u_height - (1.0 - uv.y) * u_size.y) / u_fade_height, 0.0, 1.0);
  frag_color = texture(u_backdrop, uv) * smoothstep(0.0, 1.0, progress);
}
