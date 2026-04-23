import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    // cfg_ prefix is the Plasma convention for auto-binding to KConfig keys.
    property alias cfg_apiUrl:         apiUrlField.text
    property alias cfg_pollInterval:   pollIntervalSpinBox.value
    property alias cfg_maxTokensPerSec: maxTpsSpinBox.value

    TextField {
        id: apiUrlField
        Kirigami.FormData.label: "llama-cpp API URL:"
        placeholderText: "http://localhost:8080"
    }

    SpinBox {
        id: pollIntervalSpinBox
        from:      250
        to:        30000
        stepSize:  250
        Kirigami.FormData.label: "Poll interval (ms):"
    }

    SpinBox {
        id: maxTpsSpinBox
        from:      1
        to:        2000
        stepSize:  10
        Kirigami.FormData.label: "Tok/s dial full-scale:"
    }
}
