#pragma once

#include <QDateTime>
#include <QDebug>

// Dev aid (CINEFY_PERF=1): startup and loading milestones, in ms since launch.
namespace perf {

inline double t0()
{
    static const double start = double(QDateTime::currentMSecsSinceEpoch());
    return start;
}

inline bool enabled()
{
    static const bool on = qEnvironmentVariableIsSet("CINEFY_PERF");
    return on;
}

inline void mark(const QString &what)
{
    if (enabled())
        qInfo().noquote() << QStringLiteral("perf: %1 at %2 ms")
                                 .arg(what).arg(QDateTime::currentMSecsSinceEpoch() - qint64(t0()));
}

} // namespace perf
