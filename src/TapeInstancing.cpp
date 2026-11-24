#include "TapeInstancing.h"

#include "CoverAtlas.h"
#include "StoreLayout.h"

TapeInstancing::TapeInstancing(QQuick3DObject *parent) : QQuick3DInstancing(parent) {}

QObject *TapeInstancing::layout() const
{
    return m_layout;
}

void TapeInstancing::setLayout(QObject *layout)
{
    auto *l = qobject_cast<StoreLayout *>(layout);
    if (l == m_layout)
        return;
    if (m_layout)
        disconnect(m_layout, nullptr, this, nullptr);
    m_layout = l;
    if (m_layout)
        connect(m_layout, &StoreLayout::changed, this, [this] { m_dirty = true; markDirty(); });
    m_dirty = true;
    markDirty();
    emit layoutChanged();
}

void TapeInstancing::setAtlas(CoverAtlas *atlas)
{
    if (atlas == m_atlas)
        return;
    if (m_atlas)
        disconnect(m_atlas, nullptr, this, nullptr);
    m_atlas = atlas;
    if (m_atlas)
        connect(m_atlas, &CoverAtlas::cellsChanged, this, [this] { m_dirty = true; markDirty(); });
    m_dirty = true;
    markDirty();
    emit atlasChanged();
}

QByteArray TapeInstancing::getInstanceBuffer(int *instanceCount)
{
    if (m_dirty) {
        m_buffer.clear();
        m_count = 0;
        if (m_layout && m_atlas) {
            const auto &tapes = m_layout->tapes();
            m_buffer.reserve(qsizetype(tapes.size() * sizeof(InstanceTableEntry)));
            // #Cube is 100 units on each side.
            const QVector3D scale(StoreLayout::TapeW / 100, StoreLayout::TapeH / 100,
                                  StoreLayout::TapeD / 100);
            for (int i = 0; i < tapes.size(); ++i) {
                const auto &t = tapes[i];
                // A lived-in shelf: every tape leans back a little differently,
                // some are a bit crooked or pushed in.
                const quint32 h = quint32(i) * 2654435761u;
                const float lean = -4.0f - float(h % 6);
                const float twist = (float((h >> 8) % 9) - 4.0f) * 0.9f;
                const float pushed = float((h >> 16) % 4) * 0.6f;
                const QVector3D euler = t.lying ? QVector3D(-90.0f, t.yaw, 0.0f)
                                                : QVector3D(lean, (t.facing > 0 ? 90.0f : t.facing < 0 ? -90.0f : 0.0f) + twist, 0.0f);
                const QVector3D pos = t.pos - QVector3D(t.facing * pushed, 0, 0);
                const auto entry = calculateTableEntry(pos, scale, euler, Qt::white,
                                                       m_atlas->cell(t.film));
                m_buffer.append(reinterpret_cast<const char *>(&entry), sizeof(entry));
                ++m_count;
            }
        }
        m_dirty = false;
    }
    if (instanceCount)
        *instanceCount = m_count;
    return m_buffer;
}
