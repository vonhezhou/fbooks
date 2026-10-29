#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
// progress、抓取位置、sin(pi * progress)、基础卷曲半径。
uniform vec4 uCurl;
// 折线倾斜和回折位移的纵向分量，在 CPU 上每帧各计算一次。
uniform vec2 uBend;
uniform float uSpread;
uniform float uRtl;
// 一个显示像素对应的局部逻辑长度。
uniform float uPixel;
// 由 CPU 预先换算为 0..255，避免每个片元重复转换颜色量纲。
uniform vec3 uPaperColor;
// 相机距离、折线倾斜系数、已计算的回卷张角幅度、半径纵向变化。
uniform vec4 uModel;
// 局部页角权重、后半程折线弯曲幅度、纸背涂层覆盖率及水平参考权重；与 Mesh 共用 CPU 参数。
uniform vec4 uShape;
uniform sampler2D uFront;
uniform sampler2D uBack;
out vec4 fragColor;
const float pi = 3.141592653589793;

float verticalProjectionScale(float z) {
  float perspective = 1.0 / (1.0 - z / (uSize.x * uModel.x));
  return 1.0 + (perspective - 1.0) * uShape.x;
}

float pullScale(float y) {
  float bias = sign(uCurl.y - 0.5) * uShape.x;
  return 1.0 - bias * (y / uSize.y - uCurl.y);
}

// 中线截面沿纵向一致；页角才按抓取距离改变张角。
float bendLimit(float y) {
  float offset = y / uSize.y - uCurl.y;
  float proximity = clamp(1.0 - 2.0 * offset * offset, 0.0, 1.0);
  float cornerWeight = uShape.x;
  return pi - uModel.z * (1.0 - cornerWeight + cornerWeight * proximity * proximity);
}

vec2 surface(float d, float radius, float limit) {
  if (d <= 0.0) return vec2(d, 0.0);
  float angle = min(d / radius, limit);
  float tail = max(0.0, d - radius * limit);
  return vec2(radius * sin(angle) + tail * cos(angle),
      radius * (1.0 - cos(angle)) + tail * sin(angle));
}

// radius、crease、书脊处沿曲面的积分、书脊处高度。
vec4 rowGeometry(float y) {
  float row = y / uSize.y;
  float cornerWeight = uShape.x;
  float radius = uCurl.w * (0.82 + uModel.w * cornerWeight * abs(row - uCurl.y));
  float crease = uSize.x * (1.0 - uCurl.x) - pi * radius * 0.5
      + uBend.x * (uCurl.y - row) * uSize.x * uCurl.z * uModel.y;
  float reach = uCurl.y >= 0.5 ? uCurl.y : 1.0 - uCurl.y;
  float far = uCurl.y >= 0.5 ? row : 1.0 - row;
  float q = clamp(far / reach, 0.0, 1.0);
  crease += uSize.x * uShape.y * 16.0 * q * q * (1.0 - q) * (1.0 - q);
  return vec4(radius, crease, surface(-crease, radius, bendLimit(y)));
}

// 圆柱经透视投影后的最右轮廓，同时用于页缘覆盖率和阴影定位。
float projectedFold(vec4 g) {
  float d = uSize.x * uModel.x;
  float h = d - g.x + g.w;
  return d * (-g.z * h + g.x * sqrt(h * h + g.z * g.z - g.x * g.x))
      / (h * h - g.x * g.x);
}

vec2 arcEquation(vec2 screen, float y, int branch) {
  vec4 g = rowGeometry(y);
  float distance = uSize.x * uModel.x;
  float q = screen.x / distance;
  float s = (g.z + q * (distance - g.x + g.w))
      / (g.x * sqrt(1.0 + q * q));
  float angle = (branch == 1 ? asin(clamp(s, -1.0, 1.0))
      : pi - asin(clamp(s, -1.0, 1.0))) + atan(q);
  float x = g.y + g.x * angle;
  float z = g.x * (1.0 - cos(angle)) - g.w;
  float scale = 1.0 - z / distance;
  return vec2(s, (screen.y - uSize.y * 0.5) / verticalProjectionScale(z) + uSize.y * 0.5
      + uBend.y * pullScale(y) * (x - screen.x * scale) - y);
}

