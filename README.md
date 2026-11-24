# Cinefy Video

A retro video rental shop for your Letterboxd films. A C++ / Qt 6 desktop app.

Insert your Letterboxd data export and walk into a 3D video store. The city around it
is drawn in ASCII characters (even through the door from inside); the shop itself is
drawn clear: a realistic 90s store where every tape stands face-out showing its real
cover. Each aisle has its own short shelving units, with gaps between aisles.

The aisles are Most Rented (your most rewatched films), Staff Picks, Liked Films, New Releases, Coming Soon (your watchlist), Box
Sets (TV series Letterboxd lists as films), your lists, genres, Cult Classics, the Bargain
Bin and Every Tape A–Z. Aim at a tape and click to pick it up: flip the case, see your
rental history, ratings and reviews. Your favourite films' backdrops hang on the walls,
fill the shop windows and play on the TV by the counter. Your most watched films hang
in a "Most Rented of All Time" hall of fame behind the counter. Your 5-star and reviewed
films get handwritten staff-pick cards on the shelf, and your ten latest watches lie in the
night drop by the door. It rains on the street; you hear it (muffled once you're inside),
along with the fluorescent hum, the door bell and the clack of picking up a tape. Sounds
are synthesised on first launch, no recordings.

A radio on the counter plays three synthesised stations (lo-fi, synthwave, late-night jazz);
aim at it and click to change station. SOUND ON/OFF in the bottom bar mutes everything.

Baked lighting: on your membership card, BAKE LIGHTING ray-traces soft bounced light for the
room and shelves (a few seconds) and saves it for the current layout. If your library changes
the shelves, Cinefy goes back to live lighting until you bake again.

If a tape has the wrong cover, open it and press WRONG COVER? to pick the right film; your
choice is remembered.

Controls: WASD or arrows to walk, Shift to run, move the mouse to look (hold Alt to get
the pointer back for the buttons), click or E to pick up a tape, M for the store map (click an aisle to walk there), F to ask the clerk (search,
then walk to the tape). The bottom bar has Liked, Diary, Watchlist, Map, Membership card,
Outside, Eject and Exit. Ctrl+Q quits.

Cover art and wallpapers come from TMDB (a free API key is needed).

## Build

Needs **Qt 6.8 or newer** with Qt Quick 3D, Qt Multimedia and Qt Shader Tools, plus CMake.
Baked lighting needs Qt 6.10+ (on older Qt that one option is simply hidden).

### Linux and macOS

    make deps        # prints the install command for your system (pacman, apt, dnf, zypper, brew)
    make             # optimised release build (make debug: with debug info, in build-debug/)
    make run         # build and start   (make run EXPORT=path/to/letterboxd-export.zip)
    make install     # Linux: `cinefy` + launcher entry in ~/.local; macOS: Cinefy.app with Qt inside
    make help        # all targets (test, uninstall, clean, distclean, ...)

If your distro's Qt is older than 6.8 (e.g. Ubuntu 24.04), install Qt from
https://www.qt.io/download and point CMake at it:
`make CMAKE_PREFIX_PATH=~/Qt/6.10.0/gcc_64` (or export `CMAKE_PREFIX_PATH`).

### Windows

Install Qt 6.8+ with the Qt online installer (tick Qt Quick 3D, Qt Multimedia, Qt Shader
Tools) and Visual Studio 2022 (C++ workload). Then, in a "Developer PowerShell":

    cmake -S . -B build -DCMAKE_PREFIX_PATH=C:/Qt/6.10.0/msvc2022_64
    cmake --build build --config Release
    cmake --install build --config Release --prefix dist

`dist` then holds `cinefy.exe` with every Qt file it needs; zip it to share.

### Plain CMake (any platform)

    cmake -B build && cmake --build build

Get your export at letterboxd.com → Settings → Data → Export your data.
Get a TMDB key at https://www.themoviedb.org/settings/api. Paste it on the storefront
or the membership card, or set `TMDB_API_KEY`.

## Where things are stored

- `~/.config/cinefy/cinefy.conf`: TMDB key and last opened export
- `~/.cache/cinefy/matches.json`: TMDB lookups (each film is only looked up once)
- `~/.cache/cinefy/images/`: poster and backdrop cache (the shop works offline once stocked)

## Layout

- `src/`: C++. `ExportLoader` (zip and CSV parsing, merging), `FilmModel`/`AisleModel`
  (models for QML), `TmdbClient` and `MatchCache` (cover art lookup, films and TV),
  `StoreLayout` (where every shelf, tape and sign stands, collisions, picking),
  `CoverAtlas` (all covers in one texture), `TapeInstancing` (all tapes in one draw call),
  `Shop` (exposed to QML)
- `qml/`: `Store3D` (player, HUD), `Store3DInterior`, `Store3DStreet`, popups;
  `tape.vert/frag` (tape material), `ascii.frag` (the street's ASCII effect)
- `tools/loadtest.cpp`: `./build/cinefy_loadtest export.zip` prints what was parsed

The `.github/workflows/build.yml` workflow builds and packages Cinefy for Linux, Windows and
macOS on GitHub.

Dev aids: `CINEFY_SNAPSHOT=out.png` saves a screenshot after a few seconds and quits;
`CINEFY_START="x,z,yaw,pitch"` places you in the store; `CINEFY_NO_ASCII=1` turns the
street effect off; `CINEFY_BAKE=1` bakes lighting on start; `CINEFY_MUTE=1` starts silent
(snapshot and bake runs are always silent).

This product uses the TMDB API but is not endorsed or certified by TMDB.
