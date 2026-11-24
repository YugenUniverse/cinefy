// Redraws the frame as coloured text characters, like a terminal: each cell
// takes the colour of the scene under it and a glyph chosen by its brightness.
void MAIN()
{
    vec2 px = INPUT_UV * INPUT_SIZE;
    vec2 cell = vec2(cellSize * 0.6, cellSize);
    vec2 corner = floor(px / cell) * cell;
    vec3 col = texture(INPUT, (corner + cell * 0.5) / INPUT_SIZE).rgb;

    float lum = dot(col, vec3(0.299, 0.587, 0.114));
    float level = clamp(pow(lum, 0.45) * 1.6, 0.0, 0.999);
    float glyph = floor(level * glyphCount);
    vec2 local = (px - corner) / cell;
    float mask = texture(glyphs, vec2((glyph + local.x) / glyphCount, local.y)).r;

    // Keep the hue, push it bright so neon reads well.
    vec3 hue = col / max(max(col.r, max(col.g, col.b)), 0.04);
    vec3 ascii = hue * mask * (0.45 + level * 1.3);

    vec3 orig = texture(INPUT, INPUT_UV).rgb;
    FRAGCOLOR = vec4(mix(orig, ascii, strength), 1.0);
}
