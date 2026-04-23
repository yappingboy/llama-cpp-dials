import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// No Kirigami dependency — plain Qt Quick Controls only.
ColumnLayout {
    property alias cfg_apiUrl:          urlField.text
    property alias cfg_pollInterval:    pollSpinner.value
    property alias cfg_maxTokensPerSec: maxTpsSpinner.value

    spacing: 12
    Layout.fillWidth: true

    GridLayout {
        columns: 2
        columnSpacing: 16
        rowSpacing: 8
        Layout.fillWidth: true

        Label { text: "API URL" }
        TextField {
            id: urlField
            Layout.fillWidth: true
            placeholderText: "http://localhost:8080"
        }

        Label { text: "Poll interval (ms)" }
        SpinBox {
            id: pollSpinner
            from: 250; to: 30000; stepSize: 250
        }

        Label { text: "Tok/s dial full-scale" }
        SpinBox {
            id: maxTpsSpinner
            from: 1; to: 2000; stepSize: 10
        }
    }

    Item { Layout.fillHeight: true }
}
