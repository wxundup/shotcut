import QtQuick

// Screenshot helper: playhead parked where V1 and V2 overlap, to show the
// composite rather than the fallback.
Shell {
    Component.onCompleted: seek(0.33)
}
