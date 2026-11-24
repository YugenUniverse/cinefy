#include "SurfaceDetail.h"

#include <QVector>
#include <QVector3D>

#include <algorithm>
#include <cmath>

namespace {

constexpr int N = 256; // texture size; everything below tiles seamlessly

float hash(int x, int y, int seed)
{
    quint32 h = quint32(x & (N - 1)) * 374761393u + quint32(y & (N - 1)) * 668265263u + quint32(seed) * 2246822519u;
    h = (h ^ (h >> 13)) * 1274126177u;
    return float((h ^ (h >> 16)) & 0xffff) / 65535.0f;
}

// Smooth value noise with `cells` cells across the tile (wraps).
float noise(float x, float y, int cells, int seed)
{
    const float fx = x * cells / N, fy = y * cells / N;
    const int x0 = int(std::floor(fx)), y0 = int(std::floor(fy));
    const float tx = fx - x0, ty = fy - y0;
    auto at = [&](int cx, int cy) {
        return hash(((cx % cells) + cells) % cells * (N / cells), ((cy % cells) + cells) % cells * (N / cells), seed);
    };
    const float sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty);
    const float a = at(x0, y0) + (at(x0 + 1, y0) - at(x0, y0)) * sx;
    const float b = at(x0, y0 + 1) + (at(x0 + 1, y0 + 1) - at(x0, y0 + 1)) * sx;
    return a + (b - a) * sy;
}

float fbm(float x, float y, int cells, int seed, int octaves)
{
    float v = 0, amp = 0.5f, norm = 0;
    for (int o = 0; o < octaves; ++o) {
        v += amp * noise(x, y, cells << o, seed + o * 17);
        norm += amp;
        amp *= 0.5f;
    }
    return v / norm;
}

} // namespace

SurfaceDetail::SurfaceDetail(QQuick3DObject *parent) : QQuick3DTextureData(parent)
{
    setSize(QSize(N, N));
    setFormat(QQuick3DTextureData::RGBA8);
    setHasTransparency(false);
    generate();
}

void SurfaceDetail::setKind(const QString &kind)
{
    if (kind == m_kind)
        return;
    m_kind = kind;
    generate();
    emit kindChanged();
}

void SurfaceDetail::setStrength(float strength)
{
    if (qFuzzyCompare(strength, m_strength))
        return;
    m_strength = strength;
    generate();
    emit strengthChanged();
}

void SurfaceDetail::setTiles(int tiles)
{
    tiles = std::max(1, tiles);
    if (tiles == m_tiles)
        return;
    m_tiles = tiles;
    generate();
    emit tilesChanged();
}

void SurfaceDetail::generate()
{
    QVector<float> h(N * N);
    const int cell = N / m_tiles;
    for (int y = 0; y < N; ++y) {
        for (int x = 0; x < N; ++x) {
            float v = 0;
            if (m_kind == QLatin1String("carpet")) {
                // Tufted loops: fine bumpy grain plus a soft wear pattern.
                v = 0.6f * hash(x, y, 3) + 0.4f * fbm(x, y, 16, 7, 3);
            } else if (m_kind == QLatin1String("tiles") || m_kind == QLatin1String("ceramic")) {
                // Flat tiles with grooved joints and a slightly uneven face.
                const int gx = x % cell, gy = y % cell;
                const float d = float(std::min({gx, gy, cell - 1 - gx, cell - 1 - gy}));
                const float groove = m_kind == QLatin1String("ceramic") ? 3.0f : 2.0f;
                v = d < groove ? 0.0f : std::min(1.0f, 0.75f + 0.25f * (d - groove) / 3.0f);
                v -= 0.06f * fbm(x, y, 8, 11, 2);
            } else if (m_kind == QLatin1String("brushed")) {
                // Long fine strokes along X, the look of brushed steel.
                v = 0.7f * noise(x, float(y) * 16, 4, 5) + 0.3f * hash(x / 32, y, 9);
            } else { // plaster
                v = fbm(x, y, 8, 21, 4);
            }
            h[y * N + x] = v;
        }
    }
    QByteArray data(N * N * 4, Qt::Uninitialized);
    auto *px = reinterpret_cast<uchar *>(data.data());
    for (int y = 0; y < N; ++y) {
        for (int x = 0; x < N; ++x) {
            const float l = h[y * N + ((x + N - 1) % N)], r = h[y * N + ((x + 1) % N)];
            const float u = h[((y + N - 1) % N) * N + x], d = h[((y + 1) % N) * N + x];
            QVector3D n(-(r - l) * m_strength, -(d - u) * m_strength, 1.0f);
            n.normalize();
            uchar *p = px + (y * N + x) * 4;
            p[0] = uchar(std::lround((n.x() * 0.5f + 0.5f) * 255));
            p[1] = uchar(std::lround((n.y() * 0.5f + 0.5f) * 255));
            p[2] = uchar(std::lround((n.z() * 0.5f + 0.5f) * 255));
            p[3] = 255;
        }
    }
    setTextureData(data);
}
