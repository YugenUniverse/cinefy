#include "LetteringTexture.h"

#include <QFont>
#include <QFontMetricsF>
#include <QImage>
#include <QPainter>
#include <QPainterPath>

LetteringTexture::LetteringTexture(QQuick3DObject *parent) : QQuick3DTextureData(parent)
{
    setFormat(QQuick3DTextureData::RGBA8);
    setHasTransparency(true);
    regenerate();
}

void LetteringTexture::regenerate()
{
    QImage img(m_w, m_h, QImage::Format_RGBA8888);
    img.fill(Qt::transparent);
    QPainter p(&img);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::TextAntialiasing);

    QFont font(QStringLiteral("Sans Serif"));
    font.setWeight(QFont::Black);
    font.setItalic(true);
    QRectF area(0, 0, m_w, m_h);

    if (m_kind == QLatin1String("arrow")) {
        // A plate shaped like an arrow pointing right, with a thin pale rim.
        const qreal tip = m_h * 0.45;
        QPainterPath arrow;
        arrow.moveTo(m_h * 0.06, m_h * 0.12);
        arrow.lineTo(m_w - tip, m_h * 0.12);
        arrow.lineTo(m_w - 2, m_h / 2.0);
        arrow.lineTo(m_w - tip, m_h * 0.88);
        arrow.lineTo(m_h * 0.06, m_h * 0.88);
        arrow.closeSubpath();
        p.fillPath(arrow, m_plate);
        p.setPen(QPen(QColor(255, 255, 255, 200), m_h * 0.025));
        p.drawPath(arrow);
        area = QRectF(m_h * 0.12, m_h * 0.12, m_w - tip - m_h * 0.12, m_h * 0.76);
    }

    // Largest size that fits.
    qreal size = area.height() * 0.8;
    font.setPixelSize(int(size));
    while (size > 8 && QFontMetricsF(font).horizontalAdvance(m_text) > area.width() * 0.94) {
        size *= 0.94;
        font.setPixelSize(int(size));
    }
    p.setFont(font);
    p.setPen(m_color);
    p.drawText(area, Qt::AlignCenter, m_text);
    p.end();
    // Texture data starts at the bottom row.
#if QT_VERSION >= QT_VERSION_CHECK(6, 9, 0)
    img.flip(Qt::Vertical);
#else
    img = img.mirrored(false, true);
#endif

    setSize(img.size());
    setTextureData(QByteArray(reinterpret_cast<const char *>(img.constBits()), img.sizeInBytes()));
    emit changed();
}
