#include "LightBaker.h"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QMetaObject>
#include <QSettings>
#include <QStandardPaths>
#include <QtGlobal>
#if QT_VERSION >= QT_VERSION_CHECK(6, 10, 0)
#  define CINEFY_CAN_BAKE 1
#  include <QtQuick3D/private/qquick3dlightmapbaker_p.h>
#  include <QtQuick3D/private/qquick3dviewport_p.h>
#endif

namespace {
QSettings settings()
{
    return QSettings(QStringLiteral("cinefy"), QStringLiteral("cinefy"));
}
}

LightBaker::LightBaker(QObject *parent) : QObject(parent)
{
    m_enabled = settings().value(QStringLiteral("useBakedLighting"), true).toBool();
}

QString LightBaker::path() const
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/lightmaps.bin");
}

bool LightBaker::supported()
{
#ifdef CINEFY_CAN_BAKE
    return true;
#else
    return false;
#endif
}

QUrl LightBaker::lightmapUrl() const
{
    return QUrl::fromLocalFile(path());
}

void LightBaker::setSignature(const QString &signature)
{
    if (signature == m_signature)
        return;
    m_signature = signature;
    emit changed();
}

bool LightBaker::available() const
{
    return supported() && !m_signature.isEmpty() && QFile::exists(path())
           && settings().value(QStringLiteral("bakedSignature")).toString() == m_signature;
}

void LightBaker::setEnabled(bool enabled)
{
    if (enabled == m_enabled)
        return;
    m_enabled = enabled;
    settings().setValue(QStringLiteral("useBakedLighting"), enabled);
    emit changed();
}

void LightBaker::bake(QQuickItem *item)
{
#ifndef CINEFY_CAN_BAKE
    Q_UNUSED(item);
#else
    auto *view = qobject_cast<QQuick3DViewport *>(item);
    if (!view || m_baking)
        return;
    m_baking = true;
    m_progress = 0;
    m_status = QStringLiteral("Preparing…");
    emit changed();

    const QString signature = m_signature;
    // The callback runs on the render thread: hop back to this thread.
    view->lightmapBaker()->bake([this, signature](const QVariantMap &info, QQuick3DLightmapBaker::BakingControl *) {
        if (qEnvironmentVariableIsSet("CINEFY_BAKE"))
            qInfo().noquote() << "bake:" << info;
        QMetaObject::invokeMethod(this, [this, info, signature] {
            const auto status = info.value(QStringLiteral("status")).value<QQuick3DLightmapBaker::BakingStatus>();
            const QString message = info.value(QStringLiteral("message")).toString();
            if (info.contains(QStringLiteral("totalProgress")))
                m_progress = info.value(QStringLiteral("totalProgress")).toDouble();
            if (!message.isEmpty())
                m_status = message;
            using S = QQuick3DLightmapBaker::BakingStatus;
            if (status == S::Complete || status == S::Failed || status == S::Cancelled) {
                const bool ok = status == S::Complete;
                m_baking = false;
                m_progress = ok ? 1 : 0;
                m_status = ok ? QStringLiteral("Lighting baked") : QStringLiteral("Baking failed: ") + message;
                if (ok)
                    settings().setValue(QStringLiteral("bakedSignature"), signature);
                emit changed();
                emit finished(ok);
                return;
            }
            emit changed();
        }, Qt::QueuedConnection);
    });
#endif // CINEFY_CAN_BAKE
}
