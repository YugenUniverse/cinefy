#include "StoreLayout.h"

#include "AisleModel.h"

#include <QtMath>

#include <algorithm>
#include <cmath>
#include <limits>

float StoreLayout::shelfLevel(int shelf)
{
    static constexpr float levels[Shelves] = {168, 134, 100, 66, 32};
    return levels[std::clamp(shelf, 0, Shelves - 1)];
}

StoreLayout::StoreLayout(QObject *parent) : QObject(parent)
{
    setAisles({});
}

float StoreLayout::rowX(int row) const
{
    return row * RowSpacing - (m_rows - 1) * RowSpacing / 2;
}

void StoreLayout::setAisles(const QList<AisleModel *> &aisles, const QSet<int> &staffPicks,
                            const QList<int> &recent)
{
    m_categories.clear();
    m_units.clear();
    m_tapes.clear();
    m_talkers.clear();

    // 1. Cut every aisle into units and place the units in rows.
    int row = 0;
    float cursor = 0; // distance from the front of the current row
    float longest = SectionLen;
    for (AisleModel *a : aisles) {
        const QVector<int> rows = a->sourceRows();
        if (rows.isEmpty())
            continue;
        const int cat = int(m_categories.size());
        m_categories.push_back({a->id(), a->title(), a->subtitle(), a->accent(), int(rows.size()),
                                int(m_units.size())});

        const int perUnitMax = 2 * MaxUnitSections * PerSection;
        const int unitCount = int(qCeil(rows.size() / double(perUnitMax)));
        const int perUnit = int(qCeil(rows.size() / double(unitCount)));
        for (int u = 0; u < unitCount; ++u) {
            const QVector<int> films = rows.mid(u * perUnit, perUnit);
            const int sections = std::clamp(int(qCeil(films.size() / double(2 * PerSection))), 1, MaxUnitSections);
            const float length = sections * SectionLen;
            float gap = cursor > 0 ? (u == 0 ? CategoryGap : UnitGap) : 0;
            if (cursor > 0 && cursor + gap + length > RowMaxLength) {
                ++row;
                cursor = 0;
                gap = 0;
            }
            Unit unit{cat, row, -(cursor + gap), -(cursor + gap + length), sections, u == 0};
            cursor += gap + length;
            longest = std::max(longest, cursor);
            const int unitIndex = int(m_units.size());
            m_units.push_back(unit);

            // Two faces; each fills shelf by shelf across the whole face, and
            // a part-filled face keeps its tapes around eye level.
            const int perFaceA = int(qCeil(films.size() / 2.0));
            for (int side = 0; side < 2; ++side) {
                const int begin = side == 0 ? 0 : perFaceA;
                const int count = side == 0 ? perFaceA : int(films.size()) - perFaceA;
                const int perRow = PerShelf * sections;
                const int shelvesUsed = std::min(Shelves, int(qCeil(count / double(perRow))));
                const int firstShelf = (Shelves - shelvesUsed) / 2;
                for (int j = 0; j < count; ++j) {
                    Tape t;
                    t.film = films[begin + j];
                    t.facing = side == 0 ? -1 : 1;
                    t.unit = unitIndex;
                    t.shelf = std::min(Shelves - 1, firstShelf + j / perRow);
                    const int slot = j % perRow;
                    t.pos = QVector3D(row, slot, 0); // finished below, once rows are known
                    m_tapes.push_back(t);
                }
            }
        }
    }
    m_rows = std::max(1, row + 1);

    // 2. Now the store's size is known: final tape positions.
    for (Tape &t : m_tapes) {
        const Unit &u = m_units[t.unit];
        const float slot = t.pos.y() + 0.5f;
        const float z = t.facing < 0 ? u.zBack + slot * Pitch : u.zFront - slot * Pitch;
        t.pos = QVector3D(rowX(u.row) + t.facing * TapeInset, shelfLevel(t.shelf) + TapeH / 2 + 0.6f, z);
    }

    // 3. Handwritten cards under staff picks (first copy of each film only).
    QSet<int> carded;
    for (const Tape &t : std::as_const(m_tapes)) {
        if (t.unit < 0 || !staffPicks.contains(t.film) || carded.contains(t.film) || m_talkers.size() >= 60)
            continue;
        carded.insert(t.film);
        m_talkers << QVariantMap{
            {QStringLiteral("film"), t.film},
            {QStringLiteral("position"),
             QVector3D(rowX(m_units[t.unit].row) + t.facing * (HalfDepth + 0.8f), shelfLevel(t.shelf) - 8, t.pos.z())},
            {QStringLiteral("yaw"), t.facing > 0 ? 90.0 : -90.0},
        };
    }

    m_halfWidth = (m_rows - 1) * RowSpacing / 2 + HalfDepth + SideAisle;
    m_backZ = -longest - BackAisle;
    m_frontZ = FrontArea;
    buildFrontOfStore();

    // Your latest watches, just returned: a stack on the counter, newest on
    // top, cover up, a little untidy. They're real tapes you can pick up.
    const QList<int> nightDrop = recent.mid(0, 10);
    const int stack = std::min<int>(int(nightDrop.size()), 10);
    for (int i = 0; i < stack; ++i) {
        const quint32 h = quint32(i + 1) * 2654435761u;
        Tape t;
        t.film = nightDrop[stack - 1 - i]; // oldest at the bottom
        t.facing = 0;
        t.unit = -1;
        t.shelf = 0;
        t.lying = true;
        t.yaw = 90.0f + float(int(h % 13) - 6);
        t.pos = m_counter + QVector3D(float(int(h >> 9) % 3) - 1, 108.5f + TapeD / 2 + i * (TapeD + 0.15f),
                                      -14 + float(int(h >> 17) % 3) - 1);
        m_tapes.push_back(t);
    }
    // The wall rack along the back: your latest watches, several copies of
    // each side by side, cover out, like a real wall of new releases.
    {
        const float x0 = -m_halfWidth * 0.6f + 230, x1 = m_halfWidth * 0.3f - 230;
        const float z = m_backZ + 24;
        m_wallRack = {{QStringLiteral("x0"), x0}, {QStringLiteral("x1"), x1}, {QStringLiteral("z"), m_backZ}};
        m_obstacles << QRectF(x0 - 10, m_backZ, x1 - x0 + 20, 48);
        const int perShelf = std::max(1, int((x1 - x0) / Pitch));
        const int places = perShelf * Shelves;
        const QList<int> films = recent; // one copy each, newest first
        if (!films.isEmpty()) {
            const int copies = 1;
            int slot = 0;
            for (int f = 0; f < films.size() && slot < places; ++f) {
                for (int c = 0; c < copies && slot < places; ++c, ++slot) {
                    Tape t;
                    t.film = films[f];
                    t.facing = 0;
                    t.unit = -1;
                    t.shelf = slot / perShelf;
                    t.pos = QVector3D(x0 + (slot % perShelf + 0.5f) * Pitch,
                                      shelfLevel(t.shelf) + TapeH / 2 + 0.6f, z);
                    m_tapes.push_back(t);
                }
            }
        }
    }

    // Parked cars along the kerb outside.
    {
        m_cars.clear();
        const float z = m_frontZ + 408 + 115;
        const QList<QPair<float, QString>> spots = {{-1150, "#8a1c1c"}, {640, "#d8d4c8"}, {1320, "#1f3f6b"}};
        for (const auto &sp : spots)
            m_cars << QVariantMap{{QStringLiteral("x"), sp.first}, {QStringLiteral("z"), z},
                                  {QStringLiteral("color"), sp.second}};
    }

    // You arrive on the street, facing the shop front.
    m_entrance = QVector3D(0, EyeHeight, m_frontZ + 700);
    buildStreet();
    buildWindowPosters();

    ++m_revision;
    emit changed();
}

