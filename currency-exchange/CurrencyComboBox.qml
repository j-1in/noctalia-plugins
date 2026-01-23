import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

RowLayout {
  id: root

  property real minimumWidth: 280
  property real popupHeight: 180
  property ListModel model: ListModel {}
  property string currentKey: ""
  property string placeholder: ""
  property string searchPlaceholder: "Search..."

  readonly property real preferredHeight: Math.round(Style.baseWidgetSize * 1.1)

  signal selected(string key)

  // Filtered model for search results
  property ListModel filteredModel: ListModel {}
  property string searchText: ""

  function findIndexByKey(key) {
    if (!root.model)
      return -1;
    for (var i = 0; i < root.model.count; i++) {
      if (root.model.get(i).key === key) {
        return i;
      }
    }
    return -1;
  }

  // The active model used for the popup list (source model or filtered results)
  readonly property var activeModel: isFiltered ? filteredModel : root.model

  function findIndexInActiveModel(key) {
    if (!activeModel || activeModel.count === undefined)
      return -1;
    for (var i = 0; i < activeModel.count; i++) {
      if (activeModel.get(i).key === key) {
        return i;
      }
    }
    return -1;
  }

  // Whether we're using filtered results or the source model directly
  property bool isFiltered: false

  function filterModel() {
    // Check if model exists and has items
    if (!root.model || root.model.count === undefined || root.model.count === 0) {
      filteredModel.clear();
      isFiltered = false;
      return;
    }

    var query = searchText.trim();
    if (query === "") {
      // No search text - use source model directly, don't copy
      filteredModel.clear();
      isFiltered = false;
      return;
    }

    // We have search text - need to filter
    isFiltered = true;
    filteredModel.clear();

    // Convert ListModel to array for fuzzy search
    var items = [];
    for (var i = 0; i < root.model.count; i++) {
      items.push(root.model.get(i));
    }

    // Use fuzzy search if available, fallback to simple search
    if (typeof FuzzySort !== 'undefined') {
      var fuzzyResults = FuzzySort.go(query, items, {
                                        "key": "name",
                                        "threshold": -1000,
                                        "limit": 50
                                      });

      // Add results in order of relevance
      for (var j = 0; j < fuzzyResults.length; j++) {
        filteredModel.append(fuzzyResults[j].obj);
      }
    } else {
      // Fallback to simple search
      var searchLower = query.toLowerCase();
      for (var i = 0; i < items.length; i++) {
        var item = items[i];
        if (item.name.toLowerCase().includes(searchLower)) {
          filteredModel.append(item);
        }
      }
    }
  }

  onSearchTextChanged: filterModel()

  ComboBox {
    id: combo

    Layout.fillWidth: true
    Layout.minimumWidth: Math.round(root.minimumWidth * Style.uiScaleRatio)
    Layout.preferredHeight: Math.round(root.preferredHeight * Style.uiScaleRatio)
    model: root.activeModel
    currentIndex: findIndexInActiveModel(currentKey)
    onActivated: {
      if (combo.currentIndex >= 0 && root.activeModel && combo.currentIndex < root.activeModel.count) {
        root.selected(root.activeModel.get(combo.currentIndex).key);
      }
    }

    background: Rectangle {
      // implicitWidth: Math.round(Style.baseWidgetSize * 3.75 * Style.uiScaleRatio)
      implicitHeight: Math.round(root.preferredHeight * Style.uiScaleRatio)
      color: Color.mSurface
      border.color: combo.activeFocus ? Color.mSecondary : Color.mOutline
      border.width: Style.borderS
      radius: Style.iRadiusM

      Behavior on border.color {
        ColorAnimation {
          duration: Style.animationFast
        }
      }
    }

    contentItem: NText {
      leftPadding: Style.marginL
      rightPadding: combo.indicator.width + Style.marginL
      pointSize: Style.fontSizeM
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight

      // Look up current selection directly in source model by key
      readonly property int sourceIndex: root.findIndexByKey(root.currentKey)
      readonly property bool hasSelection: root.model && sourceIndex >= 0 && sourceIndex < root.model.count

      color: hasSelection ? Color.mOnSurface : Color.mOnSurfaceVariant
      text: hasSelection ? root.model.get(sourceIndex).name : root.placeholder
    }

    indicator: NIcon {
      x: combo.width - width - Style.marginM
      y: combo.topPadding + (combo.availableHeight - height) / 2
      icon: "caret-down"
      pointSize: Style.fontSizeL
    }

    popup: Popup {
      y: combo.height + Style.marginS
      width: combo.width
      height: Math.round((root.popupHeight + 60) * Style.uiScaleRatio)
      padding: Style.marginM

      contentItem: ColumnLayout {
        spacing: Style.marginS

        // Search input
        NTextInput {
          id: searchInput
          inputIconName: "search"
          Layout.fillWidth: true
          placeholderText: root.searchPlaceholder
          text: root.searchText
          onTextChanged: root.searchText = text
          fontSize: Style.fontSizeS
        }

        NListView {
          id: listView
          Layout.fillWidth: true
          Layout.fillHeight: true
          // Use activeModel (source model when not filtering, filtered results when searching)
          model: combo.popup.visible ? root.activeModel : null
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded

          delegate: ItemDelegate {
            id: delegateRoot
            width: listView.width
            leftPadding: Style.marginM
            rightPadding: Style.marginM
            topPadding: Style.marginS
            bottomPadding: Style.marginS
            hoverEnabled: true
            highlighted: ListView.view.currentIndex === index

            onHoveredChanged: {
              if (hovered) {
                ListView.view.currentIndex = index;
              }
            }

            onClicked: {
              var selectedKey = listView.model.get(index).key;
              root.selected(selectedKey);
              combo.popup.close();
            }

            contentItem: NText {
              text: name
              pointSize: Style.fontSizeM
              color: highlighted ? Color.mOnHover : Color.mOnSurface
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight

              Behavior on color {
                ColorAnimation {
                  duration: Style.animationFast
                }
              }
            }

            background: Rectangle {
              anchors.fill: parent
              color: highlighted ? Color.mHover : "transparent"
              radius: Style.iRadiusS

              Behavior on color {
                ColorAnimation {
                  duration: Style.animationFast
                }
              }
            }
          }
        }
      }

      background: Rectangle {
        color: Color.mSurfaceVariant
        border.color: Color.mOutline
        border.width: Style.borderS
        radius: Style.iRadiusM
      }
    }

    // Update the currentIndex if the currentKey is changed externally
    Connections {
      target: root
      function onCurrentKeyChanged() {
        combo.currentIndex = root.findIndexInActiveModel(root.currentKey);
      }
    }

    // Focus search input when popup opens and ensure model is filtered
    Connections {
      target: combo.popup
      function onVisibleChanged() {
        if (combo.popup.visible) {
          // Ensure the model is filtered when popup opens
          filterModel();
          // Small delay to ensure the popup is fully rendered
          Qt.callLater(() => {
                         if (searchInput && searchInput.inputItem) {
                           searchInput.inputItem.forceActiveFocus();
                         }
                       });
        }
      }
    }
  }
}
