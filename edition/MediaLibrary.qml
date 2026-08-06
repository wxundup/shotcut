/*
 * Loads media/index.js: real durations, codecs, decoded thumbnails and PCM
 * peaks produced by media/build-media-index.ps1.
 *
 * The index is imported rather than fetched — QML blocks local XHR reads by
 * default, and an import needs no runtime permission. If the index is
 * missing the library is simply empty; nothing is invented to fill it.
 */
pragma ComponentBehavior: Bound
import QtQuick
import "media/index.js" as Index

QtObject {
    id: library

    property var items: []
    property bool loaded: false
    property string error: ""

    function peaksFor(name) {
        for (var i = 0; i < items.length; i++) {
            if (items[i].name === name)
                return items[i].peaks
        }
        return []
    }

    function thumbsFor(name) {
        for (var i = 0; i < items.length; i++) {
            if (items[i].name === name) {
                return items[i].thumbs.map(function (t) {
                    return Qt.resolvedUrl(t)
                })
            }
        }
        return []
    }

    function sourceFor(name) {
        for (var i = 0; i < items.length; i++) {
            if (items[i].name === name)
                return Qt.resolvedUrl(items[i].source)
        }
        return ""
    }

    function durationFor(name) {
        for (var i = 0; i < items.length; i++) {
            if (items[i].name === name)
                return items[i].duration
        }
        return 0
    }

    Component.onCompleted: reload()

    function reload() {
        if (!Index.media) {
            error = "media index missing — run media/build-media-index.ps1"
            return
        }
        items = Index.media
        loaded = true
    }
}