void StoreLayout::buildFrontOfStore()
{
    m_obstacles.clear();
    for (const Unit &u : std::as_const(m_units))
        m_obstacles << QRectF(rowX(u.row) - HalfDepth - 4, u.zBack - 6, 2 * HalfDepth + 8, unitLength(u) + 12);

    // The counter by the right wall, the candy rack in front of it, the
    // return bin just inside the door.
    m_counter = QVector3D(m_halfWidth - 170, 0, m_frontZ - 420);
    m_obstacles << QRectF(m_counter.x() - 55, m_counter.z() - 170, 110, 340);
    m_obstacles << QRectF(m_counter.x() + 70, m_counter.z() + 5, 50, 50); // the clerk
    // At the back (see Store3DBackWall.qml): the arcade cabinets, the popcorn
    // machine and the returns trolley.
    m_obstacles << QRectF(m_halfWidth * 0.3f - 170, m_backZ, 340, 95);
    m_obstacles << QRectF(m_halfWidth * 0.68f - 45, m_backZ, 90, 85);
    m_obstacles << QRectF(-m_halfWidth * 0.6f + 110 - 50, m_backZ + 71 - 35, 100, 70);
    m_candyRack = QVector3D(m_halfWidth - 170, 0, m_frontZ - 720);
    m_obstacles << QRectF(m_candyRack.x() - 40, m_candyRack.z() - 30, 80, 60);
    m_returnBin = QVector3D(); // (no returns bin any more: the tapes are on the counter)

}

