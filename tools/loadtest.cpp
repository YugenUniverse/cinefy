// Loads a Letterboxd export and prints what was found. Usage: cinefy_loadtest export.zip
#include "ExportLoader.h"

#include <QCoreApplication>
#include <QTextStream>

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    QTextStream out(stdout);
    if (argc < 2) {
        out << "usage: cinefy_loadtest <letterboxd-export.zip>\n";
        return 2;
    }
    Library lib;
    QString error;
    if (!ExportLoader::load(QString::fromLocal8Bit(argv[1]), lib, &error)) {
        out << "error: " << error << "\n";
        return 1;
    }
    int watched = 0, watchlist = 0, rated = 0, liked = 0, favs = 0, diary = 0, reviews = 0;
    for (const Film &f : lib.films) {
        watched += f.watched;
        watchlist += f.inWatchlist;
        rated += f.rating > 0;
        liked += f.liked;
        favs += f.favourite;
        diary += int(f.diary.size());
        reviews += int(f.reviews.size());
    }
    out << "member:    " << lib.username << " (joined " << lib.joined.toString(Qt::ISODate) << ")\n"
        << "films:     " << lib.films.size() << "\n"
        << "watched:   " << watched << "\n"
        << "watchlist: " << watchlist << "\n"
        << "rated:     " << rated << "\n"
        << "liked:     " << liked << "\n"
        << "favourite: " << favs << "\n"
        << "diary:     " << diary << "\n"
        << "reviews:   " << reviews << "\n";
    for (const auto &l : lib.lists)
        out << "list:      " << l.name << " (" << l.films.size() << " films)\n";
    return 0;
}
