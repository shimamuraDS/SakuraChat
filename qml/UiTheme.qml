pragma Singleton
import QtQuick

QtObject {
    property bool privateMode: false
    readonly property color canvas: privateMode ? "#18191b" : "#0b1018"
    readonly property color rail: privateMode ? "#101113" : "#080d14"
    readonly property color surface: privateMode ? "#202123" : "#121b27"
    readonly property color elevated: privateMode ? "#292820" : "#182435"
    readonly property color field: privateMode ? "#1b1b18" : "#0e1723"
    readonly property color hover: privateMode ? "#3e3829" : "#20334a"
    readonly property color selection: privateMode ? "#4a3c1e" : "#163a59"
    readonly property color border: privateMode ? "#494333" : "#26364a"
    readonly property color text: privateMode ? "#eee8dc" : "#e1eaf5"
    readonly property color secondary: privateMode ? "#c5baa3" : "#a1b2c7"
    readonly property color muted: privateMode ? "#a3977c" : "#8194ac"
    readonly property color accent: privateMode ? "#d6b467" : "#368ddd"
    readonly property color accentHover: privateMode ? "#e6c47b" : "#49a0ee"
    readonly property color accentPressed: privateMode ? "#b2934e" : "#246cad"
    readonly property color cyan: privateMode ? "#e3c780" : "#65d2ea"
    readonly property color accentText: privateMode ? "#201a0d" : "#ffffff"
    readonly property color danger: "#ee788b"
    readonly property color success: privateMode ? "#d6b467" : "#6fd3ae"
    readonly property color warning: "#e9bf7b"
    readonly property color scrim: "#b0080d14"
    readonly property int corner: 10
    readonly property int fast: 120
    readonly property int transition: 180
}