QString StoreLayout::signature() const
{
    QString s = QStringLiteral("%1/%2/%3").arg(m_halfWidth).arg(m_frontZ).arg(m_backZ);
    for (const Unit &u : m_units)
        s += QStringLiteral(";%1,%2,%3").arg(u.row).arg(u.zFront).arg(u.sections);
    return QString::number(qHash(s), 16);
}

QVariantList StoreLayout::gondolas() const
{
    QVariantList out;
    for (const Unit &u : m_units)
        out << QVariantMap{{QStringLiteral("x"), rowX(u.row)},
                           {QStringLiteral("z"), (u.zFront + u.zBack) / 2},
                           {QStringLiteral("length"), unitLength(u)}};
    return out;
}

QVariantList StoreLayout::signs() const
{
    QVariantList out;
    for (const Unit &u : m_units) {
        const Category &c = m_categories[u.category];
        for (int facing : {-1, 1}) {
            out << QVariantMap{
                {QStringLiteral("x"), rowX(u.row) + facing * (HalfDepth + 1.5f)},
                {QStringLiteral("z"), (u.zFront + u.zBack) / 2},
                {QStringLiteral("yaw"), facing > 0 ? 90.0 : -90.0},
                {QStringLiteral("width"), unitLength(u) - 8},
                {QStringLiteral("title"), c.title},
                {QStringLiteral("accent"), c.accent},
                {QStringLiteral("first"), u.first},
            };
        }
    }
    return out;
}

QVariantList StoreLayout::endSigns() const
{
    // Both ends of every unit say which aisle it is.
    QVariantList out;
    for (const Unit &u : m_units) {
        const Category &c = m_categories[u.category];
        for (int end : {1, -1}) {
            out << QVariantMap{{QStringLiteral("x"), rowX(u.row)},
                               {QStringLiteral("z"), end > 0 ? u.zFront + 6 : u.zBack - 6},
                               {QStringLiteral("yaw"), end > 0 ? 0.0 : 180.0},
                               {QStringLiteral("title"), c.title},
                               {QStringLiteral("count"), c.count},
                               {QStringLiteral("accent"), c.accent}};
        }
    }
    return out;
}

QVariantList StoreLayout::categories() const
{
    QVariantList out;
    for (int i = 0; i < m_categories.size(); ++i) {
        const Category &c = m_categories[i];
        QVariantList units;
        for (const Unit &u : m_units) {
            if (u.category == i)
                units << QVariantMap{{QStringLiteral("x"), rowX(u.row)},
                                     {QStringLiteral("z0"), u.zBack},
                                     {QStringLiteral("z1"), u.zFront}};
        }
        out << QVariantMap{{QStringLiteral("id"), c.id},
                           {QStringLiteral("title"), c.title},
                           {QStringLiteral("accent"), c.accent},
                           {QStringLiteral("count"), c.count},
                           {QStringLiteral("units"), units}};
    }
    return out;
}

namespace {
// Distance along the ray to an axis-aligned box, or -1 if it misses.
float rayBox(const QVector3D &o, const QVector3D &d, const QVector3D &lo, const QVector3D &hi, float maxT)
{
    float tMin = 0, tMax = maxT;
    for (int a = 0; a < 3; ++a) {
        if (std::abs(d[a]) < 1e-6f) {
            if (o[a] < lo[a] || o[a] > hi[a])
                return -1;
            continue;
        }
        float t0 = (lo[a] - o[a]) / d[a], t1 = (hi[a] - o[a]) / d[a];
        if (t0 > t1)
            std::swap(t0, t1);
        tMin = std::max(tMin, t0);
        tMax = std::min(tMax, t1);
        if (tMin > tMax)
            return -1;
    }
    return tMin;
}
} // namespace

