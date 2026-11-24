#include "CoverAtlas.h"

#include "CachingNetwork.h"
#include "FilmModel.h"
#include "Perf.h"

#include <QNetworkReply>
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QPainter>
#include <QStandardPaths>
#include <QThreadPool>

namespace {
constexpr int MaxInFlight = 24;
constexpr int Pad = 2;
}

CoverAtlas::CoverAtlas(QQuick3DObject *parent) : QQuick3DTextureData(parent)
{
    m_nam = CachingNetworkFactory().create(this);
    m_image = QImage(Size, Size, QImage::Format_RGBA8888);
    m_image.fill(QColor("#151517"));

    // Re-uploading 64 MB is not free: batch covers as they stream in.
    m_uploadTimer.setSingleShot(true);
    m_uploadTimer.setInterval(4000); // each upload is 64 MB + mipmaps: batch them
    connect(&m_uploadTimer, &QTimer::timeout, this, &CoverAtlas::upload);
    // While matches still stream in, the queue empties now and then for a
    // moment: only finish once it has stayed empty for a bit.
    m_settleTimer.setSingleShot(true);
    m_settleTimer.setInterval(1500);
    connect(&m_settleTimer, &QTimer::timeout, this, &CoverAtlas::settled);
    upload();
}

QObject *CoverAtlas::films() const
{
    return m_films;
}

void CoverAtlas::setFilms(QObject *films)
{
    auto *model = qobject_cast<FilmModel *>(films);
    if (model == m_films)
        return;
    if (m_films)
        disconnect(m_films, nullptr, this, nullptr);
    m_films = model;
    if (m_films) {
        connect(m_films, &QAbstractItemModel::modelReset, this, &CoverAtlas::rebuild);
        connect(m_films, &QAbstractItemModel::dataChanged, this, &CoverAtlas::onDataChanged);
    }
    emit filmsChanged();
    rebuild();
}

void CoverAtlas::rebuild()
{
    ++m_generation;
    m_queue.clear();
    m_shown.clear();
    m_failed = 0;
    m_image.fill(QColor("#151517"));

    const int n = m_films ? m_films->rowCount() : 0;
    // Largest 2:3 cell that fits every film.
    m_cellW = 160;
    while (m_cellW > 24 && (Size / m_cellW) * (Size / (m_cellW * 3 / 2)) < n)
        m_cellW -= 2;
    m_cellH = m_cellW * 3 / 2;
    m_cols = Size / m_cellW;

    // The finished atlas from last time, if the films and posters are the same:
    // then nothing has to be downloaded, decoded or drawn again.
    if (loadCached()) {
        for (int i = 0; i < n; ++i)
            m_shown.insert(i, m_films->film(i).tmdb.posterPath);
    } else {
        for (int i = 0; i < n; ++i) {
            drawBlank(i);
            request(i);
        }
    }
    emit cellsChanged();
    emit loadingChanged();
    upload();
    pump();
}

void CoverAtlas::onDataChanged(const QModelIndex &topLeft, const QModelIndex &bottomRight)
{
    for (int i = topLeft.row(); i <= bottomRight.row(); ++i)
        request(i);
    pump();
}

void CoverAtlas::request(int film)
{
    const QString path = m_films->film(film).tmdb.posterPath;
    if (path.isEmpty() || m_shown.value(film) == path)
        return;
    m_shown.insert(film, path);
    m_queue.enqueue({film, path});
    emit loadingChanged();
}

void CoverAtlas::pump()
{
    while (m_inFlight < MaxInFlight && !m_queue.isEmpty()) {
        m_settleTimer.stop();
        const auto next = m_queue.dequeue();
        const int film = next.first;
        const QString path = next.second;
        ++m_inFlight;
        const quint64 generation = m_generation;
        QNetworkRequest req(QUrl(FilmModel::posterUrl(path, "w185")));
        req.setTransferTimeout(20000);
        QNetworkReply *reply = m_nam->get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply, film, generation] {
            reply->deleteLater();
            if (generation != m_generation || reply->error() != QNetworkReply::NoError) {
                decoded(film, generation, {});
                return;
            }
            // Decoding and scaling a JPEG takes a few ms: do it on a worker
            // thread, so walking around stays smooth while covers stream in.
            const QByteArray data = reply->readAll();
            const QSize size = cellRect(film).size();
            const QPointer<CoverAtlas> self(this);
            QThreadPool::globalInstance()->start([self, data, size, film, generation] {
                QImage cover;
                if (cover.loadFromData(data))
                    cover = cover.scaled(size, Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
                                .convertToFormat(QImage::Format_RGBA8888);
                QMetaObject::invokeMethod(qApp, [self, film, generation, cover] {
                    if (self)
                        self->decoded(film, generation, cover);
                }, Qt::QueuedConnection);
            });
        });
    }
}

