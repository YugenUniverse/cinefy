#include "TmdbClient.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QTimer>
#include <QUrl>

#include <cmath>
#include <cstdlib>
#include <memory>

namespace {

// "Spider-Man: No Way Home" and "spider man no way home" compare equal, and
// so do "Nausicaä" and "Nausicaa" however the ä is encoded: accents are
// split off (NFKD) and dropped along with punctuation.
QString normalized(const QString &title)
{
    QString out;
    out.reserve(title.size());
    for (const QChar c : title.toLower().normalized(QString::NormalizationForm_KD)) {
        if (c.isLetterOrNumber())
            out += c;
    }
    return out;
}

} // namespace

TmdbClient::TmdbClient(QObject *parent) : QObject(parent) {}

void TmdbClient::enqueue(int filmIndex, const QString &title, int year)
{
    Job job;
    job.filmIndex = filmIndex;
    job.title = title;
    job.query = title;
    job.year = year;
    job.step = year > 0 ? MovieExactYear : MovieNoYear;
    job.generation = m_generation;
    m_queue.enqueue(job);
    ++m_total;
    emit progressChanged();
    pump();
}

void TmdbClient::cancelAll()
{
    ++m_generation;
    m_queue.clear();
    m_done = m_total = 0;
    m_reportedNetworkError = false;
    emit progressChanged();
}

void TmdbClient::pump()
{
    while (m_inFlight < MaxInFlight && !m_queue.isEmpty())
        start(m_queue.dequeue());
    if (m_inFlight == 0 && m_queue.isEmpty() && m_total > 0)
        emit idle();
}

QNetworkRequest TmdbClient::request(bool tv, QString query) const
{
    // v4 read tokens are JWTs; everything else is treated as a v3 key.
    const bool bearer = m_key.startsWith(QLatin1String("eyJ"));
    if (!bearer)
        query += QStringLiteral("&api_key=") + QString::fromLatin1(QUrl::toPercentEncoding(m_key));
    QUrl url(tv ? QStringLiteral("https://api.themoviedb.org/3/search/tv")
                : QStringLiteral("https://api.themoviedb.org/3/search/movie"));
    url.setQuery(query, QUrl::StrictMode);
    QNetworkRequest req(url);
    req.setRawHeader("Accept", "application/json");
    if (bearer)
        req.setRawHeader("Authorization", "Bearer " + m_key.toUtf8());
    req.setTransferTimeout(15000);
    return req;
}

void TmdbClient::start(const Job &job)
{
    QString query = QStringLiteral("query=") + QString::fromLatin1(QUrl::toPercentEncoding(job.query))
                    + QStringLiteral("&include_adult=false&language=en-US");
    const QString year = QString::number(job.year);
    switch (job.step) {
    case MovieExactYear: query += QStringLiteral("&primary_release_year=") + year; break;
    case TvExactYear: query += QStringLiteral("&first_air_date_year=") + year; break;
    case MovieAnyYear: query += QStringLiteral("&year=") + year; break;
    case MovieNoYear:
    case TvNoYear:
    case TvSeriesName: break;
    }
    ++m_inFlight;
    QNetworkReply *reply = m_nam.get(request(isTvStep(job.step), query));
    connect(reply, &QNetworkReply::finished, this, [this, reply, job] { finish(reply, job); });
}

void TmdbClient::searchCandidates(int filmIndex, const QString &text)
{
    const QString query = QStringLiteral("query=") + QString::fromLatin1(QUrl::toPercentEncoding(text))
                          + QStringLiteral("&include_adult=false&language=en-US");
    struct Pending {
        QVariantList results;
        int waiting = 2;
    };
    auto pending = std::make_shared<Pending>();
    for (bool tv : {false, true}) {
        QNetworkReply *reply = m_nam.get(request(tv, query));
        connect(reply, &QNetworkReply::finished, this, [this, reply, tv, pending, filmIndex] {
            reply->deleteLater();
            const QJsonArray results = QJsonDocument::fromJson(reply->readAll())
                                           .object().value(QLatin1String("results")).toArray();
            for (const auto &value : results) {
                const TmdbMatch m = matchFrom(value.toObject(), tv);
                pending->results << QVariantMap{
                    {QStringLiteral("id"), m.id},
                    {QStringLiteral("tv"), m.isTv},
                    {QStringLiteral("title"), value.toObject().value(QLatin1String(tv ? "name" : "title")).toString()},
                    {QStringLiteral("original"), m.originalTitle},
                    {QStringLiteral("date"), m.releaseDate},
                    {QStringLiteral("year"), m.releaseDate.left(4).toInt()},
                    {QStringLiteral("poster"), m.posterPath},
                    {QStringLiteral("backdrop"), m.backdropPath},
                    {QStringLiteral("overview"), m.overview},
                    {QStringLiteral("vote"), m.voteAverage},
                    {QStringLiteral("votes"), m.voteCount},
                    {QStringLiteral("genres"), QVariant::fromValue(m.genreIds)},
                };
            }
            if (--pending->waiting == 0) {
                // Best known first.
                std::stable_sort(pending->results.begin(), pending->results.end(),
                                 [](const QVariant &a, const QVariant &b) {
                                     return a.toMap().value(QStringLiteral("votes")).toInt()
                                            > b.toMap().value(QStringLiteral("votes")).toInt();
                                 });
                emit candidatesFound(filmIndex, pending->results.mid(0, 24));
            }
        });
    }
}

