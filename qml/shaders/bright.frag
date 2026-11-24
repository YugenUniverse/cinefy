#version 440
// Keeps only the bright parts of the picture (lamps, neon, signs, lit
// windows) for the glow.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float threshold;
};
layout(binding = 1) uniform sampler2D source;

void main()
{
    vec3 c = texture(source, qt_TexCoord0).rgb;
    float l = max(c.r, max(c.g, c.b));
    float k = smoothstep(threshold, threshold + 0.2, l);
    fragColor = vec4(c * k, 1.0) * qt_Opacity;
}
