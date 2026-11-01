import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQml.Models
import "."

ApplicationWindow {
    id: win

    width: 1100
    height: 720
    minimumWidth: 480
    minimumHeight: 320
    visible: true
    color: "transparent"
    title: currentEditor ? qsTr("%1 - Notepads").arg(currentEditor.title) : "Notepads"

    Material.theme: Style.dark ? Material.Dark : Material.Light
    Material.accent: Style.accent
    Material.foreground: Style.text
    Material.background: Style.panel
    Material.roundedScale: Style.radius

    // The open tabs, in order. Each is a DocumentEditor made once and kept
    // alive, so its text and undo history survive switching tabs.
    property var docs: []
    property int current: -1
    readonly property var currentEditor: current >= 0 && current < docs.length ? docs[current] : null
    property int zoom: 100
    property bool sessionOwner: false
    property bool quitting: false
    property int sessionRevision: 0
    property int savedRevision: -1
    property var pendingSaves: ({})
    property int saveTag: 0
    readonly property bool modalOpen: confirm.opened || shortcutsOverlay.opened || settings.recording

    Component {
        id: editorComponent
        DocumentEditor {}
    }

    // Tabs

    function createDoc() {
        const doc = editorComponent.createObject(editorHost, {
            zoom: Qt.binding(() => win.zoom),
            contextMenu: editMenu
        })
        doc.anchors.fill = editorHost
        doc.visible = Qt.binding(() => win.currentEditor === doc)
        doc.edited.connect(() => win.sessionRevision++)
        doc.zoomRequested.connect(step => win.setZoom(win.zoom + step))
        return doc
    }

    function addDoc(doc) {
        docs = docs.concat([doc])
        current = docs.length - 1
        sessionRevision++
    }

    function newTab() {
        addDoc(createDoc())
        focusEditor()
    }

    function removeDoc(doc) {
        const index = docs.indexOf(doc)
        if (index < 0)
            return
        const remaining = docs.filter(d => d !== doc)
        let next = current
        if (index < current)
            next = current - 1
        else if (index === current)
            next = Math.min(index, remaining.length - 1)
        docs = remaining
        current = next
        doc.destroy()
        sessionRevision++
        if (docs.length === 0)
            newTab()
        focusEditor()
    }

    function selectTab(index) {
        if (index >= 0 && index < docs.length) {
            current = index
            focusEditor()
        }
    }

    function focusEditor() {
        Qt.callLater(() => {
            // A popup opened in the meantime keeps the focus.
            if (win.currentEditor && !settings.opened && !win.modalOpen && !findBar.activeFocus)
                win.currentEditor.focusText()
        })
    }

    function openPaths(paths, createMissing) {
        for (const path of paths) {
            const existing = docs.findIndex(d => d.filePath === path)
            if (existing >= 0) {
                current = existing
                continue
            }
            const reuse = currentEditor && !currentEditor.filePath && !currentEditor.modified && currentEditor.isEmpty()
            const doc = reuse ? currentEditor : createDoc()
            let error = doc.load(path, "")
            if (error && createMissing && !backend.readFile(path).ok && backend.readFile(path).missing) {
                // A file named on the command line that doesn't exist yet
                // opens empty and is created on the first save.
                doc.filePath = path
                error = ""
            }
            if (error) {
                if (!reuse)
                    doc.destroy()
                showMessage(error)
                continue
            }
            if (!reuse)
                addDoc(doc)
            addRecent(path)
        }
        focusEditor()
    }

    function addRecent(path) {
        const list = (Style.prefs.recentFiles || []).filter(p => p !== path)
        list.unshift(path)
        Style.prefs.recentFiles = list.slice(0, 10)
    }

    // Saving

    function saveDoc(doc, then) {
        if (!doc.filePath) {
            saveDocAs(doc, then)
            return
        }
        const error = doc.saveTo(doc.filePath)
        if (error) {
            showMessage(error)
            return
        }
        sessionRevision++
        if (then)
            then()
    }

    function saveDocAs(doc, then) {
        const tag = ++saveTag
        pendingSaves[tag] = { doc: doc, then: then }
        backend.saveDialog(doc.filePath || backend.suggestedPath(doc.title), tag)
    }

    function saveAll() {
        saveChain(docs.filter(d => d.modified), null)
    }

    function saveChain(list, done) {
        if (list.length === 0) {
            if (done)
                done()
            return
        }
        saveDoc(list[0], () => saveChain(list.slice(1), done))
    }

    function closeTab(doc) {
        if (!doc.modified) {
            removeDoc(doc)
            return
        }
        selectTab(docs.indexOf(doc))
        confirm.ask(qsTr("Save changes?"),
                    qsTr("Do you want to save your changes to %1?").arg(doc.title),
                    qsTr("Save"), qsTr("Don't save"),
                    () => saveDoc(doc, () => removeDoc(doc)),
                    () => removeDoc(doc))
    }

    function closeOthers(keep) {
        for (const doc of docs.slice())
            if (doc !== keep && !doc.modified)
                removeDoc(doc)
        selectTab(docs.indexOf(keep))
    }

    // Quitting and the session

    function requestQuit() {
        if (sessionOwner && Style.prefs.sessionSnapshot) {
            writeSession(true)
            finishQuit()
            return
        }
        const dirty = docs.filter(d => d.modified)
        if (dirty.length === 0) {
            finishQuit()
            return
        }
        confirm.ask(qsTr("Save changes?"),
                    qsTr("%n tab(s) have unsaved changes.", "", dirty.length),
                    qsTr("Save all"), qsTr("Don't save"),
                    () => saveChain(dirty, finishQuit),
                    finishQuit)
    }

    function finishQuit() {
        // With snapshots off, leave no stale session behind to restore later.
        if (sessionOwner && !Style.prefs.sessionSnapshot)
            backend.saveSession({ tabs: [] })
        quitting = true
        Qt.quit()
    }

    function writeSession(force) {
        if (!sessionOwner || !Style.prefs.sessionSnapshot)
            return
        if (!force && savedRevision === sessionRevision)
            return
        const error = backend.saveSession({ current: current, tabs: docs.map(d => d.snapshot()) })
        if (error)
            showMessage(error)
        else
            savedRevision = sessionRevision
    }

    function restoreSession() {
        const session = backend.loadSession()
        const tabs = session.tabs || []
        for (const state of tabs) {
            const doc = createDoc()
            if (doc.restore(state))
                docs = docs.concat([doc])
            else
                doc.destroy()
        }
        if (docs.length)
            current = Math.max(0, Math.min(session.current || 0, docs.length - 1))
    }

    // Find and replace

    function openFind(withReplace) {
        if (settings.opened)
            settings.close()
        const area = currentEditor ? currentEditor.area : null
        findBar.show(withReplace, area ? area.selectedText : "")
    }

    function findNext(backward, incremental) {
        const doc = currentEditor
        findBar.error = ""
        findBar.notFound = false
        if (!doc || findBar.query === "")
            return
        const area = doc.area
        const from = incremental ? area.selectionStart : backward ? area.selectionStart : area.selectionEnd
        const result = backend.find(area.textDocument, findBar.query, from, backward, findBar.options)
        if (result.error) {
            findBar.error = result.error
            return
        }
        findBar.notFound = result.start < 0
        if (result.start >= 0)
            area.select(result.start, result.end)
    }

    function replaceOne() {
        const doc = currentEditor
        if (!doc || findBar.query === "")
            return
        const area = doc.area
        if (area.selectionEnd > area.selectionStart) {
            const result = backend.replaceMatch(area.textDocument, area.selectionStart, area.selectionEnd,
                                                findBar.query, findBar.replacement, findBar.options)
            if (result.start >= 0)
                area.select(result.end, result.end)
        }
        findNext(false, false)
    }

    function replaceAll() {
        const doc = currentEditor
        if (!doc || findBar.query === "")
            return
        const count = backend.replaceAll(doc.area.textDocument, findBar.query, findBar.replacement, findBar.options)
        findBar.notFound = count === 0
        showMessage(qsTr("Replaced %n occurrence(s).", "", count))
    }

    // Everything else

    Binding {
        target: spellChecker
        property: "underline"
        value: Style.prefs.spellUnderline
    }

    Connections {
        target: wheelZoom
        function onZoomBy(step) {
            if (!win.modalOpen)
                win.setZoom(win.zoom + step)
        }
    }

    function setZoom(value) {
        zoom = Math.max(10, Math.min(500, value))
    }

    function searchWeb() {
        const doc = currentEditor
        if (!doc || !doc.hasSelection)
            return
        const query = encodeURIComponent(doc.area.selectedText.replace(/\u2029/g, " ").trim())
        const engines = {
            google: "https://www.google.com/search?q=",
            bing: "https://www.bing.com/search?q=",
            duckduckgo: "https://duckduckgo.com/?q="
        }
        Qt.openUrlExternally((engines[Style.prefs.searchEngine] || engines.google) + query)
    }

    function togglePreview() {
        if (currentEditor && currentEditor.markdown)
            currentEditor.previewVisible = !currentEditor.previewVisible
    }

    function showMessage(text) {
        toast.text = text
        toast.opacity = 1
        toastTimer.restart()
    }

    onClosing: close => {
        if (!quitting) {
            close.accepted = false
            requestQuit()
        }
    }

    onCurrentChanged: {
        tabList.positionViewAtIndex(current, ListView.Contain)
        if (findBar.visible) {
            findBar.notFound = false
            findBar.error = ""
        }
    }

    Component.onCompleted: {
        sessionOwner = backend.claimSession()
        if (sessionOwner && Style.prefs.sessionSnapshot)
            restoreSession()
        const files = backend.startupFiles()
        if (files.length)
            openPaths(files, true)
        if (docs.length === 0)
            newTab()
        savedRevision = sessionRevision
        applyGlobalShortcut()
        focusEditor()
    }

    // Writes the desktop-wide shortcut to Hyprland the first time, and again
    // whenever the setting and what Hyprland has drifted apart.
    function applyGlobalShortcut() {
        const wanted = Style.prefs.globalShortcut
        if (wanted === Style.prefs.appliedShortcut) {
            // Bring a binding written by an older version up to date.
            const error = wanted ? globalShortcut.refresh(wanted) : ""
            if (error)
                showMessage(error)
            return
        }
        const taken = wanted ? globalShortcut.conflict(wanted) : ""
        if (taken) {
            showMessage(qsTr("%1 is already used by \"%2\", so Notepads didn't take it. Pick a key in Settings > Advanced.")
                        .arg(globalShortcut.displayName(wanted)).arg(taken))
            Style.prefs.globalShortcut = ""
            Style.prefs.appliedShortcut = ""
            return
        }
        const error = globalShortcut.apply(wanted)
        if (error)
            showMessage(error)
        else
            Style.prefs.appliedShortcut = wanted
    }

    Connections {
        target: backend

        function onFilesChosen(paths) {
            win.openPaths(paths, false)
        }

        function onSaveChosen(path, tag) {
            const pending = win.pendingSaves[tag]
            delete win.pendingSaves[tag]
            if (!pending || win.docs.indexOf(pending.doc) < 0)
                return
            const error = pending.doc.saveTo(path)
            if (error) {
                win.showMessage(error)
                return
            }
            win.addRecent(path)
            win.sessionRevision++
            if (pending.then)
                pending.then()
        }

        function onFailed(message) {
            win.showMessage(message)
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: win.sessionOwner && Style.prefs.sessionSnapshot
        onTriggered: win.writeSession(false)
    }

    // Shortcuts

    Shortcut { enabled: !win.modalOpen; sequences: ["Ctrl+N", "Ctrl+T"]; context: Qt.ApplicationShortcut; onActivated: win.newTab() }
    Shortcut { enabled: !win.modalOpen; sequence: "Ctrl+O"; context: Qt.ApplicationShortcut; onActivated: backend.openDialog(win.currentEditor && win.currentEditor.filePath ? backend.folderOf(win.currentEditor.filePath) : "") }
    Shortcut { enabled: !win.modalOpen; sequence: "Ctrl+S"; context: Qt.ApplicationShortcut; onActivated: if (win.currentEditor) win.saveDoc(win.currentEditor, null) }
    Shortcut { enabled: !win.modalOpen; sequence: "Ctrl+Shift+S"; context: Qt.ApplicationShortcut; onActivated: if (win.currentEditor) win.saveDocAs(win.currentEditor, null) }
    Shortcut { enabled: !win.modalOpen; sequence: "Ctrl+Alt+S"; context: Qt.ApplicationShortcut; onActivated: win.saveAll() }
    Shortcut { enabled: !win.modalOpen; sequences: ["Ctrl+W", "Ctrl+F4"]; context: Qt.ApplicationShortcut; onActivated: if (win.currentEditor) win.closeTab(win.currentEditor) }
    Shortcut { enabled: !win.modalOpen; sequences: ["Ctrl+Tab", "Ctrl+PgDown"]; context: Qt.ApplicationShortcut; onActivated: win.selectTab((win.current + 1) % win.docs.length) }
    Shortcut { enabled: !win.modalOpen; sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab", "Ctrl+PgUp"]; context: Qt.ApplicationShortcut; onActivated: win.selectTab((win.current - 1 + win.docs.length) % win.docs.length) }
    Shortcut { enabled: !win.modalOpen; sequence: "Ctrl+F"; context: Qt.ApplicationShortcut; onActivated: win.openFind(false) }
    Shortcut { enabled: !win.modalOpen; sequence: "Ctrl+H"; context: Qt.ApplicationShortcut; onActivated: win.openFind(true) }
    Shortcut { enabled: !win.modalOpen; sequence: "F3"; context: Qt.ApplicationShortcut; onActivated: findBar.visible ? win.findNext(false, false) : win.openFind(false) }
    Shortcut { enabled: !win.modalOpen; sequence: "Shift+F3"; context: Qt.ApplicationShortcut; onActivated: findBar.visible ? win.findNext(true, false) : win.openFind(false) }
    Shortcut { enabled: !win.modalOpen; sequences: ["Ctrl+=", "Ctrl++", "Ctrl+Shift+="]; context: Qt.ApplicationShortcut; onActivated: win.setZoom(win.zoom + 10) }
    Shortcut { enabled: !win.modalOpen; sequence: "Ctrl+-"; context: Qt.ApplicationShortcut; onActivated: win.setZoom(win.zoom - 10) }
    Shortcut { enabled: !win.modalOpen; sequence: "Ctrl+0"; context: Qt.ApplicationShortcut; onActivated: win.setZoom(100) }
    Shortcut { enabled: !win.modalOpen; sequence: "Alt+Z"; context: Qt.ApplicationShortcut; onActivated: Style.prefs.wrapWord = !Style.prefs.wrapWord }
    Shortcut { enabled: !win.modalOpen; sequence: "Alt+P"; context: Qt.ApplicationShortcut; onActivated: win.togglePreview() }
    Shortcut { enabled: !win.modalOpen; sequence: "Ctrl+E"; context: Qt.ApplicationShortcut; onActivated: win.searchWeb() }
    Shortcut {
        enabled: !win.modalOpen && Style.prefs.correctionShortcut !== ""
        sequence: settings.qtSequence(Style.prefs.correctionShortcut)
        context: Qt.ApplicationShortcut
        onActivated: if (win.currentEditor) win.currentEditor.acceptCorrection()
    }
    Shortcut { enabled: !win.modalOpen; sequence: "Ctrl+D"; context: Qt.ApplicationShortcut; onActivated: if (win.currentEditor) win.currentEditor.duplicateLine() }
    Shortcut { enabled: !win.modalOpen; sequence: "Ctrl+,"; context: Qt.ApplicationShortcut; onActivated: settings.opened ? settings.close() : settings.open() }
    Shortcut { enabled: !win.modalOpen; sequence: "F1"; context: Qt.ApplicationShortcut; onActivated: shortcutsOverlay.opened ? shortcutsOverlay.close() : shortcutsOverlay.open() }
    Shortcut { enabled: !win.modalOpen; sequence: "Ctrl+Q"; context: Qt.ApplicationShortcut; onActivated: win.requestQuit() }

    Instantiator {
        model: 9
        delegate: Shortcut {
            required property int index
            enabled: !win.modalOpen
            sequence: "Ctrl+" + (index + 1)
            context: Qt.ApplicationShortcut
            // Ctrl+9 goes to the last tab, as in browsers.
            onActivated: win.selectTab(index === 8 ? win.docs.length - 1 : index)
        }
    }

    // Layout. Right-to-left languages mirror the window; the Translator
    // sets the application's layout direction.
    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: drop => {
                const paths = drop.urls.map(url => backend.urlToPath(url)).filter(p => p !== "")
                if (paths.length) {
                    win.openPaths(paths, false)
                    drop.accept()
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // The tab strip. Each piece paints its own background so the
            // translucent layers never stack on top of each other.
            RowLayout {
                id: strip
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                // A layout inherits fillHeight from its children; the strip
                // must stay one row tall.
                Layout.fillHeight: false
                spacing: 0

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.fillHeight: true
                    color: Style.strip

                    IconButton {
                        id: menuButton
                        anchors.fill: parent
                        anchors.margins: 0
                        icon: "menu"
                        tip: qsTr("Menu")
                        onClicked: mainMenu.popup(menuButton, 0, menuButton.height)
                    }
                }

                ListView {
                    id: tabList
                    Layout.fillHeight: true
                    Layout.preferredWidth: Math.min(contentWidth, strip.width - 48 - 44)
                    orientation: ListView.Horizontal
                    model: win.docs
                    interactive: contentWidth > width
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    delegate: DocTab {
                        required property var modelData
                        required property int index
                        width: Math.max(120, Math.min(220, (strip.width - 48 - 44) / Math.max(1, win.docs.length)))
                        doc: modelData
                        active: index === win.current
                        onActivate: win.selectTab(index)
                        onCloseRequested: win.closeTab(modelData)
                        onMenuRequested: (x, y) => {
                            tabMenu.doc = modelData
                            tabMenu.popup(this, x, y)
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Style.strip

                    IconButton {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 44
                        icon: "add"
                        tip: qsTr("New tab (Ctrl+N)")
                        onClicked: win.newTab()
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.leftMargin: 44
                        onDoubleClicked: win.newTab()
                    }
                }
            }

            Rectangle {
                id: editorArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Style.activeTab

                Item {
                    id: editorHost
                    anchors.fill: parent
                }

                FindBar {
                    id: findBar
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 10
                    anchors.rightMargin: 22
                    z: 5
                    onFindRequested: (backward, incremental) => win.findNext(backward, incremental)
                    onReplaceRequested: win.replaceOne()
                    onReplaceAllRequested: win.replaceAll()
                    onClosed: win.focusEditor()
                }

                SettingsPanel {
                    id: settings
                    parent: editorArea
                    onClosed: win.focusEditor()
                }

                Rectangle {
                    id: toast
                    property alias text: toastLabel.text
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 16
                    width: Math.min(toastLabel.implicitWidth + 32, parent.width - 40)
                    height: toastLabel.implicitHeight + 18
                    radius: Style.smallRadius
                    color: Style.menu
                    border.color: Style.border
                    opacity: 0
                    visible: opacity > 0
                    z: 10
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Text {
                        id: toastLabel
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, toast.parent.width - 72)
                        color: Style.text
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: toast.opacity = 0
                    }

                    Timer {
                        id: toastTimer
                        interval: 5000
                        onTriggered: toast.opacity = 0
                    }
                }
            }

            Rectangle {
                id: statusBar
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                visible: Style.prefs.showStatusBar
                color: Style.status

                RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    StatusItem {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 40
                        text: win.currentEditor ? (win.currentEditor.filePath || win.currentEditor.title) : ""
                        elide: Text.ElideMiddle
                        clickable: win.currentEditor !== null && win.currentEditor.filePath !== ""
                        tip: clickable ? qsTr("Open containing folder") : ""
                        onClicked: Qt.openUrlExternally("file://" + backend.folderOf(win.currentEditor.filePath))
                    }
                    StatusItem {
                        visible: win.currentEditor !== null && win.currentEditor.modified
                        text: qsTr("Modified")
                        textColor: Style.danger
                    }
                    StatusItem {
                        text: win.currentEditor
                              ? qsTr("Ln %1, Col %2").arg(win.currentEditor.line).arg(win.currentEditor.column)
                                + (win.currentEditor.selectedCount > 0 ? " " + qsTr("(%1 selected)").arg(win.currentEditor.selectedCount) : "")
                              : ""
                    }
                    StatusItem {
                        text: win.zoom + "%"
                        clickable: true
                        tip: qsTr("Reset zoom (Ctrl+0)")
                        onClicked: win.setZoom(100)
                    }
                    StatusItem {
                        id: lineEndingItem
                        text: win.currentEditor ? Style.lineEndingName(win.currentEditor.lineEnding) : ""
                        clickable: true
                        tip: qsTr("Line ending")
                        onClicked: lineEndingMenu.popup(lineEndingItem, 0, -lineEndingMenu.implicitHeight)
                    }
                    StatusItem {
                        id: encodingItem
                        text: win.currentEditor ? Style.encodingName(win.currentEditor.encoding) : ""
                        clickable: true
                        tip: qsTr("Encoding")
                        onClicked: encodingMenu.popup(encodingItem, encodingItem.width - encodingMenu.width, -encodingMenu.implicitHeight)
                    }
                }
            }
        }
    }

    // Menus

    AppMenu {
        id: mainMenu

        AppMenuItem { text: qsTr("New tab"); iconName: "add"; shortcut: "Ctrl+N"; onTriggered: win.newTab() }
        AppMenuItem {
            text: qsTr("Open")
            iconName: "open"
            shortcut: "Ctrl+O"
            onTriggered: backend.openDialog(win.currentEditor && win.currentEditor.filePath ? backend.folderOf(win.currentEditor.filePath) : "")
        }
        AppMenu {
            id: recentMenu
            title: qsTr("Open recent")
            property string iconName: "recent"
            enabled: (Style.prefs.recentFiles || []).length > 0

            Instantiator {
                model: Style.prefs.recentFiles || []
                delegate: AppMenuItem {
                    required property string modelData
                    text: backend.fileName(modelData)
                    shortcut: ""
                    iconName: "file"
                    onTriggered: win.openPaths([modelData], false)
                    ToolTip.visible: hovered
                    ToolTip.delay: 600
                    ToolTip.text: modelData
                }
                onObjectAdded: (index, object) => recentMenu.insertItem(index, object)
                onObjectRemoved: (index, object) => recentMenu.removeItem(object)
            }
            AppMenuSeparator {}
            AppMenuItem { text: qsTr("Clear recent files"); onTriggered: Style.prefs.recentFiles = [] }
        }
        AppMenuSeparator {}
        AppMenuItem { text: qsTr("Save"); iconName: "save"; shortcut: "Ctrl+S"; enabled: win.currentEditor !== null; onTriggered: win.saveDoc(win.currentEditor, null) }
        AppMenuItem { text: qsTr("Save as"); iconName: "save-as"; shortcut: "Ctrl+Shift+S"; enabled: win.currentEditor !== null; onTriggered: win.saveDocAs(win.currentEditor, null) }
        AppMenuItem { text: qsTr("Save all"); iconName: "save-all"; shortcut: "Ctrl+Alt+S"; onTriggered: win.saveAll() }
        AppMenuSeparator {}
        AppMenuItem { text: qsTr("Find"); iconName: "search"; shortcut: "Ctrl+F"; onTriggered: win.openFind(false) }
        AppMenuItem { text: qsTr("Replace"); iconName: "replace"; shortcut: "Ctrl+H"; onTriggered: win.openFind(true) }
        AppMenuSeparator {}
        AppMenuItem { text: qsTr("Settings"); iconName: "settings"; shortcut: "Ctrl+,"; onTriggered: settings.open() }
        AppMenuItem { text: qsTr("Keyboard shortcuts"); iconName: "keyboard"; shortcut: "F1"; onTriggered: shortcutsOverlay.open() }
        AppMenuSeparator {}
        AppMenuItem { text: qsTr("Quit"); iconName: "quit"; shortcut: "Ctrl+Q"; onTriggered: win.requestQuit() }
    }

    AppMenu {
        id: editMenu

        readonly property var area: win.currentEditor ? win.currentEditor.area : null
        // The misspelled word that was right-clicked, if suggestions are on.
        readonly property var misspelled: win.currentEditor && Style.prefs.spellSuggestions
                                          && win.currentEditor.spelling.misspelled ? win.currentEditor.spelling : null
        // Only the best correction, the one Hunspell ranks first.
        readonly property string correction: misspelled ? spellChecker.bestSuggestion(misspelled.word) : ""

        AppMenuItem {
            visible: editMenu.correction !== ""
            text: editMenu.correction
            onTriggered: spellChecker.replace(editMenu.area.textDocument, editMenu.misspelled.start,
                                              editMenu.misspelled.end, editMenu.misspelled.word, editMenu.correction)
        }
        AppMenuItem {
            visible: editMenu.misspelled !== null && editMenu.correction === ""
            text: qsTr("No suggestions")
            enabled: false
        }
        AppMenuItem {
            visible: editMenu.misspelled !== null
            text: qsTr("Add to dictionary")
            iconName: "add"
            onTriggered: spellChecker.addWord(editMenu.misspelled.word)
        }
        AppMenuSeparator { visible: editMenu.misspelled !== null }

        AppMenuItem { text: qsTr("Cut"); iconName: "cut"; shortcut: "Ctrl+X"; enabled: editMenu.area && win.currentEditor.hasSelection; onTriggered: editMenu.area.cut() }
        AppMenuItem { text: qsTr("Copy"); iconName: "copy"; shortcut: "Ctrl+C"; enabled: editMenu.area && win.currentEditor.hasSelection; onTriggered: editMenu.area.copy() }
        AppMenuItem { text: qsTr("Paste"); iconName: "paste"; shortcut: "Ctrl+V"; enabled: editMenu.area && editMenu.area.canPaste; onTriggered: editMenu.area.paste() }
        AppMenuItem { text: qsTr("Undo"); iconName: "undo"; shortcut: "Ctrl+Z"; enabled: editMenu.area && editMenu.area.canUndo; onTriggered: editMenu.area.undo() }
        AppMenuItem { text: qsTr("Redo"); iconName: "redo"; shortcut: "Ctrl+Shift+Z"; enabled: editMenu.area && editMenu.area.canRedo; onTriggered: editMenu.area.redo() }
        AppMenuItem { text: qsTr("Select all"); iconName: "select-all"; shortcut: "Ctrl+A"; enabled: editMenu.area !== null; onTriggered: editMenu.area.selectAll() }
        AppMenuSeparator {}
        AppMenuItem { text: qsTr("Word wrap"); iconName: "wrap"; shortcut: "Alt+Z"; checkable: true; checked: Style.prefs.wrapWord; onTriggered: Style.prefs.wrapWord = checked }
        AppMenuItem { text: qsTr("Search in web"); iconName: "web"; shortcut: "Ctrl+E"; enabled: win.currentEditor && win.currentEditor.hasSelection; onTriggered: win.searchWeb() }
        AppMenuItem { text: qsTr("Toggle preview"); iconName: "preview"; shortcut: "Alt+P"; visible: win.currentEditor && win.currentEditor.markdown; onTriggered: win.togglePreview() }
    }

    AppMenu {
        id: tabMenu

        property var doc: null

        AppMenuItem { text: qsTr("Close"); iconName: "close"; shortcut: "Ctrl+W"; onTriggered: win.closeTab(tabMenu.doc) }
        AppMenuItem { text: qsTr("Close others"); onTriggered: win.closeOthers(tabMenu.doc) }
        AppMenuSeparator {}
        AppMenuItem {
            text: qsTr("Copy full path")
            iconName: "copy"
            enabled: tabMenu.doc && tabMenu.doc.filePath !== ""
            onTriggered: backend.copyToClipboard(tabMenu.doc.filePath)
        }
        AppMenuItem {
            text: qsTr("Open containing folder")
            iconName: "folder"
            enabled: tabMenu.doc && tabMenu.doc.filePath !== ""
            onTriggered: Qt.openUrlExternally("file://" + backend.folderOf(tabMenu.doc.filePath))
        }
    }

    AppMenu {
        id: lineEndingMenu
        width: 220

        Instantiator {
            model: ["crlf", "cr", "lf"]
            delegate: AppMenuItem {
                required property string modelData
                text: Style.lineEndingName(modelData)
                checkable: true
                checked: win.currentEditor && win.currentEditor.lineEnding === modelData
                onTriggered: win.currentEditor.setLineEnding(modelData)
            }
            onObjectAdded: (index, object) => lineEndingMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => lineEndingMenu.removeItem(object)
        }
    }

    AppMenu {
        id: encodingMenu
        width: 240

        AppMenu {
            id: reopenMenu
            title: qsTr("Reopen with encoding")
            enabled: win.currentEditor !== null && win.currentEditor.filePath !== ""

            Instantiator {
                model: Style.encodings
                delegate: AppMenuItem {
                    required property var modelData
                    text: modelData.name
                    onTriggered: {
                        const doc = win.currentEditor
                        const reopen = () => {
                            const error = doc.load(doc.filePath, modelData.key)
                            if (error)
                                win.showMessage(error)
                        }
                        if (doc.modified)
                            confirm.ask(qsTr("Discard changes?"),
                                        qsTr("Reopening %1 discards your unsaved changes.").arg(doc.title),
                                        qsTr("Reopen"), qsTr("Keep editing"), reopen, null)
                        else
                            reopen()
                    }
                }
                onObjectAdded: (index, object) => reopenMenu.insertItem(index, object)
                onObjectRemoved: (index, object) => reopenMenu.removeItem(object)
            }
        }
        AppMenu {
            id: saveWithMenu
            title: qsTr("Save with encoding")

            Instantiator {
                model: Style.encodings
                delegate: AppMenuItem {
                    required property var modelData
                    text: modelData.name
                    checkable: true
                    checked: win.currentEditor && win.currentEditor.encoding === modelData.key
                    onTriggered: win.currentEditor.setEncoding(modelData.key)
                }
                onObjectAdded: (index, object) => saveWithMenu.insertItem(index, object)
                onObjectRemoved: (index, object) => saveWithMenu.removeItem(object)
            }
        }
    }

    ConfirmDialog {
        id: confirm
        onClosed: win.focusEditor()
    }

    ShortcutsOverlay {
        id: shortcutsOverlay
        onClosed: win.focusEditor()
    }
}
