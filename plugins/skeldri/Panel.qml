import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "skeldri"
  ipcTarget: "skeldri"
  manageIpc: true

  property bool isRunning: false
  property bool isConnected: false
  property string clientName: "Waiting for iPad…"
  property int activePort: 52143
  property bool overlayVisible: true
  property int strokeCount: 0
  property var displays: []
  property var selectedDisplayId: 0
  property var statusData: null

  function refresh() {
    if (!statusProc.running) {
      statusProc.running = true
    }
  }

  function clearCanvas() {
    Quickshell.execDetached(["skeldri", "clear"])
    refreshTimer.start()
  }

  function toggleOverlay() {
    Quickshell.execDetached(["skeldri", "toggle"])
    refreshTimer.start()
  }

  function selectDisplay(displayId) {
    Quickshell.execDetached(["skeldri", "select-display", displayId.toString()])
    refreshTimer.start()
  }

  function stopDaemon() {
    Quickshell.execDetached(["skeldri", "stop"])
    root.close()
  }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    running: false
    command: ["skeldri", "status", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.statusData = data
          if (data && data.running) {
            root.isRunning = true
            root.isConnected = data.controlConnected || false
            root.clientName = data.clientName || "iPad Connected"
            root.activePort = data.port || 52143
            root.overlayVisible = data.overlayVisible !== false
            root.strokeCount = data.strokeCount || 0
            root.displays = data.displays || []
            root.selectedDisplayId = data.selectedDisplayId !== undefined ? data.selectedDisplayId : 0
          } else {
            root.isRunning = false
            root.isConnected = false
            root.clientName = "Daemon inactive"
          }
        } catch (e) {
          root.isRunning = false
          root.isConnected = false
        }
      }
    }
  }

  Timer {
    id: refreshTimer
    interval: 300
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // ---------- Bar Button ----------
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: (root.isConnected ? "🟢 " : "") + "✏️ DrawPad"
    tooltipText: "Skeldri DrawPad: " + (root.isConnected ? root.clientName : (root.isRunning ? "Listening on port " + root.activePort : "Inactive"))
    horizontalMargin: 7.5
    onPressed: function(b) {
      root.toggle()
    }
  }

  // ---------- Dropdown Popup Panel ----------
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // Header Section
        Row {
          width: parent.width
          spacing: Style.space(12)

          Text {
            text: "✏️"
            font.pixelSize: Style.font.title
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            width: parent.width - Style.space(120)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Skeldri DrawPad"
              color: Color.foreground
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: root.isConnected ? ("Connected to " + root.clientName) : (root.isRunning ? ("mDNS active (Port " + root.activePort + ")") : "Daemon not running")
              color: root.isConnected ? Color.accent : Color.muted
              font.pixelSize: Style.font.bodySmall
            }
          }

          Text {
            text: root.isConnected ? "LIVE" : (root.isRunning ? "READY" : "OFF")
            color: root.isConnected ? Color.accent : Color.muted
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        PanelSeparator {}

        // Active Monitor Selection
        Column {
          width: parent.width
          spacing: Style.space(6)

          Text {
            text: "MIRRORED DISPLAY"
            color: Color.muted
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.0
          }

          Repeater {
            model: root.displays
            delegate: Row {
              required property var modelData
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: (modelData.id === root.selectedDisplayId ? "▶ " : "  ") + (modelData.name || ("Display " + modelData.id)) + " (" + modelData.width + "x" + modelData.height + ")"
                color: modelData.id === root.selectedDisplayId ? Color.accent : Color.foreground
                font.pixelSize: Style.font.bodySmall
                font.bold: modelData.id === root.selectedDisplayId
                width: parent.width - Style.space(90)
                anchors.verticalCenter: parent.verticalCenter
              }

              Button {
                text: modelData.id === root.selectedDisplayId ? "Active" : "Switch"
                enabled: modelData.id !== root.selectedDisplayId
                bordered: true
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.selectDisplay(modelData.id)
              }
            }
          }
        }

        PanelSeparator {}

        // Canvas Actions
        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            width: (parent.width - Style.space(8)) / 2
            text: "Clear Canvas"
            bordered: true
            active: true
            onClicked: root.clearCanvas()
          }

          Button {
            width: (parent.width - Style.space(8)) / 2
            text: root.overlayVisible ? "Hide Overlay" : "Show Overlay"
            bordered: true
            onClicked: root.toggleOverlay()
          }
        }

        PanelSeparator {}

        // Footer Actions
        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            width: (parent.width - Style.space(8)) / 2
            text: "Refresh Status"
            bordered: true
            onClicked: root.refresh()
          }

          Button {
            width: (parent.width - Style.space(8)) / 2
            text: "Stop Daemon"
            bordered: true
            onClicked: root.stopDaemon()
          }
        }
      }
    }
  }
}
