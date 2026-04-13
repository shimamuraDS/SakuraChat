import QtQuick 2.15
import QtQuick.Controls 2.15

Button {
    id: btn
    property string style: "primary"  // "primary" | "secondary"

    height: 40
    font { pixelSize: 15; family: "Microsoft YaHei" }

    contentItem: Text {
        text: btn.text
        font: btn.font
        color: btn.style === "primary" ? "#ffffff" : "#2AABEE"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment:   Text.AlignVCenter
    }

    background: Rectangle {
        radius: 20
        color: {
            if (btn.style === "primary")
                return btn.pressed ? "#1a8ccc" : btn.hovered ? "#2AABEE" : "#2AABEE"
            else
                return btn.pressed ? "#d0d0d0" : btn.hovered ? "#e8e8e8" : "#f0f0f0"
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
