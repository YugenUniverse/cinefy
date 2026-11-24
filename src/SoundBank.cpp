#include "SoundBank.h"

#include <QDir>
#include <QFile>
#include <QRandomGenerator>
#include <QSaveFile>
#include <QStandardPaths>
#include <QVector>
#include <QtEndian>

#include <cmath>
#include <functional>

namespace {

constexpr int Rate = 22050;
constexpr int Version = 3; // bump to regenerate after changing a sound
constexpr double Pi = 3.14159265358979323846;

void writeWav(const QString &path, const QVector<float> &samples)
{
    QByteArray pcm(samples.size() * 2, Qt::Uninitialized);
    auto *out = reinterpret_cast<qint16 *>(pcm.data());
    for (int i = 0; i < samples.size(); ++i)
        out[i] = qToLittleEndian(qint16(std::lround(std::clamp(samples[i], -1.0f, 1.0f) * 32000)));

    QByteArray header;
    auto u32 = [&header](quint32 v) { v = qToLittleEndian(v); header.append(reinterpret_cast<const char *>(&v), 4); };
    auto u16 = [&header](quint16 v) { v = qToLittleEndian(v); header.append(reinterpret_cast<const char *>(&v), 2); };
    header.append("RIFF");
    u32(36 + pcm.size());
    header.append("WAVEfmt ");
    u32(16);
    u16(1);        // PCM
    u16(1);        // mono
    u32(Rate);
    u32(Rate * 2); // bytes per second
    u16(2);        // block align
    u16(16);       // bits
    header.append("data");
    u32(pcm.size());

    QSaveFile file(path);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(header);
        file.write(pcm);
        file.commit();
    }
}

// Blend the tail into the head so a loop has no click.
QVector<float> seamless(QVector<float> s, int fade)
{
    const int n = s.size() - fade;
    for (int i = 0; i < fade; ++i) {
        const float t = float(i) / fade;
        s[i] = s[i] * t + s[n + i] * (1 - t);
    }
    s.resize(n);
    return s;
}

QVector<float> rain(bool muffled)
{
    auto *rng = QRandomGenerator::global();
    const int fade = Rate / 2;
    QVector<float> s(Rate * 8 + fade);
    float low = 0, lower = 0;
    for (float &v : s) {
        const float white = float(rng->generateDouble() * 2 - 1);
        low += 0.25f * (white - low);    // steady hiss
        lower += 0.03f * (low - lower);  // body
        v = muffled ? lower * 2.2f : low * 0.45f + lower * 0.9f;
    }
    // Individual drops: tiny pitched ticks (dull thuds when muffled).
    const int drops = muffled ? 120 : 900;
    for (int d = 0; d < drops; ++d) {
        const int at = int(rng->bounded(s.size()));
        const double freq = muffled ? 180 + rng->bounded(200) : 1500 + rng->bounded(3000);
        const float amp = float(muffled ? 0.08 : 0.04 + rng->generateDouble() * 0.08);
        const int len = Rate / (muffled ? 25 : 60);
        for (int i = 0; i < len && at + i < s.size(); ++i)
            s[at + i] += amp * float(std::sin(2 * Pi * freq * i / Rate) * std::exp(-8.0 * i / len));
    }
    return seamless(s, fade);
}

QVector<float> hum()
{
    // Mains hum of old fluorescent tubes: 100 Hz and harmonics, a little buzz.
    // Exactly two seconds of whole cycles, so it loops cleanly.
    auto *rng = QRandomGenerator::global();
    QVector<float> s(Rate * 2);
    for (int i = 0; i < s.size(); ++i) {
        const double t = double(i) / Rate;
        s[i] = float(0.30 * std::sin(2 * Pi * 100 * t) + 0.14 * std::sin(2 * Pi * 200 * t)
                     + 0.07 * std::sin(2 * Pi * 300 * t) + 0.03 * std::sin(2 * Pi * 1200 * t)
                     + 0.015 * (rng->generateDouble() * 2 - 1));
    }
    return s;
}

