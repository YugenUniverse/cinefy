#pragma once

#include <QPointer>
#include <QtQml/qqmlregistration.h>
#include <QtQuick3D/QQuick3DGeometry>

class StoreLayout;

// All the free-standing units' stepped shelving as one mesh (one draw call
// instead of thousands of little models). `part`:
//  "wire": the chrome wire shelves - front lip rails, deck wires and the
//           brackets from the spine to each lip, stepping out shelf by shelf;
//  "ends": the stepped slatwall end panels (UVs in metres, for a slat texture).
class ShelvingGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QObject *layout READ layout WRITE setLayout NOTIFY layoutChanged)
    Q_PROPERTY(QString part READ part WRITE setPart NOTIFY partChanged)
public:
    explicit ShelvingGeometry(QQuick3DObject *parent = nullptr);
    QObject *layout() const;
    void setLayout(QObject *layout);
    QString part() const { return m_part; }
    void setPart(const QString &part);
signals:
    void layoutChanged();
    void partChanged();
private:
    void rebuild();
    QPointer<StoreLayout> m_layout;
    QString m_part = QStringLiteral("wire");
};
