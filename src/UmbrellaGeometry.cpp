#include "UmbrellaGeometry.h"

#include <QVector3D>
#include <QtMath>

namespace {
constexpr int Ribs = 8;
constexpr int Rings = 6;           // steps from the top to the rim
constexpr float Radius = 105.0f;   // cm, open
constexpr float Height = 34.0f;    // top above the rim
constexpr float Pi = 3.14159265f;
}

UmbrellaGeometry::UmbrellaGeometry(QQuick3DObject *parent) : QQuick3DGeometry(parent)
{
    rebuild();
}

void UmbrellaGeometry::setParity(int parity)
{
    if (parity == m_parity)
        return;
    m_parity = parity;
    rebuild();
    emit parityChanged();
}

void UmbrellaGeometry::setOpen(float open)
{
    open = qBound(0.0f, open, 1.0f);
    if (qFuzzyCompare(open, m_open))
        return;
    m_open = open;
    rebuild();
    emit openChanged();
}

void UmbrellaGeometry::rebuild()
{
    // Folding pulls the rim in and down along the shaft.
    const float radius = Radius * (0.12f + 0.88f * m_open);
    const float height = Height + (1 - m_open) * 60.0f;

    auto point = [&](float along, float t) {
        // along: 0 top .. 1 rim; t: angle in units of ribs (whole = on a rib)
        const float angle = t * 2 * Pi / Ribs;
        const float between = std::abs(std::sin(t * Pi)); // 0 on a rib, 1 mid-panel
        const float r = radius * along * (1 - 0.06f * between * along);
        const float y = height * (1 - along * along) - 4.0f * between * along; // sag between ribs
        return QVector3D(r * std::cos(angle), y, r * std::sin(angle));
    };

    QByteArray vertices;
    auto addVertex = [&vertices](const QVector3D &p, const QVector3D &n) {
        const float v[6] = {p.x(), p.y(), p.z(), n.x(), n.y(), n.z()};
        vertices.append(reinterpret_cast<const char *>(v), sizeof(v));
    };
    auto addTriangle = [&](const QVector3D &a, const QVector3D &b, const QVector3D &c) {
        const QVector3D n = QVector3D::normal(a, b, c);
        addVertex(a, n);
        addVertex(b, n);
        addVertex(c, n);
    };

    constexpr int Steps = 4; // subdivisions across a panel, for the sag
    for (int rib = m_parity; rib < Ribs; rib += 2) {
        for (int ring = 0; ring < Rings; ++ring) {
            const float a0 = float(ring) / Rings, a1 = float(ring + 1) / Rings;
            for (int s = 0; s < Steps; ++s) {
                const float t0 = rib + float(s) / Steps, t1 = rib + float(s + 1) / Steps;
                const QVector3D p00 = point(a0, t0), p01 = point(a0, t1);
                const QVector3D p10 = point(a1, t0), p11 = point(a1, t1);
                addTriangle(p00, p10, p11);
                addTriangle(p00, p11, p01);
            }
        }
    }

    clear();
    setVertexData(vertices);
    setStride(6 * sizeof(float));
    setPrimitiveType(PrimitiveType::Triangles);
    addAttribute(Attribute::PositionSemantic, 0, Attribute::F32Type);
    addAttribute(Attribute::NormalSemantic, 3 * sizeof(float), Attribute::F32Type);
    setBounds(QVector3D(-Radius, 0, -Radius), QVector3D(Radius, Height + 60, Radius));
    update();
}
