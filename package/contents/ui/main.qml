import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    // ── Persistent state ────────────────────────────────────────────────────
    property real baselinePromptTokens:    -1   // -1 = not yet set
    property real baselinePredictedTokens: -1

    property real currentPromptTokens:    0
    property real currentPredictedTokens: 0
    property real kvCacheUsageRatio:      0
    property real tokensPerSecond:        0

    property bool   connected:    false
    property string errorMessage: "Connecting…"

    // For rate calculation
    property real lastTotalTokens: 0
    property real lastPollTime:    0

    // Config shortcuts
    readonly property string apiUrl:         plasmoid.configuration.apiUrl
    readonly property int    pollInterval:   plasmoid.configuration.pollInterval
    readonly property int    maxTokensPerSec: plasmoid.configuration.maxTokensPerSec

    // ── Derived ─────────────────────────────────────────────────────────────
    readonly property real sessionTokens: {
        if (baselinePromptTokens < 0) return 0
        return Math.max(0,
            (currentPromptTokens    - baselinePromptTokens) +
            (currentPredictedTokens - baselinePredictedTokens))
    }

    // ── Representation ──────────────────────────────────────────────────────
    preferredRepresentation: fullRepresentation

    fullRepresentation: Item {
        implicitWidth:  300
        implicitHeight: 230

        Rectangle {
            anchors.fill: parent
            color:  Qt.rgba(0, 0, 0, 0.72)
            radius: 10

            ColumnLayout {
                anchors.fill:    parent
                anchors.margins: 14
                spacing:         10

                // ── Header / status bar ─────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: root.connected ? "#66BB6A" : "#EF5350"
                    }
                    Text {
                        text:  "llama-cpp"
                        color: "#aaaaaa"
                        font.pixelSize: 11
                        font.family:    "monospace"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible:        !root.connected
                        text:           root.errorMessage
                        color:          "#EF5350"
                        font.pixelSize: 10
                    }
                }

                // ── Session-token odometer ──────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 60
                    color:  Qt.rgba(1, 1, 1, 0.05)
                    radius: 6
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text:  root.sessionTokens.toLocaleString(Qt.locale("en_US"), 'f', 0)
                            color: "#E0E0E0"
                            font.pixelSize: 26
                            font.bold:      true
                            font.family:    "monospace"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text:  "SESSION TOKENS"
                            color: "#666666"
                            font.pixelSize:    9
                            font.letterSpacing: 1.6
                        }
                    }
                }

                // ── Dials ───────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    DialGauge {
                        Layout.fillWidth:    true
                        Layout.preferredHeight: 120
                        value:      Math.min(root.tokensPerSecond / Math.max(1, root.maxTokensPerSec), 1.0)
                        centerText: root.tokensPerSecond.toFixed(1)
                        label:      "tok / s"
                        dialColor:  "#4FC3F7"
                    }

                    DialGauge {
                        Layout.fillWidth:    true
                        Layout.preferredHeight: 120
                        value:      root.kvCacheUsageRatio
                        centerText: Math.round(root.kvCacheUsageRatio * 100) + "%"
                        label:      "ctx used"
                        dialColor: {
                            var v = root.kvCacheUsageRatio
                            if (v < 0.70) return "#66BB6A"
                            if (v < 0.90) return "#FFA726"
                            return "#EF5350"
                        }
                    }
                }
            }
        }
    }

    // ── Polling ─────────────────────────────────────────────────────────────
    Timer {
        id: pollTimer
        interval: root.pollInterval
        running:  true
        repeat:   true
        onTriggered: root.fetchMetrics()
    }

    Component.onCompleted: root.fetchMetrics()

    // Reset and immediately reconnect whenever the user saves a new URL.
    onApiUrlChanged: {
        baselinePromptTokens    = -1
        baselinePredictedTokens = -1
        tokensPerSecond         = 0
        connected               = false
        errorMessage            = "Connecting…"
        fetchMetrics()
    }

    // ── Network ─────────────────────────────────────────────────────────────
    function fetchMetrics() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                root.connected = true
                root.parseMetrics(xhr.responseText)
            } else {
                root.connected = false
                root.errorMessage = xhr.status === 0 ? "Cannot connect" : "HTTP " + xhr.status
            }
        }
        xhr.open("GET", root.apiUrl + "/metrics")
        xhr.timeout = Math.min(root.pollInterval - 50, 4000)
        xhr.ontimeout = function() {
            root.connected    = false
            root.errorMessage = "Timeout"
        }
        xhr.send()
    }

    // ── Parsing ─────────────────────────────────────────────────────────────
    function parseMetrics(text) {
        // Prometheus text format: "metric_name{labels} value [timestamp]"
        // llama.cpp uses either "llama_" (older) or "llamacpp:" (newer) as prefix,
        // so we match on the meaningful suffix instead of the full name.
        var promptTokens    = 0
        var predictedTokens = 0
        var kvRatio         = 0

        var lines = text.split('\n')
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === '' || line.charAt(0) === '#') continue

            // Split on the FIRST space to get key; value follows (ignore trailing timestamp).
            var spaceIdx = line.indexOf(' ')
            if (spaceIdx < 0) continue
            var rawKey = line.substring(0, spaceIdx)
            var rest   = line.substring(spaceIdx + 1).trim()
            var secondSpace = rest.indexOf(' ')
            var val = parseFloat(secondSpace < 0 ? rest : rest.substring(0, secondSpace))
            if (isNaN(val)) continue

            // Strip label block: "name{k=v,...}" → "name"
            var brace = rawKey.indexOf('{')
            var key   = brace >= 0 ? rawKey.substring(0, brace) : rawKey

            if      (key.indexOf('prompt_tokens_total')    >= 0) promptTokens    += val
            else if (key.indexOf('tokens_predicted_total') >= 0) predictedTokens += val
            else if (key.indexOf('kv_cache_usage_ratio')   >= 0) kvRatio          = Math.max(kvRatio, val)
        }

        var now   = Date.now()
        var total = promptTokens + predictedTokens

        if (root.baselinePromptTokens < 0) {
            // First successful fetch — record baseline
            root.baselinePromptTokens    = promptTokens
            root.baselinePredictedTokens = predictedTokens
            root.lastTotalTokens         = total
            root.lastPollTime            = now
        } else if (total < root.lastTotalTokens) {
            // Server restarted — reset
            root.baselinePromptTokens    = promptTokens
            root.baselinePredictedTokens = predictedTokens
            root.tokensPerSecond         = 0
        } else {
            var dt    = (now - root.lastPollTime) / 1000.0
            var delta = total - root.lastTotalTokens
            if (dt > 0.05) {
                var rawRate = delta / dt
                root.tokensPerSecond = root.tokensPerSecond * 0.7 + rawRate * 0.3
            }
        }

        root.lastTotalTokens         = total
        root.lastPollTime            = now
        root.currentPromptTokens     = promptTokens
        root.currentPredictedTokens  = predictedTokens
        root.kvCacheUsageRatio        = kvRatio
    }
}
