// Rounded card used inside popups and panels.
import QtQuick
import qs

Rectangle {
    default property alias content: inner.data
    property int padding: 12
    radius: 12
    color: Qt.rgba(Theme.overlay.r, Theme.overlay.g, Theme.overlay.b, 0.55)
    implicitHeight: inner.implicitHeight + padding * 2
    implicitWidth: inner.implicitWidth + padding * 2

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: parent.padding
        implicitHeight: childrenRect.height
        implicitWidth: childrenRect.width
    }
}
