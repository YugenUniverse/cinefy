#include "CachingNetwork.h"
#include "PointerHelper.h"
#include "SoundBank.h"
#include "LightBaker.h"
#include "Shop.h"

#include <QDateTime>
#include <QDir>
#include <QElapsedTimer>
#include <qpa/qwindowsysteminterface.h>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSurfaceFormat>
#include <QtQuick3D/qquick3d.h>
#include <QTimer>

namespace {
QtMessageHandler defaultHandler = nullptr;
double appT0()
{
    static const double t0 = double(QDateTime::currentMSecsSinceEpoch());
    return t0;
}

// Drop two harmless, very noisy Qt Quick 3D messages: one is printed for
// every 2D item used as a 3D texture (every sign), the other on quit.
void quietHandler(QtMsgType type, const QMessageLogContext &context, const QString &message)
{
    if (message.contains(QLatin1String("Cannot set FocusScope once item has children"))
        || message.contains(QLatin1String("Pending resource cleanup queue not empty")))
        return;
    defaultHandler(type, context, message);
}
} // namespace

int main(int argc, char **argv)
{
    appT0(); // start of the clock for the perf timings
    defaultHandler = qInstallMessageHandler(quietHandler);
    // First-person mouse look needs to hold the pointer in the middle of the
    // window. Native Wayland doesn't allow that, XWayland does, so prefer it
    // on Wayland desktops (set CINEFY_NATIVE_WAYLAND=1 to opt out).
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM") && !qEnvironmentVariableIsEmpty("WAYLAND_DISPLAY")
        && !qEnvironmentVariableIsEmpty("DISPLAY") && !qEnvironmentVariableIsSet("CINEFY_NATIVE_WAYLAND"))
        qputenv("QT_QPA_PLATFORM", "xcb");

    // CINEFY_PERF=1: print frame timings per 3D layer (GPU time needs timestamps).
    if (qEnvironmentVariableIsSet("CINEFY_PERF"))
        qputenv("QSG_RHI_PROFILE", "1");

    QGuiApplication app(argc, argv);
    // Qt Quick 3D needs a modern OpenGL context (3.3+ core, or GLES 3).
    QSurfaceFormat::setDefaultFormat(QQuick3D::idealSurfaceFormat());
    QGuiApplication::setApplicationName(QStringLiteral("cinefy"));
    QGuiApplication::setApplicationDisplayName(QStringLiteral("Cinefy Video"));
    QGuiApplication::setApplicationVersion(QStringLiteral(CINEFY_VERSION));
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    // Declared before the engine so they outlive it.
    CachingNetworkFactory networkFactory;
    Shop shop;
    PointerHelper pointer;
    SoundBank sounds;
    LightBaker baker;

    QQmlApplicationEngine engine;
    engine.setNetworkAccessManagerFactory(&networkFactory);
    engine.rootContext()->setContextProperty(QStringLiteral("shop"), &shop);
    engine.rootContext()->setContextProperty(QStringLiteral("pointer"), &pointer);
    engine.rootContext()->setContextProperty(QStringLiteral("sounds"), &sounds);
    engine.rootContext()->setContextProperty(QStringLiteral("baker"), &baker);
    // Dev aids: CINEFY_START="x,z,yaw,pitch" places you in the 3D store;
    // CINEFY_NO_ASCII=1 turns the street effect off.
    engine.rootContext()->setContextProperty(QStringLiteral("devStart"), qEnvironmentVariable("CINEFY_START"));
    engine.rootContext()->setContextProperty(QStringLiteral("devNoAscii"), qEnvironmentVariableIsSet("CINEFY_NO_ASCII"));
    // CINEFY_BAKE=1 starts a lighting bake as soon as the shop opens.
    engine.rootContext()->setContextProperty(QStringLiteral("devBake"), qEnvironmentVariableIsSet("CINEFY_BAKE"));
    // Test runs (snapshots, bakes) start silent so they don't play through the speakers.
    engine.rootContext()->setContextProperty(QStringLiteral("devMute"),
        qEnvironmentVariableIsSet("CINEFY_MUTE") || qEnvironmentVariableIsSet("CINEFY_SNAPSHOT")
            || qEnvironmentVariableIsSet("CINEFY_BAKE"));
    engine.rootContext()->setContextProperty(QStringLiteral("devPerf"), qEnvironmentVariableIsSet("CINEFY_PERF"));
    engine.rootContext()->setContextProperty(QStringLiteral("devT0"), appT0());
    // CINEFY_OFF="ao,shadows,..." switches features off, to measure what they cost.
    engine.rootContext()->setContextProperty(QStringLiteral("devOff"), qEnvironmentVariable("CINEFY_OFF"));
    // CINEFY_QUALITY=0|1|2 overrides the graphics quality setting (for measuring).
    engine.rootContext()->setContextProperty(QStringLiteral("devQuality"),
        qEnvironmentVariableIsSet("CINEFY_QUALITY") ? qEnvironmentVariableIntValue("CINEFY_QUALITY") : -1);
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Cinefy", "Main");

    // `cinefy path/to/export.zip` opens that export; otherwise reopen the last one.
    const QStringList args = QCoreApplication::arguments();
    QElapsedTimer loadClock;
    loadClock.start();
    if (args.size() > 1)
        shop.loadExport(QUrl::fromUserInput(args.at(1), QDir::currentPath(), QUrl::AssumeLocalFile));
    else
        shop.reopenLast();
    if (qEnvironmentVariableIsSet("CINEFY_PERF"))
        qInfo().noquote() << QStringLiteral("perf: export loaded in %1 ms (done at %2 ms)").arg(loadClock.elapsed()).arg(QDateTime::currentMSecsSinceEpoch() - qint64(appT0()));
    // Dev aid: CINEFY_PERF=1 also counts whole frames (all layers + 2D).
    if (qEnvironmentVariableIsSet("CINEFY_PERF")) {
        if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().value(0))) {
            QObject::connect(window, &QQuickWindow::frameSwapped, &app, [] {
                static bool once = false;
                if (!once) {
                    once = true;
                    qInfo().noquote() << QStringLiteral("perf: first frame at %1 ms").arg(QDateTime::currentMSecsSinceEpoch() - qint64(appT0()));
                }
            });
            auto *frames = new int(0);
            auto *clock = new QElapsedTimer;
            clock->start();
            QObject::connect(window, &QQuickWindow::frameSwapped, &app, [frames, clock] {
                ++*frames;
                if (clock->elapsed() >= 2000) {
                    qInfo().noquote() << QStringLiteral("perf: window %1 fps").arg(*frames * 1000.0 / clock->elapsed(), 0, 'f', 1);
                    *frames = 0;
                    clock->restart();
                }
            });
        }
    }

    // Dev aid: CINEFY_SNAPSHOT=out.png renders the window to an image after a few seconds, then quits.
    const QString snapshot = qEnvironmentVariable("CINEFY_SNAPSHOT");
    if (!snapshot.isEmpty()) {
        QTimer::singleShot(qEnvironmentVariableIntValue("CINEFY_SNAPSHOT_DELAY") > 0
                               ? qEnvironmentVariableIntValue("CINEFY_SNAPSHOT_DELAY") : 4000,
                           &app, [&engine, snapshot] {
            if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().value(0))) {
                window->grabWindow().save(snapshot);
                QMetaObject::invokeMethod(window, "quitApp");
            } else {
                QCoreApplication::quit();
            }
        });
    }

    // Dev aid: CINEFY_KEYTEST="M M C C ..." presses those keys one by one
    // (through the normal input path, like a real keyboard, so shortcuts
    // work too) and prints which panels are open after each, then quits.
    const QString keyTest = qEnvironmentVariable("CINEFY_KEYTEST");
    if (!keyTest.isEmpty()) {
        QTimer::singleShot(4000, &app, [&engine, keyTest] {
            auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().value(0));
            QObject *store = window ? window->findChild<QObject *>(QStringLiteral("store3d")) : nullptr;
            auto state = [store] {
                QVariant v;
                if (store)
                    QMetaObject::invokeMethod(store, "devState", Q_RETURN_ARG(QVariant, v));
                return v.toString();
            };
            static const QHash<QString, int> keys = {
                {QStringLiteral("Esc"), Qt::Key_Escape}, {QStringLiteral("Tab"), Qt::Key_Tab},
                {QStringLiteral("Alt"), Qt::Key_Alt}, {QStringLiteral("F"), Qt::Key_F},
            };
            qInfo().noquote() << "keytest: start ->" << state();
            for (const QString &name : keyTest.split(u' ', Qt::SkipEmptyParts)) {
                const int key = keys.value(name, name.size() == 1 ? name.at(0).toUpper().unicode() : 0);
                const QString text = name.size() == 1 ? name.toLower() : QString();
                QWindowSystemInterface::handleKeyEvent<QWindowSystemInterface::SynchronousDelivery>(
                    window, QEvent::KeyPress, key, Qt::NoModifier, text);
                QWindowSystemInterface::handleKeyEvent<QWindowSystemInterface::SynchronousDelivery>(
                    window, QEvent::KeyRelease, key, Qt::NoModifier, text);
                for (int i = 0; i < 20; ++i)
                    QCoreApplication::processEvents();
                qInfo().noquote() << "keytest:" << name.leftJustified(4) << "->" << state();
            }
            QMetaObject::invokeMethod(window, "quitApp");
        });
    }

    return app.exec();
}
