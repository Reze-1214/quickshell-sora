#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float progress;
    float aspect;
    float centerX;
    float centerY;
};

layout(binding = 1) uniform sampler2D oldTex;
layout(binding = 2) uniform sampler2D newTex;

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 center = vec2(centerX, centerY);

    vec2 p = (uv - center) * vec2(aspect, 1.0);
    float dist = length(p);
    float maxDist = length(vec2(max(center.x, 1.0 - center.x) * aspect,
                                max(center.y, 1.0 - center.y)));

    float feather = 0.14;
    float radius = mix(-feather, maxDist + feather, progress);
    float mask = 1.0 - smoothstep(radius - feather, radius + feather, dist);

    // Subtle incoming settle zoom (returns to 1.0 at progress == 1.0)
    float zoom = mix(1.035, 1.0, progress);
    vec2 newUv = (uv - vec2(0.5)) / zoom + vec2(0.5);

    vec4 oldCol = texture(oldTex, uv);
    vec4 newCol = texture(newTex, newUv);

    float edge = smoothstep(radius - feather, radius, dist)
               * (1.0 - smoothstep(radius, radius + feather, dist));
    float edgeFade = sin(progress * 3.14159265);
    vec3 sheen = vec3(0.08) * edge * edgeFade;

    vec4 blended = mix(oldCol, newCol, mask);
    blended.rgb = min(blended.rgb + sheen * blended.a, vec3(blended.a));
    fragColor = blended * qt_Opacity;
}
