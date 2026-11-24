#include "Film.h"

#include <QHash>

QString Film::keyFor(const QString &name, int year)
{
    return name.trimmed().toLower() + u'|' + QString::number(year);
}

int Film::rewatches() const
{
    int count = 0;
    for (const auto &d : diary)
        count += d.rewatch ? 1 : 0;
    return count;
}

int Film::watchCount() const
{
    if (diary.isEmpty())
        return watched ? 1 : 0;
    // The diary is sorted newest first; the last entry is the first logged watch.
    return int(diary.size()) + (diary.last().rewatch ? 1 : 0);
}

QStringList Film::genres() const
{
    QStringList out;
    for (int id : tmdb.genreIds) {
        const QString name = tmdbGenreName(id);
        if (!name.isEmpty())
            out << name;
    }
    return out;
}

QString tmdbGenreName(int id)
{
    static const QHash<int, QString> names = {
        {28, QStringLiteral("Action")},       {12, QStringLiteral("Adventure")},
        {16, QStringLiteral("Animation")},    {35, QStringLiteral("Comedy")},
        {80, QStringLiteral("Crime")},        {99, QStringLiteral("Documentary")},
        {18, QStringLiteral("Drama")},        {10751, QStringLiteral("Family")},
        {14, QStringLiteral("Fantasy")},      {36, QStringLiteral("History")},
        {27, QStringLiteral("Horror")},       {10402, QStringLiteral("Music")},
        {9648, QStringLiteral("Mystery")},    {10749, QStringLiteral("Romance")},
        {878, QStringLiteral("Sci-Fi")},      {10770, QStringLiteral("TV Movie")},
        {53, QStringLiteral("Thriller")},     {10752, QStringLiteral("War")},
        {37, QStringLiteral("Western")},
        // TV genre ids, folded into the movie names where they overlap.
        {10759, QStringLiteral("Action")},    {10762, QStringLiteral("Family")},
        {10763, QStringLiteral("News")},      {10764, QStringLiteral("Reality")},
        {10765, QStringLiteral("Sci-Fi")},    {10766, QStringLiteral("Soap")},
        {10767, QStringLiteral("Talk")},      {10768, QStringLiteral("War")},
    };
    return names.value(id);
}
