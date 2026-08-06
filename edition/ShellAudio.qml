import QtQuick

// Screenshot helper: opens the shell in the Audio workspace.
Shell {
    Component.onCompleted: openWorkspace("Audio")
}