QVector<float> chime()
{
    // Ding-dong: two bell notes with inharmonic partials.
    QVector<float> s(int(Rate * 2.4));
    auto bell = [&s](double start, double freq) {
        const int at = int(start * Rate);
        for (int i = 0; at + i < s.size(); ++i) {
            const double t = double(i) / Rate;
            const double env = std::exp(-2.6 * t) * std::min(1.0, t * 400);
            s[at + i] += float(env * (0.45 * std::sin(2 * Pi * freq * t) + 0.2 * std::sin(2 * Pi * freq * 2.76 * t)
                                      + 0.08 * std::sin(2 * Pi * freq * 5.4 * t)));
        }
    };
    bell(0.0, 1318.5); // E6
    bell(0.42, 1046.5); // C6
    return s;
}

QVector<float> pickup()
{
    // A plastic VHS case: a sharp clack, a hollow thump, then the lid clicking.
    auto *rng = QRandomGenerator::global();
    QVector<float> s(int(Rate * 0.35));
    for (int i = 0; i < s.size(); ++i) {
        const double t = double(i) / Rate;
        double v = (rng->generateDouble() * 2 - 1) * std::exp(-t * 260) * 0.7;      // clack
        v += std::sin(2 * Pi * 170 * t) * std::exp(-t * 45) * 0.5;                   // thump
        const double tc = t - 0.14;
        if (tc > 0)
            v += (rng->generateDouble() * 2 - 1) * std::exp(-tc * 400) * 0.35;      // click
        s[i] = float(v);
    }
    return s;
}

// ---------------------------------------------------------------- radio music
// Three short, seamlessly looping tracks, synthesised note by note, then run
// through a "small radio speaker" filter. Notes that ring past the end of the
// loop wrap around to the start, so the loop has no seam.

double midiFreq(int note)
{
    return 440.0 * std::pow(2.0, (note - 69) / 12.0);
}

struct Track {
    QVector<float> s;
    double bpm;
    double beat() const { return 60.0 / bpm; }
    int at(double beats) const { return int(beats * beat() * Rate); }

    // Add a sound starting at `beats`; `voice(t)` gives the sample t seconds in.
    void add(double beats, double seconds, const std::function<double(double)> &voice, double gain)
    {
        const int start = at(beats), len = int(seconds * Rate), n = s.size();
        for (int i = 0; i < len; ++i)
            s[(start + i) % n] += float(gain * voice(double(i) / Rate));
    }
};

double ePiano(double f, double t)
{
    const double env = std::exp(-2.2 * t) * std::min(1.0, t * 200);
    const double trem = 1 + 0.15 * std::sin(2 * Pi * 4.5 * t);
    return env * trem * (std::sin(2 * Pi * f * t) + 0.3 * std::sin(4 * Pi * f * t) * std::exp(-6 * t)
                         + 0.08 * std::sin(6 * Pi * f * t));
}
double pad(double f, double t, double len)
{
    const double env = std::min(1.0, t / 0.4) * std::min(1.0, (len - t) / 0.5);
    auto tri = [](double x) { return 2 * std::abs(2 * (x - std::floor(x + 0.5))) - 1; };
    return env * 0.5 * (tri(f * t) + tri(f * 1.004 * t) + 0.5 * tri(f * 0.5 * t));
}
double bass(double f, double t)
{
    const double env = std::exp(-3.0 * t) * std::min(1.0, t * 300);
    return env * (std::sin(2 * Pi * f * t) + 0.25 * std::sin(4 * Pi * f * t));
}
double pluck(double f, double t) // soft square-ish arpeggio
{
    const double env = std::exp(-7.0 * t) * std::min(1.0, t * 400);
    return env * (std::sin(2 * Pi * f * t) + 0.33 * std::sin(6 * Pi * f * t) + 0.2 * std::sin(10 * Pi * f * t));
}
double kick(double t)
{
    const double f = 45 + 80 * std::exp(-30 * t);
    return std::exp(-9 * t) * std::sin(2 * Pi * f * t);
}
double noise()
{
    return QRandomGenerator::global()->generateDouble() * 2 - 1;
}
double snare(double t) { return std::exp(-18 * t) * (0.7 * noise() + 0.4 * std::sin(2 * Pi * 185 * t)); }
double hat(double t) { return std::exp(-60 * t) * noise(); }
double brush(double t) { return std::sin(Pi * std::min(1.0, t / 0.18)) * noise() * 0.6; }

