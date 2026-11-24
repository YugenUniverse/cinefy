#include "RoomProbe.h"

#include <QSize>

#include <algorithm>
#include <cmath>

namespace {
struct Rgb {
    float r, g, b;
};
Rgb mix(Rgb a, Rgb b, float t)
{
    return {a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t};
}
} // namespace

RoomProbe::RoomProbe(QQuick3DObject *parent) : QQuick3DTextureData(parent)
{
    constexpr int W = 512, H = 256;
    constexpr float Pi = 3.14159265f;
    // In centimetres, from eye height: the ceiling is ~1.6 m up, the walls
    // ~12 m away, the floor 1.6 m down.
    constexpr float Up = 160, Wall = 1200, Down = 160;
    const Rgb ceiling{0.80f, 0.79f, 0.75f};
    const Rgb grid{0.55f, 0.55f, 0.53f};
    const Rgb panel{7.0f, 7.2f, 7.6f};
    const Rgb yellow{0.78f, 0.52f, 0.10f};
    const Rgb tapes{0.20f, 0.17f, 0.16f};
    const Rgb shelfGrey{0.45f, 0.45f, 0.44f};
    const Rgb carpet{0.07f, 0.12f, 0.30f};

    QByteArray data(W * H * 4 * int(sizeof(float)), Qt::Uninitialized);
    auto *out = reinterpret_cast<float *>(data.data());
    for (int y = 0; y < H; ++y) {
        const float theta = (y + 0.5f) / H * Pi; // 0 = straight up
        for (int x = 0; x < W; ++x) {
            const float phi = (x + 0.5f) / W * 2 * Pi;
            const float dx = std::sin(theta) * std::cos(phi), dy = std::cos(theta),
                        dz = std::sin(theta) * std::sin(phi);
            const float horiz = std::max(1e-4f, std::sqrt(dx * dx + dz * dz));
            Rgb c;
            // Which surface does this direction see first?
            const float tCeil = dy > 0 ? Up / dy : 1e9f;
            const float tFloor = dy < 0 ? Down / -dy : 1e9f;
            const float tWall = Wall / horiz;
            if (tCeil < tWall) {
                // Ceiling: 60 cm tiles, and a 1.2 x 0.6 m panel every 3 m.
                const float px = dx * tCeil, pz = dz * tCeil;
                const float gx = std::fmod(std::abs(px), 60.0f), gz = std::fmod(std::abs(pz), 60.0f);
                const float line = (gx < 2 || gz < 2) ? 1.0f : 0.0f;
                c = mix(ceiling, grid, line * 0.6f);
                const float lx = std::fmod(std::abs(px) + 60, 300.0f), lz = std::fmod(std::abs(pz) + 30, 300.0f);
                if (lx < 120 && lz < 60)
                    c = panel;
            } else if (tFloor < tWall) {
                c = carpet;
            } else {
                const float h = dy * tWall; // height on the wall, relative to the eye
                if (h > 40)
                    c = yellow;              // painted wall above the racks
                else if (h > -150)
                    c = mix(tapes, shelfGrey, 0.25f + 0.25f * std::sin(phi * 40)); // full racks
                else
                    c = carpet;
            }
            float *px = out + (y * W + x) * 4;
            px[0] = c.r;
            px[1] = c.g;
            px[2] = c.b;
            px[3] = 1;
        }
    }
    setFormat(QQuick3DTextureData::RGBA32F);
    setSize(QSize(W, H));
    setHasTransparency(false);
    setTextureData(data);
}
