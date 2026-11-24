#pragma once

#include "Film.h"

#include <QAbstractListModel>
#include <QColor>

// Every film in the library. Aisles are filtered views over this model.
class FilmModel : public QAbstractListModel
{
    Q_OBJECT
public:
    enum Role {
        IndexRole = Qt::UserRole + 1,
        NameRole,
        YearRole,
        RatingRole,
        LikedRole,
        WatchedRole,
        WatchlistRole,
        FavouriteRole,
        RewatchesRole,
        ReviewedRole,
        PosterRole,
        BackdropRole,
        GenresRole,
        SpineColorRole,
        SearchedRole,
        MatchedRole,
        TvRole,
    };
    Q_ENUM(Role)

    using QAbstractListModel::QAbstractListModel;

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void reset(QVector<Film> films);
    const QVector<Film> &films() const { return m_films; }
    const Film &film(int row) const { return m_films[row]; }
    void setMatch(int row, const TmdbMatch &match);

    static QString posterUrl(const QString &path, const char *size = "w342");
    static QString backdropUrl(const QString &path, const char *size = "w1280");
    static QColor spineColor(const Film &f);
    static QColor genreColor(const QString &genre);

private:
    QVector<Film> m_films;
};
