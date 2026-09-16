import QtQuick
import "../qml"

ChatView {
    width: 640; height: 480
    conversationUid: 2
    conversationVisible: true
    property int readCount: 0
    onMessageViewed: readCount += 1
}