void CoverAtlas::decoded(int film, quint64 generation, const QImage &cover)
{
    --m_inFlight;
    if (generation == m_generation) {
        if (!cover.isNull()) {
            drawCover(film, cover);
        } else {
            // Forget it, so the next change to this film asks again;
            // and keep the half-blank atlas off the disk.
            m_shown.remove(film);
            ++m_failed;
        }
    }
    emit loadingChanged();
    pump();
    if (m_queue.isEmpty() && m_inFlight == 0)
        m_settleTimer.start();
}

void CoverAtlas::settled()
{
    if (!m_queue.isEmpty() || m_inFlight > 0)
        return;
    perf::mark(QStringLiteral("covers in (%1 failed)").arg(m_failed));
    m_uploadTimer.stop();
    upload();
    saveCached();
}

QRect CoverAtlas::cellRect(int film) const
{
    return QRect((film % m_cols) * m_cellW, (film / m_cols) * m_cellH, m_cellW, m_cellH);
}

QVector4D CoverAtlas::cell(int film) const
{
    const QRectF r = QRectF(cellRect(film)).adjusted(Pad, Pad, -Pad, -Pad);
    return QVector4D(r.left() / Size, r.top() / Size, r.right() / Size, r.bottom() / Size);
}

void CoverAtlas::drawBlank(int film)
{
    const Film &f = m_films->film(film);
    const QRect r = cellRect(film);
    QPainter p(&m_image);
    p.setRenderHint(QPainter::Antialiasing);
    p.fillRect(r, QColor("#1b1b1d"));
    const QRectF label(r.left() + r.width() * 0.08, r.top() + r.height() * 0.07,
                       r.width() * 0.84, r.height() * 0.5);
    p.fillRect(label, QColor("#f3eee0"));
    p.fillRect(QRectF(label.left(), label.top(), label.width(), label.height() * 0.08),
               FilmModel::spineColor(f));
    QFont font;
    font.setBold(true);
    font.setItalic(true);
    font.setPixelSize(std::max(8, m_cellW / 8));
    p.setFont(font);
    p.setPen(QColor("#1d2a6b"));
    p.drawText(label.adjusted(4, label.height() * 0.1, -4, -4),
               Qt::AlignCenter | Qt::TextWordWrap, f.name);
    // Two tape reels.
    p.setPen(QPen(QColor("#3a3a3a"), 2));
    p.setBrush(QColor("#0c0c0c"));
    const qreal reel = r.width() * 0.22;
    p.drawEllipse(QPointF(r.left() + r.width() * 0.3, r.top() + r.height() * 0.76), reel / 2, reel / 2);
    p.drawEllipse(QPointF(r.left() + r.width() * 0.7, r.top() + r.height() * 0.76), reel / 2, reel / 2);
    if (!m_uploadTimer.isActive())
        m_uploadTimer.start();
}

void CoverAtlas::drawCover(int film, const QImage &cover)
{
    m_dirty = true;
    const QRect r = cellRect(film);
    QPainter p(&m_image);
    p.drawImage(r.topLeft(), cover); // already scaled to the cell
    if (!m_uploadTimer.isActive())
        m_uploadTimer.start();
}

QString CoverAtlas::cachePath() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/covers-atlas.bin");
}

QString CoverAtlas::signature() const
{
    QCryptographicHash h(QCryptographicHash::Sha1);
    h.addData(QByteArray::number(m_cellW));
    const int n = m_films ? m_films->rowCount() : 0;
    for (int i = 0; i < n; ++i) {
        const Film &f = m_films->film(i);
        h.addData(f.key().toUtf8());
        h.addData(f.tmdb.posterPath.toUtf8());
    }
    return QString::fromLatin1(h.result().toHex());
}

bool CoverAtlas::loadCached()
{
    QFile file(cachePath());
    if (!file.open(QIODevice::ReadOnly))
        return false;
    const QByteArray sig = file.readLine().trimmed();
    if (sig != signature().toLatin1())
        return false;
    const QByteArray pixels = file.readAll();
    if (pixels.size() != m_image.sizeInBytes())
        return false;
    memcpy(m_image.bits(), pixels.constData(), size_t(pixels.size()));
    m_dirty = false;
    return true;
}

void CoverAtlas::saveCached()
{
    if (!m_dirty || !m_films || m_failed > 0)
        return;
    QFile file(cachePath());
    if (!file.open(QIODevice::WriteOnly))
        return;
    file.write(signature().toLatin1() + '\n');
    file.write(reinterpret_cast<const char *>(m_image.constBits()), m_image.sizeInBytes());
    m_dirty = false;
}

void CoverAtlas::upload()
{
    auto *texture = new QQuick3DTextureData(this);
    texture->setSize(QSize(Size, Size));
    texture->setFormat(QQuick3DTextureData::RGBA8);
    texture->setHasTransparency(false);
    texture->setTextureData(QByteArray(reinterpret_cast<const char *>(m_image.constBits()),
                                       m_image.sizeInBytes()));
    QQuick3DTextureData *old = m_texture;
    m_texture = texture;
    emit textureChanged();
    if (old)
        old->deleteLater();
}
