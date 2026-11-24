// Pass the tape's cover cell (per-instance data), its local normal, UVs and
// local position on to the fragment shader.
VARYING vec4 vCell;
VARYING vec3 vLocalNormal;
VARYING vec2 vUv;
VARYING vec3 vLocal;

void MAIN()
{
    vCell = INSTANCE_DATA;
    vLocalNormal = NORMAL;
    vUv = UV0;
    vLocal = VERTEX; // #Cube spans -50..50 on each axis
}
