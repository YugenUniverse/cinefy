#pragma once

#include <QHash>
#include <QImage>
#include <QPointer>
#include <QQueue>
#include <QTimer>
#include <QVector4D>
#include <QtQml/qqmlregistration.h>
#include <QtQuick3D/QQuick3DTextureData>

class FilmModel;
class QNetworkAccessManager;

// Every film's cover packed into one 4096x4096 texture, so ~2,400 tapes in the
// 3D store can be drawn in a single instanced draw call. Films without a poster
// get a hand-written blank tape label.
class CoverAtlas : public QQuick3DTextureData
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QObject *films READ films WRITE setFilms NOTIFY filmsChanged)
    Q_PROPERTY(int loading READ loading NOTIFY loadingChanged)

public:
    static constexpr int Size = 4096;

    explicit CoverAtlas(QQuick3DObject *parent = nullptr);

    QObject *films() const;
    void setFilms(QObject *films);
    int loading() const { return int(m_queue.size()) + m_inFlight; }

    // Texture coordinates of a film's cell: (u0, v0, u1, v1).
    QVector4D cell(int film) const;

signals:
    void filmsChanged();
    void cellsChanged();
    void loadingChanged();

private:
    void rebuild();
    void onDataChanged(const QModelIndex &topLeft, const QModelIndex &bottomRight);
    void request(int film);
    void pump();
    QRect cellRect(int film) const;
    void drawBlank(int film);
    void drawCover(int film, const QImage &cover);
    void upload();
    QString cachePath() const;
    QString signature() const; // which films/posters this atlas holds
    bool loadCached();
    void saveCached();

    QPointer<FilmModel> m_films;
    QNetworkAccessManager *m_nam = nullptr;
    QImage m_image;
    int m_cols = 1, m_cellW = 64, m_cellH = 96;
    QHash<int, QString> m_shown; // film -> poster path currently drawn
    QQueue<QPair<int, QString>> m_queue;
    int m_inFlight = 0;
    quint64 m_generation = 0;
    QTimer m_uploadTimer;
    bool m_dirty = false; // drawn since the last save
    int m_failed = 0;     // covers that didn't download: don't cache the atlas with blanks
};
