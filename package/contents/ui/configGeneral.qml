import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    implicitWidth:  grid.implicitWidth  + 24
    implicitHeight: grid.implicitHeight + 24

    property alias cfg_apiUrl:          urlField.text
    property alias cfg_pollInterval:    pollSpinner.value
    property alias cfg_maxTokensPerSec: maxTpsSpinner.value

    GridLayout {
        id: grid
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        columns: 2
        columnSpacing: 16
        rowSpacing: 10

        Label { text: "API URL:" }
        TextField {
            id: urlField
            Layout.fillWidth: true
            placeholderText: "http://localhost:8080"
        }

        Label { text: "Poll interval (ms):" }
        SpinBox { id: pollSpinner; from: 250; to: 30000; stepSize: 250 }

        Label { text: "Tok/s dial full-scale:" }
        SpinBox { id: maxTpsSpinner; from: 1; to: 2000; stepSize: 10 }
    }
}
