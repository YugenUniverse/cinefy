#include "MatchCache.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>

namespace {
constexpr int FormatVersion = 7; // 5: best match over all searches; 6-7: accents, alternative titles
}

MatchCache::MatchCache(QString path) : m_path(std::move(path))
{
    load();
}

void MatchCache::insert(const QString &key, const TmdbMatch &match)
{
    if (!match.searched)
        return;
    m_map.insert(key, match);
    m_dirty = true;
}

void MatchCache::load()
{
    QFile file(m_path);
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
    for (auto it = root.begin(); it != root.end(); ++it) {
        const QJsonObject o = it.value().toObject();
        // Entries from before TV series were searched get looked up again.
        // Older automatic matches are redone; ones you picked by hand are kept.
        const bool pinned = o.value(QLatin1String("pin")).toBool();
        const int version = o.value(QLatin1String("v")).toInt();
        const bool found = o.value(QLatin1String("found")).toBool();
        // v5 matches are good; only titles v5 couldn't find are searched again.
        if (!pinned && (version < 5 || (version < FormatVersion && !found)))
            continue;
        TmdbMatch m;
        m.searched = true;
        m.found = o.value(QLatin1String("found")).toBool();
        m.isTv = o.value(QLatin1String("tv")).toBool();
        m.pinned = pinned;
        m.voteCount = o.value(QLatin1String("votes")).toInt();
        m.id = o.value(QLatin1String("id")).toInt();
        m.posterPath = o.value(QLatin1String("poster")).toString();
        m.backdropPath = o.value(QLatin1String("backdrop")).toString();
        m.overview = o.value(QLatin1String("overview")).toString();
        m.releaseDate = o.value(QLatin1String("date")).toString();
        m.originalTitle = o.value(QLatin1String("original")).toString();
        m.voteAverage = o.value(QLatin1String("vote")).toDouble();
        for (const auto &g : o.value(QLatin1String("genres")).toArray())
            m.genreIds << g.toInt();
        m_map.insert(it.key(), m);
    }
}

void MatchCache::save()
{
    if (!m_dirty)
        return;
    QJsonObject root;
    for (auto it = m_map.cbegin(); it != m_map.cend(); ++it) {
        const TmdbMatch &m = it.value();
        QJsonObject o{{QStringLiteral("v"), FormatVersion}, {QStringLiteral("found"), m.found}};
        if (m.found) {
            QJsonArray genres;
            for (int g : m.genreIds)
                genres << g;
            o.insert(QStringLiteral("id"), m.id);
            o.insert(QStringLiteral("tv"), m.isTv);
            o.insert(QStringLiteral("votes"), m.voteCount);
            if (m.pinned)
                o.insert(QStringLiteral("pin"), true);
            o.insert(QStringLiteral("poster"), m.posterPath);
            o.insert(QStringLiteral("backdrop"), m.backdropPath);
            o.insert(QStringLiteral("overview"), m.overview);
            o.insert(QStringLiteral("date"), m.releaseDate);
            o.insert(QStringLiteral("original"), m.originalTitle);
            o.insert(QStringLiteral("vote"), m.voteAverage);
            o.insert(QStringLiteral("genres"), genres);
        }
        root.insert(it.key(), o);
    }
    QDir().mkpath(QFileInfo(m_path).absolutePath());
    QSaveFile file(m_path);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
        if (file.commit())
            m_dirty = false;
    }
}
