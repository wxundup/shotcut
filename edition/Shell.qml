/*
 * EdiTogether, as a standalone window.
 *
 * The interface itself is EditorRoot.qml, an Item, so the same code runs
 * here and inside the application's own dock. This file is only the window
 * around it.
 *
 * Run: qml -I <repo>/src/qml/modules -I <repo>/edition Shell.qml
 */
import QtQuick
import QtQuick.Controls
import EdiTogether.Theme

ApplicationWindow {
    id: window

    width: 1440
    height: 900
    minimumWidth: 1080
    minimumHeight: 700
    visible: true
    title: qsTr("Untitled Project — EdiTogether")
    color: Theme.window

    // Forwarded so a host application can drive the interface without
    // knowing how it is built.
    function seek(position) { editor.seek(position) }
    function openWorkspace(name) { editor.openWorkspace(name) }

    EditorRoot {
        id: editor
        anchors.fill: parent
    }
}
