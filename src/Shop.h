#pragma once

#include "Film.h"

#include <QList>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

#include <memory>

class AisleModel;
class StoreLayout;
class FilmModel;
class MatchCache;
class TmdbClient;

// The shop: owns the library, the aisles and the TMDB enrichment. Exposed to
// QML as the `shop` context property.
class Shop : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString tmdbKey READ tmdbKey WRITE setTmdbKey NOTIFY tmdbKeyChanged)
    Q_PROPERTY(QString tmdbError READ tmdbError NOTIFY tmdbErrorChanged)
    Q_PROPERTY(QString lastExport READ lastExport NOTIFY lastExportChanged)
    Q_PROPERTY(bool stocking READ stocking NOTIFY stockChanged)
    Q_PROPERTY(int stockDone READ stockDone NOTIFY stockChanged)
    Q_PROPERTY(int stockTotal READ stockTotal NOTIFY stockChanged)
    Q_PROPERTY(QVariantMap member READ member NOTIFY memberChanged)
    Q_PROPERTY(QList<QObject *> aisles READ aisles NOTIFY aislesChanged)
    Q_PROPERTY(QObject *searchAisle READ searchAisle CONSTANT)
    Q_PROPERTY(QObject *store READ store CONSTANT)
    Q_PROPERTY(QObject *films READ films CONSTANT)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
    Q_PROPERTY(QStringList wallpapers READ wallpapers NOTIFY wallpapersChanged)
    Q_PROPERTY(QVariantList mostWatched READ mostWatched NOTIFY memberChanged)
    Q_PROPERTY(QStringList windowPosters READ windowPosters NOTIFY memberChanged)
    Q_PROPERTY(QStringList comingSoon READ comingSoon NOTIFY memberChanged) // watchlist posters

public:
    explicit Shop(QObject *parent = nullptr);
    ~Shop() override;

    bool loaded() const { return m_loaded; }
    QString error() const { return m_error; }
    QString tmdbKey() const { return m_tmdbKey; }
    void setTmdbKey(const QString &key);
    QString tmdbError() const { return m_tmdbError; }
    QString lastExport() const { return m_lastExport; }
    bool stocking() const;
    int stockDone() const;
    int stockTotal() const;
    QVariantMap member() const { return m_member; }
    QList<QObject *> aisles() const { return m_aisles; }
    QObject *searchAisle() const;
    QObject *store() const;
    QObject *films() const;
    QString searchQuery() const { return m_searchQuery; }
    void setSearchQuery(const QString &query);
    QStringList wallpapers() const { return m_wallpapers; }
    QVariantList mostWatched() const { return m_mostWatched; }
    QStringList windowPosters() const { return m_windowPosters; }
    QStringList comingSoon() const { return m_comingSoon; }

    Q_INVOKABLE void loadExport(const QUrl &url);
    Q_INVOKABLE void reopenLast();
    Q_INVOKABLE void eject();
    Q_INVOKABLE void restock();
    Q_INVOKABLE QVariantMap film(int index) const;
    Q_INVOKABLE QVariantList diary() const;
    Q_INVOKABLE QVariantList findFilms(const QString &query, int limit = 8) const;
    // A random film from your watchlist (for the clerk to recommend), or -1.
    Q_INVOKABLE int recommend() const;
    Q_INVOKABLE void openOnLetterboxd(int index) const;
    // Fixing a wrong match by hand.
    Q_INVOKABLE void findCandidates(int index, const QString &query);
    Q_INVOKABLE void pinMatch(int index, const QVariantMap &candidate);
    // Remembered preferences (volume, mouse sensitivity, ...).
    Q_INVOKABLE QVariant pref(const QString &key, const QVariant &fallback) const;
    Q_INVOKABLE void setPref(const QString &key, const QVariant &value);

signals:
    void loadedChanged();
    void errorChanged();
    void tmdbKeyChanged();
    void tmdbErrorChanged();
    void lastExportChanged();
    void stockChanged();
    void memberChanged();
    void aislesChanged();
    void searchQueryChanged();
    void wallpapersChanged();
    void candidatesReady(int index, const QVariantList &candidates);

private:
    bool loadFile(const QString &path);
    void setError(const QString &error);
    void setTmdbError(const QString &error);
    void onMatched(int index, const TmdbMatch &match);
    void onStockIdle();
    void rebuildAisles();
    void rebuildStore();
    void rebuildMember();
    void rebuildWallpapers();

    FilmModel *m_films;
    AisleModel *m_search;
    StoreLayout *m_store;
    TmdbClient *m_tmdb;
    std::unique_ptr<MatchCache> m_cache;
    Library m_library; // profile + lists; films live in m_films
    QList<QObject *> m_aisles;
    QVariantMap m_member;
    QVariantList m_mostWatched;
    QStringList m_windowPosters, m_comingSoon;
    QStringList m_wallpapers;
    QTimer m_wallpaperTimer;
    QString m_error, m_tmdbError, m_tmdbKey, m_lastExport, m_searchQuery;
    bool m_loaded = false;
    int m_matchedSinceSave = 0;
};
