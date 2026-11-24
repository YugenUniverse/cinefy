#include "FilmModel.h"

#include <QHash>

int FilmModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_films.size());
}

QVariant FilmModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_films.size())
        return {};
    const Film &f = m_films[index.row()];
    switch (role) {
    case Qt::DisplayRole:
    case NameRole: return f.name;
    case IndexRole: return index.row();
    case YearRole: return f.year;
    case RatingRole: return f.rating;
    case LikedRole: return f.liked;
    case WatchedRole: return f.watched;
    case WatchlistRole: return f.inWatchlist;
    case FavouriteRole: return f.favourite;
    case RewatchesRole: return f.rewatches();
    case ReviewedRole: return !f.reviews.isEmpty();
    case PosterRole: return posterUrl(f.tmdb.posterPath);
    case BackdropRole: return backdropUrl(f.tmdb.backdropPath);
    case GenresRole: return f.genres();
    case SpineColorRole: return spineColor(f);
    case SearchedRole: return f.tmdb.searched;
    case MatchedRole: return f.tmdb.found;
    case TvRole: return f.tmdb.isTv;
    }
    return {};
}

QHash<int, QByteArray> FilmModel::roleNames() const
{
    return {
        {IndexRole, "filmIndex"},   {NameRole, "name"},
        {YearRole, "year"},         {RatingRole, "rating"},
        {LikedRole, "liked"},       {WatchedRole, "watched"},
        {WatchlistRole, "inWatchlist"}, {FavouriteRole, "favourite"},
        {RewatchesRole, "rewatches"}, {ReviewedRole, "reviewed"},
        {PosterRole, "poster"},     {BackdropRole, "backdrop"},
        {GenresRole, "genres"},     {SpineColorRole, "spineColor"},
        {SearchedRole, "searched"}, {MatchedRole, "matched"},
        {TvRole, "isTv"},
    };
}

void FilmModel::reset(QVector<Film> films)
{
    beginResetModel();
    m_films = std::move(films);
    endResetModel();
}

void FilmModel::setMatch(int row, const TmdbMatch &match)
{
    if (row < 0 || row >= m_films.size())
        return;
    m_films[row].tmdb = match;
    const QModelIndex idx = index(row);
    emit dataChanged(idx, idx, {PosterRole, BackdropRole, GenresRole, SpineColorRole,
                                SearchedRole, MatchedRole, TvRole});
}

QString FilmModel::posterUrl(const QString &path, const char *size)
{
    if (path.isEmpty())
        return {};
    return QStringLiteral("https://image.tmdb.org/t/p/") + QLatin1String(size) + path;
}

QString FilmModel::backdropUrl(const QString &path, const char *size)
{
    return posterUrl(path, size);
}

QColor FilmModel::spineColor(const Film &f)
{
    const QStringList genres = f.genres();
    if (!genres.isEmpty())
        return genreColor(genres.first());
    // No genre yet: a stable colour from the title.
    return QColor::fromHsv(int(qHash(f.name) % 360), 150, 190);
}

QColor FilmModel::genreColor(const QString &genre)
{
    static const QHash<QString, QColor> byGenre = {
        {QStringLiteral("Action"), QColor("#e2382c")},
        {QStringLiteral("Adventure"), QColor("#f08a24")},
        {QStringLiteral("Animation"), QColor("#2fb8d8")},
        {QStringLiteral("Comedy"), QColor("#f5c400")},
        {QStringLiteral("Crime"), QColor("#8a1c1c")},
        {QStringLiteral("Documentary"), QColor("#6b8e23")},
        {QStringLiteral("Drama"), QColor("#2f5fd0")},
        {QStringLiteral("Family"), QColor("#ff8fc0")},
        {QStringLiteral("Fantasy"), QColor("#8e44ad")},
        {QStringLiteral("History"), QColor("#a0794a")},
        {QStringLiteral("Horror"), QColor("#5c0b0b")},
        {QStringLiteral("Music"), QColor("#ff3d9a")},
        {QStringLiteral("Mystery"), QColor("#3b4f66")},
        {QStringLiteral("Romance"), QColor("#e8577d")},
        {QStringLiteral("Sci-Fi"), QColor("#14b8a6")},
        {QStringLiteral("Thriller"), QColor("#4b4b6b")},
        {QStringLiteral("War"), QColor("#556b2f")},
        {QStringLiteral("Western"), QColor("#c0763a")},
    };
    return byGenre.value(genre, QColor("#777777"));
}
