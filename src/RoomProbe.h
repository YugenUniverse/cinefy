#pragma once

#include <QtQml/qqmlregistration.h>
#include <QtQuick3D/QQuick3DTextureData>

// A small HDR panorama of the inside of the shop, made in code, used as the
// light probe: every surface gets soft fill light and reflections from a
// bright room (white tiled ceiling with glowing panels, yellow walls, racks
// of tapes, blue carpet) instead of flat ambient colour.
class RoomProbe : public QQuick3DTextureData
{
    Q_OBJECT
    QML_ELEMENT
public:
    explicit RoomProbe(QQuick3DObject *parent = nullptr);
};
