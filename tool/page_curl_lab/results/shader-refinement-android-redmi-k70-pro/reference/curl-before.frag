#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
// progress、抓取位置、sin(pi * progress)、基础卷曲半径。
uniform vec4 uCurl;
// 页角倾斜和纵向牵拉幅度，在 CPU 上每帧各计算一次。
uniform vec2 uBend;
uniform float uSpread;
uniform float uRtl;
uniform sampler2D uFront;
uniform sampler2D uBack;
out vec4 fragColor;
const float pi = 3.141592653589793;

// radius、crease、书脊处沿曲面的积分、书脊处高度。
vec4 rowGeometry(float y) {
  float row = y / uSize.y;
  float radius = uCurl.w * (0.82 + 0.3 * abs(row - uCurl.y));
  float crease = uSize.x * (1.0 - uCurl.x) - pi * radius * 0.5
      + uBend.x * (uCurl.y - row) * uSize.x * uCurl.z;
  float d = -crease;
  float angle = clamp(d / radius, 0.0, pi);
  float along = d <= 0.0 ? d : d < pi * radius
      ? radius * sin(angle) : -(d - pi * radius);
  float height = d <= 0.0 ? 0.0 : radius * (1.0 - cos(angle));
  return vec4(radius, crease, along, height);
}

// 反求四段曲面的材料坐标。分支依次为平面正页、圆柱近侧、远侧、翻过的平面。
// 用三次纵向修正处理页角牵拉；每次横向反解均使用解析式，无网格搜索。
vec4 inverseSurface(vec2 screen, int branch) {
  float y = screen.y;
  float x = 0.0;
  float z = 0.0;
  float angle = 0.0;
  for (int i = 0; i < 4; i++) {
    vec4 g = rowGeometry(y);
    float distance = uSize.x * 5.0;
    if (branch == 0) {
      z = -g.w;
      x = screen.x * (1.0 - z / distance) + g.y + g.z;
      angle = 0.0;
    } else if (branch == 3) {
      z = 2.0 * g.x - g.w;
      x = g.y + pi * g.x - g.z - screen.x * (1.0 - z / distance);
      angle = pi;
    } else {
      float q = screen.x / distance;
      float s = (g.z + q * (distance - g.x + g.w))
          / (g.x * sqrt(1.0 + q * q));
      if (abs(s) > 1.0) return vec4(0.0, 0.0, 0.0, -1.0);
      angle = (branch == 1 ? asin(s) : pi - asin(s)) + atan(q);
      x = g.y + g.x * angle;
      z = g.x * (1.0 - cos(angle)) - g.w;
    }
    // 远离材料边界的候选无需继续修正，避免空白区域重复计算。
    if (x < -uSize.x * 0.1 || x > uSize.x * 1.1) {
      return vec4(0.0, 0.0, 0.0, -1.0);
    }
    if (i < 3) {
      float rowWeight = 1.0 - abs(y / uSize.y - uCurl.y);
      float fraction = x / uSize.x;
      float pull = uBend.y * fraction * fraction * rowWeight * rowWeight;
      y = (screen.y - uSize.y * 0.5) * (1.0 - z / distance)
          + uSize.y * 0.5 + pull;
    }
  }
  vec4 g = rowGeometry(y);
  bool segment = branch == 0 ? x <= g.y
      : branch == 3 ? x >= g.y + pi * g.x
      : angle >= 0.0 && angle <= pi;
  if (!segment || x < 0.0 || x > uSize.x || y < 0.0 || y > uSize.y) {
    return vec4(0.0, 0.0, 0.0, -1.0);
  }
  return vec4(x, y, z, angle);
}

void main() {
  vec2 screen = FlutterFragCoord().xy;
  // 圆柱远侧遮挡近侧；先检查翻过的平面，再检查圆柱的两侧。
  vec4 hit = inverseSurface(screen, 3);
  if (hit.w < 0.0) hit = inverseSurface(screen, 2);
  if (hit.w < 0.0) hit = inverseSurface(screen, 1);
  if (hit.w < 0.0) hit = inverseSurface(screen, 0);
  if (hit.w < 0.0) {
    // 阴影使用解析衰减，避免额外的模糊离屏层；与网格基线单独做视觉比较。
    vec4 g = rowGeometry(clamp(screen.y, 0.0, uSize.y));
    float fold = g.x - g.z;
    float edge = abs(screen.x - fold);
    float withinPage = step(0.0, screen.y) * step(screen.y, uSize.y);
    float shadow = 0.18 * exp(-edge / max(1.0, g.x * 0.2)) * withinPage;
    fragColor = vec4(0.0, 0.0, 0.0, shadow);
    return;
  }
  bool back = hit.w > pi * 0.5;
  vec2 uv = hit.xy / uSize;
  if (back && uSpread > 0.5) uv.x = 1.0 - uv.x;
  if (uRtl > 0.5) uv.x = 1.0 - uv.x;
  vec4 page = back && uSpread > 0.5 ? texture(uBack, uv) : texture(uFront, uv);
  float sine = sin(hit.w);
  float sine2 = sine * sine;
  float sine4 = sine2 * sine2;
  float light = clamp(0.74 + 0.26 * abs(cos(hit.w))
      + 0.12 * sine4 * sine4 * sine4, 0.0, 1.0);
  light = floor(light * 255.0 + 0.5) / 255.0;
  page.rgb *= light;
  if (back && uSpread < 0.5) {
    float alpha = 224.0 / 255.0;
    vec3 paper = floor(vec3(250.0, 246.0, 236.0) * light + 0.5) / 255.0;
    page = vec4(paper * alpha + page.rgb * (1.0 - alpha),
        alpha + page.a * (1.0 - alpha));
  }
  fragColor = page;
}