int StoreLayout::pick(const QVector3D &origin, const QVector3D &dir, float maxDistance) const
{
    int best = -1;
    float bestT = maxDistance;
    // The shelving is solid: the pegboard down the middle of each unit, its
    // end panels and the plinth stop the aim, so you can't pick a tape on
    // the far side of a unit (or on a shelf behind it).
    for (const Unit &u : m_units) {
        const float x = rowX(u.row);
        const QVector3D boxes[3][2] = {
            {{x - 4, 0, u.zBack}, {x + 4, 205, u.zFront}},                          // pegboard spine
            {{x - HalfDepth, 0, u.zBack - 4}, {x + HalfDepth, 210, u.zBack + 1}},    // end panels
            {{x - HalfDepth, 0, u.zFront - 1}, {x + HalfDepth, 210, u.zFront + 4}},
        };
        for (const auto &b : boxes) {
            const float t = rayBox(origin, dir, b[0], b[1], bestT);
            if (t >= 0 && t < bestT)
                bestT = t;
        }
    }
    const QVector3D standing(TapeD / 2 + 1.0f, TapeH / 2, TapeW / 2);
    for (int i = 0; i < m_tapes.size(); ++i) {
        QVector3D half = standing;
        if (m_tapes[i].facing == 0 && !m_tapes[i].lying) // facing the front (wall rack)
            half = QVector3D(TapeW / 2, TapeH / 2, TapeD / 2 + 1.0f);
        if (m_tapes[i].lying) { // box around the rotated tape
            const float c = std::abs(std::cos(qDegreesToRadians(m_tapes[i].yaw)));
            const float s = std::abs(std::sin(qDegreesToRadians(m_tapes[i].yaw)));
            half = QVector3D(c * TapeW / 2 + s * TapeH / 2, TapeD / 2 + 0.5f, s * TapeW / 2 + c * TapeH / 2);
        }
        const QVector3D lo = m_tapes[i].pos - half, hi = m_tapes[i].pos + half;
        float tMin = 0, tMax = bestT;
        bool hit = true;
        for (int a = 0; a < 3 && hit; ++a) {
            if (std::abs(dir[a]) < 1e-6f) {
                hit = origin[a] >= lo[a] && origin[a] <= hi[a];
                continue;
            }
            float t0 = (lo[a] - origin[a]) / dir[a], t1 = (hi[a] - origin[a]) / dir[a];
            if (t0 > t1)
                std::swap(t0, t1);
            tMin = std::max(tMin, t0);
            tMax = std::min(tMax, t1);
            hit = tMin <= tMax;
        }
        if (hit && tMin < bestT) {
            bestT = tMin;
            best = i;
        }
    }
    return best;
}

int StoreLayout::filmOfTape(int tape) const
{
    return (tape >= 0 && tape < m_tapes.size()) ? m_tapes[tape].film : -1;
}

QVariantMap StoreLayout::tapeInfo(int tape) const
{
    if (tape < 0 || tape >= m_tapes.size())
        return {};
    const Tape &t = m_tapes[tape];
    return {{QStringLiteral("film"), t.film},
            {QStringLiteral("position"), t.pos},
            {QStringLiteral("lying"), t.lying},
            {QStringLiteral("yaw"), t.lying ? double(t.yaw) : t.facing > 0 ? 90.0 : t.facing < 0 ? -90.0 : 0.0}};
}

