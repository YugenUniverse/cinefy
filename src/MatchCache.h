#pragma once

#include "Film.h"

#include <QHash>
#include <QString>

// Remembers TMDB answers per film ("name|year") in a JSON file so every film is
// only looked up once, and the shop opens offline afterwards.
class MatchCache
{
public:
    explicit MatchCache(QString path);

    bool contains(const QString &key) const { return m_map.contains(key); }
    TmdbMatch value(const QString &key) const { return m_map.value(key); }
    void insert(const QString &key, const TmdbMatch &match);
    void save();

private:
    void load();

    QString m_path;
    QHash<QString, TmdbMatch> m_map;
    bool m_dirty = false;
};