float arcResidual(vec2 screen, float y, int branch) {
  return arcEquation(screen, y, branch).y;
}

// 反求四段曲面的材料坐标。分支依次为平面正页、圆柱近侧、远侧、翻过的平面。
// 纵向至多修正十一次，达到显示像素误差阈值后提前结束；横向使用解析反解。
vec4 inverseSurface(vec2 screen, int branch, float initialY) {
  float y = initialY;
  float x = 0.0;
  float z = 0.0;
  float angle = 0.0;
  float previousY = y;
  float previousResidual = 0.0;
  bool haveResidual = false;
  // 页角回折可把最初落在页外的材料坐标带回纸面；粗裁剪须包含该位移。
  float materialMargin = uSize.x * 0.1
      + (2.0 * uSize.x * abs(uBend.y) + uSize.y * 0.05)
      * (2.0 * abs(uBend.y) + pi * 2.0 * abs(uModel.w) * uCurl.w / uSize.y);
  for (int i = 0; i < 12; i++) {
    vec4 g = rowGeometry(y);
    float limit = bendLimit(y);
    float distance = uSize.x * uModel.x;
    if (branch == 0) {
      z = -g.w;
      x = screen.x * (1.0 - z / distance) + g.y + g.z;
      angle = 0.0;
    } else if (branch == 3) {
      float sine = sin(limit);
      float cosine = cos(limit);
      float joinX = g.x * sine - g.z;
      float joinZ = g.x * (1.0 - cosine) - g.w;
      float tail = (screen.x * (1.0 - joinZ / distance) - joinX)
          / (cosine + screen.x * sine / distance);
      x = g.y + limit * g.x + tail;
      z = joinZ + tail * sine;
      angle = limit;
    } else {
      float q = screen.x / distance;
      float s = (g.z + q * (distance - g.x + g.w))
          / (g.x * sqrt(1.0 + q * q));
      if (s > 1.0 && abs(uBend.y) > 0.45) {
        // 超出圆弧实根区时不能把 asin 的输入夹到 1 后继续找根：
        // 那会收敛到不存在的截面，并漏掉紧贴轮廓的另一交点。
        float fold = projectedFold(g);
        float stepY = max(0.1, uPixel);
        float slope = (projectedFold(rowGeometry(y + stepY)) - fold) / stepY;
        if (abs(slope) > 0.01) {
          y += clamp((screen.x + uPixel * 0.05 - fold) / slope,
              -uSize.y * 0.15, uSize.y * 0.15);
          haveResidual = false;
          continue;
        }
      }
      // 尚未收敛时保留纵向牵拉可能移入的候选；远处空白仍可提前退出。
      float allowance = i == 11 ? uPixel : uPixel
          + (abs(uBend.y) * pi * uCurl.w * (0.82 + abs(uModel.w))
              + uSize.y * 0.03 * uCurl.z)
          * (abs(uBend.x) * uCurl.z + 0.05) * uSize.x / uSize.y;
      if (s < -1.0 - allowance / g.x ||
          (s > 1.0 && screen.x > projectedFold(g) + allowance)) {
        return vec4(0.0, 0.0, 0.0, -1.0);
      }
      s = clamp(s, -1.0, 1.0);
      angle = (branch == 1 ? asin(s) : pi - asin(s)) + atan(q);
      x = g.y + g.x * angle;
      z = g.x * (1.0 - cos(angle)) - g.w;
    }
    // 远离材料边界的候选无需继续修正，避免空白区域重复计算。
    if ((branch != 3 || i == 11) &&
        (x < -materialMargin || x > uSize.x + materialMargin)) {
      return vec4(0.0, 0.0, 0.0, -1.0);
    }
    if (i < 11) {
      float along = screen.x * (1.0 - z / distance);
      float pull = uBend.y * pullScale(y) * (x - along);
      float nextY = (screen.y - uSize.y * 0.5) / verticalProjectionScale(z)
          + uSize.y * 0.5 + pull;
      // 用相邻两次残差作割线修正，避免强页角牵拉时固定点迭代来回振荡。
      float residual = nextY - y;
      if (abs(residual) < uPixel * 0.01) break;
      float slope = residual - previousResidual;
      float step = residual;
      if (abs(uBend.y) > 0.45 && (branch == 1 || branch == 2)) {
        // 实根边界附近的固定点不稳定，沿有效区域内的导数修正，避免再次跳出边界。
        // 接近折线弯曲后的轮廓时，固定大步长会跨过局部高曲率区域，
        // 使 Newton 在实根旁振荡；随残差缩短差分步长。
        float delta = sign(uBend.y) * max(0.001,
            min(max(0.1, uPixel * 0.25), abs(residual) * 0.05));
        float derivative = (residual - arcResidual(screen, y - delta, branch)) / delta;
        if (abs(derivative) > 0.0001) {
          step = clamp(-residual / derivative, -uSize.y * 0.15, uSize.y * 0.15);
        }
        // 靠近实根边界时，完整 Newton 步可能越域，随后又被送回同一位置。
        // 回溯只接受域内且残差下降的步长，避免在边界两侧来回跳动。
        bool accepted = false;
        for (int search = 0; search < 6; search++) {
          vec2 equation = arcEquation(screen, y + step, branch);
          if (abs(equation.x) <= 1.0 && abs(equation.y) < abs(residual)) {
            accepted = true;
            break;
          }
          step *= 0.5;
        }
        if (!accepted) break;
      } else if (haveResidual && abs(slope) > 0.0001) {
        step = clamp(-residual * (y - previousY) / slope,
            -uSize.y * 0.15, uSize.y * 0.15);
      }
      previousY = y;
      previousResidual = residual;
      haveResidual = true;
      y += step;
    }
  }
  vec4 g = rowGeometry(y);
  // 圆弧和平面各自反解时会有浮点舍入差；接缝重叠 0.05 像素以免漏面。
  float seam = uPixel * 0.05;
  bool segment = branch == 0 ? x <= g.y + seam
      : branch == 3 ? x >= g.y + bendLimit(y) * g.x - seam
      : angle >= -seam / g.x && angle <= bendLimit(y) + seam / g.x;
  // 在材料边缘外保留一个窄带，避免先裁掉本应部分覆盖的像素。
  if (!segment || x < -uPixel * 4.0 || x > uSize.x + uPixel * 4.0 ||
      y < -uPixel * 4.0 || y > uSize.y + uPixel * 4.0) {
    return vec4(0.0, 0.0, 0.0, -1.0);
  }
  return vec4(x, y, z, angle);
}

