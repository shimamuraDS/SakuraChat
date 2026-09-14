import QtQuick

Canvas {
    id: icon
    property string name: "chat"
    property color color: UiTheme.cyan
    implicitWidth: 24; implicitHeight: 24
    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d")
        c.reset()
        const size = Math.min(width, height, 24)
        c.translate((width-size)/2, (height-size)/2)
        c.scale(size/24, size/24)
        c.strokeStyle = color; c.lineWidth = 1.7; c.lineCap = "round"; c.lineJoin = "round"
        c.beginPath()
        if (name === "cloud") {
            c.moveTo(7,19); c.lineTo(18,19)
            c.bezierCurveTo(24,19,24,10,18,10)
            c.bezierCurveTo(17,2,6,2,5,11)
            c.bezierCurveTo(0,12,1,19,7,19)
        } else if (name === "network") {
            c.rect(8,3,8,5)
            c.moveTo(12,8); c.lineTo(12,13)
            c.moveTo(5,16); c.lineTo(5,13); c.lineTo(19,13); c.lineTo(19,16)
            c.rect(2,16,6,5); c.rect(16,16,6,5)
        } else if (name === "chat") {
            c.moveTo(5,4); c.lineTo(19,4); c.quadraticCurveTo(21,4,21,6)
            c.lineTo(21,15); c.quadraticCurveTo(21,17,19,17)
            c.lineTo(9,17); c.lineTo(4,21); c.lineTo(4,17)
            c.quadraticCurveTo(3,17,3,15); c.lineTo(3,6); c.quadraticCurveTo(3,4,5,4)
            c.moveTo(7,9); c.lineTo(17,9); c.moveTo(7,13); c.lineTo(13,13)
        } else if (name === "contacts" || name === "request") {
            c.arc(10,8,4,0,Math.PI*2)
            c.moveTo(3,21); c.bezierCurveTo(3,12,17,12,17,21)
            c.moveTo(18,9); c.lineTo(23,9)
            if (name === "request") { c.moveTo(20.5,6.5); c.lineTo(20.5,11.5) }
            else { c.moveTo(19,15); c.quadraticCurveTo(23,16,23,21) }
        } else if (name === "logout") {
            c.moveTo(10,3); c.lineTo(4,3); c.lineTo(4,21); c.lineTo(10,21)
            c.moveTo(9,12); c.lineTo(21,12); c.moveTo(17,8); c.lineTo(21,12); c.lineTo(17,16)
        } else if (name === "settings") {
            c.arc(12,12,7,0,Math.PI*2); c.moveTo(15,12); c.arc(12,12,3,0,Math.PI*2)
            for (let i=0;i<8;i++) { const a=i*Math.PI/4; c.moveTo(12+8*Math.cos(a),12+8*Math.sin(a)); c.lineTo(12+10*Math.cos(a),12+10*Math.sin(a)) }
        } else if (name === "send") {
            c.moveTo(3,10); c.lineTo(21,3); c.lineTo(14,21); c.lineTo(11,13); c.closePath()
            c.moveTo(11,13); c.lineTo(21,3)
        } else if (name === "lock") {
            c.moveTo(7,10); c.lineTo(7,7); c.bezierCurveTo(7,1,17,1,17,7); c.lineTo(17,10)
            c.moveTo(5,10); c.lineTo(19,10); c.lineTo(19,21); c.lineTo(5,21); c.closePath()
            c.moveTo(12,14); c.lineTo(12,17)
        } else if (name === "refresh") {
            c.arc(12,12,8,0.4,5.5)
            c.moveTo(18,3); c.lineTo(18,8); c.lineTo(13,8)
        } else if (name === "search") {
            c.arc(10,10,6,0,Math.PI*2); c.moveTo(15,15); c.lineTo(21,21)
        } else {
            c.moveTo(5,12); c.lineTo(19,12); c.moveTo(12,5); c.lineTo(12,19)
        }
        c.stroke()
    }
}
