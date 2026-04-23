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
    property string statusLine:   "Connecting…"

    // For rate calculation
    property real lastTotalTokens: 0
    property real lastPollTime:    0

    // Raw diagnostic: first metric data line received, for troubleshooting.
    property string diagText: ""

    // Config — strip trailing slashes so "/metrics" concatenation is clean.
    readonly property string apiUrl: {
        var u = plasmoid.configuration.apiUrl
        if (!u || u.length === 0) u = "http://localhost:8080"
        return u.replace(/\/+$/, "")
    }
    readonly property int pollInterval:    Math.max(250, plasmoid.configuration.pollInterval)
    readonly property int maxTokensPerSec: Math.max(1,   plasmoid.configuration.maxTokensPerSec)

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
        implicitHeight: 250

        Rectangle {
            anchors.fill: parent
            color:  Qt.rgba(0, 0, 0, 0.72)
            radius: 10

            ColumnLayout {
                anchors.fill:    parent
                anchors.margins: 14
                spacing:         8

                // ── Header / connection status ──────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: root.connected ? "#66BB6A" : "#EF5350"
                    }
                    Text {
                        Layout.fillWidth: true
                        text:            "v0.3 · " + root.statusLine
                        color:           root.connected ? "#aaaaaa" : "#EF5350"
                        font.pixelSize:  10
                        font.family:     "monospace"
                        elide:           Text.ElideRight
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
                        Layout.fillWidth:       true
                        Layout.preferredHeight: 120
                        value:      Math.min(root.tokensPerSecond / root.maxTokensPerSec, 1.0)
                        centerText: root.tokensPerSecond.toFixed(1)
                        label:      "tok / s"
                        dialColor:  "#4FC3F7"
                    }

                    DialGauge {
                        Layout.fillWidth:       true
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

                // ── Diagnostic line ─────────────────────────────────────
                Text {
                    Layout.fillWidth: true
                    text:            root.diagText
                    color:           "#999999"
                    font.pixelSize:  9
                    font.family:     "monospace"
                    elide:           Text.ElideRight
                    visible:         root.diagText !== ""
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

    onApiUrlChanged: {
        baselinePromptTokens    = -1
        baselinePredictedTokens = -1
        tokensPerSecond         = 0
        connected               = false
        statusLine              = "Connecting…"
        diagText                = ""
        fetchMetrics()
    }

    // ── Network ─────────────────────────────────────────────────────────────
    function fetchMetrics() {
        var url = root.apiUrl + "/metrics"
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) {
                root.connected = true
                root.parseMetrics(xhr.responseText)
            } else {
                root.connected  = false
                var code = xhr.status === 0 ? "no response" : "HTTP " + xhr.status
                root.statusLine = code + " — " + url
                root.diagText   = "check URL and that llama-server is running"
            }
        }
        xhr.open("GET", url)
        xhr.timeout = Math.min(root.pollInterval - 50, 4000)
        xhr.ontimeout = function() {
            root.connected  = false
            root.statusLine = "Timeout — " + url
            root.diagText   = "server took too long to respond"
        }
        xhr.send()
    }

    // ── Parsing ─────────────────────────────────────────────────────────────
    function parseMetrics(text) {
        // Prometheus text format: "metric_name{labels} value [timestamp]"
        // Match by suffix so both "llama_" and "llamacpp:" prefixes work.
        var promptTokens    = 0
        var predictedTokens = 0
        var kvRatio         = 0
        var linesScanned    = 0
        var firstDataLine   = ""

        var lines = text.split('\n')
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === '' || line.charAt(0) === '#') continue
            linesScanned++
            if (firstDataLine === '') firstDataLine = line

            // First space separates key from value; ignore optional trailing timestamp.
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

        // Update status line and diagnostic
        root.statusLine = root.apiUrl
        if (linesScanned === 0) {
            root.diagText = "⚠ empty response — is --metrics enabled?"
        } else if (total === 0 && kvRatio === 0) {
            root.diagText = "⚠ no token metrics found (" + linesScanned + " lines) — " + firstDataLine.substring(0, 60)
        } else {
            root.diagText = "p:" + promptTokens + " pr:" + predictedTokens +
                            " kv:" + Math.round(kvRatio * 100) + "%"
        }

        if (root.baselinePromptTokens < 0) {
            root.baselinePromptTokens    = promptTokens
            root.baselinePredictedTokens = predictedTokens
            root.lastTotalTokens         = total
            root.lastPollTime            = now
        } else if (total < root.lastTotalTokens) {
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
