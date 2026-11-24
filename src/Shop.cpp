#include "Shop.h"

#include "AisleModel.h"
#include "StoreLayout.h"
#include "ExportLoader.h"
#include "FilmModel.h"
#include "MatchCache.h"
#include "TmdbClient.h"

#include <QDesktopServices>
#include <QFileInfo>
#include <QMap>
#include <QRandomGenerator>
#include <QSettings>
#include <QStandardPaths>

#include <algorithm>

namespace {

QSettings settings()
{
    return QSettings(QStringLiteral("cinefy"), QStringLiteral("cinefy"));
}

QString prettyDate(const QDate &d)
{
    return d.isValid() ? d.toString(QStringLiteral("d MMM yyyy")) : QString();
}

bool byRatingDesc(const Film &a, const Film &b)
{
    if (a.rating != b.rating)
        return a.rating > b.rating;
    return a.lastWatched > b.lastWatched;
}

} // namespace

Shop::Shop(QObject *parent)
    : QObject(parent), m_films(new FilmModel(this)), m_tmdb(new TmdbClient(this))
{
    m_cache = std::make_unique<MatchCache>(
        QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/matches.json"));

    m_search = new AisleModel(
        m_films, QStringLiteral("Search results"), QString(), QStringLiteral("#3df5ff"),
        [](const Film &) { return false; },
        [](const Film &a, const Film &b) { return a.name.compare(b.name, Qt::CaseInsensitive) < 0; },
        90, this);
    m_search->setId(QStringLiteral("search"));
    m_store = new StoreLayout(this);

    auto s = settings();
    m_tmdbKey = s.value(QStringLiteral("tmdbKey")).toString();
    if (m_tmdbKey.isEmpty())
        m_tmdbKey = qEnvironmentVariable("TMDB_API_KEY");
    m_lastExport = s.value(QStringLiteral("lastExport")).toString();
    m_tmdb->setApiKey(m_tmdbKey);

    connect(m_tmdb, &TmdbClient::matched, this, &Shop::onMatched);
    connect(m_tmdb, &TmdbClient::progressChanged, this, &Shop::stockChanged);
    connect(m_tmdb, &TmdbClient::idle, this, &Shop::onStockIdle);
    connect(m_tmdb, &TmdbClient::failed, this, &Shop::setTmdbError);
    connect(m_tmdb, &TmdbClient::candidatesFound, this, &Shop::candidatesReady);

    // Coalesce wallpaper updates while matches stream in.
    m_wallpaperTimer.setSingleShot(true);
    m_wallpaperTimer.setInterval(2000);
    connect(&m_wallpaperTimer, &QTimer::timeout, this, &Shop::rebuildWallpapers);
}

Shop::~Shop()
{
    m_cache->save();
}

void Shop::setTmdbKey(const QString &key)
{
    const QString k = key.trimmed();
    if (k == m_tmdbKey)
        return;
    m_tmdbKey = k;
    settings().setValue(QStringLiteral("tmdbKey"), k);
    m_tmdb->setApiKey(k);
    setTmdbError({});
    emit tmdbKeyChanged();
    if (m_loaded)
        restock();
}

bool Shop::stocking() const { return m_tmdb->busy(); }
int Shop::stockDone() const { return m_tmdb->done(); }
int Shop::stockTotal() const { return m_tmdb->total(); }
QObject *Shop::searchAisle() const { return m_search; }
QObject *Shop::store() const { return m_store; }
QObject *Shop::films() const { return m_films; }

void Shop::rebuildStore()
{
    QList<AisleModel *> aisles;
    for (QObject *o : std::as_const(m_aisles))
        aisles << static_cast<AisleModel *>(o);

    // Handwritten shelf cards for 5-star and reviewed films.
    QSet<int> picks;
    const auto &films = m_films->films();
    for (int i = 0; i < films.size(); ++i) {
        if (films[i].rating >= 5 || !films[i].reviews.isEmpty())
            picks.insert(i);
    }
    // The night drop: your ten latest watches.
    struct Watch {
        QDate date;
        int film;
    };
    QVector<Watch> watches;
    for (int i = 0; i < films.size(); ++i) {
        if (films[i].lastWatched.isValid())
            watches.push_back({films[i].lastWatched, i});
    }
    std::stable_sort(watches.begin(), watches.end(), [](const Watch &a, const Watch &b) { return a.date > b.date; });
    QList<int> recent;
    for (const Watch &w : watches.mid(0, 400))
        recent << w.film;

    m_store->setAisles(aisles, picks, recent);
}

int Shop::recommend() const
{
    QVector<int> pool;
    const auto &films = m_films->films();
    for (int i = 0; i < films.size(); ++i) {
        if (films[i].inWatchlist && !films[i].watched)
            pool << i;
    }
    return pool.isEmpty() ? -1 : pool.at(QRandomGenerator::global()->bounded(int(pool.size())));
}

QVariantList Shop::findFilms(const QString &query, int limit) const
{
    const QString q = query.trimmed();
    QVariantList out;
    if (q.isEmpty())
        return out;
    const auto &films = m_films->films();
    // Titles starting with the query first, then titles containing it.
    for (int pass = 0; pass < 2 && out.size() < limit; ++pass) {
        for (int i = 0; i < films.size() && out.size() < limit; ++i) {
            const Film &f = films[i];
            const bool starts = f.name.startsWith(q, Qt::CaseInsensitive);
            const bool match = pass == 0 ? starts
                                         : !starts && (f.name.contains(q, Qt::CaseInsensitive)
                                                       || f.tmdb.originalTitle.contains(q, Qt::CaseInsensitive)
                                                       || QString::number(f.year) == q);
            if (match)
                out << QVariantMap{{QStringLiteral("index"), i},
                                   {QStringLiteral("name"), f.name},
                                   {QStringLiteral("year"), f.year},
                                   {QStringLiteral("poster"), FilmModel::posterUrl(f.tmdb.posterPath, "w92")}};
        }
    }
    return out;
}

void Shop::setSearchQuery(const QString &query)
{
    if (query == m_searchQuery)
        return;
    m_searchQuery = query;
    const QString q = query.trimmed();
    m_search->setFilter([q](const Film &f) {
        return !q.isEmpty()
               && (f.name.contains(q, Qt::CaseInsensitive)
                   || f.tmdb.originalTitle.contains(q, Qt::CaseInsensitive)
                   || QString::number(f.year) == q);
    });
    emit searchQueryChanged();
}

void Shop::loadExport(const QUrl &url)
{
    loadFile(url.isLocalFile() ? url.toLocalFile() : url.toString());
}

void Shop::reopenLast()
{
    if (!m_lastExport.isEmpty() && QFileInfo::exists(m_lastExport))
        loadFile(m_lastExport);
}

bool Shop::loadFile(const QString &path)
{
    Library lib;
    QString err;
    if (!ExportLoader::load(path, lib, &err)) {
        setError(err);
        return false;
    }
    setError({});
    setTmdbError({});
    m_tmdb->cancelAll();

    for (Film &f : lib.films) {
        if (m_cache->contains(f.key()))
            f.tmdb = m_cache->value(f.key());
    }
    m_films->reset(std::move(lib.films));
    lib.films.clear();
    m_library = std::move(lib);

    if (m_lastExport != path) {
        m_lastExport = path;
        settings().setValue(QStringLiteral("lastExport"), path);
        emit lastExportChanged();
    }

    m_search->rebuild();
    rebuildAisles();
    rebuildMember();
    rebuildWallpapers();
    if (!m_loaded) {
        m_loaded = true;
        emit loadedChanged();
    }
    restock();
    return true;
}

void Shop::eject()
{
    m_tmdb->cancelAll();
    m_cache->save();
    if (m_loaded) {
        m_loaded = false;
        emit loadedChanged();
    }
}

void Shop::restock()
{
    m_tmdb->cancelAll();
    if (!m_tmdb->hasKey())
        return;
    const auto &films = m_films->films();
    for (int i = 0; i < films.size(); ++i) {
        if (!films[i].tmdb.searched)
            m_tmdb->enqueue(i, films[i].name, films[i].year);
    }
}

void Shop::onMatched(int index, const TmdbMatch &match)
{
    if (index < 0 || index >= m_films->rowCount())
        return;
    m_cache->insert(m_films->film(index).key(), match);
    m_films->setMatch(index, match);
    if (++m_matchedSinceSave >= 50) {
        m_cache->save();
        m_matchedSinceSave = 0;
    }
    if (!m_wallpaperTimer.isActive())
        m_wallpaperTimer.start();
}

void Shop::onStockIdle()
{
    m_cache->save();
    m_matchedSinceSave = 0;
    rebuildAisles(); // genre aisles depend on TMDB data
    rebuildMember();
    rebuildWallpapers();
    emit stockChanged();
}

void Shop::setError(const QString &error)
{
    if (error != m_error) {
        m_error = error;
        emit errorChanged();
    }
}

void Shop::setTmdbError(const QString &error)
{
    if (error != m_tmdbError) {
        m_tmdbError = error;
        emit tmdbErrorChanged();
    }
}

void Shop::rebuildAisles()
{
    const QList<QObject *> old = m_aisles;
    m_aisles.clear();
    auto add = [this](AisleModel *aisle) {
        if (aisle->count() > 0)
            m_aisles << aisle;
        else
            aisle->deleteLater();
    };
    auto aisle = [this](const QString &id, const QString &title, const QString &subtitle,
                        const QString &accent, AisleModel::Filter filter, AisleModel::Less less,
                        int limit = 0) {
        auto *a = new AisleModel(m_films, title, subtitle, accent, std::move(filter), std::move(less),
                                 limit, this);
        a->setId(id);
        return a;
    };

    add(aisle(QStringLiteral("most"), QStringLiteral("Most Rented"), QStringLiteral("The films you keep coming back to"),
              QStringLiteral("#ffb300"), [](const Film &f) { return f.watchCount() >= 2; },
              [](const Film &a, const Film &b) {
                  if (a.watchCount() != b.watchCount())
                      return a.watchCount() > b.watchCount();
                  return byRatingDesc(a, b);
              }, 40));
    add(aisle(QStringLiteral("picks"), QStringLiteral("Staff Picks"), QStringLiteral("Hand-picked by the manager"),
              QStringLiteral("#ffd21f"),
              [](const Film &f) { return f.favourite || f.rating >= 4.5; },
              [](const Film &a, const Film &b) {
                  if (a.favourite != b.favourite)
                      return a.favourite;
                  return byRatingDesc(a, b);
              }));
    add(aisle(QStringLiteral("liked"), QStringLiteral("Liked Films"),
              QStringLiteral("Every film you gave a heart"), QStringLiteral("#ff5c8a"),
              [](const Film &f) { return f.liked; },
              [](const Film &a, const Film &b) {
                  return a.name.compare(b.name, Qt::CaseInsensitive) < 0;
              }));
    add(aisle(QStringLiteral("new"), QStringLiteral("New Releases"), QStringLiteral("Just returned to the counter"),
              QStringLiteral("#ff3d9a"),
              [](const Film &f) { return f.watched && f.lastWatched.isValid(); },
              [](const Film &a, const Film &b) { return a.lastWatched > b.lastWatched; }, 40));
    add(aisle(QStringLiteral("watchlist"), QStringLiteral("Coming Soon"), QStringLiteral("Your watchlist"),
              QStringLiteral("#3df5ff"), [](const Film &f) { return f.inWatchlist; },
              [](const Film &a, const Film &b) { return a.watchlistedOn > b.watchlistedOn; }));

    add(aisle(QStringLiteral("tv"), QStringLiteral("Box Sets"), QStringLiteral("TV series you logged"),
              QStringLiteral("#7ee081"), [](const Film &f) { return f.tmdb.isTv; },
              [](const Film &a, const Film &b) { return a.lastWatched > b.lastWatched; }));

    for (const FilmList &list : m_library.lists) {
        const QString subtitle = list.description.section(u'\n', 0, 0).left(80);
        add(new AisleModel(m_films, list.name,
                           subtitle.isEmpty() ? QStringLiteral("A staff list") : subtitle,
                           QStringLiteral("#b98cff"), list.films, this));
    }

    QMap<QString, int> genreCounts;
    for (const Film &f : m_films->films()) {
        if (!f.watched)
            continue;
        for (const QString &g : f.genres())
            ++genreCounts[g];
    }
    QList<QPair<int, QString>> genres;
    for (auto it = genreCounts.cbegin(); it != genreCounts.cend(); ++it) {
        if (it.value() >= 5 && it.key() != QLatin1String("TV Movie"))
            genres << qMakePair(it.value(), it.key());
    }
    std::sort(genres.begin(), genres.end(),
              [](const auto &a, const auto &b) { return a.first > b.first; });
    for (const auto &g : genres) {
        const QString genre = g.second;
        // Signs need to read on a dark board, so brighten the darker genre colours.
        QColor accent = FilmModel::genreColor(genre);
        if (accent.lightness() < 140)
            accent = accent.lighter(170);
        add(aisle(QStringLiteral("genre:") + genre, genre, QStringLiteral("%1 tapes").arg(g.first),
                  accent.name(),
                  [genre](const Film &f) { return f.watched && f.genres().contains(genre); },
                  byRatingDesc));
    }

    add(aisle(QStringLiteral("classics"), QStringLiteral("Cult Classics"), QStringLiteral("Released before 1980"),
              QStringLiteral("#f08a24"),
              [](const Film &f) { return f.watched && f.year > 0 && f.year < 1980; },
              [](const Film &a, const Film &b) { return a.year < b.year; }));
    add(aisle(QStringLiteral("bargain"), QStringLiteral("Bargain Bin"), QStringLiteral("Rated two stars or less"),
              QStringLiteral("#e6332a"),
              [](const Film &f) { return f.rating > 0 && f.rating <= 2; },
              [](const Film &a, const Film &b) { return a.rating < b.rating; }));
    add(aisle(QStringLiteral("all"), QStringLiteral("Every Tape A–Z"), QStringLiteral("The whole back catalogue"),
              QStringLiteral("#9aa3c0"), [](const Film &f) { return f.watched; },
              [](const Film &a, const Film &b) {
                  return a.name.compare(b.name, Qt::CaseInsensitive) < 0;
              }));

    rebuildStore();
    emit aislesChanged();
    for (QObject *o : old)
        o->deleteLater();
}

void Shop::rebuildMember()
{
    const auto &films = m_films->films();
    int watched = 0, rated = 0, liked = 0, watchlist = 0, reviews = 0, diary = 0;
    double ratingSum = 0;
    QVariantList histogram;
    QVector<int> hist(10, 0);
    QMap<int, int> diaryYears, decades;
    QMap<QString, int> genres;
    QVariantList favourites;

    for (int i = 0; i < films.size(); ++i) {
        const Film &f = films[i];
        watched += f.watched;
        liked += f.liked;
        watchlist += f.inWatchlist;
        reviews += int(f.reviews.size());
        diary += int(f.diary.size());
        if (f.rating > 0) {
            ++rated;
            ratingSum += f.rating;
            hist[qBound(0, int(f.rating * 2) - 1, 9)]++;
        }
        for (const auto &d : f.diary)
            if (d.watched.isValid())
                ++diaryYears[d.watched.year()];
        if (f.watched && f.year > 0)
            ++decades[f.year / 10 * 10];
        if (f.watched)
            for (const auto &g : f.genres())
                ++genres[g];
        if (f.favourite)
            favourites << i;
    }
    for (int c : hist)
        histogram << c;

    // Your most watched films of all time.
    QVector<int> order;
    for (int i = 0; i < films.size(); ++i) {
        if (films[i].watchCount() >= 2)
            order << i;
    }
    std::stable_sort(order.begin(), order.end(), [&](int a, int b) {
        if (films[a].watchCount() != films[b].watchCount())
            return films[a].watchCount() > films[b].watchCount();
        return byRatingDesc(films[a], films[b]);
    });
    // Window posters: your favourites, then a mix of films you loved, but not
    // the top-10 most watched (those already hang in the hall of fame).
    m_windowPosters.clear();
    const QVector<int> hallOfFame = order.mid(0, 10);
    auto addPoster = [this, &films, &hallOfFame](int i) {
        const QString url = FilmModel::posterUrl(films[i].tmdb.posterPath, "w185");
        if (!url.isEmpty() && !hallOfFame.contains(i) && !m_windowPosters.contains(url) && m_windowPosters.size() < 24)
            m_windowPosters << url;
    };
    for (const QVariant &f : favourites)
        addPoster(f.toInt());
    QVector<int> loved;
    for (int i = 0; i < films.size(); ++i) {
        if (films[i].rating >= 4.5 || (films[i].liked && films[i].rating >= 4))
            loved << i;
    }
    // A stable shuffle, so the windows look the same every visit.
    std::sort(loved.begin(), loved.end(), [&films](int a, int b) {
        return qHash(films[a].name) < qHash(films[b].name);
    });
    for (int i : loved)
        addPoster(i);

    // "Coming soon" corkboard: the films you added to your watchlist most recently.
    {
        QVector<int> wl;
        for (int i = 0; i < films.size(); ++i)
            if (films[i].inWatchlist && !films[i].tmdb.posterPath.isEmpty())
                wl << i;
        std::stable_sort(wl.begin(), wl.end(), [&films](int a, int b) { return films[a].watchlistedOn > films[b].watchlistedOn; });
        m_comingSoon.clear();
        for (int i : wl.mid(0, 12))
            m_comingSoon << FilmModel::posterUrl(films[i].tmdb.posterPath, "w185");
    }

    m_mostWatched.clear();
    for (int i : order.mid(0, 10))
        m_mostWatched << QVariantMap{{QStringLiteral("index"), i},
                                     {QStringLiteral("name"), films[i].name},
                                     {QStringLiteral("year"), films[i].year},
                                     {QStringLiteral("count"), films[i].watchCount()},
                                     {QStringLiteral("rating"), films[i].rating},
                                     {QStringLiteral("poster"), FilmModel::posterUrl(films[i].tmdb.posterPath, "w342")}};

    auto topKey = [](const auto &map) {
        auto best = map.cbegin();
        for (auto it = map.cbegin(); it != map.cend(); ++it)
            if (it.value() > best.value())
                best = it;
        return best == map.cend() ? QVariant() : QVariant::fromValue(best.key());
    };

    QString name = (m_library.givenName + u' ' + m_library.familyName).trimmed();
    if (name.isEmpty())
        name = m_library.username;

    m_member = {
        {QStringLiteral("name"), name},
        {QStringLiteral("username"), m_library.username},
        {QStringLiteral("location"), m_library.location},
        {QStringLiteral("since"), prettyDate(m_library.joined)},
        {QStringLiteral("memberNo"), QStringLiteral("%1").arg(qHash(m_library.username) % 1000000, 6, 10, QChar(u'0'))},
        {QStringLiteral("watched"), watched},
        {QStringLiteral("rated"), rated},
        {QStringLiteral("liked"), liked},
        {QStringLiteral("watchlist"), watchlist},
        {QStringLiteral("reviews"), reviews},
        {QStringLiteral("diary"), diary},
        {QStringLiteral("average"), rated ? ratingSum / rated : 0.0},
        {QStringLiteral("histogram"), histogram},
        {QStringLiteral("busiestYear"), topKey(diaryYears)},
        {QStringLiteral("topDecade"), topKey(decades)},
        {QStringLiteral("topGenre"), topKey(genres)},
        {QStringLiteral("favourites"), favourites},
    };
    emit memberChanged();
}

void Shop::rebuildWallpapers()
{
    // Backdrops of the films you love most, in a shuffled rotation.
    QStringList best, rest;
    for (const Film &f : m_films->films()) {
        if (f.tmdb.backdropPath.isEmpty())
            continue;
        const QString url = FilmModel::backdropUrl(f.tmdb.backdropPath);
        if (f.favourite || f.rating >= 4.5 || (f.liked && f.rating >= 4))
            best << url;
        else if (f.watched && f.rating >= 3.5)
            rest << url;
    }
    if (best.size() < 8)
        best << rest;
    std::shuffle(best.begin(), best.end(), *QRandomGenerator::global());
    if (best.size() > 40)
        best.resize(40);
    if (best != m_wallpapers) {
        m_wallpapers = best;
        emit wallpapersChanged();
    }
}

QVariantMap Shop::film(int index) const
{
    if (index < 0 || index >= m_films->rowCount())
        return {};
    const Film &f = m_films->film(index);

    QVariantList diary;
    for (const auto &d : f.diary)
        diary << QVariantMap{{QStringLiteral("date"), prettyDate(d.watched)},
                             {QStringLiteral("rating"), d.rating},
                             {QStringLiteral("rewatch"), d.rewatch},
                             {QStringLiteral("tags"), d.tags}};
    QVariantList reviews;
    for (const auto &r : f.reviews)
        reviews << QVariantMap{{QStringLiteral("date"), prettyDate(r.watched)},
                               {QStringLiteral("rating"), r.rating},
                               {QStringLiteral("text"), r.text}};

    return {
        {QStringLiteral("index"), index},
        {QStringLiteral("name"), f.name},
        {QStringLiteral("year"), f.year},
        {QStringLiteral("uri"), f.uri},
        {QStringLiteral("rating"), f.rating},
        {QStringLiteral("liked"), f.liked},
        {QStringLiteral("watched"), f.watched},
        {QStringLiteral("inWatchlist"), f.inWatchlist},
        {QStringLiteral("favourite"), f.favourite},
        {QStringLiteral("rewatches"), f.rewatches()},
        {QStringLiteral("watchCount"), f.watchCount()},
        {QStringLiteral("watchedOn"), prettyDate(f.lastWatched)},
        {QStringLiteral("watchlistedOn"), prettyDate(f.watchlistedOn)},
        {QStringLiteral("poster"), FilmModel::posterUrl(f.tmdb.posterPath, "w500")},
        {QStringLiteral("backdrop"), FilmModel::backdropUrl(f.tmdb.backdropPath)},
        {QStringLiteral("overview"), f.tmdb.overview},
        {QStringLiteral("originalTitle"), f.tmdb.originalTitle},
        {QStringLiteral("genres"), f.genres()},
        {QStringLiteral("spineColor"), FilmModel::spineColor(f)},
        {QStringLiteral("matched"), f.tmdb.found},
        {QStringLiteral("isTv"), f.tmdb.isTv},
        {QStringLiteral("diary"), diary},
        {QStringLiteral("reviews"), reviews},
        {QStringLiteral("lists"), f.lists},
    };
}

QVariantList Shop::diary() const
{
    struct Entry {
        QDate date;
        int film;
        const DiaryEntry *entry;
    };
    QVector<Entry> entries;
    const auto &films = m_films->films();
    for (int i = 0; i < films.size(); ++i) {
        for (const auto &d : films[i].diary)
            entries.push_back({d.watched, i, &d});
    }
    std::stable_sort(entries.begin(), entries.end(),
                     [](const Entry &a, const Entry &b) { return a.date > b.date; });

    QVariantList out;
    out.reserve(entries.size());
    for (const Entry &e : entries) {
        const Film &f = films[e.film];
        out << QVariantMap{
            {QStringLiteral("index"), e.film},
            {QStringLiteral("name"), f.name},
            {QStringLiteral("year"), f.year},
            {QStringLiteral("month"), e.date.isValid() ? e.date.toString(QStringLiteral("MMMM yyyy")) : QStringLiteral("Undated")},
            {QStringLiteral("ym"), e.date.isValid() ? e.date.toString(QStringLiteral("yyyy-MM")) : QString()},
            {QStringLiteral("yearNum"), e.date.year()},
            {QStringLiteral("monthNum"), e.date.month()},
            {QStringLiteral("dayNum"), e.date.day()},
            {QStringLiteral("weekday"), e.date.isValid() ? e.date.toString(QStringLiteral("ddd")) : QString()},
            {QStringLiteral("day"), e.date.isValid() ? e.date.toString(QStringLiteral("ddd d")) : QString()},
            {QStringLiteral("rating"), e.entry->rating},
            {QStringLiteral("rewatch"), e.entry->rewatch},
            {QStringLiteral("liked"), f.liked},
            {QStringLiteral("isTv"), f.tmdb.isTv},
            {QStringLiteral("genres"), f.genres()},
            {QStringLiteral("weekdayNum"), e.date.isValid() ? e.date.dayOfWeek() : 0},
            {QStringLiteral("julian"), e.date.isValid() ? e.date.toJulianDay() : 0},
            {QStringLiteral("poster"), FilmModel::posterUrl(f.tmdb.posterPath, "w92")},
        };
    }
    return out;
}

void Shop::findCandidates(int index, const QString &query)
{
    if (m_tmdb->hasKey())
        m_tmdb->searchCandidates(index, query);
    else
        emit candidatesReady(index, {});
}

void Shop::pinMatch(int index, const QVariantMap &c)
{
    if (index < 0 || index >= m_films->rowCount())
        return;
    TmdbMatch m;
    m.searched = m.found = m.pinned = true;
    m.isTv = c.value(QStringLiteral("tv")).toBool();
    m.id = c.value(QStringLiteral("id")).toInt();
    m.posterPath = c.value(QStringLiteral("poster")).toString();
    m.backdropPath = c.value(QStringLiteral("backdrop")).toString();
    m.overview = c.value(QStringLiteral("overview")).toString();
    m.releaseDate = c.value(QStringLiteral("date")).toString();
    m.originalTitle = c.value(QStringLiteral("original")).toString();
    m.voteAverage = c.value(QStringLiteral("vote")).toDouble();
    m.voteCount = c.value(QStringLiteral("votes")).toInt();
    for (const QVariant &g : c.value(QStringLiteral("genres")).toList())
        m.genreIds << g.toInt();
    m_cache->insert(m_films->film(index).key(), m);
    m_cache->save();
    m_films->setMatch(index, m);
    rebuildAisles();
    rebuildMember();
    rebuildWallpapers();
}

QVariant Shop::pref(const QString &key, const QVariant &fallback) const
{
    return settings().value(QStringLiteral("prefs/") + key, fallback);
}

void Shop::setPref(const QString &key, const QVariant &value)
{
    settings().setValue(QStringLiteral("prefs/") + key, value);
}

void Shop::openOnLetterboxd(int index) const
{
    if (index < 0 || index >= m_films->rowCount())
        return;
    const Film &f = m_films->film(index);
    if (!f.uri.isEmpty())
        QDesktopServices::openUrl(QUrl(f.uri));
    else
        QDesktopServices::openUrl(QUrl(QStringLiteral("https://letterboxd.com/search/films/")
                                       + QString::fromLatin1(QUrl::toPercentEncoding(f.name))));
}
