#pragma once

#include <QObject>
#include <QPointF>
#include <QPointer>

class QQuickItem;
class QQuickWindow;

// First-person mouse look. Watches the window's real mouse motion, reports
// how far the mouse moved, and keeps the pointer in the middle of the window
// so you can keep turning. Holding the pointer works on X11/XWayland, not
// native Wayland; if warping turns out not to work it falls back gracefully.
class PointerHelper : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool canWarp READ canWarp NOTIFY canWarpChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool debug READ debug CONSTANT)
public:
    explicit PointerHelper(QObject *parent = nullptr);

    bool canWarp() const;
    bool active() const { return m_active; }
    bool debug() const { return m_debug; }
    void setActive(bool active);

    // Start watching the window `item` is in.
    Q_INVOKABLE void attach(QQuickItem *item);
    Q_INVOKABLE void recenter();

signals:
    void activeChanged();
    void canWarpChanged();
    void moved(qreal dx, qreal dy);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    bool windowReady() const;

    QPointer<QQuickWindow> m_window;
    QPointF m_last;
    bool m_haveLast = false;
    bool m_justWarped = false;
    bool m_active = false;
    bool m_seenPointer = false; // a real motion inside the window has arrived
    int m_failedWarps = 0;
    bool m_warpBroken = false;
    bool m_debug = false;
};