vec2 projectMaterial(vec2 point) {
  vec4 g = rowGeometry(point.y);
  vec2 material = surface(point.x - g.y, g.x, bendLimit(point.y)) - g.zw;
  float perspective = 1.0 / (1.0 - material.y / (uSize.x * uModel.x));
  vec2 projected = vec2(material.x,
      point.y + uBend.y * pullScale(point.y) * (material.x - point.x) - uSize.y * 0.5);
  projected.x *= perspective;
  projected.y *= verticalProjectionScale(material.y);
  projected.y += uSize.y * 0.5;
  return projected;
}

float projectionError(vec4 hit, vec2 screen) {
  if (hit.w < 0.0) return 1e20;
  return length(projectMaterial(hit.xy) - screen);
}

vec4 shadePaper(vec4 hit, float edge, vec2 screen) {
  bool back = hit.w > pi * 0.5;
  if (abs(uBend.y) > 0.45) {
    // 强斜拖的真实面向还取决于纵向变化，与 Mesh 的投影绕序保持相同定义。
    float h = max(0.01, uPixel * 0.25);
    vec2 dx = projectMaterial(hit.xy + vec2(h, 0.0))
        - projectMaterial(hit.xy - vec2(h, 0.0));
    vec2 dy = projectMaterial(hit.xy + vec2(0.0, h))
        - projectMaterial(hit.xy - vec2(0.0, h));
    back = dx.x * dy.y - dx.y * dy.x < 0.0;
  }
  vec2 uv = clamp(hit.xy / uSize, 0.0, 1.0);
  if (back && uSpread > 0.5) uv.x = 1.0 - uv.x;
  if (uRtl > 0.5) uv.x = 1.0 - uv.x;
  vec4 page = back && uSpread > 0.5 ? texture(uBack, uv) : texture(uFront, uv);
  float sine = sin(hit.w);
  float sine2 = sine * sine;
  float sine4 = sine2 * sine2;
  float backLight = back ? 0.74 + 0.26 * abs(cos(bendLimit(hit.y))) : 1.0;
  float legacy = (0.74 + 0.26 * abs(cos(hit.w))) / backLight
      + 0.12 * sine4 * sine4 * sine4;
  float light=legacy;
  float nativeWeight=(1.0-uShape.x)*uShape.w;
  if(nativeWeight>0.0){
    vec4 g=rowGeometry(hit.y);
    vec2 free=surface(uSize.x-g.y,g.x,bendLimit(hit.y));
    float freeEdge=(free.x-g.z)/(1.0-(free.y-g.w)/(uSize.x*uModel.x));
    float sigma=max(3.0,.15*g.x-5.0);
    float distanceToEdge=abs(screen.x-freeEdge)/sigma;
    float ownOpacity=clamp(.355*(1.0-freeEdge/uSize.x-.268),0.0,.25);
    float nativeLight=hit.w>pi*.5?1.0-.035*sine4
        :legacy*(1.0-ownOpacity*exp(-distanceToEdge*sqrt(distanceToEdge)));
    light=mix(legacy,nativeLight,nativeWeight);
  }
  light=clamp(light,0.0,1.0);
  light = floor(light * 255.0 + 0.5) / 255.0;
  page.rgb *= light;
  if (back && uSpread < 0.5) {
    float alpha = uShape.z;
    vec3 paper = floor(uPaperColor * light + 0.5) / 255.0;
    page = vec4(paper * alpha + page.rgb * (1.0 - alpha),
        alpha + page.a * (1.0 - alpha));
  }
  float rim = 1.0 - smoothstep(uPixel * 0.35, uPixel * 1.35, max(edge, 0.0));
  page.rgb = mix(page.rgb, vec3(1.0, 0.985, 0.95) * page.a, rim * 0.2);
  return page;
}