void StoreLayout::buildStreet()
{
    // A night street of tall buildings: the shop's neighbours on both sides,
    // and a row across the road. Deterministic, so it's the same every visit.
    m_streetHalf = std::max(m_halfWidth + 2600, 4200.0f);
    m_buildings.clear();
    quint32 seed = 1987;
    auto rnd = [&seed](float lo, float hi) {
        seed = seed * 1664525u + 1013904223u;
        return lo + (hi - lo) * float(seed >> 8) / float(1 << 24);
    };
    static const QStringList words = {
        QStringLiteral("NOODLES"), QStringLiteral("ARCADE"), QStringLiteral("HOTEL"),
        QStringLiteral("24H"), QStringLiteral("KARAOKE"), QStringLiteral("RAMEN"),
        QStringLiteral("PACHINKO"), QStringLiteral("BAR"), QStringLiteral("CYBER CAFE"),
        QStringLiteral("SUSHI"), QStringLiteral("PHARMACY"), QStringLiteral("JAZZ"),
        QStringLiteral("LAUNDRY"), QStringLiteral("CLUB"), QStringLiteral("TATTOO"),
        QStringLiteral("REPAIR"),
    };
    static const QStringList neon = {QStringLiteral("#ff2bd6"), QStringLiteral("#2bf6ff"),
                                     QStringLiteral("#ffe02b"), QStringLiteral("#7c4dff"),
                                     QStringLiteral("#ff5a36"), QStringLiteral("#39ff7a")};
    auto add = [&](float x, float z, float w, float d, int facing) {
        const float h = rnd(900, 2800);
        QVariantMap b{{QStringLiteral("x"), x}, {QStringLiteral("z"), z},
                      {QStringLiteral("w"), w}, {QStringLiteral("d"), d},
                      {QStringLiteral("h"), h}, {QStringLiteral("facing"), facing},
                      {QStringLiteral("tint"), rnd(0, 1)}};
        if (rnd(0, 1) < 0.75f) {
            b.insert(QStringLiteral("sign"), words[int(rnd(0, words.size() - 0.01f))]);
            b.insert(QStringLiteral("neon"), neon[int(rnd(0, neon.size() - 0.01f))]);
            b.insert(QStringLiteral("signY"), rnd(350, std::min(h - 200, 1200.0f)));
            b.insert(QStringLiteral("vertical"), rnd(0, 1) < 0.5f);
        }
        m_buildings << b;
    };
    // Neighbours left and right of the shop, fronts in line with the shop front.
    for (int side : {-1, 1}) {
        float x = side * (m_halfWidth + 20);
        while (std::abs(x) < m_streetHalf) {
            const float w = rnd(500, 1000);
            add(x + side * w / 2, m_frontZ - 700, w - 20, 1400, 1);
            x += side * w;
        }
    }
    // Across the road, facing the shop.
    for (float x = -m_streetHalf; x < m_streetHalf;) {
        const float w = rnd(500, 1000);
        add(x + w / 2, m_frontZ + StreetDepth + 700, w - 20, 1400, -1);
        x += w;
    }
}

void StoreLayout::buildWindowPosters()
{
    // Small posters taped inside the shop windows, a little crooked. They're
    // placed pane by pane so none sits across the frames between panes
    // (same pane maths as the shop front in Store3DInterior.qml).
    m_windowPosters.clear();
    quint32 seed = 77;
    auto rnd = [&seed](float lo, float hi) {
        seed = seed * 1664525u + 1013904223u;
        return lo + (hi - lo) * float(seed >> 8) / float(1 << 24);
    };
    const float glassStart = DoorHalf + 30;                  // just past the door pillar
    const float glassLen = (m_halfWidth - DoorHalf) - 60;    // to the side-wall pillar
    const int panes = std::max(1, int(std::lround(glassLen / 260)));
    const float paneW = glassLen / panes;
    const float frame = 6; // half a mullion, plus a little air
    for (int side : {-1, 1}) {
        for (int p = 0; p < panes; ++p) {
            const float left = glassStart + p * paneW + frame, right = glassStart + (p + 1) * paneW - frame;
            // Two posters per pane, one higher than the other.
            for (int k = 0; k < 2; ++k) {
                const bool high = (p + k) % 2 == 0;
                // The OPEN neon hangs high in the first pane right of the door.
                if (side > 0 && p == 0 && high)
                    continue;
                const float w = rnd(40, 50), h = w * 1.5f;
                const float tilt = rnd(-6, 6);
                const float reach = w / 2 + h / 2 * std::abs(std::sin(qDegreesToRadians(tilt))) + 6;
                const float slotLeft = left + (right - left) * k / 2, slotRight = left + (right - left) * (k + 1) / 2;
                if (slotRight - slotLeft < 2 * reach)
                    continue; // pane too narrow for two
                const float x = rnd(slotLeft + reach, slotRight - reach);
                m_windowPosters << QVariantMap{{QStringLiteral("x"), side * x},
                                               {QStringLiteral("y"), high ? rnd(172, 182) : rnd(108, 120)},
                                               {QStringLiteral("w"), w},
                                               {QStringLiteral("h"), h},
                                               {QStringLiteral("tilt"), tilt}};
            }
        }
    }
}

