#pragma once

#include <QPointer>
#include <QtQml/qqmlregistration.h>
#include <QtQuick3D/QQuick3DInstancing>

class CoverAtlas;
class StoreLayout;

// One instance per tape on the shelves: position and rotation from the store
// layout, and the tape's cover cell in the atlas as custom per-instance data.
class TapeInstancing : public QQuick3DInstancing
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QObject *layout READ layout WRITE setLayout NOTIFY layoutChanged)
    Q_PROPERTY(CoverAtlas *atlas READ atlas WRITE setAtlas NOTIFY atlasChanged)

public:
    explicit TapeInstancing(QQuick3DObject *parent = nullptr);

    QObject *layout() const;
    void setLayout(QObject *layout);
    CoverAtlas *atlas() const { return m_atlas; }
    void setAtlas(CoverAtlas *atlas);

signals:
    void layoutChanged();
    void atlasChanged();

protected:
    QByteArray getInstanceBuffer(int *instanceCount) override;

private:
    QPointer<StoreLayout> m_layout;
    QPointer<CoverAtlas> m_atlas;
    QByteArray m_buffer;
    int m_count = 0;
    bool m_dirty = true;
};
