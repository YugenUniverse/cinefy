#pragma once

#include "Film.h"

#include <QString>

namespace ExportLoader {

// Reads a Letterboxd data export (.zip) and merges every CSV into one
// Library. Returns false and fills `error` with a readable message on failure.
bool load(const QString &zipPath, Library &out, QString *error);

} // namespace ExportLoader