bool StoreLayout::blocked(float x, float z, float r) const
{
    // The shop front: solid except for the door.
    if (std::abs(z - m_frontZ) < WallT + r)
        return std::abs(x) > DoorHalf - r || std::abs(x) > m_halfWidth;
    for (const QVariant &c : m_cars) {
        const QVariantMap car = c.toMap();
        if (std::abs(x - car.value(QStringLiteral("x")).toFloat()) < 225 + r
            && std::abs(z - car.value(QStringLiteral("z")).toFloat()) < 95 + r)
            return true;
    }
    const QVector3D box = dropBox();
    if (std::abs(x - box.x()) < 32 + r && std::abs(z - box.z()) < 28 + r)
        return true; // the return box on the pavement
    if (z > m_frontZ) // outside, on the street
        return std::abs(x) > m_streetHalf - r || z > m_frontZ + StreetDepth - 300 - r;
    if (x < -m_halfWidth + r || x > m_halfWidth - r || z < m_backZ + r)
        return true;
    for (const QRectF &o : m_obstacles) {
        if (x > o.left() - r && x < o.right() + r && z > o.top() - r && z < o.bottom() + r)
            return true;
    }
    return false;
}

QVector3D StoreLayout::collide(const QVector3D &from, const QVector3D &to, float radius) const
{
    if (!blocked(to.x(), to.z(), radius))
        return to;
    if (!blocked(to.x(), from.z(), radius))
        return QVector3D(to.x(), to.y(), from.z());
    if (!blocked(from.x(), to.z(), radius))
        return QVector3D(from.x(), to.y(), to.z());
    return from;
}

QVariantMap StoreLayout::standInFront(float faceX, int facing, float z, float targetY, float distance) const
{
    const double pitch = qRadiansToDegrees(std::atan2(targetY - EyeHeight, distance));
    return {{QStringLiteral("x"), faceX + facing * distance},
            {QStringLiteral("z"), z},
            {QStringLiteral("yaw"), facing > 0 ? 90.0 : -90.0},
            {QStringLiteral("pitch"), pitch}};
}

QVariantMap StoreLayout::viewCategory(int category) const
{
    if (category < 0 || category >= m_categories.size())
        return {};
    const Unit &u = m_units[m_categories[category].firstUnit];
    return standInFront(rowX(u.row) - HalfDepth, -1, (u.zFront + u.zBack) / 2, 110, 170);
}

QVariantMap StoreLayout::viewAisle(const QString &id) const
{
    for (int i = 0; i < m_categories.size(); ++i) {
        if (m_categories[i].id == id)
            return viewCategory(i);
    }
    return {};
}

QVariantMap StoreLayout::viewFilm(int film) const
{
    for (int i = 0; i < m_tapes.size(); ++i) {
        const Tape &t = m_tapes[i];
        if (t.film != film || t.unit < 0)
            continue;
        QVariantMap v = standInFront(rowX(m_units[t.unit].row) + t.facing * HalfDepth, t.facing,
                                     t.pos.z(), t.pos.y(), 95);
        v.insert(QStringLiteral("tape"), i);
        return v;
    }
    return {};
}

QString StoreLayout::aisleAt(float x, float z) const
{
    if (z > m_frontZ)
        return QStringLiteral("Outside · walk through the door");
    // The unit face you're standing in front of.
    int best = -1;
    float bestDist = 260;
    for (int i = 0; i < m_units.size(); ++i) {
        const Unit &u = m_units[i];
        if (z < u.zBack - 40 || z > u.zFront + 40)
            continue;
        const float d = std::abs(x - rowX(u.row)) - HalfDepth;
        if (d < bestDist) {
            bestDist = d;
            best = i;
        }
    }
    if (best >= 0)
        return m_categories[m_units[best].category].title;
    return z > 0 ? QStringLiteral("Front of the store") : QStringLiteral("Shop floor");
}
