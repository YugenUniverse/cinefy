#include "ShelvingGeometry.h"

#include "StoreLayout.h"

#include <QMatrix4x4>
#include <QVector3D>

#include <cmath>

namespace {

struct Mesh {
    QByteArray data;    // vertices
    QByteArray indices; // uint32, 6 per face
    quint32 count = 0;  // vertices so far
    QVector3D lo{1e9f, 1e9f, 1e9f}, hi{-1e9f, -1e9f, -1e9f};

    void vertex(const QVector3D &p, const QVector3D &n, float u, float v)
    {
        const float f[8] = {p.x(), p.y(), p.z(), n.x(), n.y(), n.z(), u, v};
        data.append(reinterpret_cast<const char *>(f), sizeof(f));
        ++count;
        for (int a = 0; a < 3; ++a) {
            lo[a] = std::min(lo[a], p[a]);
            hi[a] = std::max(hi[a], p[a]);
        }
    }

    // A box: `m` places a unit cube (-0.5..0.5) in the world. UVs are the
    // face's world size in metres, so a repeating texture keeps its scale.
    void box(const QMatrix4x4 &m)
    {
        static const int faces[6][4] = {
            {1, 5, 7, 3}, {4, 0, 2, 6}, // +x, -x
            {2, 3, 7, 6}, {4, 5, 1, 0}, // +y, -y
            {0, 1, 3, 2}, {5, 4, 6, 7}, // -z.. (see corner order below)
        };
        QVector3D c[8];
        for (int i = 0; i < 8; ++i)
            c[i] = m.map(QVector3D(i & 1 ? 0.5f : -0.5f, i & 2 ? 0.5f : -0.5f, i & 4 ? 0.5f : -0.5f));
        for (const auto &f : faces) {
            const QVector3D a = c[f[0]], b = c[f[1]], d = c[f[3]], e = c[f[2]];
            QVector3D n = QVector3D::crossProduct(b - a, d - a).normalized();
            // Make sure the normal points away from the box centre.
            const QVector3D centre = m.map(QVector3D());
            const bool flip = QVector3D::dotProduct(n, (a + e) / 2 - centre) < 0;
            if (flip)
                n = -n;
            const float w = (b - a).length() / 100, h = (d - a).length() / 100;
            // Upper-left origin: u along a->b, v along a->d.
            const QVector3D p[4] = {a, b, e, d};
            const float uv[4][2] = {{0, 0}, {w, 0}, {w, h}, {0, h}};
            // Four shared corners and two triangles (indexed: 24 vertices a
            // box instead of 36).
            const quint32 base = count;
            for (int k = 0; k < 4; ++k)
                vertex(p[k], n, uv[k][0], uv[k][1]);
            const quint32 tri[6] = {0, 1, 2, 0, 2, 3};
            const quint32 triFlip[6] = {0, 2, 1, 0, 3, 2};
            for (int i = 0; i < 6; ++i) {
                const quint32 index = base + (flip ? triFlip[i] : tri[i]);
                indices.append(reinterpret_cast<const char *>(&index), sizeof(index));
            }
        }
    }

    // An axis-aligned box from its centre and full size.
    void box(const QVector3D &centre, const QVector3D &size)
    {
        QMatrix4x4 m;
        m.translate(centre);
        m.scale(size);
        box(m);
    }

    // A thin bar from a to b (square section `t`).
    void bar(const QVector3D &a, const QVector3D &b, float t)
    {
        const QVector3D d = b - a;
        QMatrix4x4 m;
        m.translate((a + b) / 2);
        // rotate the local X axis onto d
        const QVector3D x = d.normalized();
        QVector3D up = std::abs(x.y()) > 0.9f ? QVector3D(1, 0, 0) : QVector3D(0, 1, 0);
        const QVector3D z = QVector3D::crossProduct(x, up).normalized();
        const QVector3D y = QVector3D::crossProduct(z, x);
        QMatrix4x4 r(x.x(), y.x(), z.x(), 0,
                     x.y(), y.y(), z.y(), 0,
                     x.z(), y.z(), z.z(), 0,
                     0, 0, 0, 1);
        m *= r;
        m.scale(d.length(), t, t);
        box(m);
    }
};

} // namespace

ShelvingGeometry::ShelvingGeometry(QQuick3DObject *parent) : QQuick3DGeometry(parent) {}

QObject *ShelvingGeometry::layout() const
{
    return m_layout;
}

