#pragma once

#include <QColor>
#include <QtQml/qqmlregistration.h>
#include <QtQuick3D/QQuick3DTextureData>

// Cut-out lettering with a transparent background, for signs that stand off
// a wall (use with alphaMode Blend). `kind`: "letters" (just the text, bold
// italic) or "arrow" (the text on an arrow-shaped plate pointing right).
class LetteringTexture : public QQuick3DTextureData
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY changed)
    Q_PROPERTY(QString kind READ kind WRITE setKind NOTIFY changed)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY changed)
    Q_PROPERTY(QColor plate READ plate WRITE setPlate NOTIFY changed)
    Q_PROPERTY(int pixelWidth READ pixelWidth WRITE setPixelWidth NOTIFY changed)
    Q_PROPERTY(int pixelHeight READ pixelHeight WRITE setPixelHeight NOTIFY changed)
public:
    explicit LetteringTexture(QQuick3DObject *parent = nullptr);
    QString text() const { return m_text; }
    QString kind() const { return m_kind; }
    QColor color() const { return m_color; }
    QColor plate() const { return m_plate; }
    int pixelWidth() const { return m_w; }
    int pixelHeight() const { return m_h; }
    void setText(const QString &v) { if (v != m_text) { m_text = v; regenerate(); } }
    void setKind(const QString &v) { if (v != m_kind) { m_kind = v; regenerate(); } }
    void setColor(const QColor &v) { if (v != m_color) { m_color = v; regenerate(); } }
    void setPlate(const QColor &v) { if (v != m_plate) { m_plate = v; regenerate(); } }
    void setPixelWidth(int v) { if (v != m_w) { m_w = v; regenerate(); } }
    void setPixelHeight(int v) { if (v != m_h) { m_h = v; regenerate(); } }
signals:
    void changed();
private:
    void regenerate();
    QString m_text, m_kind = QStringLiteral("letters");
    QColor m_color = QColor(QStringLiteral("#2b3f97")), m_plate = QColor(QStringLiteral("#2b3f97"));
    int m_w = 1024, m_h = 128;
};
