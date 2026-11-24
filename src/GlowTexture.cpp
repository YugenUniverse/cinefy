#include "GlowTexture.h"

#include <QSize>

#include <algorithm>
#include <cmath>

GlowTexture::GlowTexture(QQuick3DObject *parent) : QQuick3DTextureData(parent)
{
    setFormat(QQuick3DTextureData::RGBA8);
    setHasTransparency(true);
    generate();
}

void GlowTexture::setShape(const QString &shape)
{
    if (shape == m_shape)
        return;
    m_shape = shape;
    generate();
    emit shapeChanged();
}

void GlowTexture::generate()
{
    const int w = 128, h = m_shape == QLatin1String("beam") ? 256 : 128;
    QByteArray data(w * h * 4, Qt::Uninitialized);
    auto *p = reinterpret_cast<uchar *>(data.data());
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            const float u = (x + 0.5f) / w * 2 - 1, v = (y + 0.5f) / h * 2 - 1; // -1..1
            float a = 0;
            if (m_shape == QLatin1String("beam")) {
                const float side = std::pow(std::max(0.0f, 1 - std::abs(u)), 1.6f);
                const float t = (y + 0.5f) / h; // 0 top .. 1 bottom
                a = side * std::pow(1 - t, 1.4f);
            } else if (m_shape == QLatin1String("rect")) {
                const float d = std::max(std::abs(u), std::abs(v)) * 0.6f + std::sqrt(u * u + v * v) * 0.4f;
                a = std::pow(std::max(0.0f, 1 - d), 2.0f);
            } else {
                a = std::pow(std::max(0.0f, 1 - std::sqrt(u * u + v * v)), 2.2f);
            }
            uchar *px = p + (y * w + x) * 4;
            px[0] = px[1] = px[2] = 255;
            px[3] = uchar(std::lround(std::clamp(a, 0.0f, 1.0f) * 255));
        }
    }
    setSize(QSize(w, h));
    setTextureData(data);
}
