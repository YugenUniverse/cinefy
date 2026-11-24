#include "ExportLoader.h"

#include "Csv.h"

#include <QFileInfo>
#include <QHash>

#include <QtCore/private/qzipreader_p.h>

#include <algorithm>

namespace {

constexpr qint64 MaxEntrySize = 64ll * 1024 * 1024;

// Read every CSV in the export with Qt's built-in zip reader (works the same
// on Linux, Windows and macOS; no extra library to install).
QHash<QString, QByteArray> readCsvEntries(const QString &path, QString *error)
{
    QHash<QString, QByteArray> files;
    if (!QFileInfo::exists(path)) {
        *error = QStringLiteral("Could not open the archive: no such file.");
        return files;
    }
    QZipReader zip(path);
    if (!zip.isReadable() || zip.status() != QZipReader::NoError) {
        *error = QStringLiteral("Could not open the archive: it isn't a readable zip file.");
        return files;
    }
    for (const QZipReader::FileInfo &info : zip.fileInfoList()) {
        if (!info.isFile || info.size > MaxEntrySize
            || !info.filePath.endsWith(QLatin1String(".csv"), Qt::CaseInsensitive))
            continue;
        files.insert(info.filePath, zip.fileData(info.filePath));
    }
    return files;
}

QDate isoDate(const QString &s)
{
    return QDate::fromString(s.trimmed(), Qt::ISODate);
}

// Letterboxd uses film URIs in watched/ratings/likes/watchlist/lists, but
// per-entry URIs in diary/reviews, so we key by URI when we have a film URI
// and fall back to "name|year" otherwise.
class Merger
{
public:
    explicit Merger(Library &lib) : m_lib(lib) {}

    Film &film(const QString &name, const QString &year, const QString &filmUri = {})
    {
        if (!filmUri.isEmpty()) {
            auto it = m_byUri.constFind(filmUri);
            if (it != m_byUri.cend())
                return m_lib.films[*it];
        }
        const int y = year.trimmed().toInt();
        const QString key = Film::keyFor(name, y);
        int idx;
        auto it = m_byKey.constFind(key);
        if (it != m_byKey.cend()) {
            idx = *it;
        } else {
            Film f;
            f.name = name.trimmed();
            f.year = y;
            idx = int(m_lib.films.size());
            m_lib.films.push_back(f);
            m_byKey.insert(key, idx);
        }
        if (!filmUri.isEmpty()) {
            if (m_lib.films[idx].uri.isEmpty())
                m_lib.films[idx].uri = filmUri;
            m_byUri.insert(filmUri, idx);
        }
        return m_lib.films[idx];
    }

    int indexOf(const Film &f) const { return int(&f - m_lib.films.constData()); }
    int indexOfUri(const QString &uri) const { return m_byUri.value(uri, -1); }

private:
    Library &m_lib;
    QHash<QString, int> m_byUri;
    QHash<QString, int> m_byKey;
};

Csv::Table table(const QHash<QString, QByteArray> &files, const QString &name)
{
    return Csv::Table::fromRecords(Csv::parse(QString::fromUtf8(files.value(name))));
}

void readList(const QString &fileName, const QByteArray &data, Library &lib, Merger &merger)
{
    const auto records = Csv::parse(QString::fromUtf8(data));
    FilmList list;
    // Row 0: "Letterboxd list export vN", row 1: header, row 2: list metadata.
    if (records.size() > 2) {
        const auto meta = Csv::Table::fromRecords(records, 1);
        if (!meta.rows.isEmpty()) {
            list.name = meta.value(meta.rows.first(), QStringLiteral("Name"));
            list.description = meta.value(meta.rows.first(), QStringLiteral("Description"));
        }
    }
    if (list.name.isEmpty())
        list.name = QFileInfo(fileName).completeBaseName();

    int filmsHeader = -1;
    for (int i = 0; i < records.size(); ++i) {
        if (!records[i].isEmpty() && records[i].first() == QLatin1String("Position")) {
            filmsHeader = i;
            break;
        }
    }
    if (filmsHeader < 0)
        return;

    const auto films = Csv::Table::fromRecords(records, filmsHeader);
    for (const auto &row : films.rows) {
        Film &f = merger.film(films.value(row, QStringLiteral("Name")),
                              films.value(row, QStringLiteral("Year")),
                              films.value(row, QStringLiteral("URL")));
        if (!f.lists.contains(list.name))
            f.lists << list.name;
        list.films << merger.indexOf(f);
    }
    lib.lists << list;
}

} // namespace

