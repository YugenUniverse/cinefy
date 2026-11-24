#pragma once

#include <QObject>
#include <QUrl>

class QQuickItem;

// Bakes ray-traced lighting for the shop (soft shadows, light bouncing off
// walls and shelves) into a lightmap file. The bake belongs to one store
// layout: if the shelves change, the old bake is ignored until you bake again.
class LightBaker : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool supported READ supported CONSTANT) // needs Qt 6.10+
    Q_PROPERTY(QUrl lightmapUrl READ lightmapUrl CONSTANT)
    Q_PROPERTY(bool baking READ baking NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString signature READ signature WRITE setSignature NOTIFY changed)
    Q_PROPERTY(bool available READ available NOTIFY changed) // a bake exists for this layout
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY changed) // use it

public:
    explicit LightBaker(QObject *parent = nullptr);

    static bool supported();
    QUrl lightmapUrl() const;
    bool baking() const { return m_baking; }
    double progress() const { return m_progress; }
    QString status() const { return m_status; }
    QString signature() const { return m_signature; }
    void setSignature(const QString &signature);
    bool available() const;
    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);

    // `view` is the View3D holding the shop.
    Q_INVOKABLE void bake(QQuickItem *view);

signals:
    void changed();
    void finished(bool ok);

private:
    QString path() const;
    QString m_signature, m_status;
    bool m_baking = false;
    bool m_enabled = true;
    double m_progress = 0;
};
