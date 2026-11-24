#version 440
// The final picture: glow added back, a film-like colour grade (cool
// shadows, warm highlights, a touch more contrast), a soft vignette and fine
// moving grain.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float bloomStrength;
    float time;
    vec2 resolution;
};
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D bloom;

void main()
{
    vec2 uv = qt_TexCoord0;
    vec3 c = texture(source, uv).rgb;
    c += texture(bloom, uv).rgb * bloomStrength;

    float l = dot(c, vec3(0.299, 0.587, 0.114));
    c = mix(c, c * vec3(0.93, 1.0, 1.07), 1.0 - smoothstep(0.0, 0.45, l)); // cool shadows
    c = mix(c, c * vec3(1.05, 1.0, 0.93), smoothstep(0.55, 1.0, l));       // warm highlights
    c = (c - 0.5) * 1.07 + 0.5;                                            // contrast

    vec2 d = uv - 0.5;
    c *= 1.0 - dot(d, d) * 0.6;                                            // vignette

    float n = fract(sin(dot(floor(uv * resolution) + time * 61.0, vec2(12.9898, 78.233))) * 43758.5453);
    c += (n - 0.5) * 0.022;                                                // grain

    fragColor = vec4(clamp(c, 0.0, 1.0), 1.0) * qt_Opacity;
}