namespace ExportLoader {

bool load(const QString &zipPath, Library &out, QString *error)
{
    QString err;
    const auto files = readCsvEntries(zipPath, &err);
    if (files.isEmpty()) {
        if (error)
            *error = err.isEmpty() ? QStringLiteral("That archive contains no CSV files.") : err;
        return false;
    }
    if (!files.contains(QStringLiteral("watched.csv")) && !files.contains(QStringLiteral("profile.csv"))) {
        if (error)
            *error = QStringLiteral("This doesn't look like a Letterboxd export "
                                    "(no watched.csv or profile.csv inside).");
        return false;
    }

    Library lib;
    Merger merger(lib);
    const QString N = QStringLiteral("Name"), Y = QStringLiteral("Year"),
                  U = QStringLiteral("Letterboxd URI"), D = QStringLiteral("Date"),
                  R = QStringLiteral("Rating");

    {
        const auto t = table(files, QStringLiteral("watched.csv"));
        for (const auto &row : t.rows) {
            Film &f = merger.film(t.value(row, N), t.value(row, Y), t.value(row, U));
            f.watched = true;
            f.watchedOn = isoDate(t.value(row, D));
        }
    }
    {
        const auto t = table(files, QStringLiteral("ratings.csv"));
        for (const auto &row : t.rows)
            merger.film(t.value(row, N), t.value(row, Y), t.value(row, U)).rating =
                t.value(row, R).toDouble();
    }
    {
        const auto t = table(files, QStringLiteral("watchlist.csv"));
        for (const auto &row : t.rows) {
            Film &f = merger.film(t.value(row, N), t.value(row, Y), t.value(row, U));
            f.inWatchlist = true;
            f.watchlistedOn = isoDate(t.value(row, D));
        }
    }
    {
        const auto t = table(files, QStringLiteral("likes/films.csv"));
        for (const auto &row : t.rows)
            merger.film(t.value(row, N), t.value(row, Y), t.value(row, U)).liked = true;
    }
    {
        const auto t = table(files, QStringLiteral("diary.csv"));
        for (const auto &row : t.rows) {
            Film &f = merger.film(t.value(row, N), t.value(row, Y));
            DiaryEntry d;
            d.watched = isoDate(t.value(row, QStringLiteral("Watched Date")));
            if (!d.watched.isValid())
                d.watched = isoDate(t.value(row, D));
            d.rating = t.value(row, R).toDouble();
            d.rewatch = t.value(row, QStringLiteral("Rewatch")) == QLatin1String("Yes");
            d.tags = t.value(row, QStringLiteral("Tags"));
            f.diary << d;
            f.watched = true;
            if (d.watched > f.lastWatched)
                f.lastWatched = d.watched;
            if (f.rating == 0 && d.rating > 0)
                f.rating = d.rating;
        }
    }
    {
        const auto t = table(files, QStringLiteral("reviews.csv"));
        for (const auto &row : t.rows) {
            Film &f = merger.film(t.value(row, N), t.value(row, Y));
            FilmReview r;
            r.watched = isoDate(t.value(row, QStringLiteral("Watched Date")));
            if (!r.watched.isValid())
                r.watched = isoDate(t.value(row, D));
            r.rating = t.value(row, R).toDouble();
            r.text = t.value(row, QStringLiteral("Review"));
            f.reviews << r;
        }
    }

    QStringList listFiles;
    for (auto it = files.cbegin(); it != files.cend(); ++it) {
        if (it.key().startsWith(QLatin1String("lists/")))
            listFiles << it.key();
    }
    listFiles.sort();
    for (const auto &name : listFiles)
        readList(name, files.value(name), lib, merger);

    {
        const auto t = table(files, QStringLiteral("profile.csv"));
        if (!t.rows.isEmpty()) {
            const auto &row = t.rows.first();
            lib.username = t.value(row, QStringLiteral("Username"));
            lib.givenName = t.value(row, QStringLiteral("Given Name"));
            lib.familyName = t.value(row, QStringLiteral("Family Name"));
            lib.location = t.value(row, QStringLiteral("Location"));
            lib.joined = isoDate(t.value(row, QStringLiteral("Date Joined")));
            const auto favs = t.value(row, QStringLiteral("Favorite Films")).split(u',', Qt::SkipEmptyParts);
            for (const auto &uri : favs) {
                const int idx = merger.indexOfUri(uri.trimmed());
                if (idx >= 0)
                    lib.films[idx].favourite = true;
            }
        }
    }

    for (Film &f : lib.films) {
        if (!f.lastWatched.isValid() && f.watched)
            f.lastWatched = f.watchedOn;
        std::sort(f.diary.begin(), f.diary.end(),
                  [](const DiaryEntry &a, const DiaryEntry &b) { return a.watched > b.watched; });
    }

    out = std::move(lib);
    return true;
}

} // namespace ExportLoader
