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
    // The texture to draw with. Replaced by a new one on every update: Qt
    // makes a texture's mipmaps only when it is created, so updating one in
    // place would leave the old (blank) covers in its smaller levels.
    Q_PROPERTY(QQuick3DTextureData *texture READ texture NOTIFY textureChanged)

public:
    static constexpr int Size = 4096;

    explicit CoverAtlas(QQuick3DObject *parent = nullptr);

    QObject *films() const;
    void setFilms(QObject *films);
    int loading() const { return int(m_queue.size()) + m_inFlight; }
    QQuick3DTextureData *texture() const { return m_texture; }

    // Texture coordinates of a film's cell: (u0, v0, u1, v1).
    QVector4D cell(int film) const;

signals:
    void filmsChanged();
    void cellsChanged();
    void loadingChanged();
    void textureChanged();

private:
    void rebuild();
    void onDataChanged(const QModelIndex &topLeft, const QModelIndex &bottomRight);
    void request(int film);
    void pump();
    QRect cellRect(int film) const;
    void drawBlank(int film);
    void drawCover(int film, const QImage &cover);
    void decoded(int film, quint64 generation, const QImage &cover);
    void settled(); // every cover is in: show the atlas and keep it
    void upload();
    QString cachePath() const;
    QString signature() const; // which films/posters this atlas holds
    bool loadCached();
    void saveCached();

    QPointer<FilmModel> m_films;
    QNetworkAccessManager *m_nam = nullptr;
    QImage m_image;
    QQuick3DTextureData *m_texture = nullptr;
    int m_cols = 1, m_cellW = 64, m_cellH = 96;
    QHash<int, QString> m_shown; // film -> poster path currently drawn
    QQueue<QPair<int, QString>> m_queue;
    int m_inFlight = 0;
    quint64 m_generation = 0;
    QTimer m_uploadTimer;
    QTimer m_settleTimer;
    bool m_dirty = false; // drawn since the last save
    int m_failed = 0;     // covers that didn't download: don't cache the atlas with blanks
};
