#pragma once

#include "Film.h"

#include <QNetworkAccessManager>
#include <QObject>
#include <QQueue>
#include <QVariantList>

class QJsonArray;
class QNetworkReply;

// Looks films up on TMDB by title + year, a few requests at a time. Letterboxd
// also lists TV series (miniseries mostly) as films, so TMDB's TV search is
// tried when no film matches exactly. Accepts a v3 API key or a v4 read token.
class TmdbClient : public QObject
{
    Q_OBJECT
public:
    explicit TmdbClient(QObject *parent = nullptr);

    void setApiKey(const QString &key) { m_key = key.trimmed(); }
    bool hasKey() const { return !m_key.isEmpty(); }

    void enqueue(int filmIndex, const QString &title, int year);
    void cancelAll();
    // For fixing a match by hand: films and series matching `query`.
    void searchCandidates(int filmIndex, const QString &query);
    bool busy() const { return m_done < m_total; } // only the current batch counts
    int done() const { return m_done; }
    int total() const { return m_total; }

signals:
    void matched(int filmIndex, const TmdbMatch &match);
    void progressChanged();
    void failed(const QString &message);
    void idle();
    void candidatesFound(int filmIndex, const QVariantList &candidates);

private:
    // Search steps, tried in order until one gives a good answer.
    enum Step {
        MovieExactYear, // films released in that year
        TvExactYear,    // series that first aired that year
        MovieAnyYear,   // films with any release in that year
        MovieNoYear,
        TvNoYear,
        TvSeriesName,   // "Show: Episode" / "Show 5: Finale" -> "Show"
    };
    struct Job {
        int filmIndex = -1;
        QString title;
        QString query; // what is sent to TMDB; the series name in the last step
        int year = 0;
        Step step = MovieExactYear;
        // Best candidate over all the searches so far.
        TmdbMatch best;
        double bestScore = -1;
        bool bestAcceptable = false;
        quint64 generation = 0;
    };
    struct Candidate {
        TmdbMatch match;
        double score = -1;
        bool acceptable = false; // good enough to use if nothing better turns up
        bool confident = false;  // so clearly right we can stop searching
    };

    void pump();
    QNetworkRequest request(bool tv, QString query) const;
    void start(const Job &job);
    void finish(QNetworkReply *reply, Job job);
    void accept(const Job &job, TmdbMatch match);
    void next(Job job);
    void complete();
    static Candidate pickBest(const QJsonArray &results, const Job &job);
    static TmdbMatch matchFrom(const QJsonObject &o, bool tv);
    static bool isTvStep(Step s) { return s == TvExactYear || s == TvNoYear || s == TvSeriesName; }
    static QString seriesName(const QString &title);

    QNetworkAccessManager m_nam;
    QString m_key;
    QQueue<Job> m_queue;
    int m_inFlight = 0;
    int m_done = 0;
    int m_total = 0;
    quint64 m_generation = 0;
    bool m_reportedNetworkError = false;
    // TMDB allows about 50 requests a second, and its API speaks HTTP/2, so
    // many searches share one connection; 24 at a time stays under the limit.
    static constexpr int MaxInFlight = 24;
};
