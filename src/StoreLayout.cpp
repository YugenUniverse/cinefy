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

float StoreLayout::wallLevel(int shelf)
{
    return 202.0f - 34.0f * float(std::clamp(shelf, 0, WallShelves - 1));
}

namespace {
// The two big aisles that go on the side walls.
bool onWall(const QString &id)
{
    return id == QLatin1String("all") || id == QLatin1String("watchlist");
}
} // namespace

void StoreLayout::setAisles(const QList<AisleModel *> &aisles, const QSet<int> &staffPicks,
                            const QList<int> &recent)
{
    m_categories.clear();
    m_units.clear();
    m_tapes.clear();
    m_talkers.clear();

    // 1. Cut every aisle into sides of units. A side holds `perShelf` tapes
    // on each of its five shelves; units are as long as their fuller side,
    // so shelves come out full instead of half empty.
    struct Side {
        int cat = -1;
        QVector<int> films;
    };
    struct Pending {
        Side a, b;
        bool firstA = false, firstB = false;
    };
    QVector<Pending> pending;  // gondolas, in order
    QVector<int> wallCats;     // categories for the side walls
    QVector<QVector<int>> wallFilms;
    int lonely = -1;           // index in `pending` of a unit with one free side
    for (AisleModel *a : aisles) {
        const QVector<int> rows = a->sourceRows();
        if (rows.isEmpty())
            continue;
        const int cat = int(m_categories.size());
        m_categories.push_back({a->id(), a->title(), a->subtitle(), a->accent(), int(rows.size()), 0, -1});
        if (onWall(a->id()) && wallCats.size() < 2) {
            // The whole catalogue goes on the left (the longer free wall).
            const bool first = a->id() == QLatin1String("all");
            wallCats.insert(first ? 0 : wallCats.size(), cat);
            wallFilms.insert(first ? 0 : wallFilms.size(), rows);
            continue;
        }
        if (rows.size() <= SmallAisle) {
            // One side of a unit; share the unit with the next small aisle.
            if (lonely >= 0) {
                pending[lonely].b = {cat, rows};
                pending[lonely].firstB = true;
                lonely = -1;
            } else {
                Pending p;
                p.a = {cat, rows};
                p.firstA = true;
                pending << p;
                lonely = int(pending.size()) - 1;
            }
            continue;
        }
        const int perUnitMax = 2 * Shelves * MaxPerShelf;
        const int unitCount = int(qCeil(rows.size() / double(perUnitMax)));
        const int perUnit = int(qCeil(rows.size() / double(unitCount)));
        for (int u = 0; u < unitCount; ++u) {
            const QVector<int> films = rows.mid(u * perUnit, perUnit);
            const int half = int(qCeil(films.size() / 2.0));
            Pending p;
            p.a = {cat, films.mid(0, half)};
            p.b = {cat, films.mid(half)};
            p.firstA = p.firstB = u == 0;
            pending << p;
        }
    }
    // A small aisle left on its own: spread it over both sides.
    if (lonely >= 0) {
        Pending &p = pending[lonely];
        const QVector<int> films = p.a.films;
        const int half = int(qCeil(films.size() / 2.0));
        p.a.films = films.mid(0, half);
        p.b = {p.a.cat, films.mid(half)};
        p.firstB = true;
    }

    // 2. Place the units in rows, front to back.
    int row = 0;
    float cursor = 0; // distance from the front of the current row
    float longest = MinPerShelf * Pitch;
    QVector<QPair<int, Side>> sides; // (unit, side) to stock, facing = sign below
    QVector<int> sideFacing;
    int prevA = -2, prevB = -2;
    for (const Pending &p : std::as_const(pending)) {
        const int need = std::max(qCeil(p.a.films.size() / double(Shelves)),
                                  qCeil(p.b.films.size() / double(Shelves)));
        const int perShelf = std::clamp(need, MinPerShelf, MaxPerShelf);
        const float length = perShelf * Pitch + 8; // a little room at the ends
        const bool sameAisle = p.a.cat == prevA && p.b.cat == prevB;
        float gap = cursor > 0 ? (sameAisle ? UnitGap : CategoryGap) : 0;
        if (cursor > 0 && cursor + gap + length > RowMaxLength) {
            ++row;
            cursor = 0;
            gap = 0;
        }
        Unit unit;
        unit.catA = p.a.cat;
        unit.catB = p.b.cat;
        unit.row = row;
        unit.zFront = -(cursor + gap);
        unit.zBack = -(cursor + gap + length);
        unit.perShelf = perShelf;
        unit.firstA = p.firstA;
        unit.firstB = p.firstB;
        cursor += gap + length;
        longest = std::max(longest, cursor);
        const int index = int(m_units.size());
        m_units.push_back(unit);
        sides.push_back({index, p.a});
        sideFacing << -1;
        sides.push_back({index, p.b});
        sideFacing << 1;
        prevA = p.a.cat;
        prevB = p.b.cat;
    }
    m_rows = std::max(1, row + 1);
    for (Unit &u : m_units)
        u.x = rowX(u.row);

    // 3. Stock the gondolas: shelf by shelf from the top; a side that isn't
    // full keeps its tapes around eye level, and a part-filled last shelf
    // is centred. Shelves are angled: tapes lean back against the unit.
    for (int k = 0; k < sides.size(); ++k) {
        const Unit &u = m_units[sides[k].first];
        const QVector<int> &films = sides[k].second.films;
        const int facing = sideFacing[k];
        const int count = int(films.size());
        const int perRow = u.perShelf;
        const int shelvesUsed = std::min(Shelves, int(qCeil(count / double(perRow))));
        const int firstShelf = (Shelves - shelvesUsed) / 2;
        for (int j = 0; j < count; ++j) {
            Tape t;
            t.film = films[j];
            t.facing = facing;
            t.unit = sides[k].first;
            const int line = j / perRow;
            t.shelf = std::min(Shelves - 1, firstShelf + line);
            const int onLine = std::min(perRow, count - line * perRow);
            const float slot = (perRow - onLine) / 2.0f + j % perRow + 0.5f;
            const float span = u.zFront - u.zBack;
            const float z0 = (span - perRow * Pitch) / 2;
            const float z = facing < 0 ? u.zBack + z0 + slot * Pitch : u.zFront - z0 - slot * Pitch;
            // Leaning back on the stepped wire shelf, its foot against the lip.
            t.lean = -17.0f;
            t.pos = QVector3D(u.x + facing * (stepFront(t.shelf) - 7.5f), shelfLevel(t.shelf) + TapeH / 2 + 0.6f, z);
            m_tapes.push_back(t);
        }
    }
    // Where each aisle starts: its first unit, and which side of it.
    {
        QVector<bool> found(m_categories.size(), false);
        for (int i = 0; i < m_units.size(); ++i) {
            for (int facing : {-1, 1}) {
                const int c = m_units[i].category(facing);
                if (c >= 0 && !found[c]) {
                    found[c] = true;
                    m_categories[c].firstUnit = i;
                    m_categories[c].firstFacing = facing;
                }
            }
        }
    }

    m_halfWidth = (m_rows - 1) * RowSpacing / 2 + HalfDepth + SideAisle;
    m_backZ = -longest - BackAisle;
    m_frontZ = FrontArea;

    // 4. The side walls: the whole back catalogue on the left, reading from
    // the front of the shop backwards; the watchlist on the right, from the
    // back corner up to before the candy rack. 1 m bays, filled top to bottom.
    {
        const int perBay = BayWidth * WallShelves;
        auto lengthFor = [perBay](int n) { return float(qCeil(n / double(perBay)) * BayWidth) * Pitch; };
        const float leftFront = m_frontZ - 150, rightLimit = m_frontZ - 820;
        if (!wallCats.isEmpty())
            m_backZ = std::min(m_backZ, leftFront - lengthFor(int(wallFilms[0].size())) - 60);
        if (wallCats.size() > 1)
            m_backZ = std::min(m_backZ, rightLimit - lengthFor(int(wallFilms[1].size())) - 150);
        for (int w = 0; w < wallCats.size(); ++w) {
            const int side = w == 0 ? -1 : 1; // which wall
            const int facing = -side;
            const QVector<int> &films = wallFilms[w];
            const float len = lengthFor(int(films.size()));
            Unit u;
            u.wall = side;
            u.row = -1;
            u.x = side * m_halfWidth;
            if (side < 0) {
                u.zFront = leftFront;
                u.zBack = leftFront - len;
            } else {
                u.zBack = m_backZ + 150;
                u.zFront = u.zBack + len;
            }
            u.perShelf = int(len / Pitch);
            (facing < 0 ? u.catA : u.catB) = wallCats[w];
            (facing < 0 ? u.firstA : u.firstB) = true;
            const int index = int(m_units.size());
            m_units.push_back(u);
            m_categories[wallCats[w]].firstUnit = index;
            m_categories[wallCats[w]].firstFacing = facing;
            const float lift = (WallDepth - 14.0f - 22.0f) * std::tan(qDegreesToRadians(ShelfTilt));
            for (int j = 0; j < films.size(); ++j) {
                Tape t;
                t.film = films[j];
                t.facing = facing;
                t.unit = index;
                const int bay = j / perBay, k = j % perBay;
                t.shelf = k / BayWidth;
                const float slot = bay * BayWidth + k % BayWidth + 0.5f;
                // Reading order: left to right as you face the wall.
                const float z = side < 0 ? u.zFront - slot * Pitch : u.zBack + slot * Pitch;
                t.lean = -11.0f;
                t.pos = QVector3D(u.x + facing * (WallDepth - 15.5f), wallLevel(t.shelf) + TapeH / 2 + 0.6f + lift, z);
                m_tapes.push_back(t);
            }
        }
    }

    // 5. Handwritten cards under staff picks (first copy of each film only).
    QSet<int> carded;
    for (const Tape &t : std::as_const(m_tapes)) {
        if (t.unit < 0 || !staffPicks.contains(t.film) || carded.contains(t.film) || m_talkers.size() >= 60)
            continue;
        const Unit &u = m_units[t.unit];
        carded.insert(t.film);
        const float level = u.wall ? wallLevel(t.shelf) : shelfLevel(t.shelf);
        const float front = u.wall ? u.depth() : stepFront(t.shelf);
        m_talkers << QVariantMap{
            {QStringLiteral("film"), t.film},
            {QStringLiteral("position"), QVector3D(u.x + t.facing * (front + 1.2f), level - 8, t.pos.z())},
            {QStringLiteral("yaw"), t.facing > 0 ? 90.0 : -90.0},
        };
    }

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
    for (const Unit &u : std::as_const(m_units)) {
        if (u.wall) // against the wall, sticking out WallDepth
            m_obstacles << QRectF(u.wall < 0 ? u.x : u.x - WallDepth - 4, u.zBack - 4, WallDepth + 4, unitLength(u) + 8);
        else
            m_obstacles << QRectF(u.x - HalfDepth - 4, u.zBack - 6, 2 * HalfDepth + 8, unitLength(u) + 12);
    }

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
        s += QStringLiteral(";%1,%2,%3,%4").arg(u.x).arg(u.zFront).arg(u.zBack).arg(u.wall);
    return QString::number(qHash(s), 16);
}

