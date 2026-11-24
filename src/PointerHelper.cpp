#include "PointerHelper.h"

#include <QCursor>
#include <QDebug>
#include <QGuiApplication>
#include <QMouseEvent>
#include <QQuickItem>
#include <QQuickWindow>

#include <cmath>

PointerHelper::PointerHelper(QObject *parent) : QObject(parent)
{
    // CINEFY_DEBUG_MOUSE=1 prints what the mouse look sees, for bug reports.
    m_debug = qEnvironmentVariableIsSet("CINEFY_DEBUG_MOUSE");
}

bool PointerHelper::canWarp() const
{
    return QGuiApplication::platformName() != QLatin1String("wayland") && !m_warpBroken;
}

bool PointerHelper::windowReady() const
{
    return m_window && m_window->isExposed() && m_window->isActive();
}

void PointerHelper::setActive(bool active)
{
    if (active == m_active)
        return;
    m_active = active;
    m_haveLast = false; // the next real motion sets the starting point
    if (m_debug)
        qInfo() << "mouse: active" << active << "seenPointer" << m_seenPointer;
    if (active)
        recenter();
    emit activeChanged();
}

void PointerHelper::attach(QQuickItem *item)
{
    QQuickWindow *window = item ? item->window() : nullptr;
    if (window == m_window)
        return;
    if (m_window)
        m_window->removeEventFilter(this);
    m_window = window;
    if (m_window)
        m_window->installEventFilter(this);
}

void PointerHelper::recenter()
{
    // Only once the pointer is known to be inside a shown, focused window:
    // warping earlier (while the compositor is still placing the window) can
    // throw the pointer outside it, and then no motion arrives at all.
    if (!canWarp() || !m_seenPointer || !windowReady())
        return;
    const QPointF centre(m_window->width() / 2.0, m_window->height() / 2.0);
    QCursor::setPos(m_window->screen(), m_window->mapToGlobal(centre).toPoint());
    m_last = centre;
    m_haveLast = true;
    m_justWarped = true;
    if (m_debug)
        qInfo() << "mouse: warp to centre" << centre;
}

bool PointerHelper::eventFilter(QObject *watched, QEvent *event)
{
    if (watched != m_window)
        return false;
    if (m_debug) {
        const auto t = event->type();
        if (t == QEvent::Enter || t == QEvent::Leave || t == QEvent::FocusIn || t == QEvent::FocusOut
            || t == QEvent::HoverMove || t == QEvent::WindowActivate || t == QEvent::WindowDeactivate)
            qInfo() << "mouse: window event" << t;
    }
    if (event->type() == QEvent::FocusIn && m_active) {
        m_haveLast = false;
        return false;
    }
    if (event->type() != QEvent::MouseMove)
        return false;

    const QPointF pos = static_cast<QMouseEvent *>(event)->position();
    const bool firstEver = !m_seenPointer;
    m_seenPointer = true;
    if (!m_haveLast) {
        m_last = pos;
        m_haveLast = true;
        if (m_debug)
            qInfo() << "mouse: start at" << pos << (firstEver ? "(first motion)" : "");
        if (m_active && firstEver)
            recenter();
        return false;
    }
    const QPointF d = pos - m_last;
    m_last = pos;
    const bool afterWarp = m_justWarped;
    m_justWarped = false;
    const bool jump = std::abs(d.x()) > 250 || std::abs(d.y()) > 250;

    if (afterWarp) {
        // Did the warp land? If the pointer keeps not being where we put it,
        // stop warping and let the edge-turn fallback take over.
        if (jump) {
            if (++m_failedWarps >= 3 && !m_warpBroken) {
                m_warpBroken = true;
                if (m_debug)
                    qInfo() << "mouse: warping doesn't work here, using edge turning";
                emit canWarpChanged();
            }
        } else {
            m_failedWarps = 0;
        }
    }
    if (m_debug)
        qInfo() << "mouse: move" << pos << "delta" << d << (jump ? "(ignored jump)" : "") << (afterWarp ? "(after warp)" : "");
    if (m_active && !jump)
        emit moved(d.x(), d.y());

    if (m_active && canWarp() && !afterWarp) {
        const QPointF centre(m_window->width() / 2.0, m_window->height() / 2.0);
        if (std::abs(pos.x() - centre.x()) > 80 || std::abs(pos.y() - centre.y()) > 80)
            recenter();
    }
    return false; // the scene still gets the event (clicks, hover)
}
