import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets
import qs.Services.UI

FloatingWindow {
  id: root

  property var pluginApi: null
  readonly property var mainInstance: pluginApi?.mainInstance

  width: 500
  height: 600
  visible: false

  color: "transparent"
  mask: Region { item: windowContent }

  NFilePicker {
    id: filePicker
    selectionMode: "files"
    title: pluginApi?.tr("taildrop.select-files") || "Select Files to Send"
    initialPath: Quickshell.env("HOME")
    onAccepted: paths => {
      if (paths.length > 0) {
        root.pendingFiles = paths
      }
    }
  }

  readonly property var sortedPeerList: {
    if (!mainInstance?.peerList) return []
    var peers = mainInstance.peerList.slice()
    
    // Only show online peers that are not tagged
    peers = peers.filter(function(peer) {
      return peer.Online === true && (!peer.Tags || peer.Tags.length === 0)
    })
    
    peers.sort(function(a, b) {
      var nameA = (a.HostName || a.DNSName || "").toLowerCase()
      var nameB = (b.HostName || b.DNSName || "").toLowerCase()
      return nameA.localeCompare(nameB)
    })
    return peers
  }

  function filterIPv4(ips) {
    return mainInstance?.filterIPv4(ips) || []
  }

  function getOSIcon(os) {
    if (!os) return "device-desktop"
    switch (os.toLowerCase()) {
      case "linux":
        return "brand-debian"
      case "macos":
        return "brand-apple"
      case "ios":
        return "device-mobile"
      case "android":
        return "device-mobile"
      case "windows":
        return "brand-windows"
      default:
        return "device-desktop"
    }
  }

  property var selectedPeer: null
  property string selectedPeerHostname: ""
  property var pendingFiles: []
  property bool isTransferring: false
  property string transferStatus: ""

  Process {
    id: fileTransferProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode, exitStatus) {
      root.isTransferring = false
      if (exitCode === 0) {
        var hostname = root.selectedPeer?.HostName || "device"
        var message = (pluginApi?.tr("taildrop.transfer-success.message") || "Files successfully sent to %1").replace("%1", hostname)
        ToastService.showNotice(
          pluginApi?.tr("taildrop.transfer-success.title") || "Files Sent",
          message,
          "check"
        )
        root.pendingFiles = []
        root.transferStatus = ""
        // Keep window open and selection intact for sending more files
      } else {
        var stderr = String(fileTransferProcess.stderr.text || "").trim()
        ToastService.showError(
          pluginApi?.tr("taildrop.transfer-error.title") || "Transfer Failed",
          stderr || (pluginApi?.tr("taildrop.transfer-error.message") || "Failed to send files"),
          "alert-circle"
        )
        root.transferStatus = ""
      }
    }
  }

  function sendFiles() {
    if (!selectedPeer || pendingFiles.length === 0) return
    
    isTransferring = true
    transferStatus = pluginApi?.tr("taildrop.transferring") || "Sending files..."
    
    var target = filterIPv4(selectedPeer.TailscaleIPs)[0] || selectedPeer.HostName
    var args = ["file", "cp"]
    
    for (var i = 0; i < pendingFiles.length; i++) {
      args.push(pendingFiles[i])
    }
    
    args.push(target + ":")
    
    fileTransferProcess.command = ["tailscale"].concat(args)
    fileTransferProcess.running = true
  }

  Rectangle {
    id: windowContent
    anchors.fill: parent
    color: Color.mSurface
    radius: Style.radiusL
    border.width: 1
    border.color: Color.mOutline

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginL

      // Header
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIcon {
          icon: "send"
          pointSize: Style.fontSizeL
          color: Color.mPrimary
        }

        NText {
          text: pluginApi?.tr("taildrop.title") || "Send Files via Taildrop"
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightBold
          color: Color.mOnSurface
          Layout.fillWidth: true
        }

        NIconButton {
          icon: "x"
          onClicked: root.visible = false
        }
      }

      // Device selection
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: 200

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          NText {
            text: pluginApi?.tr("taildrop.select-device") || "Select a device:"
            pointSize: Style.fontSizeM
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurface
          }

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: deviceColumn.height
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
              id: deviceColumn
              width: parent.width
              spacing: Style.marginS

              Repeater {
                model: root.sortedPeerList

                delegate: ItemDelegate {
                  id: deviceDelegate
                  Layout.fillWidth: true
                  height: 48
                  topPadding: Style.marginS
                  bottomPadding: Style.marginS
                  leftPadding: Style.marginM
                  rightPadding: Style.marginM

                  readonly property var peerData: modelData
                  readonly property string peerHostname: peerData.HostName || peerData.DNSName || "Unknown"
                  readonly property bool isSelected: root.selectedPeerHostname === peerHostname

                  background: Rectangle {
                    anchors.fill: parent
                    color: deviceDelegate.isSelected 
                      ? Qt.alpha(Color.mPrimary, 0.2)
                      : (deviceDelegate.hovered ? Qt.alpha(Color.mPrimary, 0.1) : "transparent")
                    radius: Style.radiusM
                    border.width: deviceDelegate.isSelected ? 2 : (deviceDelegate.hovered ? 1 : 0)
                    border.color: deviceDelegate.isSelected ? Color.mPrimary : Qt.alpha(Color.mPrimary, 0.3)
                  }

                  contentItem: RowLayout {
                    spacing: Style.marginM

                    NIcon {
                      icon: root.getOSIcon(deviceDelegate.peerData.OS)
                      pointSize: Style.fontSizeM
                      color: deviceDelegate.isSelected ? Color.mPrimary : Color.mOnSurface
                    }

                    NText {
                      text: deviceDelegate.peerHostname
                      color: deviceDelegate.isSelected ? Color.mPrimary : Color.mOnSurface
                      font.weight: deviceDelegate.isSelected ? Style.fontWeightBold : Style.fontWeightMedium
                      Layout.fillWidth: true
                    }

                    NIcon {
                      icon: "check"
                      pointSize: Style.fontSizeS
                      color: Color.mPrimary
                      visible: deviceDelegate.isSelected
                    }
                  }

                  onClicked: {
                    root.selectedPeer = deviceDelegate.peerData
                    root.selectedPeerHostname = deviceDelegate.peerHostname
                  }
                }
              }

              NText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Style.marginL
                text: pluginApi?.tr("taildrop.no-devices") || "No online devices available"
                visible: root.sortedPeerList.length === 0
                pointSize: Style.fontSizeM
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }
        }
      }

      // Drop zone
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: dropArea.containsDrag ? Qt.alpha(Color.mPrimary, 0.1) : Qt.alpha(Color.mSurfaceVariant, 0.5)
        radius: Style.radiusM
        border.width: 2
        border.color: dropArea.containsDrag ? Color.mPrimary : Qt.alpha(Color.mOutline, 0.3)

        DropArea {
          id: dropArea
          anchors.fill: parent

          onDropped: function(drop) {
            if (drop.hasUrls) {
              var files = []
              for (var i = 0; i < drop.urls.length; i++) {
                var url = drop.urls[i].toString()
                if (url.startsWith("file://")) {
                  files.push(url.substring(7))
                }
              }
              root.pendingFiles = files
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          enabled: !root.isTransferring
          onClicked: {
            filePicker.openFilePicker()
          }
        }

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.marginM
          width: parent.width - Style.marginL * 2

          NIcon {
            icon: root.pendingFiles.length > 0 ? "files" : "upload"
            pointSize: Style.fontSizeXL * 2
            color: dropArea.containsDrag ? Color.mPrimary : Color.mOnSurfaceVariant
            Layout.alignment: Qt.AlignHCenter
          }

          NText {
            text: {
              if (root.isTransferring) {
                return root.transferStatus
              } else if (root.pendingFiles.length > 0) {
                return (pluginApi?.tr("taildrop.files-ready") || "%1 file(s) ready to send").replace("%1", root.pendingFiles.length)
              } else if (dropArea.containsDrag) {
                return pluginApi?.tr("taildrop.drop-here") || "Drop files here"
              } else {
                return pluginApi?.tr("taildrop.drop-zone") || "Click to browse or drag files here"
              }
            }
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightMedium
            color: dropArea.containsDrag ? Color.mPrimary : Color.mOnSurface
            Layout.alignment: Qt.AlignHCenter
          }

          NText {
            text: root.pendingFiles.length > 0 
              ? root.pendingFiles.join("\n")
              : (pluginApi?.tr("taildrop.drop-hint") || "Multiple file selection supported")
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            visible: !root.isTransferring
            elide: Text.ElideMiddle
            maximumLineCount: 5
          }

          NButton {
            text: pluginApi?.tr("taildrop.clear-files") || "Clear Files"
            icon: "x"
            visible: root.pendingFiles.length > 0 && !root.isTransferring
            onClicked: root.pendingFiles = []
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }

      // Action buttons
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NButton {
          text: pluginApi?.tr("taildrop.cancel") || "Cancel"
          Layout.fillWidth: true
          enabled: !root.isTransferring
          onClicked: {
            root.visible = false
            root.pendingFiles = []
            root.selectedPeer = null
            root.selectedPeerHostname = ""
            root.transferStatus = ""
          }
        }

        NButton {
          text: pluginApi?.tr("taildrop.send") || "Send Files"
          icon: "send"
          backgroundColor: Color.mPrimary
          textColor: Color.mOnPrimary
          Layout.fillWidth: true
          enabled: root.selectedPeer !== null && root.pendingFiles.length > 0 && !root.isTransferring
          onClicked: root.sendFiles()
        }
      }
    }
  }
}