QVariantList StoreLayout::gondolas() const
{
    QVariantList out;
    for (const Unit &u : m_units) {
        if (u.wall)
            continue;
        out << QVariantMap{{QStringLiteral("x"), u.x},
                           {QStringLiteral("z"), (u.zFront + u.zBack) / 2},
                           {QStringLiteral("length"), unitLength(u)}};
    }
    return out;
}

QVariantList StoreLayout::wallRacks() const
{
    QVariantList out;
    for (const Unit &u : m_units) {
        if (!u.wall)
            continue;
        const int facing = -u.wall;
        const Category &c = m_categories[u.category(facing)];
        out << QVariantMap{{QStringLiteral("x"), u.x},
                           {QStringLiteral("side"), u.wall},
                           {QStringLiteral("z0"), u.zBack},
                           {QStringLiteral("z1"), u.zFront},
                           {QStringLiteral("bays"), int(std::lround(unitLength(u) / (BayWidth * Pitch)))},
                           {QStringLiteral("depth"), WallDepth},
                           {QStringLiteral("title"), c.title},
                           {QStringLiteral("accent"), c.accent}};
    }
    return out;
}

QVariantList StoreLayout::signs() const
{
    QVariantList out;
    for (const Unit &u : m_units) {
        if (u.wall)
            continue;
        for (int facing : {-1, 1}) {
            if (u.category(facing) < 0)
                continue;
            const Category &c = m_categories[u.category(facing)];
            out << QVariantMap{
                {QStringLiteral("x"), u.x + facing * 5.5f}, // on top of the spine
                {QStringLiteral("z"), (u.zFront + u.zBack) / 2},
                {QStringLiteral("yaw"), facing > 0 ? 90.0 : -90.0},
                {QStringLiteral("width"), unitLength(u) - 8},
                {QStringLiteral("title"), c.title},
                {QStringLiteral("accent"), c.accent},
                {QStringLiteral("first"), u.first(facing)},
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
        if (u.wall)
            continue;
        for (int end : {1, -1}) {
            // A shared unit: each end names one of its two aisles.
            const int ci = u.category(end > 0 ? -1 : 1) >= 0 ? u.category(end > 0 ? -1 : 1) : u.category(end > 0 ? 1 : -1);
            const Category &c = m_categories[ci];
            out << QVariantMap{{QStringLiteral("x"), u.x},
                               {QStringLiteral("z"), end > 0 ? u.zFront + 2.5f : u.zBack - 2.5f},
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
        QVariantList units; // the sides of units it's on, as plan rectangles
        for (const Unit &u : m_units) {
            for (int facing : {-1, 1}) {
                if (u.category(facing) != i)
                    continue;
                const float a = u.x, b = u.x + facing * u.depth();
                units << QVariantMap{{QStringLiteral("x0"), std::min(a, b)},
                                     {QStringLiteral("x1"), std::max(a, b)},
                                     {QStringLiteral("z0"), u.zBack},
                                     {QStringLiteral("z1"), u.zFront}};
            }
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
        const float x = u.x;
        if (u.wall) { // the rack's back panel and end panels
            const float inner = x - u.wall * WallDepth;
            const QVector3D boxes[3][2] = {
                {{std::min(x, x - u.wall * 6), 0, u.zBack}, {std::max(x, x - u.wall * 6), 240, u.zFront}},
                {{std::min(x, inner), 0, u.zBack - 4}, {std::max(x, inner), 240, u.zBack + 1}},
                {{std::min(x, inner), 0, u.zFront - 1}, {std::max(x, inner), 240, u.zFront + 4}},
            };
            for (const auto &b : boxes) {
                const float t = rayBox(origin, dir, b[0], b[1], bestT);
                if (t >= 0 && t < bestT)
                    bestT = t;
            }
            continue;
        }
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
        else if (m_tapes[i].lean < -14) // leaning well back: deeper box
            half = QVector3D(5.5f, TapeH / 2, TapeW / 2);
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
    const Category &c = m_categories[category];
    if (c.firstUnit < 0 || c.firstUnit >= m_units.size())
        return {};
    const Unit &u = m_units[c.firstUnit];
    const int facing = c.firstFacing;
    // A long wall rack: stand at its start, where the A's are.
    const float z = u.wall < 0 ? u.zFront - 100 : u.wall > 0 ? u.zBack + 100 : (u.zFront + u.zBack) / 2;
    return standInFront(u.x + facing * u.depth(), facing, z, 110, 170);
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
        const Unit &u = m_units[t.unit];
        QVariantMap v = standInFront(u.x + t.facing * u.depth(), t.facing,
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
    int best = -1, bestFacing = -1;
    float bestDist = 260;
    for (int i = 0; i < m_units.size(); ++i) {
        const Unit &u = m_units[i];
        if (z < u.zBack - 40 || z > u.zFront + 40)
            continue;
        const int facing = u.wall ? -u.wall : (x < u.x ? -1 : 1);
        if (u.category(facing) < 0 || (u.wall && (x - u.x) * facing < 0))
            continue;
        const float d = std::abs(x - u.x) - u.depth();
        if (d < bestDist) {
            bestDist = d;
            best = i;
            bestFacing = facing;
        }
    }
    if (best >= 0)
        return m_categories[m_units[best].category(bestFacing)].title;
    return z > 0 ? QStringLiteral("Front of the store") : QStringLiteral("Shop floor");
}
