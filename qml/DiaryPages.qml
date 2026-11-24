import QtQuick
import QtQuick.Layouts

// The two open pages of the rental ledger, drawn onto the diary you hold in
// the game (so it's driven by keys, not clicks). Left: years, months and a
// summary; right: the chosen month's rentals with one selected.
Item {
    id: pages
    width: 1600
    height: 1000

    property var entries: []
    property var years: []
    property int year: 0
    property int month: 0
    property int selected: 0
    property int hovered: -1   // row under the pointer
    property string hoveredArrow: ""
    readonly property var monthEntries: entries.filter(e => e.yearNum === year && e.monthNum === month)
    readonly property var selectedEntry: monthEntries.length > 0 ? monthEntries[Math.min(selected, monthEntries.length - 1)] : null
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July",
                                       "August", "September", "October", "November", "December"]
    readonly property var monthBest: {
        let b = null
        for (const e of monthEntries)
            if (!b || e.rating > b.rating) b = e
        return b
    }
    readonly property var weekdayNames: ["", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    readonly property var yearEntries: entries.filter(e => e.yearNum === year)
    readonly property var yearStats: {
        const list = yearEntries
        const rated = list.filter(e => e.rating > 0)
        let busiest = "–", most = 0
        for (let m = 1; m <= 12; ++m) {
            const n = list.filter(e => e.monthNum === m).length
            if (n > most) { most = n; busiest = monthNames[m - 1].slice(0, 3) }
        }
        // Longest run of consecutive days with a film.
        const days = [...new Set(list.map(e => e.julian))].sort((a, b) => a - b)
        let streak = days.length > 0 ? 1 : 0, run = 1
        for (let i = 1; i < days.length; ++i) {
            run = days[i] === days[i - 1] + 1 ? run + 1 : 1
            streak = Math.max(streak, run)
        }
        return {
            count: list.length,
            avg: rated.length ? rated.reduce((a, e) => a + e.rating, 0) / rated.length : 0,
            rewatches: list.filter(e => e.rewatch).length,
            busiest: busiest,
            streak: streak,
        }
    }
    function mostCommon(values) {
        const counts = {}
        let best = "–", top = 0
        for (const v of values) {
            counts[v] = (counts[v] || 0) + 1
            if (counts[v] > top) { top = counts[v]; best = v }
        }
        return best
    }
    readonly property var monthHistogram: {
        const bins = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        for (const e of monthEntries)
            if (e.rating > 0) bins[Math.min(9, Math.round(e.rating * 2) - 1)]++
        return bins
    }
    readonly property string monthWeekday: {
        const d = mostCommon(monthEntries.map(e => e.weekdayNum).filter(n => n > 0))
        return d === "–" ? d : weekdayNames[d]
    }
    readonly property string monthGenre: {
        const all = []
        for (const e of monthEntries) for (const g of (e.genres || [])) all.push(g)
        return mostCommon(all)
    }
    readonly property real monthAverage: {
        const rated = monthEntries.filter(e => e.rating > 0)
        return rated.length ? rated.reduce((a, e) => a + e.rating, 0) / rated.length : 0
    }

    function load() {
        entries = shop.diary()
        const ys = []
        for (const e of entries)
            if (e.yearNum > 0 && ys.indexOf(e.yearNum) < 0) ys.push(e.yearNum)
        years = ys.sort()
        if (entries.length > 0 && year === 0) {
            year = entries[0].yearNum
            month = entries[0].monthNum
        }
        selected = 0
    }
    function countFor(y, m) {
        let n = 0
        for (const e of entries)
            if (e.yearNum === y && e.monthNum === m) ++n
        return n
    }
    // Months with rentals, newest first.
    function activeMonths() {
        const seen = []
        for (const e of entries) {
            const key = e.yearNum * 100 + e.monthNum
            if (e.yearNum > 0 && seen.indexOf(key) < 0) seen.push(key)
        }
        return seen
    }
    function stepMonth(delta) {
        const list = activeMonths()
        const j = list.indexOf(year * 100 + month) - delta
        if (j >= 0 && j < list.length) {
            year = Math.floor(list[j] / 100)
            month = list[j] % 100
            selected = 0
        }
    }
    function stepYear(delta) {
        const i = years.indexOf(year) + delta
        if (i < 0 || i >= years.length)
            return
        year = years[i]
        for (const e of entries)
            if (e.yearNum === year) { month = e.monthNum; break }
        selected = 0
    }
    function moveSelection(delta) {
        selected = Math.max(0, Math.min(monthEntries.length - 1, selected + delta))
        list.positionViewAtIndex(selected, ListView.Contain)
    }

    // ---- pointer input, in page pixels (the 3D book maps the mouse here) ----
    function hit(item, px, py) {
        if (!item || !item.visible)
            return false
        const p = item.mapFromItem(pages, px, py)
        return p.x >= 0 && p.y >= 0 && p.x < item.width && p.y < item.height
    }
    function rowAt(px, py) {
        if (!hit(list, px, py))
            return -1
        const p = list.mapFromItem(pages, px, py)
        return list.indexAt(p.x, p.y + list.contentY)
    }
    // Returns the film to open (on a second click of a rental), or -1.
    function clickAt(px, py) {
        for (let i = 0; i < yearTabs.count; ++i)
            if (hit(yearTabs.itemAt(i), px, py)) {
                const d = years[i] > year ? 1 : -1
                while (years[i] !== year) stepYear(d)
                return -1
            }
        for (let m = 0; m < monthCells.count; ++m)
            if (hit(monthCells.itemAt(m), px, py)) {
                if (countFor(year, m + 1) > 0) {
                    month = m + 1
                    selected = 0
                }
                return -1
            }
        if (hit(prevArrow, px, py)) { stepMonth(-1); return -1 }
        if (hit(nextArrow, px, py)) { stepMonth(1); return -1 }
        const r = rowAt(px, py)
        if (r >= 0) {
            if (r === selected)
                return monthEntries[r].index
            selected = r
        }
        return -1
    }
    function hoverAt(px, py) {
        hovered = rowAt(px, py)
        hoveredArrow = hit(prevArrow, px, py) ? "prev" : hit(nextArrow, px, py) ? "next" : ""
    }
    function scrollBy(steps) { moveSelection(steps) }

    component Paper: Rectangle {
        color: "#f4efe0"
        Canvas { // faint ruled lines
            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d")
                ctx.strokeStyle = "rgba(90,120,170,0.18)"
                for (let y = 70; y < height; y += 36) {
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                }
            }
        }
    }
    component Ink: Text {
        color: "#22305f"
        font.family: Theme.body
    }

    Rectangle { anchors.fill: parent; color: "#1d2f6e" } // binder cover around the pages

    Paper { // ------------------------------------------------ left page
        id: left
        x: 14; y: 14
        width: parent.width / 2 - 38
        height: parent.height - 28
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 36
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                Ink {
                    text: "RENTAL LEDGER"
                    color: "#a3261f"
                    font.family: Theme.display
                    font.weight: Font.Black
                    font.pixelSize: 44
                    font.letterSpacing: 4
                }
                Item { Layout.fillWidth: true }
                Ink {
                    text: (shop.member.name || "") + "\n" + pages.entries.length + " rentals logged"
                    color: "#6b6450"
                    font.pixelSize: 19
                    horizontalAlignment: Text.AlignRight
                }
            }
            Row { // year tabs
                spacing: 10
                Repeater {
                    id: yearTabs
                    model: pages.years
                    Rectangle {
                        required property int modelData
                        width: 110; height: 46; radius: 6
                        color: pages.year === modelData ? "#22305f" : "#ebe3cc"
                        border.color: "#22305f"
                        border.width: 2
                        Ink {
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: pages.year === parent.modelData ? "#f4efe0" : "#22305f"
                            font.weight: Font.Bold
                            font.pixelSize: 24
                        }
                    }
                }
            }
            RowLayout { // the year at a glance
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: [
                        [pages.yearStats.count, "FILMS"],
                        [pages.yearStats.avg > 0 ? pages.yearStats.avg.toFixed(1) + "★" : "–", "AVERAGE"],
                        [pages.yearStats.rewatches, "REWATCHED"],
                        [pages.yearStats.streak + (pages.yearStats.streak === 1 ? " day" : " days"), "BEST STREAK"],
                        [pages.yearStats.busiest, "BUSIEST MONTH"],
                    ]
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 82
                        radius: 6
                        color: "#f8f3e4"
                        border.color: "#22305f"
                        border.width: 2
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Ink {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.modelData[0]
                                font.family: Theme.display
                                font.weight: Font.Black
                                font.pixelSize: 28
                            }
                            Ink {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: parent.parent.modelData[1]
                                color: "#a3261f"
                                font.weight: Font.Black
                                font.pixelSize: 13
                                font.letterSpacing: 1
                            }
                        }
                    }
                }
            }
            GridLayout { // the twelve months
                Layout.fillWidth: true
                columns: 6
                rowSpacing: 10
                columnSpacing: 10
                Repeater {
                    id: monthCells
                    model: 12
                    Rectangle {
                        id: cell
                        required property int index
                        readonly property int count: pages.year > 0 ? pages.countFor(pages.year, index + 1) : 0
                        readonly property bool current: pages.month === index + 1
                        Layout.fillWidth: true
                        Layout.preferredHeight: 74
                        radius: 8
                        color: current ? "#22305f" : Qt.rgba(0.64, 0.15, 0.12, Math.min(0.55, count * 0.035))
                        border.color: current ? "#22305f" : "#cfc6ad"
                        border.width: 2
                        opacity: count > 0 ? 1 : 0.45
                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Ink {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: pages.monthNames[cell.index].slice(0, 3).toUpperCase()
                                color: cell.current ? "#f4efe0" : "#22305f"
                                font.weight: Font.Black
                                font.pixelSize: 20
                            }
                            Ink {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cell.count > 0 ? cell.count : "–"
                                color: cell.current ? "#f4efe0" : "#5b5446"
                                font.pixelSize: 18
                            }
                        }
                    }
                }
            }
            Rectangle { // the chosen month
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: "#ebe3cc"
                border.color: "#cfc6ad"
                border.width: 2
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Ink {
                            text: pages.month > 0 ? (pages.monthNames[pages.month - 1] + " " + pages.year).toUpperCase() : ""
                            color: "#a3261f"
                            font.weight: Font.Black
                            font.pixelSize: 26
                            font.letterSpacing: 3
                        }
                        Item { Layout.fillWidth: true }
                        Ink {
                            text: pages.monthEntries.length + " rentals"
                                  + (pages.monthAverage > 0 ? "  ·  " + pages.monthAverage.toFixed(1) + "★ avg" : "")
                            font.pixelSize: 20
                            font.weight: Font.Bold
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 22
                        // How you rated this month, as a little bar chart.
                        Column {
                            Layout.alignment: Qt.AlignTop
                            spacing: 6
                            Ink { text: "HOW YOU RATED"; color: "#6b6450"; font.weight: Font.Black; font.pixelSize: 15; font.letterSpacing: 2 }
                            Row {
                                id: hist
                                readonly property var bars: pages.monthHistogram
                                readonly property int peak: Math.max(1, ...bars)
                                height: 200
                                spacing: 6
                                Repeater {
                                    model: hist.bars
                                    Column {
                                        required property int modelData
                                        required property int index
                                        anchors.bottom: parent.bottom
                                        spacing: 3
                                        Rectangle {
                                            width: 28
                                            height: Math.max(3, 170 * modelData / hist.peak)
                                            radius: 3
                                            color: modelData > 0 ? "#c98a00" : "#d8cfb6"
                                        }
                                        Ink {
                                            width: 28
                                            horizontalAlignment: Text.AlignHCenter
                                            text: index % 2 === 1 ? ((index + 1) / 2) + "★" : ""
                                            color: "#8a8270"
                                            font.pixelSize: 14
                                        }
                                    }
                                }
                            }
                        }
                        // Pick of the month, with a red stamp.
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: pages.monthBest !== null
                            Rectangle {
                                id: pickPoster
                                width: 110; height: 165
                                color: "#1b1b1d"
                                rotation: -3
                                Image {
                                    anchors.fill: parent
                                    source: pages.monthBest ? pages.monthBest.poster.replace("/w92/", "/w185/") : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
                            Column {
                                anchors { left: pickPoster.right; leftMargin: 16; right: parent.right; top: parent.top; topMargin: 6 }
                                spacing: 6
                                Ink { text: "PICK OF THE MONTH"; color: "#6b6450"; font.weight: Font.Black; font.pixelSize: 15; font.letterSpacing: 2 }
                                Ink {
                                    width: parent.width
                                    text: pages.monthBest ? pages.monthBest.name : ""
                                    font.weight: Font.Bold
                                    font.pixelSize: 26
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }
                                Ink {
                                    text: pages.monthBest ? Theme.stars(pages.monthBest.rating) : ""
                                    color: "#c98a00"
                                    font.pixelSize: 26
                                }
                                Item { width: 1; height: 50 }
                                Ink {
                                    text: "Favourite day: <b>" + pages.monthWeekday + "</b>"
                                    textFormat: Text.StyledText
                                    font.pixelSize: 19
                                }
                                Ink {
                                    text: "Top genre: <b>" + pages.monthGenre + "</b>"
                                    textFormat: Text.StyledText
                                    font.pixelSize: 19
                                }
                                Ink {
                                    text: pages.monthEntries.filter(e => e.rewatch).length + " rewatched  ·  "
                                          + pages.monthEntries.filter(e => e.liked).length + " ♥ liked"
                                    font.pixelSize: 19
                                }
                            }
                            Rectangle { // rubber stamp
                                anchors { left: pickPoster.left; leftMargin: 30; top: pickPoster.bottom; topMargin: -26 }
                                width: stampText.implicitWidth + 22
                                height: 40
                                rotation: -12
                                radius: 4
                                color: "transparent"
                                border.color: "#c0322a"
                                border.width: 4
                                opacity: 0.85
                                Ink {
                                    id: stampText
                                    anchors.centerIn: parent
                                    text: "STAFF FAVE"
                                    color: "#c0322a"
                                    font.family: Theme.display
                                    font.weight: Font.Black
                                    font.pixelSize: 20
                                    font.letterSpacing: 2
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Column { // binder rings
        anchors.centerIn: parent
        spacing: (parent.height - 7 * 34) / 7
        Repeater {
            model: 7
            Rectangle {
                width: 56; height: 34; radius: 17
                color: "transparent"
                border.color: "#c3c6cc"
                border.width: 8
            }
        }
    }

    Paper { // ------------------------------------------------ right page
        x: parent.width / 2 + 24; y: 14
        width: parent.width / 2 - 38
        height: parent.height - 28

        Ink {
            id: pageHead
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 28 }
            horizontalAlignment: Text.AlignHCenter
            text: pages.month > 0 ? pages.monthNames[pages.month - 1] + " " + pages.year : ""
            font.family: Theme.display
            font.weight: Font.Black
            font.pixelSize: 42
        }
        component Arrow: Rectangle {
            property string glyph
            property bool lit: false
            width: 64; height: 64; radius: 32
            color: lit ? "#22305f" : "transparent"
            border.color: "#22305f"
            border.width: 3
            Ink {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -3
                text: parent.glyph
                color: parent.lit ? "#f4efe0" : "#22305f"
                font.pixelSize: 44
                font.bold: true
            }
        }
        Arrow { id: prevArrow; glyph: "‹"; lit: pages.hoveredArrow === "prev"; x: 30; anchors.verticalCenter: pageHead.verticalCenter }
        Arrow { id: nextArrow; glyph: "›"; lit: pages.hoveredArrow === "next"; anchors.right: parent.right; anchors.rightMargin: 30; anchors.verticalCenter: pageHead.verticalCenter }
        Ink { // pencilled note at the foot of the page
            anchors { right: parent.right; bottom: parent.bottom; margins: 18 }
            text: "click a film twice to open it  ·  J, Esc or click outside to close"
            color: "#9a9282"
            font.italic: true
            font.pixelSize: 20
        }
        ListView {
            id: list
            anchors { left: parent.left; right: parent.right; top: pageHead.bottom; bottom: parent.bottom; margins: 26; topMargin: 24; bottomMargin: 56 }
            clip: true
            interactive: false
            model: pages.monthEntries
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                width: list.width
                height: 108
                radius: 6
                color: index === pages.selected ? "#e3d39e" : index === pages.hovered ? "#ece2c6" : "transparent"
                border.color: index === pages.selected ? "#a3261f" : "transparent"
                border.width: 3
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 1
                    color: "#d8cfb6"
                }
                Column {
                    id: dayCol
                    x: 10; width: 74
                    anchors.verticalCenter: parent.verticalCenter
                    Ink {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: row.modelData.dayNum
                        color: "#a3261f"
                        font.pixelSize: 44
                        font.italic: true
                        font.weight: Font.Bold
                    }
                    Ink {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: row.modelData.weekday.toUpperCase()
                        color: "#8a8270"
                        font.pixelSize: 16
                    }
                }
                Rectangle {
                    id: thumb
                    anchors { left: dayCol.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    width: 62; height: 92
                    color: "#1b1b1d"
                    Image {
                        anchors.fill: parent
                        source: row.modelData.poster
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
                Column {
                    anchors { left: thumb.right; leftMargin: 18; right: marks.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Ink {
                        width: parent.width
                        text: row.modelData.name
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Ink {
                        text: (row.modelData.year > 0 ? row.modelData.year : "") + (row.modelData.isTv ? "  ·  TV series" : "")
                        color: "#8a8270"
                        font.pixelSize: 19
                    }
                }
                Row {
                    id: marks
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    spacing: 12
                    Rectangle { // red ink stamp
                        visible: row.modelData.rewatch
                        anchors.verticalCenter: parent.verticalCenter
                        width: rwStamp.implicitWidth + 14
                        height: 30
                        rotation: -8
                        radius: 3
                        color: "transparent"
                        border.color: "#c0322a"
                        border.width: 3
                        opacity: 0.85
                        Ink { id: rwStamp; anchors.centerIn: parent; text: "REWATCH"; color: "#c0322a"; font.weight: Font.Black; font.pixelSize: 15; font.letterSpacing: 1 }
                    }
                    Ink { visible: row.modelData.liked; text: "♥"; color: "#e0436e"; font.pixelSize: 28 }
                    Ink {
                        width: 130
                        horizontalAlignment: Text.AlignRight
                        text: Theme.stars(row.modelData.rating)
                        color: "#c98a00"
                        font.pixelSize: 27
                    }
                }
            }
            Ink {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "No rentals this month."
                color: "#8a8270"
                font.pixelSize: 26
                font.italic: true
            }
        }
    }
}
