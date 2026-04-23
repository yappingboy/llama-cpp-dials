import QtQuick

Item {
    id: root

    property real value: 0          // 0.0 – 1.0
    property string label: ""
    property string centerText: "0"
    property color dialColor: "#4FC3F7"

    implicitWidth: 130
    implicitHeight: 120

    // Square canvas fills the upper portion; label sits below it.
    Canvas {
        id: canvas
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width:  Math.min(parent.width, parent.height - 20)
        height: width

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var cx = width  / 2
            var cy = height / 2
            var r  = cx - 10
            var lineW = 9

            // Arc measured clockwise from 3-o'clock (standard canvas):
            //   135° = lower-left  (7:30 position) – start of gauge
            //   405° = lower-right (4:30 position) – end of gauge (= 135° + 270°)
            var startAngle = Math.PI * 3 / 4     // 135°
            var totalSpan  = Math.PI * 3 / 2     // 270°

            // Background track
            ctx.beginPath()
            ctx.arc(cx, cy, r, startAngle, startAngle + totalSpan, false)
            ctx.strokeStyle = "rgba(255,255,255,0.12)"
            ctx.lineWidth   = lineW
            ctx.lineCap     = "round"
            ctx.stroke()

            // Value arc
            var clamped = Math.max(0, Math.min(1, root.value))
            if (clamped > 0.005) {
                ctx.beginPath()
                ctx.arc(cx, cy, r, startAngle, startAngle + totalSpan * clamped, false)
                ctx.strokeStyle = root.dialColor.toString()
                ctx.lineWidth   = lineW
                ctx.lineCap     = "round"
                ctx.stroke()
            }
        }
    }

    // Value text — anchored to canvas centre
    Text {
        anchors.horizontalCenter: canvas.horizontalCenter
        anchors.verticalCenter:   canvas.verticalCenter
        text:  root.centerText
        color: "#E0E0E0"
        font.pixelSize: Math.max(12, Math.min(20, canvas.width * 0.22))
        font.bold:   true
        font.family: "monospace"
        horizontalAlignment: Text.AlignHCenter
    }

    // Label beneath the canvas
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom:           parent.bottom
        anchors.bottomMargin:     2
        text:  root.label
        color: "#888888"
        font.pixelSize:    9
        font.letterSpacing: 1.2
    }

    onValueChanged:     canvas.requestPaint()
    onDialColorChanged: canvas.requestPaint()
}