// Small speaker: no deep bass, no sparkle, a little hiss and crackle.
QVector<float> radioSpeaker(QVector<float> s, double crackle)
{
    float lp = 0, lp2 = 0, hpIn = 0, hpOut = 0, peak = 0;
    for (float &v : s) {
        lp += 0.42f * (v - lp);
        lp2 += 0.42f * (lp - lp2);
        hpOut = 0.93f * (hpOut + lp2 - hpIn); // ~250 Hz high-pass
        hpIn = lp2;
        v = hpOut + float(0.004 * noise());
        if (QRandomGenerator::global()->generateDouble() < crackle)
            v += float(0.08 * noise());
        peak = std::max(peak, std::abs(v));
    }
    for (float &v : s)
        v *= 0.8f / std::max(peak, 0.001f);
    return s;
}

QVector<float> lofi()
{
    Track tr{QVector<float>(int(32 * 60.0 / 78 * Rate)), 78}; // 8 bars
    const int chords[4][4] = {{53, 57, 60, 64}, {52, 55, 59, 62}, {50, 53, 57, 60}, {48, 52, 55, 59}};
    const int melody[16] = {72, 0, 69, 67, 71, 0, 67, 64, 69, 0, 65, 64, 67, 0, 64, 62};
    for (int bar = 0; bar < 8; ++bar) {
        const auto &c = chords[bar / 2];
        const double b0 = bar * 4;
        for (double hit : {0.0, 2.5}) // electric piano stabs
            for (int n : c)
                tr.add(b0 + hit, 2.2, [n](double t) { return ePiano(midiFreq(n), t); }, 0.09);
        tr.add(b0, 1.6, [c](double t) { return bass(midiFreq(c[0] - 12), t); }, 0.32);
        tr.add(b0 + 2, 1.4, [c](double t) { return bass(midiFreq(c[0] - 12), t); }, 0.26);
        if (bar % 2 == 0) // a lazy melody every other bar
            for (int i = 0; i < 4; ++i) {
                const int n = melody[(bar / 2) * 4 + i];
                if (n)
                    tr.add(b0 + i * 1.0 + 0.5, 1.2, [n](double t) { return ePiano(midiFreq(n), t); }, 0.13);
            }
        tr.add(b0, 0.4, kick, 0.55);
        tr.add(b0 + 2.5, 0.4, kick, 0.45);
        tr.add(b0 + 1, 0.3, snare, 0.25);
        tr.add(b0 + 3, 0.3, snare, 0.25);
        for (int e = 0; e < 8; ++e) // swung eighths
            tr.add(b0 + e * 0.5 + (e % 2 ? 0.08 : 0), 0.08, hat, e % 2 ? 0.06 : 0.09);
    }
    return radioSpeaker(tr.s, 0.0006);
}

QVector<float> synthwave()
{
    Track tr{QVector<float>(int(32 * 60.0 / 104 * Rate)), 104};
    const int chords[4][3] = {{57, 60, 64}, {53, 57, 60}, {48, 52, 55}, {55, 59, 62}}; // Am F C G
    for (int bar = 0; bar < 8; ++bar) {
        const auto &c = chords[bar / 2];
        const double b0 = bar * 4;
        if (bar % 2 == 0)
            for (int n : c) {
                const double len = 8 * tr.beat();
                tr.add(b0, len, [n, len](double t) { return pad(midiFreq(n), t, len); }, 0.06);
            }
        for (int k = 0; k < 16; ++k) { // sixteenth-note arpeggio
            const int n = c[k % 3] + 12 + (k % 6 >= 3 ? 12 : 0);
            tr.add(b0 + k * 0.25, 0.4, [n](double t) { return pluck(midiFreq(n), t); }, 0.07);
        }
        for (int e = 0; e < 8; ++e)
            tr.add(b0 + e * 0.5, 0.4, [c](double t) { return bass(midiFreq(c[0] - 24), t); }, 0.22);
        for (int q = 0; q < 4; ++q)
            tr.add(b0 + q, 0.4, kick, 0.5);
        tr.add(b0 + 1, 0.5, snare, 0.3);
        tr.add(b0 + 3, 0.5, snare, 0.3);
        for (int e = 0; e < 8; ++e)
            tr.add(b0 + e * 0.5 + 0.25, 0.06, hat, 0.07);
    }
    return radioSpeaker(tr.s, 0.0004);
}

