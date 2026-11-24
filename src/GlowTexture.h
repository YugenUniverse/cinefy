#pragma once

#include <QtQml/qqmlregistration.h>
#include <QtQuick3D/QQuick3DTextureData>

// Soft white light shapes with alpha, for drawing visible light: "pool"
// (round, fading out), "rect" (rounded rectangle halo), "beam" (bright at
// the top, fading down, soft sides).
class GlowTexture : public QQuick3DTextureData
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString shape READ shape WRITE setShape NOTIFY shapeChanged)
public:
    explicit GlowTexture(QQuick3DObject *parent = nullptr);
    QString shape() const { return m_shape; }
    void setShape(const QString &shape);
signals:
    void shapeChanged();
private:
    void generate();
    QString m_shape = QStringLiteral("pool");
};
