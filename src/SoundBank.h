#pragma once

#include <QObject>
#include <QUrl>

// The shop's sounds, synthesised on first launch and saved as WAV files in the
// cache: rain (outside, and muffled for inside), fluorescent hum, the door
// chime and the clack of picking up a tape. No recordings to license.
class SoundBank : public QObject
{
    Q_OBJECT
public:
    explicit SoundBank(QObject *parent = nullptr);

    Q_INVOKABLE QUrl url(const QString &name) const;

private:
    QString m_dir;
};