vec4 paperShadow(vec2 screen) {
  vec4 g = rowGeometry(clamp(screen.y, 0.0, uSize.y));
  float lift = max(0.0, surface(uSize.x - g.y, g.x,
      bendLimit(clamp(screen.y, 0.0, uSize.y))).y - g.w);
  float edge = screen.x - projectedFold(g);
  float nativeWeight=(1.0-uShape.x)*uShape.w;
  float legacyShadow=0.0;
  if(nativeWeight<1.0){
    float penumbra=max(uPixel,1.5+lift*.12);
    float castDistance=edge-lift*.10;
    float castShadow=.18*exp(-.5*castDistance*castDistance/(penumbra*penumbra));
    float contact=.10*exp(-abs(edge)/max(uPixel,.8+lift*.025));
    legacyShadow=(castShadow+contact)*smoothstep(0.0,uPixel*3.0,lift)*(1.0-nativeWeight);
  }
  float nativeShadow=0.0;
  if(nativeWeight>0.0){
    float sigma=2.0+.17*g.x,q=edge/sigma+.6;
    nativeShadow=.2*exp(-.5*q*q)*smoothstep(0.0,3.0,lift)*nativeWeight;
  }
  float withinPage=step(0.0,screen.y)*step(screen.y,uSize.y);
  return vec4(0.0,0.0,0.0,(nativeShadow+legacyShadow*(1.0-nativeShadow))*withinPage);
}

