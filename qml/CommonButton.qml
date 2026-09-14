import QtQuick 2.15
import QtQuick.Controls 2.15

SakuraButton {
    id: btn
    property string style: "primary"  // "primary" | "secondary"

    height: 40
    font { pixelSize: 15; family: "Microsoft YaHei" }

    contentItem: Text {
        text: btn.text
        font: btn.font
        color: btn.style === "primary" ? UiTheme.text : UiTheme.accent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment:   Text.AlignVCenter
    }

    background: Rectangle {
        radius: 20
        color: {
            if (btn.style === "primary")
                return btn.pressed ? UiTheme.accentPressed : btn.hovered ? UiTheme.accentHover : UiTheme.accent
            else
                return btn.pressed ? UiTheme.hover : btn.hovered ? UiTheme.hover : UiTheme.canvas
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