QVector<float> jazz()
{
    Track tr{QVector<float>(int(32 * 60.0 / 66 * Rate)), 66};
    // Dm7 G7 Cmaj7 A7, two bars each, with a walking bass line.
    const int chords[4][4] = {{50, 53, 57, 60}, {55, 59, 62, 65}, {48, 52, 55, 59}, {57, 61, 64, 67}};
    const int walk[4][8] = {{38, 41, 45, 48, 50, 48, 45, 43}, {43, 47, 50, 53, 55, 53, 50, 49},
                            {36, 40, 43, 47, 48, 47, 43, 44}, {45, 49, 52, 55, 57, 55, 52, 50}};
    for (int bar = 0; bar < 8; ++bar) {
        const auto &c = chords[bar / 2];
        const double b0 = bar * 4;
        for (int q = 0; q < 4; ++q) {
            const int n = walk[bar / 2][(bar % 2) * 4 + q];
            tr.add(b0 + q, 0.9, [n](double t) { return bass(midiFreq(n), t); }, 0.3);
        }
        for (double hit : {0.0, 1.66, 3.33}) // laid-back comping
            for (int n : c)
                tr.add(b0 + hit, 1.8, [n](double t) { return ePiano(midiFreq(n + 12), t); }, 0.06);
        tr.add(b0 + 1, 0.3, brush, 0.12);
        tr.add(b0 + 3, 0.3, brush, 0.12);
        for (double r : {0.0, 1.0, 1.66, 2.0, 3.0, 3.66}) // swung ride
            tr.add(b0 + r, 0.5, [](double t) { return std::exp(-9 * t) * noise(); }, 0.035);
    }
    return radioSpeaker(tr.s, 0.0009);
}

QVector<float> tune()
{
    // Turning the dial: a burst of static.
    QVector<float> s(int(Rate * 0.35));
    for (int i = 0; i < s.size(); ++i) {
        const double t = double(i) / Rate;
        s[i] = float(noise() * 0.35 * std::sin(Pi * t / 0.35) * (0.6 + 0.4 * std::sin(2 * Pi * 31 * t)));
    }
    return s;
}

QVector<float> door()
{
    // Automatic sliding door: a soft rising whoosh of filtered noise and a
    // faint motor hum, about a second long.
    auto *rng = QRandomGenerator::global();
    QVector<float> s(int(Rate * 1.1));
    float low = 0;
    for (int i = 0; i < s.size(); ++i) {
        const double t = double(i) / Rate;
        const double env = std::sin(Pi * std::min(1.0, t / 1.1));
        const float k = float(0.04 + 0.12 * env);
        low += k * (float(rng->generateDouble() * 2 - 1) - low);
        s[i] = float(env * (low * 1.6 + 0.05 * std::sin(2 * Pi * 95 * t)));
    }
    return s;
}

} // namespace

SoundBank::SoundBank(QObject *parent) : QObject(parent)
{
    m_dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/sounds");
    QDir().mkpath(m_dir);
    const QList<QPair<QString, std::function<QVector<float>()>>> sounds = {
        {QStringLiteral("rain"), [] { return rain(false); }},
        {QStringLiteral("rain-muffled"), [] { return rain(true); }},
        {QStringLiteral("hum"), hum},
        {QStringLiteral("chime"), chime},
        {QStringLiteral("pickup"), pickup},
        {QStringLiteral("door"), door},
        {QStringLiteral("radio-lofi"), lofi},
        {QStringLiteral("radio-synthwave"), synthwave},
        {QStringLiteral("radio-jazz"), jazz},
        {QStringLiteral("tune"), tune},
    };
    for (const auto &[name, make] : sounds) {
        const QString path = QStringLiteral("%1/%2-v%3.wav").arg(m_dir, name).arg(Version);
        if (!QFile::exists(path))
            writeWav(path, make());
    }
}

QUrl SoundBank::url(const QString &name) const
{
    return QUrl::fromLocalFile(QStringLiteral("%1/%2-v%3.wav").arg(m_dir, name).arg(Version));
}
