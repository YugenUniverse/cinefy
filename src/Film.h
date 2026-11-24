#pragma once

#include <QDate>
#include <QList>
#include <QString>
#include <QStringList>
#include <QVector>

struct DiaryEntry {
    QDate watched;
    double rating = 0;
    bool rewatch = false;
    QString tags;
};

struct FilmReview {
    QDate watched;
    double rating = 0;
    QString text;
};

// What TMDB told us about a film. `searched` means we have a definitive answer
// (found or not); network failures leave it false so we retry next time.
struct TmdbMatch {
    bool searched = false;
    bool found = false;
    bool isTv = false; // Letterboxd lists some TV series as films
    int id = 0;
    QString posterPath;
    QString backdropPath;
    QString overview;
    QString releaseDate;
    QString originalTitle;
    QList<int> genreIds;
    double voteAverage = 0;
    int voteCount = 0;
    bool pinned = false; // chosen by hand: never re-matched automatically
};

struct Film {
    QString name;
    int year = 0;
    QString uri; // film-level boxd.it link (diary/review URIs point at entries, not films)

    double rating = 0; // 0 = unrated, otherwise 0.5..5
    bool liked = false;
    bool watched = false;
    bool inWatchlist = false;
    bool favourite = false;

    QDate watchedOn;     // when it was marked watched
    QDate watchlistedOn; // when it was added to the watchlist
    QDate lastWatched;   // latest diary date, falls back to watchedOn

    QVector<DiaryEntry> diary;
    QVector<FilmReview> reviews;
    QStringList lists;

    TmdbMatch tmdb;

    QString key() const { return keyFor(name, year); }
    static QString keyFor(const QString &name, int year);
    int rewatches() const;
    // How many times you've seen it: diary entries, plus one if the first
    // logged watch was already a rewatch.
    int watchCount() const;
    QStringList genres() const;
};

struct FilmList {
    QString name;
    QString description;
    QVector<int> films; // indices into Library::films, in list order
};

struct Library {
    QString username;
    QString givenName;
    QString familyName;
    QString location;
    QDate joined;
    QVector<Film> films;
    QVector<FilmList> lists;
};

// TMDB's fixed movie genre ids.
QString tmdbGenreName(int id);
