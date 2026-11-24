#pragma once

#include <QtQml/qqmlregistration.h>
#include <QtQuick3D/QQuick3DGeometry>

// An umbrella canopy: ribs from the top down to the rim, with the fabric
// sagging between them. `parity` picks every other panel (0 or 1), so two
// models with different colours make the classic striped umbrella.
class UmbrellaGeometry : public QQuick3DGeometry
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int parity READ parity WRITE setParity NOTIFY parityChanged)
    Q_PROPERTY(float open READ open WRITE setOpen NOTIFY openChanged) // 0 folded .. 1 open

public:
    explicit UmbrellaGeometry(QQuick3DObject *parent = nullptr);

    int parity() const { return m_parity; }
    void setParity(int parity);
    float open() const { return m_open; }
    void setOpen(float open);

signals:
    void parityChanged();
    void openChanged();

private:
    void rebuild();
    int m_parity = 0;
    float m_open = 1;
};
