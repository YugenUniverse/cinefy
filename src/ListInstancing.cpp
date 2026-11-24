#include "ListInstancing.h"

#include <QColor>
#include <QVector3D>
#include <QVector4D>

ListInstancing::ListInstancing(QQuick3DObject *parent) : QQuick3DInstancing(parent) {}

void ListInstancing::setEntries(const QVariantList &entries)
{
    m_entries = entries;
    m_dirty = true;
    markDirty();
    emit entriesChanged();
}

QByteArray ListInstancing::getInstanceBuffer(int *instanceCount)
{
    if (m_dirty) {
        m_buffer.clear();
        m_count = 0;
        m_buffer.reserve(qsizetype(m_entries.size() * sizeof(InstanceTableEntry)));
        static const QString P = QStringLiteral("p"), S = QStringLiteral("s"), R = QStringLiteral("r"),
                             C = QStringLiteral("c"), D = QStringLiteral("d");
        for (const QVariant &v : std::as_const(m_entries)) {
            const QVariantMap e = v.toMap();
            const QVector3D pos = e.value(P).value<QVector3D>();
            const QVector3D scale = e.contains(S) ? e.value(S).value<QVector3D>() : QVector3D(1, 1, 1);
            const QVector3D rot = e.value(R).value<QVector3D>();
            const QColor color = e.contains(C) ? e.value(C).value<QColor>() : QColor(Qt::white);
            const QVector4D data = e.value(D).value<QVector4D>();
            const auto entry = calculateTableEntry(pos, scale, rot, color, data);
            m_buffer.append(reinterpret_cast<const char *>(&entry), sizeof(entry));
            ++m_count;
        }
        m_dirty = false;
    }
    if (instanceCount)
        *instanceCount = m_count;
    return m_buffer;
}
