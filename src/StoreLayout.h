#pragma once

#include <QObject>
#include <QRectF>
#include <QSet>
#include <QVariantList>
#include <QVector3D>
#include <QVector>

class AisleModel;

// Where everything stands in the 3D store (units are centimetres, Y up).
//
// Every aisle (category) gets double-sided shelving units sized to its films,
// so the shelves are full; a small aisle takes one side of a unit and shares
// it with another. Units stand in rows along Z, with a walk-through gap
// between units and a wider gap between categories. Two big aisles (the whole
// back catalogue and the watchlist) go on tall racks along the side walls.
// Tapes stand face-out, leaning back on angled shelves. The store grows to
// fit the library.
class StoreLayout : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(QVariantList gondolas READ gondolas NOTIFY changed)
    Q_PROPERTY(QVariantList signs READ signs NOTIFY changed)
    Q_PROPERTY(QVariantList endSigns READ endSigns NOTIFY changed)
    Q_PROPERTY(QVariantList categories READ categories NOTIFY changed)
    Q_PROPERTY(QVariantList talkers READ talkers NOTIFY changed)
    Q_PROPERTY(float halfWidth READ halfWidth NOTIFY changed)
    Q_PROPERTY(float frontZ READ frontZ NOTIFY changed)
    Q_PROPERTY(float backZ READ backZ NOTIFY changed)
    Q_PROPERTY(QVector3D counter READ counter NOTIFY changed)
    Q_PROPERTY(QVector3D clerk READ clerk NOTIFY changed)
    Q_PROPERTY(QVector3D candyRack READ candyRack NOTIFY changed)
    Q_PROPERTY(QVector3D returnBin READ returnBin NOTIFY changed)
    Q_PROPERTY(QVector3D dropBox READ dropBox NOTIFY changed)
    Q_PROPERTY(QVariantMap wallRack READ wallRack NOTIFY changed) // {x0, x1, z}
    Q_PROPERTY(QVariantList wallRacks READ wallRacks NOTIFY changed) // side-wall racks
    Q_PROPERTY(QVariantList cars READ cars NOTIFY changed)
    Q_PROPERTY(QVector3D entrance READ entrance NOTIFY changed)
    Q_PROPERTY(float eyeHeight READ eyeHeight CONSTANT)
    Q_PROPERTY(float doorHalfWidth READ doorHalfWidth CONSTANT)
    Q_PROPERTY(float streetHalfWidth READ streetHalfWidth NOTIFY changed)
    Q_PROPERTY(float streetEndZ READ streetEndZ NOTIFY changed)
    Q_PROPERTY(QVariantList buildings READ buildings NOTIFY changed)
    Q_PROPERTY(QVariantList windowPosters READ windowPosters NOTIFY changed)
    Q_PROPERTY(QString signature READ signature NOTIFY changed) // changes when the room/shelves change

