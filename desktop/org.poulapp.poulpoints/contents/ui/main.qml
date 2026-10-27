import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    preferredRepresentation: fullRepresentation
    property var tasks: []
    property string selectedList: ""
    property var lists: ["Toutes les listes"]
    property double nowMs: Date.now()

    function isOverdue(task) {
        // La projection Flutter ne contient que les tâches non terminées.
        // Les échéances sont enregistrées en millisecondes Unix.
        return task && typeof task.due === "number" && isFinite(task.due) && task.due < root.nowMs
    }
    function overdueLabel(task) {
        if (!root.isOverdue(task)) return ""
        const due = new Date(task.due)
        const now = new Date(root.nowMs)
        // Comparer les jours calendaires locaux via UTC pour ignorer les jours
        // de 23 ou 25 heures au changement d’heure.
        const dueDay = Date.UTC(due.getFullYear(), due.getMonth(), due.getDate())
        const today = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate())
        const days = Math.round((today - dueDay) / 86400000)
        return days <= 0 ? "En retard" : "J+" + days
    }
    function overdueCount() {
        return root.tasks.filter(t => (root.selectedList === "" || t.list === root.selectedList) && root.isOverdue(t)).length
    }
    function visibleTasks() {
        const filtered = root.selectedList === "" ? root.tasks : root.tasks.filter(t => t.list === root.selectedList)
        // Prioriser les tâches en retard sans modifier l’ordre des autres.
        return filtered.map((task, index) => ({task: task, index: index}))
            .sort((a, b) => {
                const firstLate = root.isOverdue(a.task)
                const secondLate = root.isOverdue(b.task)
                return firstLate === secondLate ? a.index - b.index : (firstLate ? -1 : 1)
            }).map(entry => entry.task)
    }
    function dueText(task) {
        if (typeof task.due !== "number" || !isFinite(task.due)) return task.list
        const format = task.hasDueTime ? "dd/MM/yyyy hh:mm" : "dd/MM/yyyy"
        return task.list + " · " + new Date(task.due).toLocaleString(Qt.locale(), format)
    }
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
    Timer { interval: 60000; running: true; repeat: true; onTriggered: root.nowMs = Date.now() }
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
        Label {
            visible: root.overdueCount() > 0
            text: "⚠ " + root.overdueCount() + " tâche(s) en retard"
            color: Kirigami.Theme.negativeTextColor
            font.bold: true
            font.pointSize: 9
            Layout.fillWidth: true
        }
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
                model: root.visibleTasks()
                spacing: 12
                delegate: Item {
                    id: taskRow
                    required property var modelData
                    readonly property bool overdue: root.isOverdue(modelData)
                    readonly property string overdueTag: root.overdueLabel(modelData)
                    width: ListView.view.width
                    height: Math.max(50, taskInfo.implicitHeight + 12)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 4
                        radius: 2
                        visible: taskRow.overdue
                        color: Kirigami.Theme.negativeTextColor
                    }
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
                        Row {
                            width: parent.width
                            spacing: 6
                            Label {
                                width: Math.max(0, parent.width - (lateBadge.visible ? lateBadge.width + parent.spacing : 0))
                                text: taskRow.modelData.title
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                id: lateBadge
                                visible: taskRow.overdue
                                width: visible ? lateLabel.implicitWidth + 12 : 0
                                height: 21
                                radius: 6
                                color: Qt.rgba(1.0, 0.22, 0.22, 0.16)
                                Label {
                                    id: lateLabel
                                    anchors.centerIn: parent
                                    text: taskRow.overdueTag
                                    color: Kirigami.Theme.negativeTextColor
                                    font.bold: true
                                    font.pointSize: 9
                                }
                            }
                        }
                        Label {
                            width: parent.width
                            text: root.dueText(taskRow.modelData)
                            textFormat: Text.PlainText
                            font.pointSize: 9
                            color: taskRow.overdue ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                            opacity: taskRow.overdue ? 1.0 : 0.75
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
                        color: Kirigami.Theme.textColor
                        opacity: 0.12
                    }
                }
            }
        }
        Label { text: "Cocher termine la tâche sans ouvrir de fenêtre."; font.pointSize: 9; wrapMode: Text.Wrap; Layout.fillWidth: true }
    }
}