void ShelvingGeometry::setLayout(QObject *layout)
{
    auto *l = qobject_cast<StoreLayout *>(layout);
    if (l == m_layout)
        return;
    if (m_layout)
        disconnect(m_layout, nullptr, this, nullptr);
    m_layout = l;
    if (m_layout)
        connect(m_layout, &StoreLayout::changed, this, &ShelvingGeometry::rebuild);
    emit layoutChanged();
    rebuild();
}

void ShelvingGeometry::setPart(const QString &part)
{
    if (part == m_part)
        return;
    m_part = part;
    emit partChanged();
    rebuild();
}

void ShelvingGeometry::rebuild()
{
    Mesh mesh;
    if (m_layout) {
        const float slope = std::tan(qDegreesToRadians(12.0f)); // deck falls towards the back
        for (const QVariant &g : m_layout->gondolas()) {
            const QVariantMap unit = g.toMap();
            const float x = unit.value(QStringLiteral("x")).toFloat();
            const float zc = unit.value(QStringLiteral("z")).toFloat();
            const float len = unit.value(QStringLiteral("length")).toFloat();
            const float z0 = zc - len / 2, z1 = zc + len / 2;
            for (int side : {-1, 1}) {
                for (int k = 0; k < StoreLayout::Shelves; ++k) {
                    const float level = StoreLayout::shelfLevel(k);
                    const float front = StoreLayout::stepFront(k);
                    auto at = [&](float out, float y, float z) { return QVector3D(x + side * out, y, z); };
                    if (m_part == QLatin1String("wire")) {
                        // Front lip: two rails, the upper one stops the tapes sliding off.
                        mesh.bar(at(front, level + 4, z0), at(front, level + 4, z1), 0.9f);
                        mesh.bar(at(front, level, z0), at(front, level, z1), 0.9f);
                        // Deck wires, falling towards the spine.
                        for (float d : {3.5f, 7.0f, 10.5f, 14.0f})
                            mesh.bar(at(front - d, level - d * slope, z0), at(front - d, level - d * slope, z1), 0.55f);
                        // Brackets from the spine out to the lip, every ~45 cm.
                        const int n = std::max(1, int(std::lround(len / 45)));
                        for (int i = 0; i <= n; ++i) {
                            const float z = z0 + 1 + (len - 2) * i / n;
                            const QVector3D lipLow = at(front, level, z), lipHigh = at(front, level + 4, z);
                            const QVector3D back = at(3.5f, level - (front - 3.5f) * slope, z);
                            mesh.bar(back, lipLow, 0.7f);
                            mesh.bar(lipLow, lipHigh, 0.7f);
                            mesh.bar(back, at(3.5f, level - (front - 3.5f) * slope - 10, z), 0.7f); // hook into the slatwall
                        }
                    } else if (k > 0) {
                        // End panels: one step of the staircase on each end.
                        const float inner = StoreLayout::stepFront(k - 1), top = level + 30;
                        for (float z : {z0 - 1.2f, z1 + 1.2f})
                            mesh.box(QVector3D(x + side * (inner + front) / 2, top / 2, z),
                                     QVector3D(front - inner, top, 2.4f));
                    }
                }
            }
            if (m_part != QLatin1String("wire")) {
                // The tall middle of each end, and a base step out to the plinth.
                const float mid = StoreLayout::stepFront(0);
                mesh.box(QVector3D(x, 108, zc), QVector3D(7, 212, len)); // slatwall spine
                for (float z : {z0 - 1.2f, z1 + 1.2f}) {
                    mesh.box(QVector3D(x, 106, z), QVector3D(2 * mid, 212, 2.4f));
                    for (int side : {-1, 1}) {
                        const float a = StoreLayout::stepFront(StoreLayout::Shelves - 1);
                        mesh.box(QVector3D(x + side * (a + StoreLayout::HalfDepth) / 2, 14, z),
                                 QVector3D(StoreLayout::HalfDepth - a, 28, 2.4f));
                    }
                }
            }
        }
    }
    clear();
    setStride(8 * sizeof(float));
    setPrimitiveType(PrimitiveType::Triangles);
    addAttribute(Attribute::PositionSemantic, 0, Attribute::F32Type);
    addAttribute(Attribute::NormalSemantic, 3 * sizeof(float), Attribute::F32Type);
    addAttribute(Attribute::TexCoord0Semantic, 6 * sizeof(float), Attribute::F32Type);
    addAttribute(Attribute::IndexSemantic, 0, Attribute::U32Type);
    setVertexData(mesh.data);
    setIndexData(mesh.indices);
    if (mesh.data.isEmpty())
        setBounds(QVector3D(), QVector3D());
    else
        setBounds(mesh.lo, mesh.hi);
    update();
}
