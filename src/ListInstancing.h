#pragma once

#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include <QtQuick3D/QQuick3DInstancing>

// Instancing from a plain list, so many copies of one small object (light
// panels, vents, sweets...) are a single draw call instead of one each.
// Each entry is a map: { p: position, s: scale (default 1,1,1), r: euler
// rotation in degrees, c: colour (multiplies the material; alpha too),
// d: vector4d custom data (INSTANCE_DATA in custom shaders) }.
class ListInstancing : public QQuick3DInstancing
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariantList entries READ entries WRITE setEntries NOTIFY entriesChanged)
public:
    explicit ListInstancing(QQuick3DObject *parent = nullptr);
    QVariantList entries() const { return m_entries; }
    void setEntries(const QVariantList &entries);
signals:
    void entriesChanged();
protected:
    QByteArray getInstanceBuffer(int *instanceCount) override;
private:
    QVariantList m_entries;
    QByteArray m_buffer;
    int m_count = 0;
    bool m_dirty = true;
};