void TmdbClient::finish(QNetworkReply *reply, Job job)
{
    reply->deleteLater();
    --m_inFlight;
    if (job.generation != m_generation) {
        pump();
        return;
    }

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (status == 401) {
        cancelAll();
        emit failed(QStringLiteral("TMDB rejected the API key. Check it and try again."));
        return;
    }
    if (status == 429) { // rate limited: back off and retry the same step
        ++m_inFlight;    // keep the slot so idle() doesn't fire early
        const int wait = qBound(500, reply->rawHeader("Retry-After").toInt() * 1000, 10000);
        QTimer::singleShot(wait, this, [this, job] {
            --m_inFlight;
            if (job.generation == m_generation)
                m_queue.prepend(job);
            pump();
        });
        return;
    }
    if (reply->error() != QNetworkReply::NoError) {
        if (!m_reportedNetworkError) {
            m_reportedNetworkError = true;
            emit failed(QStringLiteral("Couldn't reach TMDB: %1").arg(reply->errorString()));
        }
        complete(); // left unsearched, so it's retried on the next restock
        return;
    }

    const QJsonArray results =
        QJsonDocument::fromJson(reply->readAll()).object().value(QLatin1String("results")).toArray();
    const Candidate c = pickBest(results, job);
    if (c.match.found && c.score > job.bestScore) {
        job.best = c.match;
        job.bestScore = c.score;
        job.bestAcceptable = c.acceptable;
    }
    // A popular film with the same title and year: no need to keep looking.
    if (c.confident)
        return accept(job, c.match);

    const bool lastSearch = job.step == TvSeriesName
                            || (job.step == TvNoYear && (job.bestAcceptable || seriesName(job.title).isEmpty()));
    if (!lastSearch)
        return next(job);
    return accept(job, job.bestAcceptable ? job.best : TmdbMatch{});
}

QString TmdbClient::seriesName(const QString &title)
{
    const int colon = title.indexOf(u':');
    if (colon <= 0)
        return {};
    QString name = title.left(colon).trimmed();
    // "Stranger Things 5" -> "Stranger Things"
    static const QRegularExpression season(QStringLiteral("\\s+\\d+$"));
    name.remove(season);
    return name;
}

void TmdbClient::next(Job job)
{
    job.step = Step(int(job.step) + 1);
    if (job.step == TvSeriesName)
        job.query = seriesName(job.title);
    m_queue.prepend(job);
    pump();
}

void TmdbClient::accept(const Job &job, TmdbMatch match)
{
    match.searched = true;
    emit matched(job.filmIndex, match);
    complete();
}

void TmdbClient::complete()
{
    ++m_done;
    emit progressChanged();
    pump();
}

TmdbMatch TmdbClient::matchFrom(const QJsonObject &o, bool tv)
{
    TmdbMatch m;
    m.found = true;
    m.isTv = tv;
    m.id = o.value(QLatin1String("id")).toInt();
    m.posterPath = o.value(QLatin1String("poster_path")).toString();
    m.backdropPath = o.value(QLatin1String("backdrop_path")).toString();
    m.overview = o.value(QLatin1String("overview")).toString();
    m.releaseDate = o.value(QLatin1String(tv ? "first_air_date" : "release_date")).toString();
    m.originalTitle = o.value(QLatin1String(tv ? "original_name" : "original_title")).toString();
    m.voteAverage = o.value(QLatin1String("vote_average")).toDouble();
    m.voteCount = o.value(QLatin1String("vote_count")).toInt();
    for (const auto &g : o.value(QLatin1String("genre_ids")).toArray())
        m.genreIds << g.toInt();
    return m;
}

TmdbClient::Candidate TmdbClient::pickBest(const QJsonArray &results, const Job &job)
{
    const bool tv = isTvStep(job.step);
    const QLatin1String titleKey(tv ? "name" : "title");
    const QLatin1String originalKey(tv ? "original_name" : "original_title");
    const QLatin1String dateKey(tv ? "first_air_date" : "release_date");
    const QString wanted = normalized(job.query);

    // Score = title + year + how well known it is. TMDB often dates famous
    // films a year off from Letterboxd (festival vs. release), so one year off
    // costs little, and a film thousands have rated beats an unknown with the
    // same name and exact year.
    Candidate best;
    for (qsizetype rank = 0; rank < results.size(); ++rank) {
        const QJsonObject o = results.at(rank).toObject();
        const QString title = normalized(o.value(titleKey).toString());
        const QString original = normalized(o.value(originalKey).toString());
        const int year = o.value(dateKey).toString().left(4).toInt();
        const int votes = o.value(QLatin1String("vote_count")).toInt();
        const bool poster = !o.value(QLatin1String("poster_path")).toString().isEmpty();

        double titleScore = 0;
        if (title == wanted || original == wanted)
            titleScore = 2;
        else if (!wanted.isEmpty() && (title.contains(wanted) || (wanted.contains(title) && title.size() > 3)))
            titleScore = 1;
        double yearScore = 0;
        if (job.year > 0 && year > 0) {
            const int diff = std::abs(year - job.year);
            yearScore = diff == 0 ? 2 : diff == 1 ? 1.5 : diff == 2 ? 0.5 : 0;
        }
        // The series-name step matches "Show: Episode" to "Show", any year.
        if (job.step == TvSeriesName && titleScore == 2)
            yearScore = 2;
        const double score = titleScore + yearScore + 0.25 * std::log10(votes + 1.0) + (poster ? 0.2 : 0);

        if (score > best.score) {
            best.match = matchFrom(o, tv);
            best.score = score;
            // TMDB also searches alternative titles: its top hit can be right
            // under another name ("Nausicaä" is "Warriors of the Wind" there),
            // so trust it when the year fits and plenty of people know it.
            const bool aliasHit = rank == 0 && yearScore >= 1.5 && votes >= 50;
            best.acceptable = titleScore == 2 || (titleScore == 1 && yearScore >= 2) || aliasHit;
            best.confident = titleScore == 2 && yearScore == 2 && votes >= 100 && poster;
        }
    }
    return best;
}