void main() {
  vec2 screen = FlutterFragCoord().xy;
  vec4 result = vec4(0.0);
  bool strong = abs(uBend.y) > 0.45;
  vec4 nearest = vec4(0.0, 0.0, -1e20, -1.0);
  vec4 behind = nearest;
  vec2 nearestEdge = vec2(0.0);
  vec2 behindEdge = vec2(0.0);
  bool skipNearArc = false;
  // 不透明内部仍只处理一个面；仅半覆盖的边缘继续合成其后方的纸面。
  for (int branch = 3; branch >= 0; branch--) {
    if (branch == 1 && skipNearArc) continue;
    vec4 hit = inverseSurface(screen, branch, screen.y);
    // 强斜拖可能有多个材料行交点，保留误差合格且更靠近观察者的解。
    if (branch >= 1 && strong) {
      float error = projectionError(hit, screen);
      // 近轮廓 asin 的浮点误差可到约 0.023 显示像素；保留 0.05 像素的实测余量。
      float tolerance = uPixel * 0.05;
      for (int seed = 1; seed <= 2; seed++) {
        float initialY = screen.y + uBend.y * (uSize.x - screen.x) * float(seed) * 0.5;
        vec4 candidate = inverseSurface(screen, branch, initialY);
        float candidateError = projectionError(candidate, screen);
        bool accurate = error < tolerance;
        bool candidateAccurate = candidateError < tolerance;
        if (candidate.w >= 0.0 &&
            ((candidateAccurate && !accurate) ||
             (candidateAccurate && accurate && candidate.z > hit.z) ||
             (!candidateAccurate && !accurate && candidateError < error))) {
          hit = candidate;
          error = candidateError;
        }
      }
    }
    if (hit.w < 0.0) continue;
    if (strong && projectionError(hit, screen) > uPixel * 0.05) continue;
    float perspective = 1.0 / (1.0 - hit.z / (uSize.x * uModel.x));
    float dx = abs(cos(hit.w) + screen.x / (uSize.x * uModel.x) * sin(hit.w)) * perspective;
    float edgeX = min(hit.x, uSize.x - hit.x) * dx;
    float edgeY = min(hit.y, uSize.y - hit.y) * verticalProjectionScale(hit.z);
    float edge = min(edgeX, edgeY);
    if (!strong && (branch == 1 || branch == 2)) {
      float foldEdge = projectedFold(rowGeometry(hit.y)) - screen.x;
      if (branch == 2 && foldEdge <= edge) skipNearArc = true;
      edge = min(edge, foldEdge);
    }
    float coverage = smoothstep(-uPixel * 0.5, uPixel * 0.5, edge);
    if (coverage <= 0.0) continue;
    if (strong) {
      // 纵向回折会改变分支之间的遮挡顺序，不能假设尾部总在圆弧前面。
      if (hit.z > nearest.z) {
        behind = nearest;
        behindEdge = nearestEdge;
        nearest = hit;
        nearestEdge = vec2(edge, coverage);
      } else if (hit.z > behind.z) {
        behind = hit;
        behindEdge = vec2(edge, coverage);
      }
      continue;
    }
    result += shadePaper(hit, edge, screen) * coverage * (1.0 - result.a);
    if (result.a >= 0.9999) break;
  }
  if (strong && nearest.w >= 0.0) {
    result = shadePaper(nearest, nearestEdge.x, screen) * nearestEdge.y;
    if (result.a < 0.9999 && behind.w >= 0.0) {
      result += shadePaper(behind, behindEdge.x, screen) * behindEdge.y * (1.0 - result.a);
    }
  }
  if (result.a < 0.9999) result += paperShadow(screen) * (1.0 - result.a);
  fragColor = result;
}
