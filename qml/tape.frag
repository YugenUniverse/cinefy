// A VHS box: the cover on the front in a glossy plastic sleeve; the long
// sides are printed spines in the cover's colours with a white title label;
// the back and ends are black plastic. Edges are a little worn.
VARYING vec4 vCell;
VARYING vec3 vLocalNormal;
VARYING vec2 vUv;
VARYING vec3 vLocal;

vec3 cover(vec2 uv)
{
    return pow(texture(atlas, vec2(mix(vCell.x, vCell.z, uv.x), mix(vCell.w, vCell.y, uv.y))).rgb, vec3(2.2));
}

void MAIN()
{
    vec3 p = vLocal / 100.0 + 0.5;          // 0..1 across the box
    // Worn corners: lighter, rougher plastic near every edge.
    vec3 e = min(p, 1.0 - p);
    float edge = 1.0 - smoothstep(0.0, 0.035, min(min(e.x, e.y), e.z) + 0.004 * sin(vLocal.y * 2.7));

    if (vLocalNormal.z > 0.5) {               // front: the cover
        vec3 c = cover(vUv);
        float rim = 1.0 - smoothstep(0.0, 0.04, min(min(vUv.x, 1.0 - vUv.x), min(vUv.y, 1.0 - vUv.y)));
        BASE_COLOR = vec4(mix(c, c * 0.55, rim * 0.6), 1.0);
        ROUGHNESS = 0.18;                      // the plastic sleeve
        SPECULAR_AMOUNT = 0.9;
    } else if (abs(vLocalNormal.x) > 0.5) {   // long sides: printed spine
        float t = p.y;                         // along the spine
        // colour from the matching edge of the cover, a bit deeper
        vec3 c = cover(vec2(vLocalNormal.x > 0.0 ? 0.97 : 0.03, t)) * 0.8;
        // white label strip with a thin dark band where the title would be
        float label = step(0.30, t) * step(t, 0.70);
        float title = step(0.44, t) * step(t, 0.56) * step(0.3, p.z) * step(p.z, 0.7);
        vec3 col = mix(c, vec3(0.86, 0.84, 0.79), label * 0.92);
        col = mix(col, vec3(0.05), title * 0.8);
        // a stripe of the shop's yellow near the bottom, like a rental sticker
        col = mix(col, vec3(0.80, 0.62, 0.08), step(0.08, t) * step(t, 0.13));
        BASE_COLOR = vec4(mix(col, vec3(0.35), edge * 0.5), 1.0);
        ROUGHNESS = 0.35;
        SPECULAR_AMOUNT = 0.6;
    } else {                                   // back and ends: black plastic
        BASE_COLOR = vec4(mix(vec3(0.012, 0.012, 0.014), vec3(0.09), edge), 1.0);
        ROUGHNESS = 0.5 + 0.3 * edge;
    }
    METALNESS = 0.0;
}
