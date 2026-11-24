// Draws nothing visible, but still fills the depth buffer: used to hide parts
// of the shop that are behind street objects, letting the ASCII city show.
void MAIN()
{
    FRAGCOLOR = vec4(0.0);
}
