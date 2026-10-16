import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    property var tasks: []
    property string selectedList: ""
    property var lists: ["Toutes les listes"]
    property string status: "Chargement…"
    property string baseCommand: "python3 \"${XDG_DATA_HOME:-$HOME/.local/share}/poulpoints-desktop/helper.py\" "
    function run(operation) { executable.connectSource(baseCommand + operation) }
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(sourceName, data) {
            disconnectSource(sourceName)
            if (sourceName === root.baseCommand + "read") {
                try {
                    const snapshot = JSON.parse(data.stdout)
                    root.tasks = snapshot.tasks || []
                    root.lists = ["Toutes les listes"].concat([...new Set(root.tasks.map(t => t.list))].sort())
                    if (root.selectedList !== "" && root.lists.indexOf(root.selectedList) < 0) root.selectedList = ""
                    root.status = snapshot.error || (root.tasks.length + " tâche(s) · données locales")
                } catch (e) { root.status = "Installez le compagnon Bureau Poulpoints." }
            } else {
                root.status = data["exit code"] === 0 ? (sourceName.indexOf("complete ") >= 0 ? "Validation en cours…" : "Ouverture de Poulpoints…") : "Ouverture impossible : vérifiez l’installation."
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.run("read") }
    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: 270
        Layout.minimumHeight: 260
        Layout.preferredWidth: 340
        Layout.preferredHeight: 420
        RowLayout {
            Image { source: "logo.png"; sourceSize.width: 34; sourceSize.height: 34; Layout.preferredWidth: 34; Layout.preferredHeight: 34 }
            Label { text: "Poulpoints"; font.bold: true; font.pointSize: 16; Layout.fillWidth: true }
            ToolButton { text: "＋"; Accessible.name: "Nouvelle tâche"; onClicked: root.run("new") }
            ToolButton { text: "↗"; Accessible.name: "Ouvrir Poulpoints"; onClicked: root.run("open") }
        }
        Label { text: root.status; wrapMode: Text.Wrap; Layout.fillWidth: true; font.pointSize: 9 }
        ComboBox {
            Layout.fillWidth: true
            model: root.lists
            currentIndex: Math.max(0, root.lists.indexOf(root.selectedList))
            onActivated: root.selectedList = currentIndex === 0 ? "" : currentText
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ListView {
                model: root.selectedList === "" ? root.tasks : root.tasks.filter(t => t.list === root.selectedList)
                spacing: 12
                delegate: Item {
                    id: taskRow
                    required property var modelData
                    width: ListView.view.width
                    height: Math.max(44, taskInfo.implicitHeight + 12)
                    ToolButton {
                        id: completeButton
                        anchors.left: parent.left
                        anchors.verticalCenter: taskInfo.verticalCenter
                        width: 34
                        height: 34
                        text: "○"
                        Accessible.name: "Terminer " + taskRow.modelData.title
                        onClicked: root.run("complete " + Qt.btoa(unescape(encodeURIComponent(JSON.stringify({id:taskRow.modelData.id, revision:taskRow.modelData.revision})))))
                    }
                    Column {
                        id: taskInfo
                        anchors.left: completeButton.right
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        anchors.rightMargin: 6
                        spacing: 2
                        Label {
                            width: parent.width
                            text: taskRow.modelData.title
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                        }
                        Label {
                            width: parent.width
                            text: taskRow.modelData.list + (taskRow.modelData.due ? " · " + new Date(taskRow.modelData.due).toLocaleString(Qt.locale(), "dd/MM hh:mm") : "")
                            textFormat: Text.PlainText
                            font.pointSize: 9
                            opacity: 0.75
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        anchors.fill: taskInfo
                        cursorShape: Qt.PointingHandCursor
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: "Ouvrir " + taskRow.modelData.title
                        Keys.onReturnPressed: clicked(null)
                        Keys.onSpacePressed: clicked(null)
                        onClicked: root.run("open-task " + Qt.btoa(unescape(encodeURIComponent(JSON.stringify({id:taskRow.modelData.id, revision:taskRow.modelData.revision})))))
                    }
                    Rectangle {
                        anchors.left: taskInfo.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -6
                        height: 1
                        color: taskInfo.children[0].color
                        opacity: 0.12
                    }
                }
            }
        }
        Label { text: "Cocher termine la tâche sans ouvrir de fenêtre."; font.pointSize: 9; wrapMode: Text.Wrap; Layout.fillWidth: true }
    }
}