public:
    // Shared dimensions (cm).
    // A big-box rental case, in cm (shelves are 34 cm apart, so it still fits).
    static constexpr float TapeW = 14.5f, TapeH = 24.0f, TapeD = 3.8f, Pitch = 16.8f;
    static constexpr int Shelves = 5;
    static constexpr int MinPerShelf = 6, MaxPerShelf = 30; // a unit is 1 to ~5 m long
    static constexpr int SmallAisle = Shelves * 12;          // fits on one side of a unit
    static constexpr int WallShelves = 6, BayWidth = 6;      // wall racks: 6 high, 1 m bays
    static constexpr float WallDepth = 44.0f;
    static constexpr float ShelfTilt = 8.0f;                 // degrees, front edge up
    static constexpr float HalfDepth = 46.0f;       // units are 92 cm deep at the floor
    static constexpr float RowSpacing = 380.0f;     // between rows of units
    static constexpr float UnitGap = 110.0f;        // between units of one aisle
    static constexpr float CategoryGap = 230.0f;    // between aisles
    static constexpr float RowMaxLength = 2300.0f;
    static constexpr float SideAisle = 360.0f, BackAisle = 360.0f, FrontArea = 1050.0f;
    static constexpr float EyeHeight = 162.0f;
    static constexpr float WallT = 14.0f, DoorHalf = 90.0f, StreetDepth = 2400.0f;
    static float shelfLevel(int shelf); // top surface of shelf 0 (highest) .. 4
    static float wallLevel(int shelf);  // wall racks: shelf 0 (highest) .. 5
    // Units step out like a staircase: each lower wire shelf reaches further
    // out. Distance of shelf `shelf`'s front lip from the unit's centre line.
    static float stepFront(int shelf) { return 22.0f + 6.0f * float(shelf); }

    struct Tape {
        int film;
        QVector3D pos;
        int facing; // +1: cover faces +X, -1: faces -X (0 for tapes lying flat)
        int unit;   // -1: not on a shelf (the night drop)
        int shelf;
        bool lying = false; // lying flat, cover up
        float yaw = 0;      // for tapes lying flat
        float lean = 0;     // how far it leans back, degrees (0: a slight random lean)
    };

    explicit StoreLayout(QObject *parent = nullptr);

    // `staffPicks`: films that get a handwritten card on the shelf.
    // `recent`: your latest watches, newest first (a stack of the first ten
    // on the counter; as many as fit, one copy each, on the back wall rack).
    void setAisles(const QList<AisleModel *> &aisles, const QSet<int> &staffPicks = {},
                   const QList<int> &recent = {});
    const QVector<Tape> &tapes() const { return m_tapes; }

    int revision() const { return m_revision; }
    QVariantList gondolas() const;
    QVariantList signs() const;
    QVariantList endSigns() const;
    QVariantList categories() const;
    QVariantList talkers() const { return m_talkers; }
    float halfWidth() const { return m_halfWidth; }
    float frontZ() const { return m_frontZ; }
    float backZ() const { return m_backZ; }
    QVector3D counter() const { return m_counter; }
    QVector3D clerk() const { return m_counter + QVector3D(95, 0, 25); } // behind the counter
    QVector3D candyRack() const { return m_candyRack; }
    QVector3D returnBin() const { return m_returnBin; }
    // the blue tape-return box out on the pavement
    QVariantMap wallRack() const { return m_wallRack; }
    QVariantList wallRacks() const;
    QVariantList cars() const { return m_cars; }
    QVector3D dropBox() const { return QVector3D(DoorHalf + 300, 0, m_frontZ + 130); }
    QVector3D entrance() const { return m_entrance; }
    float eyeHeight() const { return EyeHeight; }
    float doorHalfWidth() const { return DoorHalf; }
    float streetHalfWidth() const { return m_streetHalf; }
    float streetEndZ() const { return m_frontZ + StreetDepth; }
    QVariantList buildings() const { return m_buildings; }
    QVariantList windowPosters() const { return m_windowPosters; }
    QString signature() const;

    // Nearest tape hit by a ray, or -1.
    Q_INVOKABLE int pick(const QVector3D &origin, const QVector3D &direction, float maxDistance) const;
    Q_INVOKABLE int filmOfTape(int tape) const;
    Q_INVOKABLE QVariantMap tapeInfo(int tape) const;
    // Move from -> to, sliding along shelves and walls instead of passing through.
    Q_INVOKABLE QVector3D collide(const QVector3D &from, const QVector3D &to, float radius) const;
    // Where to stand to look at an aisle / a film: {x, z, yaw, pitch, tape}.
    Q_INVOKABLE QVariantMap viewAisle(const QString &id) const;
    Q_INVOKABLE QVariantMap viewCategory(int category) const;
    Q_INVOKABLE QVariantMap viewFilm(int film) const;
    // Name of the aisle you're standing in.
    Q_INVOKABLE QString aisleAt(float x, float z) const;

signals:
    void changed();

private:
    struct Category {
        QString id, title, subtitle, accent;
        int count = 0;
        int firstUnit = 0;
        int firstFacing = -1; // which side of that unit
    };
    // A double-sided gondola (wall == 0), or a one-sided rack against a side
    // wall (wall -1: left wall, tapes face +X; +1: right wall, face -X).
    struct Unit {
        int catA = -1, catB = -1; // the -X side, the +X side (-1: empty)
        int row = 0;
        float zFront = 0, zBack = 0;
        int perShelf = MinPerShelf;
        bool firstA = false, firstB = false; // first unit of that side's category
        int wall = 0;
        float x = 0;
        int category(int facing) const { return facing < 0 ? catA : catB; }
        bool first(int facing) const { return facing < 0 ? firstA : firstB; }
        float depth() const { return wall ? WallDepth : HalfDepth; }
    };

    float rowX(int row) const;
    float unitLength(const Unit &u) const { return u.zFront - u.zBack; }
    QVariantMap standInFront(float faceX, int facing, float z, float targetY, float distance) const;
    bool blocked(float x, float z, float radius) const;
    void buildFrontOfStore();
    void buildStreet();

    QVector<Category> m_categories;
    QVector<Unit> m_units;
    QVector<Tape> m_tapes;
    QVector<QRectF> m_obstacles; // furniture footprints (x, z)
    QVariantList m_talkers, m_buildings, m_windowPosters, m_cars;
    QVariantMap m_wallRack;
    void buildWindowPosters();
    int m_rows = 1;
    float m_halfWidth = 600, m_frontZ = 1000, m_backZ = -1000, m_streetHalf = 4000;
    QVector3D m_counter, m_candyRack, m_returnBin, m_entrance;
    int m_revision = 0;
};
