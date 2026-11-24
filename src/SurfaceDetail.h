#pragma once

#include <QtQml/qqmlregistration.h>
#include <QtQuick3D/QQuick3DTextureData>

// A tileable normal map (surface relief that catches the light), generated
// from a procedural height field. Kinds: "carpet", "tiles", "plaster",
// "brushed", "ceramic".
class SurfaceDetail : public QQuick3DTextureData
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString kind READ kind WRITE setKind NOTIFY kindChanged)
    Q_PROPERTY(float strength READ strength WRITE setStrength NOTIFY strengthChanged)
    Q_PROPERTY(int tiles READ tiles WRITE setTiles NOTIFY tilesChanged) // joints per side (tiles/ceramic)

public:
    explicit SurfaceDetail(QQuick3DObject *parent = nullptr);

    QString kind() const { return m_kind; }
    void setKind(const QString &kind);
    float strength() const { return m_strength; }
    void setStrength(float strength);
    int tiles() const { return m_tiles; }
    void setTiles(int tiles);

signals:
    void kindChanged();
    void strengthChanged();
    void tilesChanged();

private:
    void generate();
    QString m_kind = QStringLiteral("plaster");
    float m_strength = 2.0f;
    int m_tiles = 4;
};
